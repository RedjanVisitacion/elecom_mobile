import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/state/login_view_model.dart';

class ElecomApp extends StatelessWidget {
  const ElecomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Elecom',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Colors.black,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
