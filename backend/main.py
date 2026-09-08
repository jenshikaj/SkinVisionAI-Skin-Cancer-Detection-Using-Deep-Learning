"""
main.py — SkinVision AI Backend
────────────────────────────────
Routes:
  GET  /                    → health check
  GET  /health              → health check
  POST /api/v1/analyze      → skin image analysis (SkinFusionNet + dermatology insights)
  POST /api/v1/chat         → RAG dermatology chat
  
"""

import logging
import os

from dotenv import load_dotenv
load_dotenv(override=True)  # must be before any module that reads env vars; override stale OS-level vars

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.analysis import router as analysis_router
from chat_router import router as chat_router

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

# ── FastAPI app ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="SkinVision AI Backend",
    description="SkinFusionNet image analysis + RAG dermatology chat",
    version="2.0.0",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(analysis_router, prefix="/api/v1")
app.include_router(chat_router,     prefix="/api/v1")


# ── Startup: pre-load model ───────────────────────────────────────────────────
@app.on_event("startup")
async def startup_event():
    """Pre-load SkinFusionNet at startup so the first request is fast."""
    try:
        from model.loader import get_model
        get_model()
        logger.info("SkinFusionNet pre-loaded at startup ✓")
    except FileNotFoundError as e:
        logger.warning(f"Checkpoint not found — model will fail on first request: {e}")
    except Exception as e:
        logger.error(f"Startup model load failed: {e}")


# ── Health endpoints ──────────────────────────────────────────────────────────
@app.get("/")
async def root():
    return {"status": "ok", "message": "SkinVision AI backend is running ✅"}


@app.get("/health")
async def health():
    return {"status": "healthy"}