import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'providers/chat_provider.dart';
import 'providers/document_provider.dart';
import 'providers/flashcard_provider.dart';
import 'providers/location_provider.dart';
import 'providers/news_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_register_screen.dart';
import 'screens/home/home_dashboard_screen.dart';
import 'services/location_cleanup_service.dart';
import 'translation/translation_demo_screen.dart';
import 'utils/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
        ChangeNotifierProvider.value(value: ChatProvider.instance),
        ChangeNotifierProvider.value(value: DocumentProvider.instance),
        ChangeNotifierProvider.value(value: FlashcardProvider.instance),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    debugPrint('[AppLifecycle] State changed: $state');

    switch (state) {
      case AppLifecycleState.detached:
        debugPrint('[AppLifecycle] DETACHED: App is being terminated');
        _clearUserLocation(currentUser.uid);
        break;
      case AppLifecycleState.paused:
        debugPrint('[AppLifecycle] PAUSED: App entered background');
        _clearUserLocation(currentUser.uid);
        break;
      case AppLifecycleState.resumed:
        debugPrint('[AppLifecycle] RESUMED: App came to foreground');
        break;
      case AppLifecycleState.inactive:
        debugPrint('[AppLifecycle] INACTIVE: App transitioning');
        break;
      case AppLifecycleState.hidden:
        debugPrint('[AppLifecycle] HIDDEN: App is hidden');
        break;
    }
  }

  Future<void> _clearUserLocation(String userId) async {
    try {
      debugPrint('[AppLifecycle] Attempting to clear location for user: $userId');

      await LocationRealtimeService().removeLocationImmediately(userId);

      await LocationCleanupService().clearUserLocation(
        userId,
        async: true,
      );

      debugPrint('[AppLifecycle] Location clear initiated');
    } catch (error) {
      debugPrint('[AppLifecycle] Lỗi xóa vị trí: $error');
    }
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
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: Colors.white,
      ),
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
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF2A223D),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeProvider themeProvider = context.watch<ThemeProvider>();
    final app_auth.AuthProvider authProvider = context.watch<app_auth.AuthProvider>();

    final User? user = authProvider.user;
    context.read<NewsProvider>().syncForUser(user?.uid);
    context.read<FlashcardProvider>().syncForUser(user?.uid);

    return MaterialApp(
      title: 'Smart Document & Vocab',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeProvider.themeMode,
      home: authProvider.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : authProvider.isAuthenticated
              ? HomeScreen(
                  isDarkMode: themeProvider.isDarkMode,
                  onToggleTheme: themeProvider.toggleTheme,
                )
              : const AuthScreen(),
      routes: {'/translate_demo': (_) => const TranslationDemoScreen()},
    );
  }
}
