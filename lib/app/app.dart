import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/state/login_view_model.dart';
import '../features/elecom/student_dashboard/utils/theme_notifier.dart';

final RouteObserver<PageRoute<dynamic>> elecomRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

class ElecomApp extends StatelessWidget {
  const ElecomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeState, _) {
          final darkTheme = themeState.isPremiumMode
              ? _premiumTheme()
              : _darkTheme();
          return ToastificationWrapper(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Elecom',
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
                scaffoldBackgroundColor: Colors.white,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                textSelectionTheme: const TextSelectionThemeData(
                  cursorColor: Colors.black,
                ),
              ),
              darkTheme: darkTheme,
              themeMode: themeState.themeMode,
              home: const SplashScreen(),
              navigatorObservers: [elecomRouteObserver],
              builder: (context, child) {
                return _SoftKeyboardFocusGuard(child: child);
              },
            ),
          );
        },
      ),
    );
  }
}

ThemeData _darkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.black,
      brightness: Brightness.dark,
    ),
  );
}

ThemeData _premiumTheme() {
  const royalBlue = Color(0xFF2563EB);
  const gold = Color(0xFFFACC15);
  const navy = Color(0xFF0F172A);
  const surface = Color(0xFF111827);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: royalBlue,
        brightness: Brightness.dark,
      ).copyWith(
        primary: royalBlue,
        secondary: gold,
        surface: navy,
        onSurface: Colors.white,
        surfaceContainerHighest: surface,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF05070B),
    canvasColor: navy,
    cardColor: surface.withValues(alpha: 0.82),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF05070B),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navy.withValues(alpha: 0.94),
      indicatorColor: gold.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? gold
              : Colors.white.withValues(alpha: 0.62),
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white.withValues(alpha: 0.62),
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
          fontSize: 11,
        );
      }),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: navy,
      selectedItemColor: gold,
      unselectedItemColor: Colors.white.withValues(alpha: 0.62),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface.withValues(alpha: 0.78),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: royalBlue,
      textColor: Colors.white,
      subtitleTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.055),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: gold, width: 1.3),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: royalBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: gold),
    dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.10)),
  );
}

class _SoftKeyboardFocusGuard extends StatefulWidget {
  const _SoftKeyboardFocusGuard({required this.child});

  final Widget? child;

  @override
  State<_SoftKeyboardFocusGuard> createState() =>
      _SoftKeyboardFocusGuardState();
}

class _SoftKeyboardFocusGuardState extends State<_SoftKeyboardFocusGuard> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showKeyboardForFocusedInput();
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 80)).then((_) {
          if (!mounted) return;
          _showKeyboardForFocusedInput();
        }),
      );
    });
  }

  void _showKeyboardForFocusedInput() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null || !focusContext.mounted) return;

    final editable = focusContext.findAncestorWidgetOfExactType<EditableText>();
    final focusedWidget = focusContext.widget;
    final focusedEditable = focusedWidget is EditableText
        ? focusedWidget
        : editable;
    if (focusedEditable == null || focusedEditable.readOnly) return;

    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox.shrink();
  }
}
