import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/state/login_view_model.dart';
import '../features/elecom/student_dashboard/utils/theme_notifier.dart';

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
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.black,
                  brightness: Brightness.dark,
                ),
              ),
              themeMode: themeState.themeMode,
              home: const SplashScreen(),
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

class _SoftKeyboardFocusGuard extends StatefulWidget {
  const _SoftKeyboardFocusGuard({required this.child});

  final Widget? child;

  @override
  State<_SoftKeyboardFocusGuard> createState() => _SoftKeyboardFocusGuardState();
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

    final editable =
        focusContext.findAncestorWidgetOfExactType<EditableText>();
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
