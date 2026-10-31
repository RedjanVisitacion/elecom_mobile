import 'package:elecom_mobile/core/theme/app_shape.dart';
import 'package:elecom_mobile/features/elecom/candidates/candidate_filing_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    test(
      'compact shapes preserve state styling in ${brightness.name} mode',
      () {
        const errorSide = BorderSide(color: Colors.red, width: 2);
        const focusedSide = BorderSide(color: Colors.blue, width: 1.5);
        final base = ThemeData(
          brightness: brightness,
          inputDecorationTheme: const InputDecorationThemeData(
            fillColor: Colors.amber,
            filled: true,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
              borderSide: focusedSide,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
              borderSide: errorSide,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey,
              padding: const EdgeInsets.all(20),
            ),
          ),
        );
        final compact = compactAppTheme(base);
        expect(compact.colorScheme, base.colorScheme);
        expect(compact.textTheme, base.textTheme);
        final focused =
            compact.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
        final error =
            compact.inputDecorationTheme.errorBorder! as OutlineInputBorder;
        expect(focused.borderSide, focusedSide);
        expect(error.borderSide, errorSide);
        expect(focused.borderRadius, AppShape.controlBorderRadius);
        expect(error.borderRadius, AppShape.controlBorderRadius);
        expect(compact.inputDecorationTheme.fillColor, Colors.amber);
        final style = compact.filledButtonTheme.style!;
        expect(style.backgroundColor!.resolve({}), Colors.blue);
        expect(
          style.backgroundColor!.resolve({WidgetState.disabled}),
          Colors.grey,
        );
        expect(style.padding!.resolve({}), const EdgeInsets.all(20));
      },
    );

    test(
      'filing color overrides retain compact controls in ${brightness.name} mode',
      () {
        final theme = candidateFilingTheme(ThemeData(brightness: brightness));
        expect(
          theme.primaryColor,
          brightness == Brightness.dark
              ? const Color(0xFF60A5FA)
              : const Color(0xFF2563EB),
        );
        expect(theme.primaryIconTheme.color, Colors.white);
        expect(
          theme.outlinedButtonTheme.style!.shape!.resolve({}),
          AppShape.control,
        );
        expect(theme.cardTheme.shape, AppShape.card);
      },
    );
  }
}
