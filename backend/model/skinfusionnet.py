"""
model/skinfusionnet.py
─────────────────────
SkinFusionNet v3 architecture — exactly matches the training notebook.
EfficientNet-B4 backbone + Multi-Scale DualPath (CBAM + ASPP) + ResNeck + TempScale.

Classes  : ['NV', 'MEL', 'BKL', 'BCC', 'AKIEC', 'VASC', 'DF', 'NORMAL']
Stages   : ['mild', 'moderate', 'severe']
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import timm


# ── Squeeze-and-Excitation ────────────────────────────────────────────────────
class SEBlock(nn.Module):
    def __init__(self, channels, reduction=16):
        super().__init__()
        mid = max(channels // reduction, 8)
        self.se = nn.Sequential(
            nn.AdaptiveAvgPool2d(1), nn.Flatten(),
            nn.Linear(channels, mid), nn.ReLU(inplace=True),
            nn.Linear(mid, channels), nn.Sigmoid(),
        )

    def forward(self, x):
        return x * self.se(x).unsqueeze(-1).unsqueeze(-1)


# ── Spatial Attention ─────────────────────────────────────────────────────────
class SpatialAttention(nn.Module):
    def __init__(self, kernel_size=7):
        super().__init__()
        self.conv = nn.Conv2d(2, 1, kernel_size, padding=kernel_size // 2, bias=False)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        avg = x.mean(dim=1, keepdim=True)
        mx, _ = x.max(dim=1, keepdim=True)
        return x * self.sigmoid(self.conv(torch.cat([avg, mx], dim=1)))


# ── Full CBAM (channel + spatial) ─────────────────────────────────────────────
class CBAM(nn.Module):
    def __init__(self, channels, reduction=16, kernel_size=7):
        super().__init__()
        self.channel = SEBlock(channels, reduction)
        self.spatial = SpatialAttention(kernel_size)

    def forward(self, x):
        return self.spatial(self.channel(x))


# ── ASPP-style triple-dilated global branch ───────────────────────────────────
class ASPPModule(nn.Module):
    def __init__(self, in_c, out_c):
        super().__init__()
        mid = out_c // 4
        self.d1 = nn.Sequential(
            nn.Conv2d(in_c, mid, 3, padding=2, dilation=2, bias=False),
            nn.BatchNorm2d(mid), nn.ReLU(inplace=True))
        self.d2 = nn.Sequential(
            nn.Conv2d(in_c, mid, 3, padding=4, dilation=4, bias=False),
            nn.BatchNorm2d(mid), nn.ReLU(inplace=True))
        self.d3 = nn.Sequential(
            nn.Conv2d(in_c, mid, 3, padding=6, dilation=6, bias=False),
            nn.BatchNorm2d(mid), nn.ReLU(inplace=True))
        self.gap = nn.Sequential(
            nn.AdaptiveAvgPool2d(1),
            nn.Conv2d(in_c, mid, 1, bias=False),
            nn.BatchNorm2d(mid), nn.ReLU(inplace=True))
        self.proj = nn.Sequential(
            nn.Conv2d(mid * 4, out_c, 1, bias=False),
            nn.BatchNorm2d(out_c), nn.ReLU(inplace=True))

    def forward(self, x):
        h, w = x.shape[2:]
        g = F.interpolate(self.gap(x), size=(h, w), mode='bilinear', align_corners=False)
        return self.proj(torch.cat([self.d1(x), self.d2(x), self.d3(x), g], dim=1))


# ── Multi-Scale DualPathModule ────────────────────────────────────────────────
class DualPathModule(nn.Module):
    def __init__(self, in_c, out_dim=256):
        super().__init__()
        self.local_branch = nn.Sequential(
            nn.Conv2d(in_c, out_dim, 1, bias=False),
            nn.BatchNorm2d(out_dim), nn.ReLU(inplace=True),
            CBAM(out_dim),
        )
        self.global_branch = ASPPModule(in_c, out_dim)
        self.gap = nn.AdaptiveAvgPool2d(1)

    def forward(self, x):
        loc = self.gap(self.local_branch(x)).flatten(1)
        glo = self.gap(self.global_branch(x)).flatten(1)
        return torch.cat([loc, glo], dim=1)


# ── SkinFusionNet v3 ──────────────────────────────────────────────────────────
class SkinFusionNet(nn.Module):
    """
    Multi-scale feature fusion:
      - Stage 3 features (mid-level): capture lesion shape & colour
      - Stage 4 features (deep):      capture high-level semantic class info
    Temperature parameter τ on disease logits suppresses overconfidence.
    """

    def __init__(
        self,
        backbone_name: str = "efficientnet_b4",
        num_disease_cls: int = 8,
        num_stage_cls: int = 3,
        path_dim: int = 256,
        dropout: float = 0.45,
        pretrained: bool = False,   # False for inference (weights loaded from checkpoint)
    ):
        super().__init__()

        self.backbone = timm.create_model(
            backbone_name, pretrained=pretrained,
            features_only=True, out_indices=[3, 4]
        )
        with torch.no_grad():
            feats = self.backbone(torch.zeros(1, 3, 224, 224))
            in_c3 = feats[0].shape[1]
            in_c4 = feats[1].shape[1]

        self.dual_path3 = DualPathModule(in_c3, path_dim)
        self.dual_path4 = DualPathModule(in_c4, path_dim)

        neck_in = path_dim * 4
        neck_mid = 512
        self.neck = nn.Sequential(
            nn.Linear(neck_in, neck_mid),
            nn.LayerNorm(neck_mid), nn.GELU(), nn.Dropout(dropout),
            nn.Linear(neck_mid, neck_mid),
            nn.LayerNorm(neck_mid), nn.GELU(), nn.Dropout(dropout * 0.5),
        )
        self.neck_skip = nn.Linear(neck_in, neck_mid, bias=False)

        self.disease_head = nn.Sequential(
            nn.Linear(neck_mid, 256), nn.ReLU(inplace=True),
            nn.Dropout(dropout * 0.5),
            nn.Linear(256, num_disease_cls),
        )
        self.stage_head = nn.Sequential(
            nn.Linear(neck_mid, 128), nn.ReLU(inplace=True),
            nn.Dropout(dropout * 0.5),
            nn.Linear(128, num_stage_cls),
        )

        self.log_temp = nn.Parameter(torch.zeros(1))

    def forward(self, x):
        f3, f4 = self.backbone(x)
        feat3 = self.dual_path3(f3)
        feat4 = self.dual_path4(f4)
        fused = torch.cat([feat3, feat4], 1)
        neck_out = self.neck(fused) + self.neck_skip(fused)
        temp = self.log_temp.exp().clamp(min=0.5, max=5.0)
        d_logits = self.disease_head(neck_out) / temp
        s_logits = self.stage_head(neck_out)
        return d_logits, s_logits