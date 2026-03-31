import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/login_register_screen.dart';
import 'screens/home/home_dashboard_screen.dart';
import 'services/notification_service.dart';
import 'utils/app_colors.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first so Firebase-dependent screens don't race on startup.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 12));

    await NotificationService.instance.initialize();
  } on TimeoutException catch (error) {
    debugPrint('Firebase initialize timeout: $error');
  } catch (error, stackTrace) {
    debugPrint('Firebase initialize error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppRoot();
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  void _toggleTheme() {
    _themeModeNotifier.value = _themeModeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  ThemeData _buildLightTheme() {
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.deepPurple,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.deepPurple,
          secondary: AppColors.periwinkle,
          tertiary: AppColors.lavender,
          surface: Colors.white,
          onSurface: const Color(0xFF231A3D),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(elevation: 0),
    );
  }

  ThemeData _buildDarkTheme() {
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.deepPurple,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.periwinkle,
          secondary: AppColors.deepPurple,
          tertiary: const Color(0xFF2A223D),
          surface: const Color(0xFF121212),
          onSurface: const Color(0xFFEDE7FF),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF101014),
      appBarTheme: const AppBarTheme(elevation: 0),
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
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: themeMode,
          themeAnimationDuration: const Duration(milliseconds: 350),
          themeAnimationCurve: Curves.easeInOutCubic,
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
        );
      },
    );
  }
}
