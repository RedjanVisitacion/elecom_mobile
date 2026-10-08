# Agent Instructions (Flutter app: `elecom_mobile`)

> Intended for any AI coding agent working in this workspace. If you maintain `CLAUDE.md` or `GEMINI.md` elsewhere, keep them aligned with this file.

This repository is a **Flutter** client for the ELECOM voting app. Optimize for **fast, safe iteration**: small changes, `flutter analyze` clean, and runnable builds.

## What this repo is (and is not)

- **This repo (`elecom_mobile`)**: Flutter UI, local config, and HTTP calls to the backend. There is **no Django/Python API code here**.
- **Backend (Django)**: Lives in a **separate** tree, typically next to this project, e.g. `F:\elecom_web\backend` (contains `manage.py`, `core/settings.py`, `core/urls.py`, `core/views.py`, `elecom_auth/`, `.env`). If the user mentions "the backend," **open or reference that path explicitly**; it is not under `lib/backend/` unless they added a stub folder.

Agents fixing **404/500 on API routes**, **email/OTP**, or **DB behavior** must edit the **Django backend** project, not only this Flutter repo.

## Repo map (where to put code)

- **App entrypoint**: `lib/main.dart` boots notifications/services then runs `ElecomApp`.
- **App shell / routing / top-level widgets**: `lib/app/`
- **Reusable "core" concerns** (config, networking, session, notifications, ledger, etc.): `lib/core/`
- **Feature modules** (screens, controllers, feature-specific widgets/services): `lib/features/`
- **Assets**: `assets/` and `pubspec.yaml` `flutter/assets`

## API base URL (Flutter)

- **Preferred**: `flutter run --dart-define=API_BASE_URL=http://<host>:8000`
- **Implementation**: `lib/core/config/api_config.dart` reads `String.fromEnvironment('API_BASE_URL')`. The current fallback on all platforms is `https://el3com.duckdns.org` (production). Local development requires an explicit override; do not assume the default points to a local server.
- **Rule**: Do not scatter hardcoded base URLs; use `ApiConfig.baseUrl` (or the same pattern) for new HTTP code.

## Mobile HTTP API shape (contract hints)

The app calls Django under **`{baseUrl}/api/mobile/...`** for most mobile flows. Examples:

- Forgot password: `POST /api/mobile/auth/forgot-password/`, `POST /api/mobile/auth/verify-otp/`, `POST /api/mobile/auth/reset-password/` (see `lib/features/auth/data/forgot_password_api.dart`). Step 1 returns **404** with `ok: false` when no account matches the Student ID or email (no OTP is sent).
- Responses are usually JSON with an **`ok`** boolean; clients may throw if the body is not JSON (e.g. Django HTML error pages).

If the client gets **404**, check **`core/urls.py`** on the backend for the path. If **500** with "unexpected" in the app, the server may have returned **non-JSON**; check Django logs and the matching view in **`core/views.py`**.

## Backend configuration (high level)

The Django server reads **`backend/.env`** (loaded in `core/settings.py`). Relevant knobs agents often touch:

- **Database**: `DATABASES` / `DB_*` as used in that project's settings.
- **Email (forgot-password OTP)**: `EMAIL_BACKEND`, `EMAIL_HOST*`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL`. Default backend may be **console** (no real inbox) unless SMTP is set in `.env`.

Restart **`runserver`** (or the production process) after changing `.env` or URL routes.

## SMS OTP (SMS Chef)

The app supports sending OTP via SMS using the user's own Android phone as a gateway through **SMS Chef**.

### How it works
- The backend view `_send_otp_sms()` in `core/views.py` calls `https://www.cloud.smschef.com/api/send/sms`
- The SMS Chef Android app must be installed and running on the gateway device

### Required `.env` keys on the server (`/var/www/elecom/backend/.env`)
```
SMSCHEF_API_KEY=<your api key from cloud.smschef.com>
SMSCHEF_DEVICE_ID=<device id from SMS Chef app → Settings → Device Information>
SMSCHEF_SIM_SLOT=<0 for SIM 1, 1 for SIM 2 — default 0>
```

### Known gateway device
- **Model**: Realme RMX3261
- **Device ID**: `cb723b0014acd1b3`
- **Active SIM slot**: `0` (SIM 1)

### Diagnosing SMS failures
- `{"status":400,"message":"Invalid Parameters"}` → `device_id` is missing or wrong in the API call
- `{"status":400,"message":"Invalid phone number!"}` → phone number format issue; backend normalizes to E.164 (`+639XXXXXXXXX`)
- `{"status":401,"message":"Invalid API secret supplied!"}` → wrong `SMSCHEF_API_KEY`
- Response `200` with 56-byte body but no SMS received → check server `.env` has all three keys; verify `SMSCHEF_SIM_SLOT` is correct (not `2`)
- No "sms chef" in `journalctl` → check if the `.env` on the **server** (not local) has the keys; they are separate files

### After changing `.env` on the server
```bash
sudo systemctl restart gunicorn
```

## Building a release APK

### App identity
- **Application ID**: `com.elecom.mobile`
- **Namespace**: `com.elecom.mobile`
- **MainActivity**: `android/app/src/main/kotlin/com/elecom/mobile/MainActivity.kt`

### Signing
- The APK is signed with the **Android debug keystore** to match the existing Mediafire distribution.
- Keystore path (local machine): `C:\Users\Redjan Phil\.android\debug.keystore`
- Config: `android/key.properties` (not committed — gitignored)
  ```properties
  storePassword=android
  keyPassword=android
  keyAlias=androiddebugkey
  storeFile=C:\\Users\\Redjan Phil\\.android\\debug.keystore
  ```
- `android/app/build.gradle.kts` loads `key.properties` and applies it to the release build type.
- **Do not switch to a new release keystore** unless intentionally re-distributing — changing the signing key breaks updates for existing installs and triggers Google Play Protect "unknown developer" warnings.

### Version bumping
Use the helper script `bump_and_build.ps1` at the repo root:
```powershell
.\bump_and_build.ps1           # bump build number only, then build
.\bump_and_build.ps1 -patch    # bump patch version (1.0.0 -> 1.0.1)
.\bump_and_build.ps1 -minor    # bump minor version (1.0.0 -> 1.1.0)
.\bump_and_build.ps1 -major    # bump major version (1.0.0 -> 2.0.0)
.\bump_and_build.ps1 -nobuild  # bump version only, skip flutter build
```
The build number (`+N` in `pubspec.yaml`) always increments on every run — Android uses this as `versionCode` to detect updates.

### Output
```
build\app\outputs\flutter-apk\app-release.apk
```

### Google Play Protect warning
Sideloaded APKs (distributed outside the Play Store) will show a Play Protect warning on first install. This is normal and unavoidable for sideloaded apps. Users tap **"Install anyway"** to proceed. Using the same debug keystore as previous releases minimizes this — devices that already have the app won't see the "unknown developer" warning on updates.

## Running the app (local)

- **Install deps**: `flutter pub get`
- **Run**: `flutter run`
- **Optional**: `flutter run --dart-define=API_BASE_URL=http://<host>:8000`

## Quality gates (before handing back)

- **Analyze**: `flutter analyze`
- **Format**: `dart format .`
- **Tests**: `flutter test` (when tests exist/are relevant to the change)

## Engineering conventions (for changes in this repo)

- **Prefer feature-first placement**: UI/state for a feature goes under `lib/features/<feature>/...`. Shared utilities go in `lib/core/...`.
- **Avoid mixing state management styles** within one flow; follow existing patterns in the closest feature/module.
- **Networking**: keep API base URL decisions centralized in `ApiConfig`; do not hardcode new base URLs in random services/widgets.
- **Keep diffs tight**: avoid drive-by refactors unless necessary to complete the task.

## Git hygiene (important)

Do **not** commit build outputs or IDE caches. These paths should remain untracked/ignored:

- `.dart_tool/`
- `build/`
- `android/.gradle/` (and similar Gradle caches)
- Platform build folders under `android/app/` (`debug`, `profile`, `release`)
- `android/key.properties` (contains signing passwords)
- `android/app/*.jks` and `android/app/*.keystore`

If they show up as untracked changes, they should be removed from git tracking (if accidentally added) and kept ignored.

## When things break

- Start from the actual error output (compile/runtime/logcat / Django traceback) and fix the *root cause*.
- For **API** issues, confirm **which host** the device hits (`ApiConfig`) and **which repo** owns the route (Flutter vs `elecom_web/backend`).
- For **SMS OTP** issues, always check the **server's** `.env` (not local) and gunicorn logs (`journalctl -u gunicorn -n 100 --no-pager`).
- Prefer deterministic reproduction (minimal steps) and add/adjust tests where feasible.

## EleVote Live Chat — Architecture & Lessons Learned

### How the chat works (mobile ↔ backend ↔ web admin)

- **Table**: `elevote_chat_messages` — columns: `id (BIGSERIAL)`, `student_id`, `role` (`user` / `assistant` / `admin`), `content`, `model`, `created_at`
- **Table**: `elevote_chat_takeover` — columns: `student_id (PK)`, `active (bool)`, `taken_at`, `taken_by (admin student_id)`
- **Mobile endpoint**: `GET/POST/DELETE /api/mobile/elevote/chat/`
  - `GET ?since_id=<n>` returns only messages with `id > n` (up to 50, oldest-first) + `takeover_active` bool
  - `POST { "message": "..." }` saves user message, calls Groq AI unless admin takeover is active
  - POST response includes `message` (user row with real `id`), `assistant_message` (AI row), `takeover_active`
- **Admin endpoints** (web only): `/api/admin/chat/reply/`, `/api/admin/chat/takeover/`, `/api/admin/chat/thread/?since_id=`

### Polling approach (no WebSocket)

The backend has **no Django Channels / WebSocket infrastructure** — it runs Gunicorn (WSGI). Real-time is achieved via **3-second interval polling** on the mobile:

- `_pollTimer` fires `_poll()` every 3 s
- `_poll()` calls `GET /api/mobile/elevote/chat/?since_id=_lastMessageId`
- Only appends messages with `id > 0 && !existingIds.contains(id)` — **de-duplicates by server id**
- Skips if `_sending == true` (avoids race with optimistic send)
- `_isLive` green dot in appbar fades in for 2 s when a new message arrives

### Optimistic send & de-duplication

- When user sends, an optimistic bubble is added with `id: -1` (sentinel)
- After POST response, the `-1` bubble is **replaced in-place** with the real server message (real id)
- The poll filter `m.id > 0` skips any `-1` bubble, preventing duplicates
- `_lastMessageId` is updated from POST response, not from poll — avoids race conditions

### Admin photo in chat bubbles

- `admin_chat_reply_api` saves the admin's own `student_id` into the `model` field of the message row
- `_elevote_message_json` enriches admin messages with `sender_photo_url` + `sender_name` by joining `users` table on `row.model`
- Fallback for old messages (where `model` is null): queries `elevote_chat_takeover.taken_by` for the same `student_id`
- Mobile `_ChatBubble` renders `Image.network(senderPhotoUrl)` inside `ClipOval` with `support_agent` icon fallback
- Admin name is shown above the bubble (like Messenger group chat sender label)

### ListView blinking fix

- Use `ListView.builder` (not `ListView` with `children:`) — only builds visible items, no full rebuild on setState
- Use `ClampingScrollPhysics()` — prevents bounce/overscroll that triggers layout loops
- Initial load uses `jumpTo` (instant, no animation frame loop); user actions use `animateTo`
- `_onScroll` listener drives `_showScrollDown` bool — shows Messenger-style floating down-arrow FAB when user scrolls up

### Dark mode color palette

- In **dark mode**, use `Color(0xFF60A5FA)` (Tailwind blue-400) instead of `Color(0xFF2563EB)` (blue-600) for all blue UI elements — blue-600 is too dark to read on dark backgrounds
- Section headers ("Candidates", "Omnibus Code", "Election Transparency") use `isDark ? Color(0xFF60A5FA) : Color(0xFF2563EB)`
- Info card stat tiles, arc painters, and bottom nav inactive items follow the same rule

### AppBar icons (Results / Election / Receipt / Me tabs)

- Use plain `Icons.search` and `Icons.notifications_none` at 24px — **no Container wrapper, no circle decoration**
- The circle/pill decoration caused large grey blobs in the appbar on non-home tabs
- Padding: search icon `EdgeInsets.fromLTRB(8, 8, 4, 8)`, bell icon `EdgeInsets.fromLTRB(4, 8, 8, 8)` — keeps them visually close together
- Notification badge: red circle at `right: -2, top: -2`, size 16, font 9px w900

### Deploy sequence (production server)

After changing `F:\elecom_web\backend\core\views.py` or any backend file:
```bash
cd /var/www/elecom
git pull origin main
sudo systemctl restart gunicorn
sudo systemctl status gunicorn --no-pager | tail -5
```

After changing Flutter mobile code, rebuild APK:
```powershell
.\bump_and_build.ps1
```

## Face Verification — Local InsightFace (No Face++ API)

### Why
Face++ free plan has daily quota limits and `CONCURRENCY_LIMIT_EXCEEDED` errors under load.
The system now uses **InsightFace (ArcFace)** running entirely on the server — no external API, no cost, no rate limits.

### How it works
- **Enrollment**: captures a selfie → InsightFace computes a 512-d ArcFace embedding → stored as JSON in `FaceEnrollment.face_encoding`
- **Duplicate check**: on every enrollment, the new embedding is compared (cosine similarity ≥ 0.40) against all other active enrollments — blocks same-face registration under two accounts
- **Verification before voting**: live selfie embedding compared against stored enrollment embedding — must score ≥ 0.40 to pass
- Face++ is kept as a last-resort fallback only if both insightface and face_recognition are unavailable

### Key files
- `backend/core/local_face_service.py` — all face encoding/comparison logic
- `backend/core/views.py` — `_save_face_enrollment_facepp()` and `_face_verification_vote_handler()` call `local_face_service` first
- `elecom_voting/migrations/0016_face_enrollment_local_encoding.py` — adds `face_encoding` TextField to `FaceEnrollment` model

### Fresh server setup (run once)
```bash
# 1. System library required by OpenCV (insightface dependency)
apt-get install -y libgl1

# 2. Install Python packages (insightface, onnxruntime, opencv-python are in requirements.txt)
/var/www/elecom/venv/bin/pip install -r /var/www/elecom/backend/requirements.txt

# 3. Run migrations (creates face_encoding column)
/var/www/elecom/venv/bin/python /var/www/elecom/backend/manage.py migrate

# 4. Restart gunicorn
sudo systemctl restart gunicorn
```

### Troubleshooting
- `ImportError: libGL.so.1` → run `apt-get install -y libgl1` then restart gunicorn
- `InsightFace initialisation failed` → check gunicorn logs: `journalctl -u gunicorn -n 30 --no-pager | grep -i insightface`
- First enrollment after deploy takes a few extra seconds — InsightFace downloads `buffalo_sc` model weights (~30MB) on first use and caches them in `~/.insightface/models/`
- Legacy enrollments (before this migration) auto-backfill their `face_encoding` on first verification attempt by downloading the Cloudinary photo and re-encoding it

## Calendar of Activities — Automatic Updates

- Implemented in `lib/features/elecom/student_dashboard/student_dashboard.dart`. Fetches `/api/mobile/calendar-events/` every **3 seconds**, following the chat polling approach; this is polling, not a WebSocket connection.
- Poll only while the app is resumed, the dashboard route is visible, and Home is the selected tab. Refresh immediately when returning to the visible Home route or resuming the app.
- `_loadingCalendarEvents` prevents overlapping requests. Compare the new event list with the previous list before calling `setState`; retain the last successful list on failures and retry on the next poll.
- Fetch the full list so additions, edits, and deletions are reflected. Preserve the calendar widget's selected month, expansion state, and scroll position during updates.
- Cancel `_calendarPollTimer` and unregister `WidgetsBindingObserver` in `dispose`.
- The backend admin and mobile calendar endpoints read the same `election_calendar_events` table. No backend change was needed for automatic mobile updates.

## Candidate Filing — Follow-up Documents and Rejection Rules

### COC administration

- Web page: `F:\elecom_web\frontend\org_elecom\elecom_admin\elecom_certificate_of_candidacy.html`; its link follows Candidate Files in all admin sidebars.
- `candidate_certificate_settings` stores per-election USG/department academic year and chairperson settings. `candidate_certificate_issuances` stores the approved PDF, frozen settings, and initial approval timestamp. Migration `elecom_auth.0009` creates both tables; install `pypdf` and `reportlab` from the backend requirements.
- Initial approval dates the COC in Philippine time and saves the issued edition while retaining the original archive. Final approval and later settings changes must not modify the issued PDF. Do not infer older initial approval dates from `reviewed_at`, which may have been overwritten by final review.
- Mobile previews load settings from `/api/mobile/certificate-of-candidacy/settings/`; filed certificate views download the server edition to avoid displaying an outdated local copy. Deployment steps: `docs/coc-admin-settings.md`.
- Chairperson signatures are drawn/uploaded once on COC Management and saved for both forms in `candidate_certificate_settings.chairperson_signature_bytes` (migration `elecom_auth.0010`). Admin placement previews may show the signature, but initial candidate COCs must not contain it. Final approval saves an immutable additional PDF in `candidate_certificate_finalizations`; certificate downloads select it only for status `approved`. Original and initial editions remain unchanged. Do not expose reusable signature bytes through mobile settings responses.

### Filing stages

- Initial filing: `pending`. Initial approval changes it to `requirements_pending`; the candidate is not yet published.
- Follow-up submission: Certificate of Enrollment, grades for the last two consecutive semesters, and Good Moral Certificate. Once all three PDFs are saved, the status becomes `requirements_review` and `requirements_submitted_at` is recorded. The 2x2 photo is already included in the initial COC; no duplicate photo upload is required.
- Final approval publishes the candidate and changes the status to `approved`.
- Both rejection stages use `rejected`, but their refiling rules differ:
  - **Initial filing rejected:** corrections and **File Again** are allowed.
  - **Follow-up documents rejected:** no new filing is allowed for that election, including a different position. Show **Requirements Rejected**, retain the reason, and hide **File Again**.
- Do not treat every `rejected` application as eligible to refile. A non-empty `requirements_submitted_at` or any of the four saved requirement URLs identifies the follow-up stage, including older records.

### Enforcement and files

- Mobile rule: `lib/features/elecom/data/candidate_application_policy.dart`, function `canFileCandidateApplicationAgain`. Also honors a server `can_file_again: false` restriction. Used by `candidate_filing_screen.dart` for the button, callback guard, and rejection message.
- Backend: `F:\elecom_web\backend\core\views.py`, helper `_candidate_application_can_file_again`. `_candidate_application_json` exposes the `can_file_again` boolean.
- `candidate_application_submit_api` must fetch the requirement metadata for the student's existing filing in the current election and return **409**, code `requirements_rejected`, after a follow-up rejection. Hiding a button alone is insufficient.
- No database migration is needed for this rule; the timestamp and requirement URL columns already exist. Do not delete the rejected filing or its documents to enable another filing.

### Upload failures: 413 and SQL errors

- Mobile `submitCandidateRequirements` sends the three PDFs in **one multipart POST** to `/api/mobile/candidate-applications/requirements/`. Older clients may still send a separate photo, which remains accepted for compatibility.
- Each file must be non-empty and at most **8 MiB**. The combined request can approach **24 MiB**, plus multipart overhead (32 MiB for older clients). The app validates sizes before sending; Django retains per-file validation.
- An HTML **413** response means an upload-size rejection, not invalid document JSON. Preserve the specific upload error and backend validation errors; do not relabel response-decoding errors as network failures.
- Nginx configuration is separate from the Git repository. In `/etc/nginx/sites-available/elecom`, set `client_max_body_size 40m;` inside the **HTTPS server block with `listen 443 ssl`**. Putting it only in the port 80 redirect block does not affect HTTPS uploads. Check for smaller location-level overrides.
- Validate and apply with `sudo nginx -t && sudo systemctl reload nginx`. Full steps are in `docs/candidate-requirements-server-fix.md`.
- The requirements SELECT in `candidate_application_requirements_api` must include `FROM candidate_applications`. A prior missing FROM caused `column "id" does not exist`, even though the table had an `id` column. Inspect the query and running code before altering the schema.
- `git pull` does not reload Gunicorn workers. After pushing and pulling backend fixes, run `sudo systemctl restart gunicorn`.
- Use absolute paths in diagnostic commands to avoid confusion when already inside `backend`:

```bash
grep -n -A 5 'SELECT id, status, requirements_photo_url' /var/www/elecom/backend/core/views.py
sudo journalctl -u gunicorn --since "2 minutes ago" --no-pager
```

Reproduce the submission before inspecting logs. Successful GET polling entries alone do not prove a requirements POST succeeded. SQL displayed by `grep` is code to inspect, not a shell command to execute.

### Focused regression checks

```powershell
flutter test test/candidate_requirements_upload_test.dart test/candidate_application_policy_test.dart
python F:/elecom_web/backend/core/test_candidate_application_policy.py
```

The backend tests extract the relevant view functions to test policy and the submit guard without importing unrelated face-service dependencies. They do not replace a full Django system check or live upload verification.

## Windows Release Builds — Disk Space and Gradle Cache Recovery

- Check free space on **both C: and F:**. Even with outputs on F:, Gradle normally uses `C:\Users\Redjan Phil\.gradle` and Windows temporary storage on C:. An APK build previously failed at `mergeReleaseNativeLibs` / `ExtractJniTransform` with **There is not enough space on the disk**.
- A working alternative is the ignored workspace cache at `F:\elecom_mobile\.dart_tool\gradle-user-home` and temporary directory at `.dart_tool\build-temp`. These are disposable build artifacts; never commit them.
- For a new alternate cache, copy only the original `.gradle\caches\modules-2` dependency cache and `.gradle\wrapper` distributions if needed. Avoid copying interrupted generated caches such as version-specific caches or `jars-9`; an incomplete generated Gradle API jar caused missing `Settings` / `pluginManagement` errors despite unchanged build scripts.
- If that cache error occurs, stop the failed build and regenerate only the affected temporary generated cache. Before recursive cleanup, verify resolved absolute paths are inside the intended cache directory. Do not delete source files, signing files, or personal files.
- Set these variables **only for the build session**, creating the directories first:

```powershell
$env:GRADLE_USER_HOME = 'F:\elecom_mobile\.dart_tool\gradle-user-home'
$env:TEMP = 'F:\elecom_mobile\.dart_tool\build-temp'
$env:TMP = $env:TEMP
$env:JAVA_TOOL_OPTIONS = ($env:JAVA_TOOL_OPTIONS + ' -Djava.io.tmpdir=F:/elecom_mobile/.dart_tool/build-temp').Trim()
flutter build apk --release --no-pub
```

- Use `--no-pub` only when dependencies are already resolved. On retry, keep the version already bumped; do not repeatedly run the bump script for failed attempts.
- If PowerShell blocks `bump_and_build.ps1`, use `powershell -NoProfile -ExecutionPolicy Bypass -File .\bump_and_build.ps1` for that process rather than changing the machine's execution policy.
- The bump script can print **Build failed** while returning process exit code 0. Inspect Flutter/Gradle's final output, and verify `build/app/outputs/apk/release/output-metadata.json` for the expected `versionCode`; do not mistake an older APK for a successful new build.
- Cache regeneration and release builds were slow on this machine. Preserve completed caches and wait for the actual build result rather than repeatedly restarting an active build.

### Verification snapshot (2026-10-07)

- Release `1.0.0+7` built successfully and includes the follow-up rejection restriction. Check `pubspec.yaml` for the current version rather than treating this snapshot as the latest release forever.
- Nine targeted Flutter tests and four backend policy tests passed; the changed filing screen and policy analyzed cleanly.
- Full-app analysis had 42 existing warnings/lint findings, and the existing login widget test expected missing text `WELCOME`. Investigate current output before attributing these to a new change.
- Local `manage.py check` was blocked by missing `numpy` from the face-service import. Backend syntax and isolated policy tests passed; full Django checks still require the appropriate backend environment and dependencies.
