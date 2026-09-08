"""
routers/gpt_insights.py
────────────────────────
Generates structured dermatology insights from RAG given a skin disease prediction from SkinFusionNet.

Returns a dict whose keys map 1-to-1 with DiseaseInsightsScreen fields:
  summary, definition, causes, symptoms, self_care, red_flags, when_to_seek_care, next_steps
  
"""

import os
import json
import logging
from openai import OpenAI

logger = logging.getLogger(__name__)

client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))

# ── Disease metadata for richer prompts ──────────────────────────────────────
DISEASE_CONTEXT = {
    "NV": "Melanocytic Nevi (common moles)",
    "MEL": "Melanoma (skin cancer)",
    "BKL": "Benign Keratosis (seborrheic keratosis or solar lentigo)",
    "BCC": "Basal Cell Carcinoma (most common skin cancer)",
    "AKIEC": "Actinic Keratosis / Intraepithelial Carcinoma (pre-cancerous lesion)",
    "VASC": "Vascular Lesion (angioma, pyogenic granuloma, etc.)",
    "DF": "Dermatofibroma (benign fibrous nodule)",
    "NORMAL": "Normal Skin (no apparent condition detected)",
}


def generate_insights(
    disease_code: str,
    disease_display: str,
    stage: str,
    disease_confidence: float,
) -> dict:
    """
    Call GPT-4o-mini to generate patient-facing insights for the detected condition.
    Returns a structured dict with all DiseaseInsightsScreen fields.
    """
    context_desc = DISEASE_CONTEXT.get(disease_code, disease_display)
    is_normal = disease_code == "NORMAL"

    stage_text = f"Severity stage: {stage}." if stage not in ("N/A", "") else ""

    system_prompt = (
        "You are an educational dermatology assistant. "
        "Your job is to provide clear, accurate, non-prescriptive information "
        "about skin conditions for general users of a mobile health app.\n\n"
        "STRICT RULES:\n"
        "- Do NOT provide a diagnosis or say the user definitely has the condition.\n"
        "- Do NOT recommend specific drug names, dosages, or prescriptions.\n"
        "- Always recommend consulting a qualified dermatologist for diagnosis and treatment.\n"
        "- Keep language simple, friendly, and reassuring.\n"
        "- Return ONLY valid JSON — no markdown, no preamble, no backticks.\n\n"
        "The JSON must have exactly these keys:\n"
        "  summary (string, 2-3 sentences overview)\n"
        "  definition (string, 2-4 sentences what it is)\n"
        "  causes (string, 2-4 sentences why it happens)\n"
        "  symptoms (array of 3-6 short strings)\n"
        "  self_care (array of 3-6 short actionable strings)\n"
        "  red_flags (array of 3-5 short warning signs requiring urgent care)\n"
        "  when_to_seek_care (array of 3-5 short strings)\n"
        "  next_steps (array of 3-5 short recommended actions)"
    )

    if is_normal:
        user_prompt = (
            "The AI model analyzed a skin image and detected: NORMAL SKIN "
            "(no apparent skin condition detected, confidence: "
            f"{disease_confidence:.1f}%).\n\n"
            "Generate educational insights reassuring the user their skin appears healthy, "
            "but reminding them of good skin health practices and when to see a doctor."
        )
    else:
        user_prompt = (
            f"The AI model detected: {context_desc}\n"
            f"{stage_text}\n"
            f"Detection confidence: {disease_confidence:.1f}%\n\n"
            f"Generate educational insights about {disease_display} for a general user. "
            "Be informative but remind them this is NOT a diagnosis and they should "
            "consult a dermatologist."
        )

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            max_tokens=1200,
            temperature=0.4,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user",   "content": user_prompt},
            ],
        )
        raw = response.choices[0].message.content
        insights = json.loads(raw)
        return _validate_and_fill(insights, disease_display, stage)

    except json.JSONDecodeError as e:
        logger.error(f"GPT returned invalid JSON: {e}")
        return _fallback_insights(disease_display, stage)
    except Exception as e:
        logger.error(f"GPT insights generation failed: {e}")
        return _fallback_insights(disease_display, stage)


def _validate_and_fill(data: dict, disease: str, stage: str) -> dict:
    """Ensure all required keys exist with correct types."""
    required_str  = ["summary", "definition", "causes"]
    required_list = ["symptoms", "self_care", "red_flags", "when_to_seek_care", "next_steps"]

    for key in required_str:
        if not isinstance(data.get(key), str) or not data[key].strip():
            data[key] = f"Information about {disease} is not available at this time."

    for key in required_list:
        if not isinstance(data.get(key), list) or len(data[key]) == 0:
            data[key] = ["Please consult a dermatologist for detailed information."]

    return data


def _fallback_insights(disease: str, stage: str) -> dict:
    """Return a safe fallback when GPT fails."""
    return {
        "summary": (
            f"The AI model has detected a possible skin condition: {disease}. "
            "This is not a medical diagnosis. Please consult a qualified dermatologist."
        ),
        "definition": f"{disease} is a skin condition that requires professional evaluation.",
        "causes": "Various factors including genetics, sun exposure, and skin type can contribute.",
        "symptoms": [
            "Changes in skin appearance",
            "Unusual texture or coloration",
            "Consult a doctor for a proper symptom assessment",
        ],
        "self_care": [
            "Keep the area clean and moisturized",
            "Avoid sun exposure and use SPF 30+ sunscreen",
            "Do not pick or scratch the affected area",
            "Document any changes with photos over time",
        ],
        "red_flags": [
            "Rapid change in size, shape, or colour",
            "Bleeding or oozing from the lesion",
            "Significant pain or itching",
            "Spreading to nearby skin",
        ],
        "when_to_seek_care": [
            "If the lesion changes rapidly",
            "If you notice new or unusual skin growths",
            "If the area bleeds, oozes, or does not heal",
            "Whenever you are concerned about your skin health",
        ],
        "next_steps": [
            "Schedule an appointment with a dermatologist",
            "Share this AI report with your doctor",
            "Avoid self-treating without professional guidance",
            "Take photos to track any changes over time",
        ],
    }