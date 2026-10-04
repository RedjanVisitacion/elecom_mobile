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
- **Implementation**: `lib/core/config/api_config.dart` reads `String.fromEnvironment('API_BASE_URL')`. If empty, it falls back to:
  - Android emulator/device: `http://192.168.1.171:8000` (LAN IP — adjust if the user's PC address differs)
  - Other platforms: `http://127.0.0.1:8000`
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
