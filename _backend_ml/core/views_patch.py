"""
views_patch.py — Drop-in replacements for the two face functions in core/views.py.

HOW TO APPLY:
  1. Copy local_face_service.py → F:/elecom_web/backend/core/local_face_service.py
  2. In core/views.py, add this import near the top (after the facepp_service import):
       from . import local_face_service
  3. Replace _save_face_enrollment_facepp() with the version below.
  4. Replace _face_verification_vote_handler() with the version below.
  5. Add LOCAL_FACE_* settings to core/settings.py (see bottom of this file).
  6. pip install insightface onnxruntime opencv-python-headless numpy
  7. Run the server once — InsightFace will auto-download buffalo_l (~280 MB).

Fallback chain after patching:
  Enrollment:    Face++ → InsightFace/ONNX+.pkl → error
  Verification:  Face++ → InsightFace/ONNX+.pkl → PIL pixel diff → error
"""

# ============================================================
# PASTE THIS IMPORT into core/views.py (after facepp_service):
# ============================================================
#   from . import local_face_service

# ============================================================
# REPLACE _save_face_enrollment_facepp in core/views.py
# ============================================================

def _save_face_enrollment_facepp(student_id: str, user_id, raw: bytes):
    """
    Enrollment with 3-tier fallback:
      1. Face++ cloud (if configured)
      2. InsightFace/ArcFace local ONNX + .pkl storage
    """
    from decimal import Decimal
    from django.conf import settings
    from django.db import transaction
    from django.http import JsonResponse
    from elecom_voting.models import FaceEnrollment
    from .cloudinary_upload import upload_enrollment_image_bytes
    from . import facepp_service
    from . import local_face_service

    dup_thr_facepp = getattr(settings, "FACEPP_DUPLICATE_THRESHOLD", 80.0)
    dup_thr_local = getattr(settings, "LOCAL_FACE_DUPLICATE_THRESHOLD", 0.55)

    # ------------------------------------------------------------------
    # TIER 1: Face++ cloud
    # ------------------------------------------------------------------
    if _facepp_configured():
        thr = dup_thr_facepp
        try:
            facepp_service.create_faceset_if_missing()
            new_token = facepp_service.detect_face(raw)
            try:
                results = facepp_service.search_duplicate_face(new_token)
            except facepp_service.FacePPError as e:
                msg = (e.message or "").strip().upper()
                if "EMPTY_FACESET" in msg:
                    results = []
                else:
                    raise
            for r in results:
                try:
                    conf = float(r.get("confidence") or 0.0)
                except (TypeError, ValueError):
                    conf = 0.0
                if conf < thr:
                    continue
                matched_token = (r.get("face_token") or "").strip()
                if not matched_token:
                    continue
                rid = str(r.get("user_id") or r.get("userid") or "").strip()
                if rid and rid != student_id:
                    return JsonResponse(
                        {"ok": False, "error": _DUP_FACE_ENROLL_MSG, "code": "face_already_enrolled"},
                        status=409,
                    )
                owner = FaceEnrollment.objects.filter(
                    enrollment_status="active",
                    facepp_face_token__iexact=matched_token,
                ).first()
                if owner is not None and owner.student_id != student_id:
                    return JsonResponse(
                        {"ok": False, "error": _DUP_FACE_ENROLL_MSG, "code": "face_already_enrolled"},
                        status=409,
                    )

            prev = FaceEnrollment.objects.filter(
                student_id=student_id, enrollment_status="active"
            ).first()
            old_token = (prev.facepp_face_token or "").strip() if prev else ""

            facepp_service.add_face_to_faceset(new_token)
            try:
                facepp_service.set_face_userid(new_token, student_id)
            except Exception:
                pass

            secure_url, public_id = "", ""
            try:
                secure_url, public_id = upload_enrollment_image_bytes(raw)
                if len(public_id) > 255:
                    public_id = public_id[:255]
            except Exception as e:
                logger.exception("Cloudinary enrollment upload failed")
                facepp_service.remove_face_from_faceset(new_token)
                msg = str(e) if getattr(settings, "DEBUG", False) else "Failed to store enrollment image."
                return JsonResponse({"ok": False, "error": msg}, status=500)

            with transaction.atomic():
                FaceEnrollment.objects.filter(
                    student_id=student_id, enrollment_status="active"
                ).update(enrollment_status="archived")
                rec = FaceEnrollment.objects.create(
                    user_id=user_id,
                    student_id=student_id,
                    face_image_url=secure_url,
                    cloudinary_public_id=public_id,
                    facepp_face_token=new_token,
                    enrollment_status="active",
                )
            if old_token and old_token != new_token:
                facepp_service.remove_face_from_faceset(old_token)

            # Also save local embedding so local verify works even when Face++ is later disabled
            try:
                local_face_service.enroll_face_local(
                    student_id, raw, duplicate_threshold=dup_thr_local
                )
            except Exception:
                pass  # Non-fatal: Face++ is primary

            return JsonResponse({"ok": True, "enrolled": True, "enrollment": _enrollment_json(rec)})

        except facepp_service.FacePPError as e:
            logger.warning("Face++ enrollment error: %s", e.message)
            return JsonResponse({"ok": False, "error": e.message}, status=400)
        except Exception as e:
            logger.exception("Face enrollment failed (Face++ path)")
            if getattr(settings, "DEBUG", False):
                return JsonResponse({"ok": False, "error": str(e)}, status=500)
            return JsonResponse({"ok": False, "error": "Failed to save face enrollment."}, status=500)

    # ------------------------------------------------------------------
    # TIER 2: InsightFace / ArcFace local ONNX + .pkl
    # ------------------------------------------------------------------
    try:
        local_face_service.enroll_face_local(
            student_id, raw, duplicate_threshold=dup_thr_local
        )

        secure_url, public_id = "", ""
        try:
            secure_url, public_id = upload_enrollment_image_bytes(raw)
            if len(public_id) > 255:
                public_id = public_id[:255]
        except Exception as e:
            logger.exception("Cloudinary enrollment upload failed (local path)")
            local_face_service.delete_embedding(student_id)
            msg = str(e) if getattr(settings, "DEBUG", False) else "Failed to store enrollment image."
            return JsonResponse({"ok": False, "error": msg}, status=500)

        with transaction.atomic():
            FaceEnrollment.objects.filter(
                student_id=student_id, enrollment_status="active"
            ).update(enrollment_status="archived")
            rec = FaceEnrollment.objects.create(
                user_id=user_id,
                student_id=student_id,
                face_image_url=secure_url,
                cloudinary_public_id=public_id,
                facepp_face_token=None,  # no Face++ token in local mode
                enrollment_status="active",
            )
        return JsonResponse({"ok": True, "enrolled": True, "enrollment": _enrollment_json(rec)})

    except local_face_service.LocalFaceError as e:
        code = e.code or "local_face_error"
        status = 409 if code == "face_already_enrolled" else 400
        return JsonResponse({"ok": False, "error": e.message, "code": code}, status=status)
    except Exception as e:
        logger.exception("Face enrollment failed (local path)")
        if getattr(settings, "DEBUG", False):
            return JsonResponse({"ok": False, "error": str(e)}, status=500)
        return JsonResponse({"ok": False, "error": "Failed to save face enrollment."}, status=500)


# ============================================================
# REPLACE _face_verification_vote_handler in core/views.py
# ============================================================

def _face_verification_vote_handler(request):
    """
    Verification with 3-tier fallback:
      1. Face++ cloud (if configured + enrolled token exists)
      2. InsightFace/ArcFace local ONNX + .pkl
      3. PIL pixel diff (last resort, URL-based)
    """
    import json
    from decimal import Decimal
    from django.conf import settings
    from django.http import JsonResponse
    from elecom_voting.models import FaceEnrollment, FaceVerificationLog
    from . import facepp_service
    from . import local_face_service

    student_id = (request.session.get("student_id") or "").strip()
    if not student_id:
        return JsonResponse({"ok": False, "error": "Unauthorized."}, status=401)

    _ensure_face_verification_tables()

    live_bytes = None
    liveness_ok = False
    election_override = None
    payload = {}

    upload = _multipart_face_upload(request)
    if upload is not None:
        live_bytes = upload.read()
        max_bytes = 8 * 1024 * 1024
        if not live_bytes or len(live_bytes) > max_bytes:
            live_bytes = None
        vp = getattr(request, "POST", {})
        lv = vp.get("liveness_passed", "false")
        liveness_ok = str(lv).lower() in ("1", "true", "yes", "on")
        eid_raw = vp.get("election_id")
        if eid_raw not in (None, ""):
            try:
                election_override = int(eid_raw)
            except (TypeError, ValueError):
                election_override = None
    else:
        try:
            payload = json.loads((request.body or b"{}").decode("utf-8"))
        except Exception:
            payload = {}
        liveness_ok = _post_bool(payload, "liveness_passed")
        live_face_image_url = str(payload.get("live_face_image_url") or "").strip()
        election_override = _parse_election_id_from_request(request, payload)
        if live_face_image_url:
            live_bytes = _download_public_image(live_face_image_url)

    enrollment = FaceEnrollment.objects.filter(
        student_id=student_id, enrollment_status="active"
    ).order_by("-updated_at", "-id").first()

    election_id = election_override if election_override is not None else _active_election_id()

    verification_status = "failed"
    failure_reason = ""
    verified = False
    match_score = None

    enrolled_token = ""
    if enrollment and (enrollment.facepp_face_token or "").strip():
        enrolled_token = enrollment.facepp_face_token.strip()

    if enrollment is None:
        failure_reason = "No active enrolled face."
    elif not liveness_ok:
        failure_reason = "Blink/liveness check failed."
    elif not live_bytes:
        failure_reason = "Missing live capture."

    # ------------------------------------------------------------------
    # TIER 1: Face++ cloud
    # ------------------------------------------------------------------
    elif _facepp_configured() and enrolled_token:
        thr = getattr(settings, "FACEPP_VERIFY_THRESHOLD", 80.0)
        try:
            live_token = facepp_service.detect_face(live_bytes)
            conf = facepp_service.compare_faces(enrolled_token, live_token)
            match_score = Decimal(str(round(conf, 4)))
            verified = conf >= thr
            if verified:
                verification_status = "passed"
            else:
                failure_reason = _MISMATCH_VOTER_MSG
        except facepp_service.FacePPError as e:
            failure_reason = e.message or _MISMATCH_VOTER_MSG
        except Exception:
            logger.exception("Face++ verify unexpected error")
            failure_reason = _MISMATCH_VOTER_MSG

    # ------------------------------------------------------------------
    # TIER 2: InsightFace / ArcFace local ONNX + .pkl
    # ------------------------------------------------------------------
    elif live_bytes:
        local_thr = getattr(settings, "LOCAL_FACE_VERIFY_THRESHOLD", 0.55)
        try:
            passed, sim = local_face_service.verify_face_local(
                student_id, live_bytes, verify_threshold=local_thr
            )
            match_score = Decimal(str(round(sim, 4)))
            verified = passed
            if verified:
                verification_status = "passed"
            else:
                failure_reason = _MISMATCH_VOTER_MSG
        except local_face_service.LocalFaceError as e:
            # No .pkl stored — fall through to PIL pixel diff if URL available
            logger.info("Local face verify failed (%s): %s", e.code, e.message)
            live_url = str(payload.get("live_face_image_url") or "").strip()
            if live_url and enrollment is not None:
                # ----------------------------------------------------------
                # TIER 3: PIL pixel diff (last resort, URL-based)
                # ----------------------------------------------------------
                matched, ms, compare_reason = _compare_face_urls(
                    enrollment.face_image_url, live_url
                )
                if ms is not None:
                    match_score = Decimal(str(round(ms, 4)))
                verified = matched
                if verified:
                    verification_status = "passed"
                else:
                    failure_reason = compare_reason or _MISMATCH_VOTER_MSG
            else:
                failure_reason = e.message or _MISMATCH_VOTER_MSG
        except Exception:
            logger.exception("Local face verify unexpected error")
            failure_reason = _MISMATCH_VOTER_MSG

    else:
        failure_reason = _MISMATCH_VOTER_MSG if enrollment else "No active enrolled face."

    try:
        FaceVerificationLog.objects.create(
            student_id=student_id,
            election_id=election_id,
            liveness_status="passed" if liveness_ok else "failed",
            verification_status=verification_status,
            match_score=match_score,
            failure_reason=failure_reason or None,
        )
    except Exception as e:
        logger.exception("Face verification log write failed: %s", e)

    if verified:
        _set_session_face_vote_verified(request, student_id)

    return JsonResponse(
        {
            "ok": True,
            "verified": verified,
            "allow_to_vote": verified,
            "verification_status": verification_status,
            "liveness_status": "passed" if liveness_ok else "failed",
            "failure_reason": failure_reason if not verified else "",
        }
    )


# ============================================================
# ADD THESE SETTINGS to core/settings.py
# ============================================================
#
# # Local ML face recognition (InsightFace/ArcFace ONNX fallback)
# # Cosine similarity thresholds — 0.55 ≈ Face++ 80/100 confidence
# LOCAL_FACE_DUPLICATE_THRESHOLD = float(os.getenv("LOCAL_FACE_DUPLICATE_THRESHOLD", "0.55"))
# LOCAL_FACE_VERIFY_THRESHOLD    = float(os.getenv("LOCAL_FACE_VERIFY_THRESHOLD",    "0.55"))
