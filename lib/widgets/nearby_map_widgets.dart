import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/nearby_study_peer.dart';
import '../utils/app_colors.dart';

class NearbyMapInfoChip extends StatelessWidget {
  const NearbyMapInfoChip({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color chipBg = isDark
        ? const Color(0xFF1A1A22).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppColors.lavender.withValues(alpha: 0.7);
    final Color titleColor = isDark ? Colors.white : AppColors.lightText;
    final Color subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.lightTextSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
          ],
        ),
      ),
    );
  }
}

class NearbyMapBackButtonChip extends StatelessWidget {
  const NearbyMapBackButtonChip({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? const Color(0xFF1A1A22).withValues(alpha: 0.94)
          : Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.lightText,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class NearbyMapPrivacySwitchCard extends StatelessWidget {
  const NearbyMapPrivacySwitchCard({
    super.key,
    required this.isVisible,
    required this.isSaving,
    required this.onChanged,
  });

  final bool isVisible;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? const Color(0xFF1A1A22).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.94);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppColors.lavender.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            isVisible ? 'Hiện' : 'Ẩn',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightText,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: isVisible,
            onChanged: isSaving ? null : onChanged,
            activeThumbColor: AppColors.deepPurple,
            activeTrackColor: AppColors.deepPurple.withValues(alpha: 0.28),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey,
          ),
        ],
      ),
    );
  }
}

class NearbyMapStatusBanner extends StatelessWidget {
  const NearbyMapStatusBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A22).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.lavender.withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? Colors.white.withValues(alpha: 0.78)
              : AppColors.lightTextSecondary,
          height: 1.35,
        ),
      ),
    );
  }
}

class NearbyMapEmptyNearbyCard extends StatelessWidget {
  const NearbyMapEmptyNearbyCard({super.key, required this.isLocationVisible});

  final bool isLocationVisible;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A22).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.lavender.withValues(alpha: 0.8),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.person_search_outlined,
            color: AppColors.deepPurple,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            isLocationVisible
                ? 'Chưa có bạn học nào trong bán kính 2km.'
                : 'Bạn đang ẩn vị trí, nên sẽ không hiển thị với người khác.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.78)
                  : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class NearbyPeerBottomSheet extends StatelessWidget {
  const NearbyPeerBottomSheet({
    super.key,
    required this.peer,
    required this.distanceMeters,
    required this.onStartChat,
  });

  final NearbyStudyPeer peer;
  final double? distanceMeters;
  final VoidCallback onStartChat;

  String _distanceLabel() {
    final double meters = distanceMeters ?? peer.distanceMeters;
    if (meters < 1000) {
      return 'Cách bạn ${meters.toStringAsFixed(0)}m';
    }

    return 'Cách bạn ${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelBg = isDark ? const Color(0xFF1A1A22) : Colors.white;
    final Color panelTitle = isDark ? Colors.white : AppColors.lightText;
    final Color panelSubtle = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _NearbyPeerAvatar(avatarUrl: peer.avatarUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        peer.displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: panelTitle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _distanceLabel(),
                        style: TextStyle(fontSize: 13, color: panelSubtle),
                      ),
                      const SizedBox(height: 10),
                      _NearbyStatusBadge(label: peer.studyStatus),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: onStartChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Bắt đầu trò chuyện',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyPeerAvatar extends StatelessWidget {
  const _NearbyPeerAvatar({required this.avatarUrl});

  final String? avatarUrl;

  bool get _isDataUri => avatarUrl?.startsWith('data:image/') == true;

  @override
  Widget build(BuildContext context) {
    final String? url = avatarUrl?.trim().isNotEmpty == true ? avatarUrl : null;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.lavender.withValues(alpha: 0.55),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.lavender,
        ),
      ),
      child: ClipOval(
        child: url == null
            ? const Icon(Icons.person, color: AppColors.deepPurple, size: 36)
            : _isDataUri
            ? Image.memory(
                base64Decode(url.split(',').last),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  color: AppColors.deepPurple,
                  size: 36,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  color: AppColors.deepPurple,
                  size: 36,
                ),
              ),
      ),
    );
  }
}

class _NearbyStatusBadge extends StatelessWidget {
  const _NearbyStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.lavender.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.lightText,
        ),
      ),
    );
  }
}