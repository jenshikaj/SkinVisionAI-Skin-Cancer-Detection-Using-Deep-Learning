<div align="center">

<img src="skinvision_ai_app/assets/app_icon/icon.png" width="96" alt="SkinVision AI logo" />

# SkinVision AI

**AI-powered skin-lesion analysis and dermatological insights, with an educational dermatology assistant.**

![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![CNN](https://img.shields.io/badge/CNN-SkinFusionNet-6f42c1)
![PyTorch](https://img.shields.io/badge/PyTorch-EfficientNet--B4-EE4C2C?logo=pytorch&logoColor=white)
![NumPy](https://img.shields.io/badge/NumPy-preprocessing-013243?logo=numpy&logoColor=white)
![FAISS](https://img.shields.io/badge/FAISS-RAG-4B8BBE)
![FastAPI](https://img.shields.io/badge/FastAPI-backend-009688?logo=fastapi&logoColor=white)

<br/>

![Firebase](https://img.shields.io/badge/Firebase-auth%20%2B%20data-FFCA28?logo=firebase&logoColor=black)
![Flutter](https://img.shields.io/badge/Flutter-mobile%20app-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.4-0175C2?logo=dart&logoColor=white)
![Google](https://img.shields.io/badge/Google%20Sign--In-4285F4?logo=google&logoColor=white)
![Cloudinary](https://img.shields.io/badge/Cloudinary-media%20storage-3448C5?logo=cloudinary&logoColor=white)
</div>

> [!IMPORTANT]
> **Medical disclaimer.** SkinVision AI is for **educational purposes only**. It does **not** provide a medical diagnosis, prescription, or treatment. Every result directs the user to consult a qualified dermatologist.

SkinVision AI lets a user photograph a skin lesion, get an AI-generated condition + severity read-out, browse plain-language dermatology insights grounded in real reference textbooks, chat with an educational dermatology assistant, and export a shareable PDF report — all from a phone.

| Part | Stack | Role |
|---|---|---|
| [`backend/`](backend) | Python · FastAPI · PyTorch · FAISS | Serves **SkinFusionNet** (lesion classifier) and a **RAG** pipeline for dermatology Q&A + insights |
| [`skinvision_ai_app/`](skinvision_ai_app) | Flutter · Firebase · Cloudinary | Mobile app: capture/upload → analyze → insights → chat → PDF report |

---

## Contents

- [Screenshots](#screenshots)
- [Repository layout](#repository-layout)
- [Backend](#backend)
  - [Served endpoints](#served-endpoints)
  - [SkinFusionNet model](#skinfusionnet-model)
  - [RAG pipeline](#rag-pipeline)
  - [API reference](#api-reference)
- [Mobile app](#mobile-app)
  - [Features](#features)
  - [Screen flow](#screen-flow)
  - [Firestore data model](#firestore-data-model)
- [Getting started](#getting-started)
- [Data & model-training notebooks](#data--model-training-notebooks)

---

## Screenshots

<table>
<tr>
<td align="center" width="20%"><img src="docs/screenshots/splash.png" width="200"/><br/><sub>Splash</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/login.png" width="200"/><br/><sub>Sign in</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/signup.png" width="200"/><br/><sub>Sign up</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/home.png" width="200"/><br/><sub>Home</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/disease_image_input.png" width="200"/><br/><sub>Upload lesion image</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/analyzing_image.png" width="200"/><br/><sub>Analyzing</sub></td>
<td align="center"><img src="docs/screenshots/detection_result_i.png" width="200"/><br/><sub>Detection result</sub></td>
<td align="center"><img src="docs/screenshots/detection_result_ii.png" width="200"/><br/><sub>Detection result</sub></td>
<td align="center"><img src="docs/screenshots/detection_result_iii.png" width="200"/><br/><sub>Detection result</sub></td>
<td align="center"><img src="docs/screenshots/normal_skin_detection_result.png" width="200"/><br/><sub>Normal-skin result</sub></td>
</tr>
</table>

<details>
<summary><b>Dermatology Insights walkthrough</b> (Overview → Causes → Symptoms → Self-Care → Red Flags → Next Steps)</summary>
<br/>
<table>
<tr>
<td align="center" width="16%"><img src="docs/screenshots/dermatology_insights_i.png" width="170"/></td>
<td align="center" width="16%"><img src="docs/screenshots/dermatology_insights_ii.png" width="170"/></td>
<td align="center" width="16%"><img src="docs/screenshots/dermatology_insights_iii.png" width="170"/></td>
<td align="center" width="16%"><img src="docs/screenshots/dermatology_insights_iv.png" width="170"/></td>
<td align="center" width="16%"><img src="docs/screenshots/dermatology_insights_v.png" width="170"/></td>
<td align="center" width="16%"><img src="docs/screenshots/dermatology_insights_vi.png" width="170"/></td>
</tr>
</table>
</details>

<details>
<summary><b>PDF report & sharing</b></summary>
<br/>
<table>
<tr>
<td align="center" width="20%"><img src="docs/screenshots/share_report.png" width="200"/><br/><sub>Share report</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/generate_report.png" width="200"/><br/><sub>Generate report</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/share.png" width="200"/><br/><sub>Share</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/report_via_email.png" width="200"/><br/><sub>Emailed report</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/report.png" width="200"/><br/><sub>Report</sub></td>
</tr>
</table>
</details>

<details>
<summary><b>DermaBot chat & profile</b></summary>
<br/>
<table>
<tr>
<td align="center" width="20%"><img src="docs/screenshots/skinvisionaibot_chat_i.png" width="200"/><br/><sub>DermaBot chat</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/skinvisionaibot_chat_ii.png" width="200"/><br/><sub>DermaBot chat</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/clear_chat_history.png" width="200"/><br/><sub>Clear history</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/profile.png" width="200"/><br/><sub>Profile</sub></td>
<td align="center" width="20%"><img src="docs/screenshots/update_profile.png" width="200"/><br/><sub>Edit profile</sub></td>
</tr>
</table>
</details>

A sample generated report is included at [`docs/reports/SkinVisionAI_Melanocytic_Nevus.pdf`](docs/reports/SkinVisionAI_Melanocytic_Nevus.pdf).

---

## Repository layout

```
SkinVisionAI/
├── .gitattributes                  # Git LFS rule for *.pth checkpoints
├── .gitignore
├── docs/
│   ├── screenshots/                # App screenshots used in this README
│   └── reports/                    # Sample exported PDF report
│
├── backend/
│   ├── main.py                     # FastAPI app — the entrypoint that is actually served
│   ├── chat_router.py              # POST /api/v1/chat → RAG pipeline
│   ├── routers/
│   │   ├── analysis.py             # POST /api/v1/analyze → model
│   │   └── gpt_insights.py         # Structured insights via GPT
│   ├── model/
│   │   ├── loader.py               # Model loader
│   │   ├── skinfusionnet.py        # SkinFusionNet architecture (EfficientNet-B4 + DualPath + CBAM + ASPP)
│   │   └── checkpoints/
│   │       └── skinfusionnet_best.pth   # Trained weights (Git LFS)
│   ├── RAG/
│   │   ├── derm_pdf_vector.py      # Build script: PDFs → FAISS index
│   │   ├── derm_question_vector.py # ask_question_silent(): embed → retrieve top-5 → gpt-4o-mini
│   │   ├── derm_vectors.index      # Prebuilt FAISS index
│   │   ├── derm_chunks.pkl         # Chunk text + metadata
│   │   └── dermatology_knowledge_base/
│   │       ├── Derm_Handbook_3rd-Edition-_Nov_2020-FINAL.pdf
│   │       └── Oxford-Handbook-of-Medical-Dermatology.pdf
│   ├── Derm_Augmentation_Module/    # Notebook: GAN-based lesion augmentation / class balancing
│   ├── StageGeneration/             # Notebook: severity-stage label generation + normal-skin integration
│   ├── SkinFusionNet_Model_Building/ # Notebook: full model training & export
│   ├── requirements.txt
│   └── .env.example                # Template — copy to .env
│
└── skinvision_ai_app/
    ├── lib/
    │   ├── main.dart                # App bootstrap + Firebase init
    │   ├── firebase_options.dart    # Generated by flutterfire
    │   ├── theme/app_theme.dart
    │   ├── config/cloudinary_config.dart
    │   ├── screens/
    │   │   ├── splash_screen.dart
    │   │   ├── auth_screen.dart           # Sign in / Sign up / Google
    │   │   ├── main_shell.dart            # Bottom nav: Home + AI Chat
    │   │   ├── home_screen.dart           # Pick image → analyze → results
    │   │   ├── disease_insights_screen.dart  # Paged insights + PDF export
    │   │   ├── chat_screen.dart           # DermaBot chat (Firestore-backed)
    │   │   └── profile_screen.dart        # Profile + avatar + sign out
    │   ├── services/
    │   │   ├── api_service.dart           # /analyze
    │   │   ├── chat_service.dart          # /chat + Firestore chat history
    │   │   ├── firebase_service.dart      # profile + scan history
    │   │   ├── cloudinary_service.dart    # Disease image and profile picture upload
    │   │   └── pdf_report_service.dart    # Branded PDF report
    │   └── widgets/app_notification.dart  # Top toast notifications
    ├── assets/
    ├── pubspec.yaml
    └── android/ ios/ web/ macos/ linux/ windows/
```

---

## Backend

The served app is **`backend/main.py`** (`uvicorn main:app`). On startup it pre-loads the model checkpoint so the first request is fast. CORS is fully open for development.

### Served endpoints

| Method & path | Purpose |
|---|---|
| `GET /` | Health check → `{"status":"ok", ...}` |
| `GET /health` | Health check → `{"status":"healthy"}` |
| `POST /api/v1/analyze` | Analyze a skin image → disease + severity stage + educational insights |
| `POST /api/v1/chat` | Ask a dermatology question → RAG answer grounded in dermatology textbooks |

### SkinFusionNet model

Defined in `backend/model/skinfusionnet.py` — a **multi-task CNN**:

- **Backbone:** `timm` EfficientNet-B4, features from stages 3 & 4 (`features_only`, `out_indices=[3, 4]`).
- **Multi-Scale DualPath module** on each stage:
  - *local branch* — 1×1 conv + **CBAM** (channel + spatial attention)
  - *global branch* — **ASPP**-style block, dilated convs (rates 2/4/6) + global pooling
- **ResNeck:** 2-layer MLP (LayerNorm + GELU + dropout) with a linear skip connection.
- **Two heads:** `disease_head` (8 classes), `stage_head` (3 classes).
- **Temperature scaling** (`log_temp`, clamped 0.5–5.0) on disease logits to curb over-confidence.

| Task | Labels |
|---|---|
| Disease | `NV` Melanocytic Nevus · `MEL` Melanoma · `BKL` Benign Keratosis · `BCC` Basal Cell Carcinoma · `AKIEC` Actinic Keratosis / intraepithelial carcinoma · `VASC` Vascular Lesion · `DF` Dermatofibroma · `NORMAL` Normal Skin |
| Severity stage | `mild` · `moderate` · `severe` (reported `N/A` when prediction is `NORMAL`) |

**Preprocessing** (must match training): resize 224×224 bilinear → `ToTensor` → normalize with ImageNet mean/std.

`model/loader.py` loads the checkpoint once (`functools.lru_cache`), supports several checkpoint key layouts (`model_state` / `model_state_dict` / `state_dict` / bare state dict), uses CUDA if available else CPU, and `predict()` returns:

```jsonc
{
  "disease": "Basal Cell Carcinoma",
  "disease_code": "BCC",
  "disease_id": 3,
  "disease_confidence": 46.29,      // percent
  "stage": "mild",
  "stage_confidence": 71.1,         // percent
  "top_k_predictions": [ { "class": "BCC", "confidence": 46.29 }, ... ]  // top 5
}
```

### RAG pipeline

**Index build (one-time)** — `RAG/derm_pdf_vector.py`:
1. Extract text from the two dermatology PDFs with `PyPDF2`.
2. Sliding-window chunk: 500 chars, 400-char step (100-char overlap).
3. Embed in batches of 100 with OpenAI `text-embedding-3-small` (1536-dim).
4. Build `faiss.IndexFlatIP` over L2-normalized vectors (cosine similarity).
5. Persist `derm_vectors.index` + `derm_chunks.pkl`.

Prebuilt copies are committed — rebuild only if you change the source PDFs or chunking.

**Query time** — `RAG/derm_question_vector.py` → `ask_question_silent(question)`:
1. Embed the question, retrieve **top-5** chunks (tagged `[Source: file, Page ~N]`).
2. Strict system prompt: no diagnosis, no drug names/dosages, answer only from context, recommend a dermatologist.
3. Answer generated with `gpt-4o-mini` (`temperature=0.3`, `max_tokens=600`).
4. Safe fallback message if the index is missing or the API call fails.

**Insights for a detected condition** — `routers/gpt_insights.py` → `generate_insights(...)` calls `gpt-4o-mini` with `response_format=json_object` and returns a validated dict with exactly these keys (consumed 1:1 by the app's insights screen and the PDF report):

```
summary, definition, causes,
symptoms[], self_care[], red_flags[], when_to_seek_care[], next_steps[]
```

### API reference

<details>
<summary><code>POST /api/v1/analyze</code></summary>

- **Body:** `multipart/form-data`, field **`file`** = image (JPEG/PNG/WebP; also accepts `application/octet-stream` / missing type — validated by decoding with PIL). Max **10 MB**.
- **`200`:**

```jsonc
{
  "disease": "Melanoma", "disease_code": "MEL", "disease_id": 1,
  "disease_confidence": 82.4,
  "stage": "moderate", "stage_confidence": 63.7,
  "top_k_predictions": [ ... ],
  "image_url": "https://res.cloudinary.com/.../scan.jpg",
  "insights": {
    "disease": "Melanoma", "disease_confidence": 82.4,
    "stage": "moderate", "stage_confidence": 63.7,
    "summary": "…", "definition": "…", "causes": "…",
    "symptoms": ["…"], "self_care": ["…"], "red_flags": ["…"],
    "when_to_seek_care": ["…"], "next_steps": ["…"]
  }
}
```
</details>

<details>
<summary><code>POST /api/v1/chat</code></summary>

- **Body:** `application/json` → `{ "question": "What causes eczema?" }`
- **`200`:** `{ "answer": "…" }`
</details>

---

## Mobile app

`skinvision_ai_app/` — package `skinvision_ai_app`, Dart SDK `>=3.4.4 <4.0.0`, Android `minSdk 23`.

### Features

- **Email/password + Google sign-in** (Firebase Auth); user doc in Firestore `users/{uid}`.
- **Image analysis** — pick from gallery, send to `/analyze`, show detected condition + severity with confidence badges. `NORMAL` shows a "skin appears healthy" card instead of insights.
- **Dermatology Insights** — paged walkthrough (Overview → About & Causes → Symptoms → Self-Care → Red Flags → Next Steps) built dynamically from the backend `insights` object.
- **PDF report** — branded A4 report generated on-device (`pdf` + `printing` + Google Fonts), shared via the OS share sheet (`share_plus`).
- **DermaBot chat** — Q&A against `/chat`, quick-question chips, typing indicator, history persisted in Firestore `users/{uid}/chat_messages` (clearable).
- **Profile** — name / phone / age / gender (Firestore), avatar (Cloudinary), sign out.
- **Toasts** — custom overlay (`AppNotification.success/error/info/warning`).

### Screen flow

```
SplashScreen (3 s, animated)
   └─▶ currentUser == null ?  AuthScreen  :  MainShell
                                              ├── HomeScreen ──▶ DiseaseInsightsScreen ──▶ (share PDF)
                                              │        └──▶ ProfileScreen
                                              └── ChatScreen
```

### Firestore data model

```
users/{uid}
  ├─ name, email, photoUrl, phone, age, gender, createdAt, updatedAt
  ├─ scans/{scanId}       → { ...scanData, imageUrl, insights, createdAt, updatedAt }
  └─ chat_messages/{id}   → { text, isUser, timestamp }
```

---

## Getting started

### Requirements

| | |
|---|---|
| Backend | Python 3.12, an OpenAI API key with credit |
| Mobile app | Flutter SDK (Dart 3.4+), Android Studio / Xcode |
| Services | A Firebase project (Auth + Firestore), a Cloudinary account |
| Model weights | `checkpoints/skinfusionnet_best.pth` |

```bash
git lfs install
git clone https://github.com/jenshikaj/SkinVisionAI-Skin-Cancer-Detection-Using-Deep-Learning.git
cd SkinVisionAI
```

### 1 · Backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate                   # macOS/Linux: source venv/bin/activate

pip install -r requirements.txt
copy .env.example .env                  # macOS/Linux: cp .env.example .env

# Only if you changed the source PDFs in RAG/dermatology_knowledge_base/:
python RAG/derm_pdf_vector.py

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Verify at <http://localhost:8000/health> → `{"status":"healthy"}`.

**Key dependencies** (`requirements.txt`): `fastapi`, `uvicorn[standard]`, `python-multipart`, `torch`, `torchvision`, `timm`, `Pillow`, `openai`, `faiss-cpu`, `PyPDF2`, `numpy`, `httpx`, `pydantic`, `python-dotenv`.

> **PyTorch note:** PyTorch ≥2.6 defaults `torch.load(weights_only=True)`, which rejects this checkpoint (it contains NumPy scalars). `model/loader.py` loads with `weights_only=False` — keep that; the checkpoint is a trusted local file.

### 2 · Point the app at your backend

The backend base URL is hard-coded in `api_service.dart` and `chat_service.dart`:

```dart
static const String _baseUrl = 'http://10.0.2.2:8000/api/v1';
```

| Target | Value |
|---|---|
| Android emulator | `http://10.0.2.2:8000/api/v1` *(default, no change needed)* |
| iOS simulator | `http://localhost:8000/api/v1` |
| Physical device | `http://<your-machine-LAN-IP>:8000/api/v1` |

For a physical device, update `_baseUrl` in **both** `api_service.dart` and `chat_service.dart`.

### 3 · Mobile app

```bash
cd skinvision_ai_app
flutter pub get

# Firebase:
#   dart pub global activate flutterfire_cli
#   flutterfire configure        → regenerates lib/firebase_options.dart + android/app/google-services.json
#   In Firebase console: enable Authentication (Email/Password + Google) + Cloud Firestore
#   For Google Sign-In on Android: add debug + release SHA-1/SHA-256 fingerprints

# Cloudinary: create an UNSIGNED upload preset named "skinvisionai_uploads"

flutter run                      # backend must already be running
```

---

## Data & model-training notebooks

| Notebook | What it does |
|---|---|
| [`DermAugment_Skin_Lesion_GAN_Pipeline.ipynb`](backend/Derm_Augmentation_Module) | Base lesion dataset → EDA → custom **DermAugment** augmentation + a **DCGAN** → class-balance → export final dataset. |
| [`Derm_Stage_Label_Generation.ipynb`](backend/StageGeneration) | Adds a **Normal Skin** class, extracts image features, assigns clinically meaningful **severity-stage** labels, writes the train/val/test CSVs SkinFusionNet consumes. |
| [`SkinFusionNet_Model_Development_May2_v3.ipynb`](backend/SkinFusionNet_Model_Building) | Dataset loader → **SkinFusionNet** architecture → class-weighted losses → training loop → evaluation + confusion matrix → single-image / grid / upload inference → export (ONNX + TFLite) → summary dashboard. Produces `skinfusionnet_best.pth`. |

**⭐ If you like this project, please give it a star on GitHub!**

---

<div align="center">
<sub>Built for educational dermatology support — not a substitute for professional medical advice.</sub>
</div>
