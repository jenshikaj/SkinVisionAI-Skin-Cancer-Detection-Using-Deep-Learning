"""
Singleton that loads SkinFusionNet once at startup and keeps it in memory.
Falls back to CPU if CUDA is unavailable.

"""

import os
import logging
from functools import lru_cache

import torch
import torch.nn.functional as F
import torchvision.transforms as T
from PIL import Image

from .skinfusionnet import SkinFusionNet

logger = logging.getLogger(__name__)

# ── Constants (must match training notebook) ──────────────────────────────────
IMG_SIZE = 224
MEAN = [0.485, 0.456, 0.406]
STD  = [0.229, 0.224, 0.225]

ALL_CLASSES     = ['NV', 'MEL', 'BKL', 'BCC', 'AKIEC', 'VASC', 'DF', 'NORMAL']
STAGES          = ['mild', 'moderate', 'severe']
NORMAL_CLASS_ID = ALL_CLASSES.index('NORMAL')

# Friendly display names for Flutter UI
DISEASE_DISPLAY = {
    'NV':     'Melanocytic Nevus',
    'MEL':    'Melanoma',
    'BKL':    'Benign Keratosis',
    'BCC':    'Basal Cell Carcinoma',
    'AKIEC':  'Actinic Keratosis',
    'VASC':   'Vascular Lesion',
    'DF':     'Dermatofibroma',
    'NORMAL': 'Normal Skin',
}

# ── Preprocessing transform (matches training) ────────────────────────────────
inference_transform = T.Compose([
    T.Resize((IMG_SIZE, IMG_SIZE), interpolation=T.InterpolationMode.BILINEAR),
    T.ToTensor(),
    T.Normalize(mean=MEAN, std=STD),
])


# ── Model loader (singleton via lru_cache) ────────────────────────────────────
@lru_cache(maxsize=1)
def get_model() -> tuple[SkinFusionNet, torch.device]:
    """
    Loads the SkinFusionNet checkpoint once and caches it.
    Returns (model, device).
    """
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    logger.info(f"Loading SkinFusionNet on {device} ...")

    model = SkinFusionNet(
        backbone_name="efficientnet_b4",
        num_disease_cls=len(ALL_CLASSES),
        num_stage_cls=len(STAGES),
        path_dim=256,
        dropout=0.45,
        pretrained=False,
    )

    ckpt_path = os.environ.get(
        "MODEL_CHECKPOINT",
        os.path.join(os.path.dirname(__file__), "checkpoints", "skinfusionnet_best.pth"),
    )

    if not os.path.exists(ckpt_path):
        raise FileNotFoundError(
            f"Checkpoint not found at {ckpt_path}. "
            "Set MODEL_CHECKPOINT env var or place the .pt file at model/checkpoints/skinfusionnet_best.pt"
        )

    # weights_only=False: our own trusted checkpoint contains numpy scalars
    # (metrics/epoch), which the PyTorch 2.6+ default (weights_only=True) rejects.
    checkpoint = torch.load(ckpt_path, map_location=device, weights_only=False)

    # Support all common checkpoint formats
    if isinstance(checkpoint, dict) and "model_state" in checkpoint:
        state_dict = checkpoint["model_state"]
    elif isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
        state_dict = checkpoint["model_state_dict"]
    elif isinstance(checkpoint, dict) and "state_dict" in checkpoint:
        state_dict = checkpoint["state_dict"]
    else:
        state_dict = checkpoint

    model.load_state_dict(state_dict, strict=True)
    model.to(device)
    model.eval()

    logger.info("SkinFusionNet loaded successfully ✓")
    return model, device


# ── Inference helper ──────────────────────────────────────────────────────────
def predict(pil_image: Image.Image) -> dict:
    """
    Run SkinFusionNet inference on a PIL Image.

    Returns a dict with:
      disease, disease_id, disease_confidence,
      stage, stage_confidence,
      top_k_predictions (list of {class, confidence})
    """
    model, device = get_model()

    img_t = inference_transform(pil_image.convert("RGB")).unsqueeze(0).to(device)

    with torch.no_grad():
        d_logits, s_logits = model(img_t)

    d_prob = F.softmax(d_logits, dim=1)[0]   # (8,)
    s_prob = F.softmax(s_logits, dim=1)[0]   # (3,)

    pred_id  = int(d_prob.argmax().item())
    pred_cls = ALL_CLASSES[pred_id]
    conf     = float(d_prob[pred_id].item()) * 100.0   # percent

    if pred_id != NORMAL_CLASS_ID:
        stage_id   = int(s_prob.argmax().item())
        stage_lbl  = STAGES[stage_id]
        stage_conf = float(s_prob[stage_id].item()) * 100.0
    else:
        stage_id, stage_lbl, stage_conf = -1, "N/A", 100.0

    # Top-5 predictions
    topk_v, topk_i = d_prob.topk(min(5, len(ALL_CLASSES)))
    top_k = [
        {"class": ALL_CLASSES[int(i)], "confidence": float(v) * 100.0}
        for i, v in zip(topk_i.tolist(), topk_v.tolist())
    ]

    return {
        "disease":             DISEASE_DISPLAY.get(pred_cls, pred_cls),
        "disease_code":        pred_cls,
        "disease_id":          pred_id,
        "disease_confidence":  round(conf, 2),
        "stage":               stage_lbl,
        "stage_confidence":    round(stage_conf, 2),
        "top_k_predictions":   top_k,
    }