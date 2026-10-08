import 'package:flutter/material.dart';

/// Dashboard colors for filing controls, including separately pushed routes.
ThemeData candidateFilingTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final blue = dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  final surface = dark ? base.colorScheme.surface : Colors.white;
  return base.copyWith(
    primaryColor: blue,
    primaryIconTheme: const IconThemeData(color: Colors.white),
    colorScheme: base.colorScheme.copyWith(
      primary: blue,
      onPrimary: dark ? const Color(0xFF0F172A) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF1E3A8A)
          : const Color(0xFFDBEAFE),
      onPrimaryContainer: dark ? Colors.white : const Color(0xFF0F172A),
      secondary: blue,
      surface: surface,
      surfaceTint: Colors.transparent,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: dark ? Colors.white : const Color(0xFF0F172A),
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: dark ? Colors.white : const Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    textSelectionTheme: base.textSelectionTheme.copyWith(cursorColor: blue),
  );
}

class CandidateFilingStyle extends StatelessWidget {
  const CandidateFilingStyle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: candidateFilingTheme(Theme.of(context)), child: child);
}
