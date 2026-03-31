import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/login_register_screen.dart';
import 'screens/home/home_dashboard_screen.dart';
import 'utils/app_colors.dart';
import 'firebase_options.dart';
import 'translation/translation_demo_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with a shorter timeout and better error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8)); // Reduced from 12s to 8s
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    // We still continue to runApp, screens will handle missing Firebase state
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  void _toggleTheme() {
    _themeModeNotifier.value =
        _themeModeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.deepPurple,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.periwinkle : AppColors.deepPurple,
      secondary: isDark ? AppColors.deepPurple : AppColors.periwinkle,
      tertiary: isDark ? const Color(0xFF2A223D) : AppColors.lavender,
      surface: isDark ? const Color(0xFF121212) : Colors.white,
      onSurface: isDark ? const Color(0xFFEDE7FF) : const Color(0xFF231A3D),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF101014) : Colors.white,
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
    );
  }

  @override
  void dispose() {
    _themeModeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Smart Document & Vocab',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeMode,
          // App home — use auth state to pick Home or Auth screen.
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return HomeScreen(
                  isDarkMode: themeMode == ThemeMode.dark,
                  onToggleTheme: _toggleTheme,
                );
              }
              return const AuthScreen();
            },
          ),
          routes: {
            '/translate_demo': (_) => const TranslationDemoScreen(),
          },
        );
      },
    );
  }
}
