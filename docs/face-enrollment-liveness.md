# Mobile enrollment liveness

Enrollment requires one centered face, a stable forward-facing blink, a left
turn, then a right turn. Voting verification continues to use blink capture.

`EnrollmentLivenessController` consumes the confirmed open-close-open blink
from `LiveFaceCaptureScreen`, then ML Kit `headEulerAngleY` observations. Front
camera yaw is inverted into mirrored user coordinates: left is <= -20 degrees,
right is >= +20 degrees. Each qualifying pose must persist for 180 ms, with
no frame gap longer than 350 ms. Missing/nonfinite yaw or an interrupted pose
clears the pose hold. See [ML Kit's angle conventions](https://developers.google.com/android/reference/com/google/mlkit/vision/face/Face).

The camera overlay shows instructions, directional arrows, and Blink / Turn
Left / Turn Right completion indicators. Detection continues after the blink;
only completion locks the analyzer and begins capture. The success-animation
delay was removed; capture starts as soon as the image stream stops safely.

Losing alignment, losing the face, detecting multiple faces, switching tracked
faces, pausing the app, or retrying requires a fresh sequence. Each motion has
an 18-second deadline. Frame analysis remains serial and stale detections are
discarded after lifecycle/capture transitions.

The captured file returns to `FaceEnrollmentScreen`, which uses the existing
multipart `face_image` upload. The Django InsightFace duplicate check and
Cloudinary storage are unchanged. Motion validation is on-device; a still-image
upload alone is not server-verifiable proof that these motions occurred.

## Verification

Run sequentially:

```powershell
flutter test --no-pub --concurrency=1 test/enrollment_liveness_test.dart
flutter analyze --no-pub
```

On the RMX3261, check the following before distributing an APK:

- A blink advances only to Turn Left; an early right turn cannot complete it.
- Physical left/right movements agree with the mirrored arrows.
- Brief angle spikes do not advance steps; sustained 20-degree turns do.
- Losing the face, another person entering, backgrounding, or Retry resets progress.
- The final right turn triggers one photo and the normal enrollment upload.
- Accepted photos enroll successfully through InsightFace; duplicate faces are rejected.
- Check portrait/landscape alignment and capture quality in actual lighting.

Automated tests exercise the state transitions and narrow-screen progress UI.
They do not exercise physical camera calibration or the production backend.

The release build exposed Kotlin incremental-cache errors because plugin sources
are on C: and the project is on F:. `android/gradle.properties` disables Kotlin
incremental compilation and uses the in-process compiler to avoid these cache
failures and an additional compiler JVM. Native recompilation may take longer.
These are supported [Kotlin compiler settings](https://kotlinlang.org/docs/gradle-compilation-and-caches.html).
