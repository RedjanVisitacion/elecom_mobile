import 'dart:async';
// The camera plugin's platform interface is used only to fake hardware in tests.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:elecom_mobile/features/elecom/face/live_face_capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Camera extends CameraPlatform {
  int created = 0;
  final disposed = <int>[];
  final errors = StreamController<CameraErrorEvent>.broadcast();
  @override
  Future<List<CameraDescription>> availableCameras() async => [
    const CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 90,
    ),
  ];
  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? preset, {
    bool enableAudio = false,
  }) async => ++created;
  @override
  Future<void> initializeCamera(
    int id, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) => Stream.value(
    CameraInitializedEvent(
      id,
      640,
      480,
      ExposureMode.auto,
      false,
      FocusMode.auto,
      false,
    ),
  );
  @override
  Stream<CameraErrorEvent> onCameraError(int id) =>
      Stream.value(CameraErrorEvent(id, ''));
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  bool supportsImageStreaming() => true;
  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int id, {
    CameraImageStreamOptions? options,
  }) => const Stream.empty();
  @override
  Widget buildPreview(int id) => const ColoredBox(color: Colors.grey);
  @override
  Future<void> dispose(int id) async {
    disposed.add(id);
  }
}

void main() {
  testWidgets('no-face Retry replaces camera; Cancel exits guarded route', (
    tester,
  ) async {
    final original = CameraPlatform.instance;
    final camera = _Camera();
    CameraPlatform.instance = camera;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('google_mlkit_face_detector'),
      (_) async => null,
    );
    addTearDown(() async {
      CameraPlatform.instance = original;
      await camera.errors.close();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_face_detector'),
        null,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LiveFaceCaptureScreen(
                  mode: LiveFaceMode.verification,
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(camera.created, 1);
    await tester.pump(const Duration(seconds: 19));
    expect(find.text('No face detected. Please try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(camera.disposed, contains(1));
    expect(camera.created, 2);
    expect(find.text('Position your face inside the frame'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(camera.disposed, contains(2));
    expect(camera.created, 3);
    await tester.tap(find.text('Cancel'));
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(LiveFaceCaptureScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
