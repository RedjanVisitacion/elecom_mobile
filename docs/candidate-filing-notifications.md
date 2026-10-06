# Candidate filing notifications

Filing submission, initial approval/rejection, requirements submission, and final
approval/rejection create persistent `candidate_filing` inbox entries. The mobile
inbox and unread badge refresh every 3 seconds throughout the signed-in app,
pause in the background, and refresh on resume. Failed requests retain the inbox.

Android push uses FCM high-priority data messages, displayed by the existing
local-notification service. Both polling and FCM use the server notification ID
and a persisted delivery history to avoid repeated alerts. Push permission and
the app's Push Notifications setting remain under the user's control.

## Firebase configuration required before background push can work

1. In Firebase Console, register Android package `com.elecom.mobile`.
2. Download `google-services.json` into `android/app/google-services.json`.
   The Gradle plugin activates when the file exists. This environment config is ignored.
3. Enable Firebase Cloud Messaging HTTP v1 for the same project.
4. On the server, store that project's service-account JSON outside the repository
   (for example `/etc/elecom/firebase-service-account.json`) and grant the Gunicorn
   service user read access. Do not put this secret in the APK or commit it.
5. In `/var/www/elecom/backend/.env`, set:

   ```dotenv
   GOOGLE_APPLICATION_CREDENTIALS=/etc/elecom/firebase-service-account.json
   ```

Official setup: https://firebase.google.com/docs/android/setup
Admin credentials: https://firebase.google.com/docs/admin/setup
Flutter message handling: https://firebase.google.com/docs/cloud-messaging/flutter/receive

## Deploy the backend before the updated APK

```bash
cd /var/www/elecom
git pull origin main
/var/www/elecom/venv/bin/pip install -r /var/www/elecom/backend/requirements.txt
/var/www/elecom/venv/bin/python /var/www/elecom/backend/manage.py migrate
sudo systemctl restart gunicorn
```

Migration `0017_candidate_push_notifications` creates the authenticated device-token
registry and push outbox. Push is queued inside the filing transaction and sent
only after commit. FCM failures do not undo a successful review. Unregistered
tokens are removed; successfully delivered devices are skipped on retry.

Configure a one-minute cron job under the same server account/environment as Gunicorn:

```cron
* * * * * /var/www/elecom/venv/bin/python /var/www/elecom/backend/manage.py deliver_candidate_push --limit 100
```

This retries queued deliveries for up to seven days. Entries with no currently
registered devices are completed without replaying old alerts onto future devices.
The command reports checked entries; inspect Gunicorn/cron logs for deferred sends.
A Firebase network failure can still delay push; the durable inbox remains available.

Rebuild and install the APK after supplying the Android Firebase file. Log in,
allow notifications, and enable Push Notifications. Verify both approval stages
with the app on Home, then in the background. Check the inbox and unread badge,
then test rejection reasons, disabling push, and logout/account switching.

Android force-stop and device power restrictions can block background delivery
until the app is reopened. Do not use a stopped-app test as the sole FCM check.

## Focused checks

```powershell
flutter test --concurrency=1 test/notification_center_live_updates_test.dart test/notification_push_deduplication_test.dart test/candidate_filing_live_status_test.dart
python F:/elecom_web/backend/core/test_candidate_push.py
python F:/elecom_web/backend/core/test_candidate_application_policy.py
```
