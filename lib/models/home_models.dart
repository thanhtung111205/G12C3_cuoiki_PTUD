import 'package:flutter/material.dart';

class HomeNewsArticle {
  const HomeNewsArticle({
    required this.title,
    required this.imageUrl,
    required this.targetScreen,
  });

  final String title;
  final String imageUrl;
  final String targetScreen;
}

class HomeFeatureItem {
  const HomeFeatureItem({
    required this.title,
    required this.icon,
    required this.targetScreen,
  });

  final String title;
  final IconData icon;
  final String targetScreen;
}
