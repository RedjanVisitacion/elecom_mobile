# Release Commands

Before building a new APK, bump the build number:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bump_build.ps1
```

To also change the visible version name:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bump_build.ps1 -VersionName 1.0.1
```

Then build the APK and upload it to MediaFire. Use the printed build number as
`APP_UPDATE_LATEST_BUILD` in the backend `.env`.
