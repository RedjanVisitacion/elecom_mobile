"""
migrate_embeddings.py — One-time migration script.

Run this ONCE after deploying local_face_service.py to backfill .pkl embeddings
for all voters who already enrolled via Face++ (their images are on Cloudinary).

Usage:
  cd F:/elecom_web/backend
  python migrate_embeddings.py

What it does:
  1. Queries all active FaceEnrollment rows
  2. Downloads each voter's face_image_url from Cloudinary
  3. Extracts ArcFace embedding via InsightFace
  4. Saves as ml_models/embeddings/<student_id>.pkl

This lets local verification work immediately for existing voters without
requiring them to re-enroll.
"""
from __future__ import annotations

import os
import sys
import pathlib
import urllib.request
import django

# Bootstrap Django
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")
django.setup()

from elecom_voting.models import FaceEnrollment  # noqa: E402
from core import local_face_service  # noqa: E402


def main():
    enrollments = FaceEnrollment.objects.filter(enrollment_status="active").order_by("id")
    total = enrollments.count()
    print(f"Found {total} active enrollments to migrate.")

    ok = 0
    skipped = 0
    failed = 0

    for rec in enrollments:
        sid = rec.student_id
        url = (rec.face_image_url or "").strip()

        # Skip if already migrated
        if local_face_service.load_embedding(sid) is not None:
            print(f"  [SKIP]  {sid} — embedding already exists")
            skipped += 1
            continue

        if not url:
            print(f"  [FAIL]  {sid} — no face_image_url")
            failed += 1
            continue

        try:
            with urllib.request.urlopen(url, timeout=15) as resp:
                image_bytes = resp.read()
            emb = local_face_service.detect_and_embed(image_bytes)
            local_face_service.save_embedding(sid, emb)
            print(f"  [OK]    {sid} — embedding saved ({len(image_bytes)//1024} KB)")
            ok += 1
        except local_face_service.LocalFaceError as e:
            print(f"  [FAIL]  {sid} — {e.message}")
            failed += 1
        except Exception as e:
            print(f"  [FAIL]  {sid} — {e}")
            failed += 1

    print(f"\nDone. OK={ok}  Skipped={skipped}  Failed={failed}")


if __name__ == "__main__":
    main()
