import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/location_cleanup_service.dart';
import 'package:provider/provider.dart';

import 'screens/auth/login_register_screen.dart';
import 'screens/home/home_dashboard_screen.dart';
import 'utils/app_colors.dart';
import 'firebase_options.dart';
import 'translation/translation_demo_screen.dart';

import 'providers/auth_provider.dart';
import 'providers/news_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/document_provider.dart';
import 'providers/flashcard_provider.dart';
import 'providers/location_provider.dart';

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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  @override
  void initState() {
    super.initState();
    // Lắng nghe các thay đổi app lifecycle
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Xóa listener khi MyApp bị hủy
    WidgetsBinding.instance.removeObserver(this);
    _themeModeNotifier.dispose();
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
        // App đã bị tắt hoàn toàn - xóa vị trí khỏi Firebase
        debugPrint('[AppLifecycle] DETACHED: App is being terminated');
        _clearUserLocation(currentUser.uid);
        break;
      case AppLifecycleState.paused:
        // App chuyển sang background - XÓA vị trí vì không biết khi nào sẽ mở lại
        // Cách này bảo đảm vị trí sẽ bị xóa ngay khi user tắt app
        debugPrint('[AppLifecycle] PAUSED: App entered background');
        _clearUserLocation(currentUser.uid);
        break;
      case AppLifecycleState.resumed:
        // App quay trở lại foreground - NearbyMapScreen sẽ tự cập nhật vị trí
        debugPrint('[AppLifecycle] RESUMED: App came to foreground');
        break;
      case AppLifecycleState.inactive:
        // App đang chuyển đổi trạng thái
        debugPrint('[AppLifecycle] INACTIVE: App transitioning');
        break;
      case AppLifecycleState.hidden:
        // App được ẩn nhưng không bị tắt (Android 12+)
        debugPrint('[AppLifecycle] HIDDEN: App is hidden');
        break;
    }
  }

  /// Xóa vị trí người dùng khỏi Firebase khi app tắt
  /// Sử dụng Firebase Realtime Database + Firestore
  /// Realtime DB sẽ tự động xóa nếu connection mất (onDisconnect handler)
  Future<void> _clearUserLocation(String userId) async {
    try {
      debugPrint('[AppLifecycle] Attempting to clear location for user: $userId');

      // Xóa trực tiếp từ Realtime Database (nhanh - 100-300ms)
      // This is the primary removal method
      await LocationRealtimeService().removeLocationImmediately(userId);

      // Cũng xóa từ Firestore cho compatibility
      // This is backup for existing queries
      await LocationCleanupService().clearUserLocation(
        userId,
        async: true, // Fire and forget
      );

      debugPrint('[AppLifecycle] ✅ Location clear initiated');
    } catch (error) {
      debugPrint('[AppLifecycle] ❌ Lỗi xóa vị trí: $error');
      // Không throw - app shutdown không bị block
    }
  }

  void _toggleTheme() {
    _themeModeNotifier.value = _themeModeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
  }


class _MyAppState extends State<MyApp> {
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
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    
    // Sync other providers that need auth context
    final user = authProvider.user;
    context.read<NewsProvider>().syncForUser(user?.uid);
    // You could also sync ChatProvider/DocumentProvider here if they had similar syncForUser method, but currently only NewsProvider and FlashcardProvider have it.
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
