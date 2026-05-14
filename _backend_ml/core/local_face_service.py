"""
Local ML face recognition service using InsightFace (ArcFace/buffalo_l via ONNX Runtime).

This module is the **offline fallback** when Face++ cloud API is not configured.
It provides the same contract as facepp_service but runs entirely on-device:

  - Face detection + 512-d embedding extraction via ONNX (ArcFace buffalo_l)
  - Per-voter embeddings persisted as .pkl files under ml_models/embeddings/
  - Duplicate detection via cosine similarity across all stored embeddings
  - 1:1 verification via cosine similarity against the stored .pkl embedding

Model files (.onnx) are downloaded once by InsightFace into:
  ~/.insightface/models/buffalo_l/   (standard InsightFace cache)

Embedding files (.pkl) are stored in:
  <BACKEND_ROOT>/ml_models/embeddings/<student_id>.pkl

Thresholds (cosine similarity, 0-1 scale):
  - DUPLICATE_THRESHOLD: default 0.55  (~80/100 Face++ confidence equivalent)
  - VERIFY_THRESHOLD:    default 0.55
"""
from __future__ import annotations

import io
import logging
import os
import pickle
import pathlib
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_BACKEND_ROOT = pathlib.Path(__file__).resolve().parent.parent
_EMBEDDINGS_DIR = _BACKEND_ROOT / "ml_models" / "embeddings"
_EMBEDDINGS_DIR.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
# Lazy model loader — InsightFace is optional; import only when needed
# ---------------------------------------------------------------------------

_app = None  # insightface FaceAnalysis app singleton


def _get_app():
    """Return (and lazily initialise) the InsightFace FaceAnalysis app."""
    global _app
    if _app is not None:
        return _app
    try:
        import insightface  # type: ignore
        from insightface.app import FaceAnalysis  # type: ignore
    except ImportError as exc:
        raise LocalFaceError(
            "insightface is not installed. Run: pip install insightface onnxruntime",
            "local_face_not_installed",
        ) from exc

    app = FaceAnalysis(
        name="buffalo_l",           # ArcFace R100 — best accuracy, ~280 MB ONNX
        providers=["CPUExecutionProvider"],  # GPU: replace with CUDAExecutionProvider
    )
    # det_size: detection input resolution. 640x640 is the standard.
    app.prepare(ctx_id=0, det_size=(640, 640))
    _app = app
    logger.info("InsightFace buffalo_l model loaded (ONNX/ArcFace).")
    return _app


# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

class LocalFaceError(Exception):
    def __init__(self, message: str, code: str = "local_face_error"):
        self.message = message
        self.code = code
        super().__init__(message)


# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def _image_bytes_to_bgr(image_bytes: bytes) -> "np.ndarray":
    """Decode raw image bytes → BGR numpy array (OpenCV convention)."""
    try:
        import cv2  # type: ignore
        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            raise LocalFaceError("Could not decode image.", "local_face_bad_image")
        return img
    except ImportError:
        # cv2 not available — fall back to PIL → numpy (RGB→BGR swap)
        try:
            from PIL import Image  # type: ignore
            img_pil = Image.open(io.BytesIO(image_bytes)).convert("RGB")
            arr = np.array(img_pil)
            return arr[:, :, ::-1].copy()  # RGB → BGR
        except Exception as exc:
            raise LocalFaceError(
                "Could not decode image (PIL fallback).", "local_face_bad_image"
            ) from exc


def _extract_embedding(image_bytes: bytes) -> "np.ndarray":
    """
    Run InsightFace detection + ArcFace embedding on raw image bytes.
    Returns a normalised 512-d float32 numpy vector.
    Raises LocalFaceError if no face is detected.
    """
    app = _get_app()
    img_bgr = _image_bytes_to_bgr(image_bytes)
    faces = app.get(img_bgr)
    if not faces:
        raise LocalFaceError("No face detected in image.", "local_no_face")
    # Use the largest/highest-confidence face when multiple faces are present
    face = max(faces, key=lambda f: float(f.det_score))
    emb = face.embedding  # shape (512,), already L2-normalised by InsightFace
    emb = emb / (np.linalg.norm(emb) + 1e-10)  # re-normalise for safety
    return emb.astype(np.float32)


def _cosine_similarity(a: "np.ndarray", b: "np.ndarray") -> float:
    """Cosine similarity in [0, 1] between two L2-normalised vectors."""
    return float(np.clip(np.dot(a, b), 0.0, 1.0))


# ---------------------------------------------------------------------------
# Embedding persistence (.pkl files)
# ---------------------------------------------------------------------------

def _embedding_path(student_id: str) -> pathlib.Path:
    # Sanitise student_id to prevent path traversal
    safe_id = "".join(c for c in student_id if c.isalnum() or c in "-_.")
    if not safe_id:
        raise LocalFaceError("Invalid student_id.", "local_bad_student_id")
    return _EMBEDDINGS_DIR / f"{safe_id}.pkl"


def save_embedding(student_id: str, embedding: "np.ndarray") -> pathlib.Path:
    """Persist a 512-d ArcFace embedding vector as a .pkl file."""
    path = _embedding_path(student_id)
    with open(path, "wb") as f:
        pickle.dump(
            {"student_id": student_id, "embedding": embedding},
            f,
            protocol=4,
        )
    logger.info("Saved face embedding: %s", path.name)
    return path


def load_embedding(student_id: str) -> Optional["np.ndarray"]:
    """Load a stored embedding. Returns None if not found."""
    path = _embedding_path(student_id)
    if not path.exists():
        return None
    try:
        with open(path, "rb") as f:
            data = pickle.load(f)
        emb = data.get("embedding")
        if emb is None or not isinstance(emb, np.ndarray):
            return None
        return emb.astype(np.float32)
    except Exception as exc:
        logger.warning("Failed to load embedding %s: %s", path.name, exc)
        return None


def delete_embedding(student_id: str) -> None:
    """Remove a stored .pkl embedding (called on re-enrollment or account deletion)."""
    path = _embedding_path(student_id)
    if path.exists():
        path.unlink()
        logger.info("Deleted face embedding: %s", path.name)


def list_all_embeddings() -> list[tuple[str, "np.ndarray"]]:
    """Load all stored embeddings. Used for duplicate detection scan."""
    results = []
    for pkl_file in _EMBEDDINGS_DIR.glob("*.pkl"):
        try:
            with open(pkl_file, "rb") as f:
                data = pickle.load(f)
            sid = data.get("student_id", pkl_file.stem)
            emb = data.get("embedding")
            if emb is not None and isinstance(emb, np.ndarray):
                results.append((sid, emb.astype(np.float32)))
        except Exception as exc:
            logger.warning("Skipping corrupt embedding %s: %s", pkl_file.name, exc)
    return results


# ---------------------------------------------------------------------------
# Public API  (mirrors facepp_service contract)
# ---------------------------------------------------------------------------

def detect_and_embed(image_bytes: bytes) -> "np.ndarray":
    """
    Detect face in image_bytes and return its 512-d ArcFace embedding.
    Raises LocalFaceError on failure.
    """
    if not image_bytes or len(image_bytes) < 512:
        raise LocalFaceError("Image data is too small.", "local_face_bad_image")
    return _extract_embedding(image_bytes)


def search_duplicate(
    new_embedding: "np.ndarray",
    exclude_student_id: Optional[str] = None,
    threshold: float = 0.55,
) -> Optional[str]:
    """
    Scan all stored .pkl embeddings for a match above `threshold`.
    Returns the matching student_id, or None if no duplicate found.
    `exclude_student_id` skips the voter's own existing embedding (re-enrollment).
    """
    all_embs = list_all_embeddings()
    for sid, stored_emb in all_embs:
        if exclude_student_id and sid == exclude_student_id:
            continue
        sim = _cosine_similarity(new_embedding, stored_emb)
        if sim >= threshold:
            logger.info(
                "Duplicate face found: new vs %s similarity=%.4f", sid, sim
            )
            return sid
    return None


def verify_face(
    live_embedding: "np.ndarray",
    student_id: str,
    threshold: float = 0.55,
) -> tuple[bool, float]:
    """
    Compare `live_embedding` against the stored .pkl for `student_id`.
    Returns (passed: bool, similarity_score: float 0-1).
    Raises LocalFaceError if no stored embedding exists.
    """
    stored = load_embedding(student_id)
    if stored is None:
        raise LocalFaceError(
            "No local face embedding found. Please re-enroll.",
            "local_no_embedding",
        )
    sim = _cosine_similarity(live_embedding, stored)
    passed = sim >= threshold
    return passed, sim


# ---------------------------------------------------------------------------
# High-level enrollment helper (called from views.py)
# ---------------------------------------------------------------------------

def enroll_face_local(
    student_id: str,
    image_bytes: bytes,
    duplicate_threshold: float = 0.55,
) -> "np.ndarray":
    """
    Full enrollment pipeline:
      1. Extract ArcFace embedding from image_bytes
      2. Scan for duplicates (raises LocalFaceError on match)
      3. Persist embedding as .pkl
    Returns the new embedding.
    """
    new_emb = detect_and_embed(image_bytes)
    dup_sid = search_duplicate(
        new_emb,
        exclude_student_id=student_id,
        threshold=duplicate_threshold,
    )
    if dup_sid is not None:
        raise LocalFaceError(
            "This face is already registered to another account. Please contact ELECOM.",
            "face_already_enrolled",
        )
    save_embedding(student_id, new_emb)
    return new_emb


def verify_face_local(
    student_id: str,
    live_image_bytes: bytes,
    verify_threshold: float = 0.55,
) -> tuple[bool, float]:
    """
    Full verification pipeline:
      1. Extract ArcFace embedding from live_image_bytes
      2. Compare against stored .pkl for student_id
    Returns (passed, similarity_score).
    """
    live_emb = detect_and_embed(live_image_bytes)
    return verify_face(live_emb, student_id, threshold=verify_threshold)
