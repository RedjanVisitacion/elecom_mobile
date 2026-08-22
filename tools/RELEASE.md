# Release Commands

Build a new release APK with an auto-increased build number:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_release_apk.ps1
```

The upload file will be:

```text
build\app\outputs\flutter-apk\elecom.apk
```

To also change the visible version name while building:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_release_apk.ps1 -VersionName 1.0.1
```

Upload `elecom.apk` to MediaFire. Use the printed build number as
`APP_UPDATE_LATEST_BUILD` in the backend `.env`.
