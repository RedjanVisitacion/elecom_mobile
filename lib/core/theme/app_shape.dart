import 'package:flutter/material.dart';

/// Shared compact geometry for cards and controls throughout the app.
abstract final class AppShape {
  static const cardRadius = 8.0;
  static const controlRadius = 6.0;
  static const cardBorderRadius = BorderRadius.all(Radius.circular(cardRadius));
  static const controlBorderRadius = BorderRadius.all(
    Radius.circular(controlRadius),
  );
  static const card = RoundedRectangleBorder(borderRadius: cardBorderRadius);
  static const control = RoundedRectangleBorder(
    borderRadius: controlBorderRadius,
  );
}

InputBorder? _compactBorder(InputBorder? border) => border is OutlineInputBorder
    ? border.copyWith(borderRadius: AppShape.controlBorderRadius)
    : border;

InputDecorationThemeData _compactInputs(InputDecorationThemeData input) =>
    input.copyWith(
      border: _compactBorder(input.border),
      enabledBorder: _compactBorder(input.enabledBorder),
      focusedBorder: _compactBorder(input.focusedBorder),
      errorBorder: _compactBorder(input.errorBorder),
      focusedErrorBorder: _compactBorder(input.focusedErrorBorder),
      disabledBorder: _compactBorder(input.disabledBorder),
    );

ButtonStyle _compactButton(ButtonStyle? style) => (style ?? const ButtonStyle())
    .copyWith(shape: const WidgetStatePropertyAll(AppShape.control));

/// Apply after a screen's color/font theme so nested themes keep compact shapes.
ThemeData compactAppTheme(ThemeData base) => base.copyWith(
  cardTheme: base.cardTheme.copyWith(shape: AppShape.card),
  listTileTheme: base.listTileTheme.copyWith(shape: AppShape.card),
  dialogTheme: base.dialogTheme.copyWith(shape: AppShape.card),
  popupMenuTheme: base.popupMenuTheme.copyWith(shape: AppShape.card),
  bottomSheetTheme: base.bottomSheetTheme.copyWith(
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppShape.cardRadius),
      ),
    ),
  ),
  datePickerTheme: base.datePickerTheme.copyWith(shape: AppShape.card),
  timePickerTheme: base.timePickerTheme.copyWith(shape: AppShape.card),
  expansionTileTheme: base.expansionTileTheme.copyWith(
    shape: AppShape.card,
    collapsedShape: AppShape.card,
  ),
  inputDecorationTheme: _compactInputs(base.inputDecorationTheme),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: _compactButton(base.elevatedButtonTheme.style),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: _compactButton(base.filledButtonTheme.style),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: _compactButton(base.outlinedButtonTheme.style),
  ),
  textButtonTheme: TextButtonThemeData(
    style: _compactButton(base.textButtonTheme.style),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: _compactButton(base.segmentedButtonTheme.style),
  ),
  chipTheme: base.chipTheme.copyWith(shape: AppShape.control),
  searchBarTheme: base.searchBarTheme.copyWith(
    shape: const WidgetStatePropertyAll(AppShape.control),
  ),
);

/// Keeps existing ThemeData construction readable when applying shared shapes.
extension CompactAppTheme on ThemeData {
  ThemeData withCompactShapes() => compactAppTheme(this);
}
