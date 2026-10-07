import 'package:elecom_mobile/screens/get_started_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final scenario in [
    (size: const Size(320, 640), scale: 1.0),
    (size: const Size(320, 568), scale: 1.5),
    (size: const Size(640, 360), scale: 1.0),
  ]) {
    testWidgets(
      'three steps and centered controls fit ${scenario.size} at ${scenario.scale}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!,
            ),
            home: const GetStartedScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Biometric Face Verification'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('face-scan-illustration')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Cast your vote securely. Quick facial recognition verification ensures your ballot is authentic and protected.',
          ),
          findsOneWidget,
        );
        final heading = tester.widget<Text>(
          find.text('Biometric Face Verification'),
        );
        expect(heading.style!.fontSize, 22);
        expect(heading.style!.fontWeight, FontWeight.w700);
        expect(heading.style!.color, const Color(0xFF0D1B3E));
        final graphic = tester.getRect(
          find.byKey(const ValueKey('onboarding-graphic-security')),
        );
        expect(graphic.height, lessThanOrEqualTo(220));
        expect(tester.takeException(), isNull);
        for (var step = 0; step < 2; step++) {
          await tester.tap(find.byKey(const ValueKey('onboarding-next')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Instant Results'), findsOneWidget);
        expect(find.text('Continue to Login'), findsOneWidget);
        final dots = tester.getRect(
          find.byKey(const ValueKey('onboarding-pagination')),
        );
        final button = tester.getRect(
          find.byKey(const ValueKey('onboarding-next')),
        );
        expect(dots.center.dx, closeTo(scenario.size.width / 2, 0.5));
        expect(dots.overlaps(button), isFalse);
        expect(button.bottom, lessThanOrEqualTo(scenario.size.height));
        await tester.drag(find.byType(PageView), const Offset(500, 0));
        await tester.pumpAndSettle();
        expect(find.text('Next'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'onboarding completion remains persisted with the existing key',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(await GetStartedScreen.shouldShow(), isTrue);
      await GetStartedScreen.markComplete();
      expect(await GetStartedScreen.shouldShow(), isFalse);
    },
  );
}
