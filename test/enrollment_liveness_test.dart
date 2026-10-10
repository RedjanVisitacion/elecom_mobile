import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elecom_mobile/features/elecom/face/enrollment_liveness_controller.dart';
import 'package:elecom_mobile/features/elecom/face/enrollment_liveness_progress.dart';

void main() {
  final start = DateTime(2026);

  test('normalizes yaw for mirrored front-camera guidance', () {
    expect(EnrollmentLivenessController.userYaw(20, frontCamera: true), -20);
    expect(EnrollmentLivenessController.userYaw(-20, frontCamera: true), 20);
    expect(EnrollmentLivenessController.userYaw(20, frontCamera: false), 20);
    expect(
      EnrollmentLivenessController.userYaw(null, frontCamera: true),
      isNull,
    );
  });

  test('requires blink then sustained left then sustained right', () {
    final controller = EnrollmentLivenessController();
    controller.observeYaw(-25, start);
    controller.observeYaw(25, start.add(const Duration(milliseconds: 200)));
    expect(controller.completedSteps, 0);
    controller.confirmBlink();
    controller.observeYaw(25, start);
    expect(controller.completedSteps, 1);
    controller.observeYaw(-20, start);
    expect(
      controller.observeYaw(-20, start.add(const Duration(milliseconds: 180))),
      isTrue,
    );
    expect(controller.completedSteps, 2);
    controller.observeYaw(20, start.add(const Duration(milliseconds: 200)));
    expect(controller.isComplete, isFalse);
    controller.observeYaw(20, start.add(const Duration(milliseconds: 380)));
    expect(controller.isComplete, isTrue);
  });

  test('angle spikes, missing angles, and frame gaps do not pass a turn', () {
    final controller = EnrollmentLivenessController()..confirmBlink();
    for (final invalid in [null, double.nan, double.infinity, -19.9, 25.0]) {
      controller.observeYaw(-25, start);
      controller.observeYaw(
        invalid,
        start.add(const Duration(milliseconds: 100)),
      );
      controller.observeYaw(-25, start.add(const Duration(milliseconds: 200)));
      expect(controller.completedSteps, 1);
      controller.reset();
      controller.confirmBlink();
    }
    controller.observeYaw(-25, start);
    controller.observeYaw(-25, start.add(const Duration(seconds: 2)));
    expect(controller.completedSteps, 1);
  });

  test('changed face and retry require a new blink', () {
    final controller = EnrollmentLivenessController();
    controller.observeFace(1);
    controller.confirmBlink();
    expect(controller.observeFace(2), isFalse);
    expect(controller.completedSteps, 0);
    controller.confirmBlink();
    controller.reset();
    expect(controller.isComplete, isFalse);
    expect(controller.completedSteps, 0);
  });

  testWidgets(
    'overlay shows completed and remaining steps on a narrow screen',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                child: EnrollmentLivenessProgress(completedSteps: 2),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Blink'), findsOneWidget);
      expect(find.text('Turn Left'), findsOneWidget);
      expect(find.text('Turn Right'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
