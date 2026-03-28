import 'package:flutter/material.dart';
import '../../../models/article_model.dart';

/// Data model for a core feature tile in the main feature grid.
class CoreFeature {
  final IconData icon;
  final String label;
  final String targetScreen;
  final Color lightBg;
  final Color darkBg;
  final Color iconColor;

  const CoreFeature({
    required this.icon,
    required this.label,
    required this.targetScreen,
    required this.lightBg,
    required this.darkBg,
    required this.iconColor,
  });
}

/// All static mock/seed data consumed by the Home screen widgets.
class HomeMockData {
  HomeMockData._();

  static const String userName = 'Thành Tùng';
  static const String avatarUrl =
      'https://i.pravatar.cc/150?img=12';

  static const List<String> bottomTabs = [
    'Home',
    'Tài liệu',
    'Đọc Báo',
    'Cá nhân',
  ];

  /// Fallback articles shown while the RSS feed is loading.
  static final List<Article> fallbackArticles = [
    Article(
      articleId: 'mock-1',
      title: 'AI Is Transforming the Way We Learn Languages',
      source: 'BBC News',
      link: 'https://bbc.co.uk',
      pubDate: DateTime.now().subtract(const Duration(hours: 2)),
      imageUrl:
          'https://images.unsplash.com/photo-1677442135703-1787eea5ce01?w=800',
      description:
          'Artificial intelligence tools are reshaping language education for millions worldwide.',
    ),
    Article(
      articleId: 'mock-2',
      title: 'Top Universities Now Offer Free Online Degrees',
      source: 'BBC News',
      link: 'https://bbc.co.uk',
      pubDate: DateTime.now().subtract(const Duration(hours: 5)),
      imageUrl:
          'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=800',
      description:
          'A wave of reputable universities is launching fully accredited free programmes.',
    ),
    Article(
      articleId: 'mock-3',
      title: 'How Reading the News Daily Boosts Your Vocabulary',
      source: 'BBC News',
      link: 'https://bbc.co.uk',
      pubDate: DateTime.now().subtract(const Duration(hours: 9)),
      imageUrl:
          'https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=800',
      description:
          'Researchers confirm that daily news reading leads to measurable vocabulary gains.',
    ),
  ];

  static const List<CoreFeature> coreFeatures = [
    CoreFeature(
      icon: Icons.folder_rounded,
      label: 'Kho Tài liệu',
      targetScreen: 'DocumentsScreen',
      lightBg: Color(0xFFF3EEF8),
      darkBg: Color(0xFF2E1F4A),
      iconColor: Color(0xFF6A1B9A),
    ),
    CoreFeature(
      icon: Icons.document_scanner_rounded,
      label: 'Quét OCR',
      targetScreen: 'OcrScanScreen',
      lightBg: Color(0xFFFEF0F4),
      darkBg: Color(0xFF3A1F2E),
      iconColor: Color(0xFFAD1457),
    ),
    CoreFeature(
      icon: Icons.style_rounded,
      label: 'Học Flashcard',
      targetScreen: 'FlashcardScreen',
      lightBg: Color(0xFFF3EEF8),
      darkBg: Color(0xFF2E1F4A),
      iconColor: Color(0xFF4527A0),
    ),
    CoreFeature(
      icon: Icons.map_rounded,
      label: 'Bản đồ Bạn học',
      targetScreen: 'StudyMapScreen',
      lightBg: Color(0xFFEEF8F3),
      darkBg: Color(0xFF1A3530),
      iconColor: Color(0xFF2E7D32),
    ),
    CoreFeature(
      icon: Icons.newspaper_rounded,
      label: 'Đọc báo Tiếng Anh',
      targetScreen: 'NewsScreen',
      lightBg: Color(0xFFEEF2FD),
      darkBg: Color(0xFF1A2545),
      iconColor: Color(0xFF1565C0),
    ),
    CoreFeature(
      icon: Icons.people_rounded,
      label: 'Bạn học',
      targetScreen: 'SocialScreen',
      lightBg: Color(0xFFFEF0F4),
      darkBg: Color(0xFF3A1F2E),
      iconColor: Color(0xFFC62828),
    ),
  ];
}
