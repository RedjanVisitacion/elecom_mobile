# Local ML Face Recognition — Deployment Guide

## What was added

| File | Purpose |
|---|---|
| `core/local_face_service.py` | Local ML service — InsightFace/ArcFace ONNX inference + .pkl embedding storage |
| `core/views_patch.py` | Patched enrollment + verification handlers (copy logic into `views.py`) |
| `requirements-ml.txt` | New Python dependencies |
| `migrate_embeddings.py` | One-time backfill script for existing voters |
| `ml_models/embeddings/` | Created automatically — stores `<student_id>.pkl` files |

## Model files

InsightFace downloads the `buffalo_l` pack on first use (~280 MB total):

```
~/.insightface/models/buffalo_l/
  det_10g.onnx        ← RetinaFace face detector
  w600k_r50.onnx      ← ArcFace R50 recognition (512-d embeddings)
```

These are standard ONNX files. You can pre-download them and point InsightFace
to a custom path via the `root` parameter in `FaceAnalysis(root=...)`.

## Fallback chain

```
Enrollment:
  Face++ cloud (if FACEPP_API_KEY set)
    └─ InsightFace/ArcFace ONNX + .pkl  ← NEW

Verification:
  Face++ cloud (if FACEPP_API_KEY set AND facepp_face_token stored)
    └─ InsightFace/ArcFace ONNX + .pkl  ← NEW
         └─ PIL pixel diff (last resort, URL-based)
```

## Step-by-step deployment

### 1. Install dependencies
```bash
cd F:/elecom_web/backend
pip install -r requirements-ml.txt
```

### 2. Copy the new service file
```bash
copy _backend_ml\core\local_face_service.py core\local_face_service.py
```

### 3. Patch core/views.py

**a) Add import** (after `from . import facepp_service`):
```python
from . import local_face_service
```

**b) Replace `_save_face_enrollment_facepp`** with the version in `views_patch.py`

**c) Replace `_face_verification_vote_handler`** with the version in `views_patch.py`

### 4. Add settings to core/settings.py
```python
# Local ML face recognition (InsightFace/ArcFace ONNX fallback)
LOCAL_FACE_DUPLICATE_THRESHOLD = float(os.getenv("LOCAL_FACE_DUPLICATE_THRESHOLD", "0.55"))
LOCAL_FACE_VERIFY_THRESHOLD    = float(os.getenv("LOCAL_FACE_VERIFY_THRESHOLD",    "0.55"))
```

### 5. Backfill existing voter embeddings (one-time)
```bash
cd F:/elecom_web/backend
python migrate_embeddings.py
```

### 6. Restart the server
```bash
# Django dev server
python manage.py runserver

# Or gunicorn
gunicorn core.wsgi:application
```

On first request, InsightFace will download the ONNX models (~280 MB).
Subsequent requests use the cached models — no internet needed.

## .pkl file format

Each file is a Python pickle (protocol 4):
```python
{
    "student_id": "2021-00123",
    "embedding": np.ndarray(shape=(512,), dtype=float32)  # L2-normalised ArcFace vector
}
```

## Threshold tuning

| Setting | Default | Meaning |
|---|---|---|
| `LOCAL_FACE_DUPLICATE_THRESHOLD` | `0.55` | Cosine similarity above which two faces are "the same person" during enrollment |
| `LOCAL_FACE_VERIFY_THRESHOLD` | `0.55` | Cosine similarity above which a live face matches the enrolled face |

`0.55` cosine similarity ≈ Face++ `80/100` confidence. Raise to `0.65` for stricter matching, lower to `0.45` for more lenient.

## GPU acceleration (optional)

Replace in `local_face_service.py`:
```python
providers=["CPUExecutionProvider"]
# →
providers=["CUDAExecutionProvider", "CPUExecutionProvider"]
```
And install `onnxruntime-gpu` instead of `onnxruntime`.
