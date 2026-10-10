/// Sequential enrollment challenge. Yaw is in the user's mirrored coordinates:
/// negative means their left, positive means their right.
enum EnrollmentLivenessStep { blink, turnLeft, turnRight, complete }

class EnrollmentLivenessController {
  static const double turnThreshold = 20;
  static const Duration poseHold = Duration(milliseconds: 180);

  EnrollmentLivenessStep _step = EnrollmentLivenessStep.blink;
  EnrollmentLivenessStep get step => _step;
  DateTime? _poseSince;
  DateTime? _lastPoseAt;
  int? _trackingId;

  int get completedSteps => step.index;
  bool get isComplete => step == EnrollmentLivenessStep.complete;

  /// ML Kit measures input-image yaw; front previews mirror that image.
  static double? userYaw(double? imageYaw, {required bool frontCamera}) =>
      imageYaw == null
      ? null
      : frontCamera
      ? -imageYaw
      : imageYaw;

  void reset() {
    _step = EnrollmentLivenessStep.blink;
    _poseSince = null;
    _lastPoseAt = null;
    _trackingId = null;
  }

  /// Returns false on a different tracked face, requiring a fresh blink.
  bool observeFace(int? trackingId) {
    if (_trackingId != null && trackingId != _trackingId) {
      reset();
      _trackingId = trackingId;
      return false;
    }
    _trackingId = trackingId;
    return true;
  }

  void confirmBlink() {
    if (step == EnrollmentLivenessStep.blink) {
      _step = EnrollmentLivenessStep.turnLeft;
      _poseSince = null;
    }
  }

  /// Invalid or interrupted poses cannot accumulate time across separate frames.
  bool observeYaw(double? yaw, DateTime now) {
    if (_lastPoseAt != null &&
        now.difference(_lastPoseAt!) > const Duration(milliseconds: 350)) {
      _poseSince = null;
    }
    _lastPoseAt = now;
    final valid =
        yaw != null &&
        yaw.isFinite &&
        switch (step) {
          EnrollmentLivenessStep.turnLeft => yaw <= -turnThreshold,
          EnrollmentLivenessStep.turnRight => yaw >= turnThreshold,
          _ => false,
        };
    if (!valid) {
      _poseSince = null;
      return false;
    }
    _poseSince ??= now;
    if (now.difference(_poseSince!) < poseHold) return false;
    _step = step == EnrollmentLivenessStep.turnLeft
        ? EnrollmentLivenessStep.turnRight
        : EnrollmentLivenessStep.complete;
    _poseSince = null;
    return true;
  }
}
