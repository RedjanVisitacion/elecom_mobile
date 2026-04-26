import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
          return MaterialApp(
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
          );
        },
      ),
    );
  }
}
