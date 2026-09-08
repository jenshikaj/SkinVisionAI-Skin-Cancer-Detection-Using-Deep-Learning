"""
routers/analysis.py
────────────────────
POST /api/v1/analyze
  • Accepts a multipart image upload
  • Uploads to Cloudinary
  • Runs SkinFusionNet inference
  • Generates RAG insights
  • Returns a unified JSON response consumed by the Flutter app

"""

import asyncio
import io
import logging
import os

import httpx
from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import Image

from model.loader import predict
from .gpt_insights import generate_insights

logger = logging.getLogger(__name__)
router = APIRouter()

# ── Cloudinary config (optional) ─────────────────────────────────────────────
CLOUDINARY_UPLOAD_URL = (
    f"https://api.cloudinary.com/v1_1/"
    f"{os.environ.get('CLOUDINARY_CLOUD_NAME', 'defb9fgsy')}/image/upload"
)
CLOUDINARY_PRESET = os.environ.get("CLOUDINARY_UPLOAD_PRESET", "skinvisionai_uploads")

# Allowed image content types
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp", "application/octet-stream", ""}
MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024   # 10 MB


# ── Cloudinary upload (non-blocking) ─────────────────────────────────────────
async def upload_to_cloudinary(image_bytes: bytes, filename: str) -> str | None:
    """
    Uploads image bytes to Cloudinary and returns the secure URL.
    Returns None if upload fails (analysis continues without it).
    """
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                CLOUDINARY_UPLOAD_URL,
                data={
                    "upload_preset": CLOUDINARY_PRESET,
                    "folder": "skinvision/scans",
                },
                files={"file": (filename, image_bytes, "image/jpeg")},
            )
            if response.status_code == 200:
                return response.json().get("secure_url")
            else:
                logger.warning(f"Cloudinary upload failed: {response.status_code} {response.text[:200]}")
                return None
    except Exception as e:
        logger.warning(f"Cloudinary upload error (non-fatal): {e}")
        return None


# ── POST /api/v1/analyze ──────────────────────────────────────────────────────
@router.post("/analyze")
async def analyze_image(file: UploadFile = File(...)):
    """
    Analyze a skin image:
    1. Validate & load image
    2. Run SkinFusionNet inference (CPU/GPU)
    3. Generate GPT insights
    4. Upload to Cloudinary (best-effort)
    5. Return combined JSON
    """

    # ── 1. Validate file ─────────────────────────────────────────────────────
    content_type = file.content_type or ""
    # Some mobile clients (Android) send application/octet-stream or no content type.
    # We validate by actually decoding the image with PIL instead of trusting the header.
    if content_type and content_type not in ALLOWED_CONTENT_TYPES and not content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{content_type}'. Upload a JPEG, PNG, or WebP image.",
        )

    image_bytes = await file.read()

    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    if len(image_bytes) > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image too large ({len(image_bytes) // 1024} KB). Maximum is 10 MB.",
        )

    # ── 2. Decode image ──────────────────────────────────────────────────────
    try:
        pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Could not decode image: {e}")

    # ── 3. SkinFusionNet inference (blocking → run in thread) ─────────────────
    try:
        prediction = await asyncio.to_thread(predict, pil_image)
    except FileNotFoundError as e:
        # Model checkpoint not found
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.exception("SkinFusionNet inference failed")
        raise HTTPException(status_code=500, detail=f"Model inference error: {e}")

    # ── 4. GPT insights (blocking → run in thread) ────────────────────────────
    try:
        insights = await asyncio.to_thread(
            generate_insights,
            prediction["disease_code"],
            prediction["disease"],
            prediction["stage"],
            prediction["disease_confidence"],
        )
    except Exception as e:
        logger.warning(f"RAG insights failed (non-fatal): {e}")
        insights = {}

    # ── 5. Cloudinary upload (fire-and-forget; don't block response) ──────────
    image_url = await upload_to_cloudinary(image_bytes, file.filename or "scan.jpg")

    # ── 6. Build & return response ────────────────────────────────────────────
    insights_payload = {
        "disease":            prediction["disease"],
        "disease_confidence": prediction["disease_confidence"],
        "stage":              prediction["stage"],
        "stage_confidence":   prediction["stage_confidence"],
        **insights,   # summary, definition, causes, symptoms, self_care, red_flags, etc.
    }

    return {
        **prediction,                   # disease, disease_code, disease_id, confidences, top_k
        "image_url": image_url,         # Cloudinary URL (may be null)
        "insights":  insights_payload,  # Full insights for DiseaseInsightsScreen
    }