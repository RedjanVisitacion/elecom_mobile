import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'enrollment_liveness_controller.dart';
import 'enrollment_liveness_progress.dart';
import 'biometric_tracking_overlay.dart';

enum LiveFaceMode { enrollment, verification }

/// UI / flow states for face capture (product + internal).
enum FaceCaptureUiState {
  initializingCamera,
  positioningFace,
  faceDetected,
  holdStill,
  blinkNow,
  blinkDetected,
  turnLeft,
  turnRight,
  capturing,
  verifying,
  failed,
}

/// Internal blink sequence after the face is stable inside the oval.
enum _BlinkStage { idle, sawOpenWhileEligible, inClosedSegment }

class LiveFaceCaptureResult {
  const LiveFaceCaptureResult({
    required this.capturedImage,
    required this.statusMessage,
    this.livenessPassed = true,
  });

  final File capturedImage;
  final String statusMessage;
  final bool livenessPassed;
}

class LiveFaceCaptureScreen extends StatefulWidget {
  const LiveFaceCaptureScreen({super.key, required this.mode, this.title});

  final LiveFaceMode mode;
  final String? title;

  @override
  State<LiveFaceCaptureScreen> createState() => _LiveFaceCaptureScreenState();
}

class _LiveFaceCaptureScreenState extends State<LiveFaceCaptureScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const double _fallbackEyeOpenMin = 0.46;
  static const double _fallbackEyeClosedMax = 0.42;
  static const double _hardClosedEyeMax = 0.24;
  static const double _minBlinkDrop = 0.18;
  static const Duration _stableHoldRequired = Duration(milliseconds: 350);
  static const Duration _closedMin = Duration(milliseconds: 35);
  static const Duration _closedMax = Duration(milliseconds: 950);
  static const Duration _sessionTimeout = Duration(seconds: 18);
  static const Duration _minFrameInterval = Duration(milliseconds: 55);

  CameraController? _camera;
  FaceDetector? _detector;
  bool _cameraReady = false;
  bool _permissionDenied = false;
  bool _isExiting = false;
  bool _processingDisabled = false;
  bool _appResumed = true;

  bool _streamBusy = false;
  bool _restartingCamera = false;
  Future<void> _cameraTransition = Future<void>.value();
  final List<Offset> _meshPoints = [];
  final List<Offset> _eyeTargets = [];
  DateTime? _lastFrameProcessedAt;

  FaceCaptureUiState _uiState = FaceCaptureUiState.initializingCamera;
  final _liveness = EnrollmentLivenessController();

  _BlinkStage _blinkStage = _BlinkStage.idle;
  DateTime? _stableSince;
  DateTime? _closedStartedAt;
  final List<Offset> _recentCenters = [];
  double? _openEyeBaseline;
  double? _lowestEyeScoreInClosedSegment;

  bool _captureInFlight = false;
  bool _showCheckFlash = false;
  bool _blinkSessionArmed = false;

  /// Locks the analyzer only after the entire required liveness sequence.
  bool _livenessLocked = false;

  /// Stream stopped + photo capture + validation / pop in progress.
  bool _isProcessingFinalCapture = false;

  /// Prevents duplicate [CameraController.takePicture] calls.
  bool _hasCapturedFinalImage = false;

  /// Bumped when liveness locks or analyzer restarts — stale async ML completions must not touch UI.
  int _analysisGeneration = 0;

  Timer? _sessionTimer;
  Timer? _noFaceTimer;

  late final AnimationController _pulseController;
  late final AnimationController _checkController;

  /// Instruction shown in the floating pill (may differ slightly from internal state label).
  String _instructionPillText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _instructionPillText = _pillForState(FaceCaptureUiState.initializingCamera);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _checkController.dispose();
    _cancelTimers();
    unawaited(_releasePipeline());
    super.dispose();
  }

  void _cancelTimers() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _noFaceTimer?.cancel();
    _noFaceTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _analysisGeneration++;
      _cancelTimers();
      _liveness.reset();
      _openEyeBaseline = null;
      _resetBlinkTracking();
      _stableSince = null;
      _recentCenters.clear();
      if (!_isProcessingFinalCapture) {
        _safeSetState(() {
          _uiState = FaceCaptureUiState.positioningFace;
          _instructionPillText = _pillForState(_uiState);
        });
      }
      _cameraTransition = _cameraTransition.then(
        (_) => _stopStreamSafe(camera),
      );
    } else if (state == AppLifecycleState.resumed &&
        !_captureInFlight &&
        !_processingDisabled &&
        !_isExiting &&
        !_livenessLocked &&
        !_isProcessingFinalCapture) {
      _cameraTransition = _cameraTransition.then((_) async {
        if (mounted && _appResumed && !_isExiting) {
          await _retryAfterFailure();
        }
      });
    }
  }

  Future<void> _stopStreamSafe(CameraController camera) async {
    try {
      if (camera.value.isInitialized && camera.value.isStreamingImages) {
        await camera.stopImageStream().timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
  }

  Future<void> _releasePipeline() async {
    _processingDisabled = true;
    _cancelTimers();

    final cam = _camera;
    final det = _detector;

    try {
      if (cam != null && cam.value.isInitialized) {
        await _stopStreamSafe(cam);
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    } catch (_) {}

    try {
      await det?.close().timeout(const Duration(seconds: 5));
    } catch (_) {}
    _detector = null;

    try {
      await cam?.dispose().timeout(const Duration(seconds: 5));
    } catch (_) {}
    _camera = null;
  }

  Future<void> _requestExit() async {
    if (_isExiting) return;
    _safeSetState(() => _isExiting = true);
    _processingDisabled = true;
    await _releasePipeline();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _initCamera() async {
    _processingDisabled = false;
    try {
      final cameras = await availableCameras().timeout(
        const Duration(seconds: 10),
      );
      final front = cameras
          .where((c) => c.lensDirection == CameraLensDirection.front)
          .toList();
      final selected = front.isNotEmpty ? front.first : cameras.first;
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      _camera = controller;
      await controller.initialize().timeout(const Duration(seconds: 15));
      if (!mounted || _isExiting || !_appResumed) {
        await controller.dispose();
        return;
      }
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      _camera = controller;
      _cameraReady = true;
      _safeSetState(() {
        _uiState = FaceCaptureUiState.positioningFace;
        _instructionPillText = _pillForState(_uiState);
      });
      _startNoFaceTimer();
      await _startImageStream();
    } on CameraException catch (e) {
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'AudioAccessDenied' ||
          (e.description ?? '').toLowerCase().contains('permission')) {
        _permissionDenied = true;
        _safeSetState(() {
          _uiState = FaceCaptureUiState.failed;
          _instructionPillText =
              'Camera permission is required for face verification.';
        });
      } else {
        _safeSetState(() {
          _uiState = FaceCaptureUiState.failed;
          _instructionPillText = 'Could not open the camera. Please try again.';
        });
      }
    } catch (_) {
      _safeSetState(() {
        _uiState = FaceCaptureUiState.failed;
        _instructionPillText = 'Could not open the camera. Please try again.';
      });
    }
  }

  void _startNoFaceTimer() {
    _noFaceTimer?.cancel();
    _noFaceTimer = Timer(_sessionTimeout, () {
      if (!mounted ||
          _processingDisabled ||
          _captureInFlight ||
          _livenessLocked ||
          _isProcessingFinalCapture) {
        return;
      }
      if (_uiState == FaceCaptureUiState.positioningFace ||
          _uiState == FaceCaptureUiState.faceDetected) {
        _safeSetState(() {
          _uiState = FaceCaptureUiState.failed;
          _instructionPillText = 'No face detected. Please try again.';
        });
      }
    });
  }

  void _restartMotionDeadline() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_sessionTimeout, () {
      if (!mounted ||
          _processingDisabled ||
          _captureInFlight ||
          _livenessLocked ||
          _isProcessingFinalCapture) {
        return;
      }
      if (_uiState != FaceCaptureUiState.failed) {
        _safeSetState(() {
          final waitingForBlink = _uiState == FaceCaptureUiState.blinkNow;
          _uiState = FaceCaptureUiState.failed;
          _instructionPillText = waitingForBlink
              ? 'Blink not detected. Try blinking slowly once.'
              : 'Head turn not detected. Please try again.';
          _resetBlinkTracking();
        });
        _cancelBlinkDeadline();
      }
    });
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  /// Analyzer-driven UI only — never overwrite blink/success/capture UI.
  void _applyLiveAnalyzerUi(VoidCallback fn) {
    if (!mounted || _livenessLocked || _isProcessingFinalCapture) return;
    setState(fn);
  }

  Future<void> _startImageStream() async {
    final camera = _camera;
    final detector = _detector;
    if (camera == null ||
        detector == null ||
        !camera.value.isInitialized ||
        !_appResumed ||
        _processingDisabled ||
        _livenessLocked ||
        _isProcessingFinalCapture) {
      return;
    }
    if (camera.value.isStreamingImages) return;
    await camera
        .startImageStream((image) {
          _processCameraFrame(image, detector);
        })
        .timeout(const Duration(seconds: 10));
  }

  void _processCameraFrame(CameraImage image, FaceDetector detector) {
    if (!_appResumed ||
        _processingDisabled ||
        _captureInFlight ||
        _isExiting ||
        _livenessLocked ||
        _isProcessingFinalCapture) {
      return;
    }
    final now = DateTime.now();
    if (_lastFrameProcessedAt != null &&
        now.difference(_lastFrameProcessedAt!) < _minFrameInterval) {
      return;
    }
    if (_streamBusy) return;
    _streamBusy = true;
    _lastFrameProcessedAt = now;

    final genWhenScheduled = _analysisGeneration;

    scheduleMicrotask(() async {
      try {
        if (genWhenScheduled != _analysisGeneration) return;
        final bytes = WriteBuffer();
        for (final plane in image.planes) {
          bytes.putUint8List(plane.bytes);
        }
        final allBytes = bytes.done().buffer.asUint8List();
        final inputImage = InputImage.fromBytes(
          bytes: allBytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: _rotationFromCamera(_camera!),
            format: _formatFromCameraImage(image),
            bytesPerRow: image.planes.first.bytesPerRow,
          ),
        );
        final faces = await detector
            .processImage(inputImage)
            .timeout(const Duration(seconds: 10));
        if (!mounted ||
            genWhenScheduled != _analysisGeneration ||
            _livenessLocked ||
            _isProcessingFinalCapture ||
            _processingDisabled ||
            _captureInFlight) {
          return;
        }
        _onFacesDetected(faces, image);
      } catch (_) {
        // Ignore per-frame failures.
      } finally {
        _streamBusy = false;
      }
    });
  }

  InputImageRotation _rotationFromCamera(CameraController controller) {
    var degrees = controller.description.sensorOrientation;
    if (Platform.isAndroid) {
      final deviceDegrees = switch (controller.value.deviceOrientation) {
        DeviceOrientation.portraitUp => 0,
        DeviceOrientation.landscapeLeft => 90,
        DeviceOrientation.portraitDown => 180,
        DeviceOrientation.landscapeRight => 270,
      };
      degrees =
          controller.description.lensDirection == CameraLensDirection.front
          ? (degrees + deviceDegrees) % 360
          : (degrees - deviceDegrees + 360) % 360;
    }
    switch (degrees) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  InputImageFormat _formatFromCameraImage(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.bgra8888:
        return InputImageFormat.bgra8888;
      case ImageFormatGroup.yuv420:
      case ImageFormatGroup.nv21:
        return InputImageFormat.nv21;
      default:
        return InputImageFormat.nv21;
    }
  }

  double? _eyeScore(double? l, double? r) {
    if (l == null && r == null) return null;
    if (l == null) return r;
    if (r == null) return l;
    return (l + r) / 2;
  }

  double? _lowestEye(double? l, double? r) {
    if (l == null && r == null) return null;
    if (l == null) return r;
    if (r == null) return l;
    return math.min(l, r);
  }

  void _learnOpenEyeBaseline(double score) {
    final current = _openEyeBaseline;
    if (current == null) {
      _openEyeBaseline = score.clamp(0.35, 0.95).toDouble();
      return;
    }
    if (score >= current) {
      _openEyeBaseline = (current * 0.65) + (score * 0.35);
    } else if (_blinkStage != _BlinkStage.inClosedSegment) {
      _openEyeBaseline = (current * 0.94) + (score * 0.06);
    }
  }

  bool _eyesOpen(double? l, double? r) {
    final score = _eyeScore(l, r);
    if (score == null) return false;
    final baseline = _openEyeBaseline ?? score;
    final threshold = math.max(_fallbackEyeOpenMin, baseline - 0.12);
    return score >= threshold || score >= 0.62;
  }

  bool _eyesClosed(double? l, double? r) {
    final score = _eyeScore(l, r);
    if (score == null) return false;
    final lowest = _lowestEye(l, r) ?? score;
    final baseline = _openEyeBaseline ?? math.max(score, _fallbackEyeOpenMin);
    final adaptiveClosed = math.min(
      _fallbackEyeClosedMax,
      baseline - _minBlinkDrop,
    );
    final clearDrop = baseline - score >= _minBlinkDrop;
    return score <= adaptiveClosed ||
        lowest <= _hardClosedEyeMax ||
        (score <= 0.50 && clearDrop);
  }

  bool _eyesAmbiguous(double? l, double? r) {
    final score = _eyeScore(l, r);
    if (score == null) return true;
    return !_eyesOpen(l, r) && !_eyesClosed(l, r);
  }

  Offset _normalizedFaceCenter(
    Face face,
    CameraImage image,
    CameraController controller,
  ) {
    final box = face.boundingBox;
    final cx = box.center.dx;
    final cy = box.center.dy;
    // ML Kit bounding boxes use rotated, upright image coordinates.
    final rotation = _rotationFromCamera(controller);
    final sideways =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final w = (sideways ? image.height : image.width).toDouble();
    final h = (sideways ? image.width : image.height).toDouble();
    double nx = cx / w;
    double ny = cy / h;
    if (controller.description.lensDirection == CameraLensDirection.front) {
      nx = 1.0 - nx;
    }
    return Offset(nx, ny);
  }

  double _faceSizeRatio(Face face, CameraImage image) {
    final box = face.boundingBox;
    final area = box.width * box.height;
    final ia = image.width * image.height;
    if (ia <= 0) return 0;
    return area / ia;
  }

  bool _faceCenterInOvalGuide(
    Face face,
    CameraImage image,
    CameraController controller,
  ) {
    final c = _normalizedFaceCenter(face, image, controller);
    const ecx = 0.5;
    const ecy = 0.5;
    const rx = 0.40;
    const ry = 0.32;
    final dx = (c.dx - ecx) / rx;
    final dy = (c.dy - ecy) / ry;
    final inside = dx * dx + dy * dy <= 1.0;
    final bigEnough = _faceSizeRatio(face, image) >= 0.026;
    return inside && bigEnough;
  }

  bool _isStableEnough() {
    if (_recentCenters.length < 4) return false;
    double maxD = 0;
    final first = _recentCenters.first;
    for (final o in _recentCenters) {
      maxD = math.max(maxD, (o - first).distance);
    }
    return maxD < 0.092;
  }

  void _pushCenterSample(Offset c) {
    _recentCenters.add(c);
    while (_recentCenters.length > 8) {
      _recentCenters.removeAt(0);
    }
  }

  void _resetBlinkTracking() {
    _blinkStage = _BlinkStage.idle;
    _closedStartedAt = null;
    _lowestEyeScoreInClosedSegment = null;
  }

  void _cancelBlinkDeadline() {
    _blinkSessionArmed = false;
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  void _debugLog(double? l, double? r, String blinkStateLabel) {
    if (kDebugMode) {
      debugPrint(
        '[FaceCapture] leftEyeOpenProbability=${l?.toStringAsFixed(3) ?? "null"} '
        'rightEyeOpenProbability=${r?.toStringAsFixed(3) ?? "null"} '
        'eyeScore=${_eyeScore(l, r)?.toStringAsFixed(3) ?? "null"} '
        'baseline=${_openEyeBaseline?.toStringAsFixed(3) ?? "null"} '
        'currentBlinkState=$blinkStateLabel ui=$_uiState stage=$_blinkStage',
      );
    }
  }

  String _pillForState(FaceCaptureUiState s) {
    switch (s) {
      case FaceCaptureUiState.initializingCamera:
        return 'Starting camera…';
      case FaceCaptureUiState.positioningFace:
        return 'Position your face inside the frame';
      case FaceCaptureUiState.faceDetected:
        return 'Face detected';
      case FaceCaptureUiState.holdStill:
        return 'Hold still';
      case FaceCaptureUiState.blinkNow:
        return widget.mode == LiveFaceMode.enrollment
            ? 'Blink once, then slowly turn head left and right'
            : 'Hold still and blink once';
      case FaceCaptureUiState.blinkDetected:
        return widget.mode == LiveFaceMode.enrollment
            ? 'Liveness complete'
            : 'Blink detected';
      case FaceCaptureUiState.turnLeft:
        return 'Turn head slowly to the left';
      case FaceCaptureUiState.turnRight:
        return 'Turn head slowly to the right';
      case FaceCaptureUiState.capturing:
        return 'Capturing photo';
      case FaceCaptureUiState.verifying:
        return widget.mode == LiveFaceMode.verification
            ? 'Verifying identity'
            : 'Checking image quality';
      case FaceCaptureUiState.failed:
        return _instructionPillText.isEmpty
            ? 'Please try again.'
            : _instructionPillText;
    }
  }

  void _onFacesDetected(List<Face> faces, CameraImage image) {
    if (!mounted ||
        _livenessLocked ||
        _isProcessingFinalCapture ||
        _processingDisabled ||
        _captureInFlight) {
      return;
    }

    final camera = _camera;
    if (camera == null) return;

    if (_uiState == FaceCaptureUiState.failed) return;

    if (faces.length != 1) {
      _meshPoints.clear();
      _eyeTargets.clear();
      _liveness.reset();
      _openEyeBaseline = null;
      _recentCenters.clear();
      _stableSince = null;
      _cancelBlinkDeadline();
      _resetBlinkTracking();
      _applyLiveAnalyzerUi(() {
        _uiState = FaceCaptureUiState.positioningFace;
        _instructionPillText = faces.length > 1
            ? 'Only one person should be in the frame'
            : _pillForState(FaceCaptureUiState.positioningFace);
      });
      if (_noFaceTimer == null) _startNoFaceTimer();
      _debugLog(null, null, 'no_face');
      return;
    }

    final face = faces.first;
    final rotation = _rotationFromCamera(camera);
    final sideways =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final width = (sideways ? image.height : image.width).toDouble();
    final height = (sideways ? image.width : image.height).toDouble();
    Offset normalized(FaceLandmark landmark) {
      final x = landmark.position.x / width;
      return Offset(
        camera.description.lensDirection == CameraLensDirection.front
            ? 1 - x
            : x,
        landmark.position.y / height,
      );
    }

    _meshPoints
      ..clear()
      ..addAll([
        for (final type in [
          FaceLandmarkType.leftEye,
          FaceLandmarkType.rightEye,
          FaceLandmarkType.leftCheek,
          FaceLandmarkType.rightCheek,
          FaceLandmarkType.noseBase,
          FaceLandmarkType.leftMouth,
          FaceLandmarkType.rightMouth,
          FaceLandmarkType.bottomMouth,
        ])
          if (face.landmarks[type] != null) normalized(face.landmarks[type]!),
      ]);
    _eyeTargets
      ..clear()
      ..addAll([
        for (final type in [
          FaceLandmarkType.leftEye,
          FaceLandmarkType.rightEye,
        ])
          if (face.landmarks[type] != null) normalized(face.landmarks[type]!),
      ]);
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;

    if (!_faceCenterInOvalGuide(face, image, camera)) {
      _liveness.reset();
      _openEyeBaseline = null;
      _recentCenters.clear();
      _stableSince = null;
      _cancelBlinkDeadline();
      _resetBlinkTracking();
      _applyLiveAnalyzerUi(() {
        _uiState = FaceCaptureUiState.positioningFace;
        _instructionPillText = _pillForState(
          FaceCaptureUiState.positioningFace,
        );
      });
      if (_noFaceTimer == null) _startNoFaceTimer();
      _debugLog(left, right, 'out_of_oval');
      return;
    }

    _noFaceTimer?.cancel();
    _noFaceTimer = null;

    if (widget.mode == LiveFaceMode.enrollment) {
      if (!_liveness.observeFace(face.trackingId)) {
        _openEyeBaseline = null;
        _cancelBlinkDeadline();
        _resetBlinkTracking();
        _stableSince = null;
        _recentCenters.clear();
      }
      if (_liveness.step != EnrollmentLivenessStep.blink) {
        // ML Kit yaw is relative to the unmirrored input image. The front
        // preview is mirrored, so invert it for the user's left/right cues.
        final yaw = EnrollmentLivenessController.userYaw(
          face.headEulerAngleY,
          frontCamera:
              camera.description.lensDirection == CameraLensDirection.front,
        );
        final advanced = _liveness.observeYaw(yaw, DateTime.now());
        if (_liveness.isComplete) {
          _beginLivenessSuccessCapture();
        } else {
          _showRotationGuidance();
          if (advanced) _restartMotionDeadline();
        }
        return;
      }
      // Establish the blink while looking forward, before any head turns.
      final yaw = face.headEulerAngleY;
      if (yaw == null || !yaw.isFinite || yaw.abs() > 12) {
        _stableSince = null;
        _recentCenters.clear();
        _resetBlinkTracking();
        _applyLiveAnalyzerUi(() {
          _uiState = FaceCaptureUiState.positioningFace;
          _instructionPillText = 'Face the camera and center your head';
        });
        return;
      }
    }

    final center = _normalizedFaceCenter(face, image, camera);
    _pushCenterSample(center);

    final eyeScore = _eyeScore(left, right);
    if (eyeScore == null) {
      _stableSince = null;
      _resetBlinkTracking();
      _applyLiveAnalyzerUi(() {
        _uiState = FaceCaptureUiState.faceDetected;
        _instructionPillText = 'Move closer and face the camera.';
      });
      _debugLog(left, right, 'null_eye_prob');
      return;
    }

    if (!_isStableEnough()) {
      _stableSince = null;
      _resetBlinkTracking();
      _applyLiveAnalyzerUi(() {
        _uiState = FaceCaptureUiState.holdStill;
        _instructionPillText = _pillForState(FaceCaptureUiState.holdStill);
      });
      _debugLog(left, right, 'unstable');
      return;
    }

    _stableSince ??= DateTime.now();
    final stableElapsed = DateTime.now().difference(_stableSince!);
    final stableOk = stableElapsed >= _stableHoldRequired;

    if (!stableOk) {
      _applyLiveAnalyzerUi(() {
        _uiState = FaceCaptureUiState.faceDetected;
        _instructionPillText = _pillForState(FaceCaptureUiState.faceDetected);
      });
      _debugLog(left, right, 'stabilizing');
      return;
    }

    if (_blinkStage != _BlinkStage.inClosedSegment && _eyesOpen(left, right)) {
      _learnOpenEyeBaseline(eyeScore);
    }

    // Stable enough — blink guidance.
    if (_uiState != FaceCaptureUiState.blinkNow &&
        _uiState != FaceCaptureUiState.blinkDetected &&
        _uiState != FaceCaptureUiState.capturing) {
      _applyLiveAnalyzerUi(() {
        _uiState = FaceCaptureUiState.blinkNow;
        _instructionPillText = _pillForState(FaceCaptureUiState.blinkNow);
      });
    }
    if (!_blinkSessionArmed) {
      _blinkSessionArmed = true;
      _restartMotionDeadline();
    }

    final now = DateTime.now();

    // Adaptive blink: open baseline → clear drop → open rebound.
    switch (_blinkStage) {
      case _BlinkStage.idle:
        if (_eyesOpen(left, right)) {
          _blinkStage = _BlinkStage.sawOpenWhileEligible;
          _learnOpenEyeBaseline(eyeScore);
        }
        _debugLog(left, right, 'idle');
        break;

      case _BlinkStage.sawOpenWhileEligible:
        if (_eyesAmbiguous(left, right)) {
          _debugLog(left, right, 'ambiguous_wait');
          break;
        }
        if (_eyesClosed(left, right)) {
          _blinkStage = _BlinkStage.inClosedSegment;
          _closedStartedAt = now;
          _lowestEyeScoreInClosedSegment = eyeScore;
          _debugLog(left, right, 'closed_start');
          break;
        }
        if (!_eyesOpen(left, right)) {
          _blinkStage = _BlinkStage.idle;
        } else {
          _learnOpenEyeBaseline(eyeScore);
        }
        _debugLog(left, right, 'wait_close');
        break;

      case _BlinkStage.inClosedSegment:
        _lowestEyeScoreInClosedSegment = math.min(
          _lowestEyeScoreInClosedSegment ?? eyeScore,
          eyeScore,
        );
        final start = _closedStartedAt;
        if (start != null && now.difference(start) > _closedMax) {
          _resetBlinkTracking();
          _debugLog(left, right, 'closed_too_long');
          break;
        }
        if (_eyesClosed(left, right)) {
          _debugLog(left, right, 'holding_closed');
          break;
        }
        if (_eyesOpen(left, right)) {
          final dur = start != null ? now.difference(start) : Duration.zero;
          final blinkDrop =
              (_openEyeBaseline ?? eyeScore) -
              (_lowestEyeScoreInClosedSegment ?? eyeScore);
          if (dur < _closedMin && blinkDrop < 0.30) {
            _resetBlinkTracking();
            _debugLog(left, right, 'closed_too_short');
            break;
          }
          if (dur > _closedMax) {
            _resetBlinkTracking();
            _debugLog(left, right, 'closed_long_invalid');
            break;
          }
          if (blinkDrop < _minBlinkDrop) {
            _resetBlinkTracking();
            _debugLog(left, right, 'drop_too_small');
            break;
          }
          _cancelBlinkDeadline();
          _debugLog(left, right, 'blink_confirmed');
          if (widget.mode == LiveFaceMode.enrollment) {
            _liveness.confirmBlink();
            _showRotationGuidance();
            _restartMotionDeadline();
          } else {
            _beginLivenessSuccessCapture();
          }
          break;
        }
        _debugLog(left, right, 'ambiguous_in_closed_keep_waiting');
        break;
    }
  }

  void _showRotationGuidance() {
    _applyLiveAnalyzerUi(() {
      _uiState = _liveness.step == EnrollmentLivenessStep.turnLeft
          ? FaceCaptureUiState.turnLeft
          : FaceCaptureUiState.turnRight;
      _instructionPillText = _pillForState(_uiState);
    });
  }

  bool _ovalGuideGreenish() {
    return _uiState == FaceCaptureUiState.faceDetected ||
        _uiState == FaceCaptureUiState.holdStill ||
        _uiState == FaceCaptureUiState.blinkNow ||
        _uiState == FaceCaptureUiState.blinkDetected ||
        _uiState == FaceCaptureUiState.turnLeft ||
        _uiState == FaceCaptureUiState.turnRight ||
        _uiState == FaceCaptureUiState.capturing ||
        _uiState == FaceCaptureUiState.verifying;
  }

  /// Liveness is checked before capture; we do not reject stills for brightness/blur (budget cameras).
  Future<bool> _capturedFileUsable(File file) async {
    try {
      if (!await file.exists()) return false;
      final len = await file.length();
      if (len < 80) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Must be synchronous (no `async` gap) so no other frame microtask resets UI before flags apply.
  void _beginLivenessSuccessCapture() {
    if (widget.mode == LiveFaceMode.enrollment && !_liveness.isComplete) return;
    if (_livenessLocked || _isProcessingFinalCapture) return;

    _analysisGeneration++;
    _livenessLocked = true;
    _isProcessingFinalCapture = true;
    _captureInFlight = true;
    _processingDisabled = true;
    _cancelTimers();
    _cancelBlinkDeadline();

    if (!mounted) return;
    setState(() {
      _uiState = FaceCaptureUiState.blinkDetected;
      _instructionPillText = _pillForState(FaceCaptureUiState.blinkDetected);
      _showCheckFlash = true;
    });
    _checkController.forward(from: 0);

    unawaited(_runCapturePipelineAfterLivenessLocked());
  }

  Future<void> _runCapturePipelineAfterLivenessLocked() async {
    if (!mounted || _hasCapturedFinalImage) return;

    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      await _failFinalCapture('Camera unavailable.');
      return;
    }

    await _stopStreamSafe(camera);

    if (!mounted || _hasCapturedFinalImage) return;

    setState(() {
      _uiState = FaceCaptureUiState.capturing;
      _instructionPillText = _pillForState(FaceCaptureUiState.capturing);
    });

    try {
      if (_hasCapturedFinalImage) return;
      final shot = await camera.takePicture().timeout(
        const Duration(seconds: 12),
      );
      final file = File(shot.path);

      if (!mounted) return;

      final ok = await _capturedFileUsable(file);
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _uiState = FaceCaptureUiState.failed;
          _instructionPillText = 'Could not save photo. Please try again.';
        });
        await _resumePreviewAfterFailedCapture();
        return;
      }

      setState(() => _hasCapturedFinalImage = true);

      if (!mounted) return;
      final result = LiveFaceCaptureResult(
        capturedImage: file,
        statusMessage: widget.mode == LiveFaceMode.enrollment
            ? 'Blink and head turns verified'
            : 'Blink detected',
        livenessPassed: true,
      );
      // Defer pop so camera plugin / stream teardown finishes cleanly on slow devices.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isExiting) return;
        Navigator.of(context).pop(result);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uiState = FaceCaptureUiState.failed;
        _instructionPillText = 'Capture failed. Please try again.';
      });
      await _resumePreviewAfterFailedCapture();
    }
  }

  Future<void> _failFinalCapture(String message) async {
    if (!mounted) return;
    setState(() {
      _uiState = FaceCaptureUiState.failed;
      _instructionPillText = message;
    });
    await _resumePreviewAfterFailedCapture();
  }

  /// Re-open the preview stream after capture/validation failed (camera still initialized).
  Future<void> _resumePreviewAfterFailedCapture() => _retryAfterFailure();

  Future<void> _retryAfterFailure() async {
    if (_restartingCamera || _isExiting || !mounted) return;
    _analysisGeneration++;
    _cancelTimers();
    _cancelBlinkDeadline();
    _livenessLocked = false;
    _liveness.reset();
    _openEyeBaseline = null;
    _isProcessingFinalCapture = false;
    _hasCapturedFinalImage = false;
    _captureInFlight = false;
    _processingDisabled = false;
    _stableSince = null;
    _recentCenters.clear();
    _resetBlinkTracking();

    _restartingCamera = true;
    try {
      _safeSetState(() {
        _cameraReady = false;
        _permissionDenied = false;
        _meshPoints.clear();
        _eyeTargets.clear();
        _uiState = FaceCaptureUiState.initializingCamera;
        _instructionPillText = _pillForState(_uiState);
      });
      await _releasePipeline();
      if (!mounted || _isExiting || !_appResumed) return;
      _streamBusy = false;
      _lastFrameProcessedAt = null;
      await _initCamera();
    } finally {
      _restartingCamera = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.title ??
        (widget.mode == LiveFaceMode.enrollment
            ? 'Face Enrollment'
            : 'Face Verification');

    return PopScope(
      canPop: _isExiting || _hasCapturedFinalImage,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _requestExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_cameraReady && _camera != null)
              Positioned.fill(child: CameraPreview(_camera!))
            else
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            IgnorePointer(
              child: CustomPaint(
                painter: BiometricTrackingPainter(
                  animation: _pulseController,
                  active: _ovalGuideGreenish() && _appResumed,
                  landmarks: _meshPoints,
                  eyes: _eyeTargets,
                ),
              ),
            ),
            if (_showCheckFlash &&
                (_uiState == FaceCaptureUiState.blinkDetected ||
                    _uiState == FaceCaptureUiState.capturing))
              Center(
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _checkController,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF22C55E),
                      size: 72,
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => unawaited(_requestExit()),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_ovalGuideGreenish())
                      FadeTransition(
                        opacity: Tween<double>(
                          begin: 0.55,
                          end: 1,
                        ).animate(_pulseController),
                        child: const Text(
                          'LIVENESS ACTIVE \u25c9',
                          style: TextStyle(
                            color: Color(0xFF72E8DD),
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    _InstructionPill(
                      text: _instructionPillText,
                      direction: _uiState == FaceCaptureUiState.turnLeft
                          ? Icons.arrow_back_rounded
                          : _uiState == FaceCaptureUiState.turnRight
                          ? Icons.arrow_forward_rounded
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.mode == LiveFaceMode.enrollment)
              Align(
                alignment: const Alignment(0, -0.70),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: EnrollmentLivenessProgress(
                    completedSteps: _liveness.completedSteps,
                  ),
                ),
              ),
            if (_uiState != FaceCaptureUiState.failed)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: BiometricCaptureActions(
                      animation: _pulseController,
                      onCancel: () => unawaited(_requestExit()),
                      label: _isProcessingFinalCapture
                          ? 'Capturing...'
                          : _cameraReady
                          ? 'Scanning...'
                          : 'Starting camera...',
                    ),
                  ),
                ),
              ),
            if (_uiState == FaceCaptureUiState.failed)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_permissionDenied)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Allow camera access in system settings, then tap Retry.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    unawaited(_retryAfterFailure()),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white70),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => unawaited(_requestExit()),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InstructionPill extends StatelessWidget {
  const _InstructionPill({required this.text, this.direction});

  final String text;
  final IconData? direction;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (direction != null) ...[
            Icon(direction, color: Colors.white70, size: 24),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.25,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
