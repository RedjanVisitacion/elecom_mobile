import 'package:elecom_mobile/features/auth/presentation/login_screen.dart';
import 'package:elecom_mobile/features/auth/state/login_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'login fits narrow screens and keeps accessible actions at scale $scale',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'elecom_tutorial_login_v1': true,
        });
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final vm = LoginViewModel();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: vm,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('LOGIN'), findsOneWidget);
        final footer = tester.getRect(
          find.byKey(const ValueKey('login-campus-footer')),
        );
        final copyright = tester.getRect(
          find.byKey(const ValueKey('login-copyright')),
        );
        expect(footer.left, 0);
        expect(footer.right, 320);
        expect(footer.bottom, 640);
        expect(copyright.bottom, closeTo(footer.bottom - 12, 0.01));
        expect(footer.contains(copyright.center), isTrue);
        expect(find.text('Enter your Student ID'), findsOneWidget);
        expect(find.text('Enter your Password'), findsOneWidget);
        final input = tester.widget<TextField>(find.byType(TextField).first);
        expect(input.decoration!.enabledBorder, isA<UnderlineInputBorder>());
        expect(input.style!.color, const Color(0xFF1E293B));
        expect(input.decoration!.hintStyle!.color, const Color(0xFF64748B));
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.ensureVisible(find.byTooltip('Show password'));
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();
        expect(vm.obscurePassword, isFalse);
        expect(
          tester.widget<TextField>(find.byType(TextField).last).obscureText,
          isFalse,
        );
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(vm.acceptedTerms, isTrue);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();
        await tester.ensureVisible(find.text('Sign In'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      },
    );
  }
}
