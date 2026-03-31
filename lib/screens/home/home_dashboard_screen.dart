import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/article_model.dart';
import '../documents/ocr_scanner_screen.dart';
import '../news/article_detail_screen.dart';
import '../news/news_tabs_screen.dart';
import '../flashcards/deck_list_screen.dart';
import '../profile/profile_settings_screen.dart';
import '../social/nearby_map_screen.dart';
import '../documents/document_manager_screen.dart';
import '../../utils/app_colors.dart';
import 'data/home_mock_data.dart';
import 'widgets/home_sections.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.isDarkMode = false, this.onToggleTheme});

  final bool isDarkMode;
  final VoidCallback? onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? get _userProfileStream {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
  }

  /// Resolved from FirebaseAuth; falls back to mock name if not signed in.
  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return HomeMockData.userName;
    return user.displayName?.trim().isNotEmpty == true
        ? user.displayName!
        : (user.email?.split('@').first ?? HomeMockData.userName);
  }

  void _onBottomTabTap(int index) {
    if (index == 0) {
      setState(() => _currentTabIndex = 0);
      return;
    }

    setState(() => _currentTabIndex = index);
    final Widget destination = _buildBottomTabDestination(index);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination)).then((_) {
      if (mounted) setState(() => _currentTabIndex = 0);
    });
  }

  Widget _buildBottomTabDestination(int index) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    switch (index) {
      case 1:
        return const DocumentListScreen();
      case 2:
        return const NewsTabsScreen();
      case 3:
        return const _ComingSoonScreen(
          title: 'Bạn học',
          description: 'Tính năng Bạn học đang được phát triển.',
        );
      case 4:
        return currentUserId == null
            ? const _ComingSoonScreen(
                title: 'Bản đồ',
                description: 'Không xác định được người dùng hiện tại.',
              )
            : NearbyMapScreen(currentUserId: currentUserId);
      case 5:
        return ProfileSettingsScreen(
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
        );
      default:
        return const _ComingSoonScreen(
          title: 'Tính năng',
          description: 'Trang này chưa có, sẽ cập nhật sớm.',
        );
    }
  }

  void _onArticleTap(Article article) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticleDetailScreen(article: article),
      ),
    );
  }

  void _onFeatureTap(CoreFeature feature) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final Widget destination;
    switch (feature.targetScreen) {
      case 'NewsScreen':
        destination = const NewsTabsScreen();
        break;
      case 'DocumentsScreen':
        destination = const DocumentListScreen();
        break;
      case 'OcrScanScreen':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DocumentListScreen()),
        );
        destination = const OcrScannerScreen();
        break;
      case 'StudyMapScreen':
        destination = currentUserId == null
            ? const _ComingSoonScreen(
                title: 'Bản đồ Bạn học',
                description: 'Không xác định được người dùng hiện tại.',
              )
            : NearbyMapScreen(currentUserId: currentUserId);
        break;
      case 'FlashcardScreen':
        destination = const FlashcardDeckScreen();
        break;
      case 'SocialScreen':
        destination = _ComingSoonScreen(
          title: feature.label,
          description: 'Trang này chưa có, sẽ cập nhật sớm.',
        );
        break;
      default:
        destination = _ComingSoonScreen(
          title: feature.targetScreen,
          description: 'Trang này chưa có, sẽ cập nhật sớm.',
        );
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = widget.isDarkMode;

    // Keep the system UI consistent with the active theme.
    SystemChrome.setSystemUIOverlayStyle(
      dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userProfileStream,
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          extendBodyBehindAppBar: true,
          body: _HomeBody(
            isDarkMode: dark,
            userName: _userName,
            avatarUrl: _resolveAvatarUrl(snapshot.data?.data()),
            onToggleTheme: widget.onToggleTheme ?? () {},
            onArticleTap: _onArticleTap,
            onFeatureTap: _onFeatureTap,
          ),
          bottomNavigationBar: _HomeBottomNav(
            currentIndex: _currentTabIndex,
            isDarkMode: dark,
            onTap: _onBottomTabTap,
          ),
        );
      },
    );
  }

  String? _resolveAvatarUrl(Map<String, dynamic>? profileData) {
    final User? user = FirebaseAuth.instance.currentUser;

    String readString(dynamic value) {
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
      return '';
    }

    final String profileAvatar = readString(profileData?['avatarUrl']);
    final String profilePhoto = readString(profileData?['photoUrl']);
    final String authPhoto = readString(user?.photoURL);

    if (profileAvatar.isNotEmpty) return profileAvatar;
    if (profilePhoto.isNotEmpty) return profilePhoto;
    if (authPhoto.isNotEmpty) return authPhoto;
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCROLLABLE BODY
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.isDarkMode,
    required this.userName,
    required this.avatarUrl,
    required this.onToggleTheme,
    required this.onArticleTap,
    required this.onFeatureTap,
  });

  final bool isDarkMode;
  final String userName;
  final String? avatarUrl;
  final VoidCallback onToggleTheme;
  final void Function(Article article) onArticleTap;
  final void Function(CoreFeature feature) onFeatureTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: <Widget>[
        // ── Header ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: HomeHeaderSection(
            userName: userName,
            avatarUrl: avatarUrl,
            isDarkMode: isDarkMode,
            onToggleTheme: onToggleTheme,
          ),
        ),

        // ── Hot News label ─────────────────────────────────────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        const SliverToBoxAdapter(
          child: HomeSectionTitle(title: 'Bài báo nổi bật 🔥'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),

        // ── Carousel ───────────────────────────────────────────────────────
        SliverToBoxAdapter(child: HotNewsCarousel(onTap: onArticleTap)),

        // ── Core Features label ────────────────────────────────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
        const SliverToBoxAdapter(
          child: HomeSectionTitle(title: 'Chức năng chính ✨'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),

        // ── Feature Grid ───────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: MainFeatureGrid(
              features: HomeMockData.coreFeatures,
              isDarkMode: isDarkMode,
              onTap: onFeatureTap,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAVIGATION BAR
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.currentIndex,
    required this.isDarkMode,
    required this.onTap,
  });

  final int currentIndex;
  final bool isDarkMode;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final Color activeColor = AppColors.deepPurple;
    final Color inactiveColor = isDarkMode
        ? AppColors.darkTextSecondary
        : const Color(0xFFBDB8CC);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: activeColor,
          unselectedItemColor: inactiveColor,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.home_rounded),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.folder_rounded),
              ),
              label: 'Tài liệu',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.newspaper_rounded),
              ),
              label: 'Đọc Báo',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.people_rounded),
              ),
              label: 'Bạn học',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.map_rounded),
              ),
              label: 'Bản đồ',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.person_rounded),
              ),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Alias kept for backward compatibility with main.dart's existing import.
class HomeDashboardScreen extends HomeScreen {
  const HomeDashboardScreen({super.key, super.isDarkMode, super.onToggleTheme});
}
