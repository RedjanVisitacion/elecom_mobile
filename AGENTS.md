# Agent Instructions (Flutter app: `elecom_mobile`)

> This file is mirrored across `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` so the same instructions load in any AI environment.

This repository is a **Flutter** application. Optimize for **fast, safe iteration**: small changes, `flutter analyze` clean, and runnable builds.

## Repo map (where to put code)

- **App entrypoint**: `lib/main.dart` boots notifications/services then runs `ElecomApp`.
- **App shell / routing / top-level widgets**: `lib/app/`
- **Reusable “core” concerns** (config, networking, session, notifications, ledger, etc.): `lib/core/`
- **Feature modules** (screens, controllers, feature-specific widgets/services): `lib/features/`
- **Assets**: `assets/` and `pubspec.yaml` `flutter/assets`

## Running the app (local)

- **Install deps**:
  - `flutter pub get`
- **Run**:
  - `flutter run`
- **Set API base URL** (preferred):
  - `flutter run --dart-define=API_BASE_URL=http://<host>:8000`

`lib/core/config/api_config.dart` reads `API_BASE_URL` via `String.fromEnvironment('API_BASE_URL')`, otherwise it falls back to:
- Android: `http://192.168.1.171:8000`
- Others: `http://127.0.0.1:8000`

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

If they show up as untracked changes, they should be removed from git tracking (if accidentally added) and kept ignored.

## When things break

- Start from the actual error output (compile/runtime/logcat) and fix the *root cause*.
- Prefer deterministic reproduction (minimal steps) and add/adjust tests where feasible.


