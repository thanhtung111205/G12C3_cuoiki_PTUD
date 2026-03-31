import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../auth/login_register_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    this.isDarkMode = false,
    this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback? onToggleTheme;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  bool _reminderEnabled = true;
  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _profileData = snapshot.data();
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  String _readString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return '';
  }

  String _firstNonEmpty(Iterable<String> values, String fallback) {
    for (final String value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  String get _displayName {
    final User? user = FirebaseAuth.instance.currentUser;
    return _firstNonEmpty(<String>[
      _readString(_profileData?['displayName']),
      _readString(_profileData?['name']),
      _readString(user?.displayName),
      _readString(user?.email?.split('@').first),
    ], 'Người dùng');
  }

  String get _email {
    final User? user = FirebaseAuth.instance.currentUser;
    return _firstNonEmpty(<String>[
      _readString(_profileData?['email']),
      _readString(user?.email),
    ], 'Chưa có email');
  }

  String? get _avatarValue {
    final User? user = FirebaseAuth.instance.currentUser;
    final String profileAvatar = _readString(_profileData?['avatarUrl']);
    final String profilePhoto = _readString(_profileData?['photoUrl']);
    final String authPhoto = _readString(user?.photoURL);

    if (profileAvatar.isNotEmpty) return profileAvatar;
    if (profilePhoto.isNotEmpty) return profilePhoto;
    if (authPhoto.isNotEmpty) return authPhoto;
    return null;
  }

  Future<String?> _pickAvatarDataUri() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (image == null) return null;

    final List<int> bytes = await image.readAsBytes();
    final String encoded = base64Encode(bytes);
    return 'data:image/jpeg;base64,$encoded';
  }

  Future<void> _openEditProfileSheet() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final TextEditingController nameController = TextEditingController(
      text: _displayName,
    );
    String? selectedAvatar = _avatarValue;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            Future<void> chooseAvatar() async {
              final String? avatar = await _pickAvatarDataUri();
              if (avatar == null) return;
              setSheetState(() {
                selectedAvatar = avatar;
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Chỉnh sửa hồ sơ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.deepPurple,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: _EditableAvatarPreview(
                          avatarValue: selectedAvatar,
                          label: _displayName,
                          onPick: chooseAvatar,
                          onRemove: () {
                            setSheetState(() {
                              selectedAvatar = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Tên người dùng',
                          filled: true,
                          fillColor: AppColors.lavender.withValues(alpha: 0.22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _email,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          filled: true,
                          fillColor: AppColors.lavender.withValues(alpha: 0.10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _isSavingProfile
                            ? null
                            : () async {
                                final String name = nameController.text.trim();
                                if (name.isEmpty) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Vui lòng nhập tên người dùng.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.of(sheetContext).pop(true);
                                setState(() => _isSavingProfile = true);
                                try {
                                  await AuthService.instance.updateUserProfile(
                                    userId: user.uid,
                                    displayName: name,
                                    avatarUrl: selectedAvatar,
                                  );
                                  if (!mounted) return;
                                  final Map<String, dynamic> updatedProfile =
                                      <String, dynamic>{
                                        ...?_profileData,
                                        'displayName': name,
                                        'name': name,
                                      };
                                  if (selectedAvatar != null) {
                                    updatedProfile['avatarUrl'] =
                                        selectedAvatar;
                                    updatedProfile['photoUrl'] = selectedAvatar;
                                  }
                                  setState(() {
                                    _profileData = updatedProfile;
                                  });
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã cập nhật hồ sơ.'),
                                    ),
                                  );
                                } catch (error) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Không thể lưu hồ sơ: $error',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isSavingProfile = false);
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.deepPurple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSavingProfile
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Lưu thay đổi'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    if (saved == true && mounted) {
      await _loadProfileData();
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Đăng xuất'),
              content: const Text(
                'Bạn có chắc muốn đăng xuất khỏi tài khoản này không?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepPurple,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Đăng xuất'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout) return;

    try {
      await AuthService.instance.signOut();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã đăng xuất.')));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể đăng xuất: $error')));
      }
    }
  }

  Future<void> _exportData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng xuất dữ liệu sẽ sớm khả dụng.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final ThemeData theme = Theme.of(context);
    final bool isDark =
        widget.isDarkMode || theme.brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF121018)
        : const Color(0xFFF7F5FF);
    final Color cardColor = isDark ? const Color(0xFF1A1824) : Colors.white;
    final Color textPrimary = isDark ? Colors.white : AppColors.lightText;
    final Color textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : AppColors.lightTextSecondary;

    final String displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'Người dùng');
    final String avatarLabel = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân'), centerTitle: false),
      backgroundColor: bgColor,
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ProfileHeroCard(
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      displayName: _displayName,
                      email: _email,
                      avatarUrl: _avatarValue,
                      avatarLabel: avatarLabel,
                      onEdit: _openEditProfileSheet,
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      cardColor: cardColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _SectionTitle(
                            title: 'Cài đặt',
                            subtitle: 'Tuỳ chỉnh giao diện và nhắc nhở học tập',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 14),
                          _SettingTile(
                            icon: Icons.dark_mode_rounded,
                            title: 'Giao diện',
                            subtitle: widget.isDarkMode
                                ? 'Chế độ Tối'
                                : 'Chế độ Sáng',
                            trailing: Switch(
                              value: widget.isDarkMode,
                              activeThumbColor: AppColors.deepPurple,
                              onChanged: (_) => widget.onToggleTheme?.call(),
                            ),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const Divider(height: 24),
                          _SettingTile(
                            icon: Icons.notifications_active_rounded,
                            title: 'Thông báo nhắc nhở',
                            subtitle: _reminderEnabled
                                ? 'Đang bật nhắc học mỗi ngày'
                                : 'Đã tắt nhắc học',
                            trailing: Switch(
                              value: _reminderEnabled,
                              activeThumbColor: AppColors.deepPurple,
                              onChanged: (bool value) {
                                setState(() => _reminderEnabled = value);
                              },
                            ),
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      cardColor: cardColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _SectionTitle(
                            title: 'Lộ trình & dữ liệu',
                            subtitle:
                                'Theo dõi tiến độ và xuất dữ liệu cá nhân',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 14),
                          _StatRow(
                            icon: Icons.route_rounded,
                            title: 'Lộ trình học',
                            value: 'Đang hoàn thiện',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 12),
                          _StatRow(
                            icon: Icons.file_download_rounded,
                            title: 'Xuất dữ liệu',
                            value: 'JSON / CSV',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _exportData,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Xuất dữ liệu'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.deepPurple,
                              side: const BorderSide(color: AppColors.lavender),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded, color: Colors.red),
                      label: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: isDark
                            ? Colors.red.withValues(alpha: 0.08)
                            : Colors.red.withValues(alpha: 0.06),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.avatarLabel,
    required this.onEdit,
  });

  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String avatarLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ProfileAvatar(
            avatarUrl: avatarUrl,
            avatarLabel: avatarLabel,
            size: 88,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            email,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded),
                      tooltip: 'Sửa hồ sơ',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Quản lý tài khoản, xem lộ trình và xuất dữ liệu.',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.avatarLabel,
    required this.size,
  });

  final String? avatarUrl;
  final String avatarLabel;
  final double size;

  bool get _isDataUri => avatarUrl?.startsWith('data:image/') == true;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_isDataUri) {
      final String base64Data = avatarUrl!.split(',').last;
      child = Image.memory(
        base64Decode(base64Data),
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _fallback();
        },
      );
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      child = Image.network(
        avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _fallback();
        },
      );
    } else {
      child = _fallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: <Color>[AppColors.deepPurple, AppColors.periwinkle],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepPurple.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        avatarLabel,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _EditableAvatarPreview extends StatelessWidget {
  const _EditableAvatarPreview({
    required this.avatarValue,
    required this.label,
    required this.onPick,
    required this.onRemove,
  });

  final String? avatarValue;
  final String label;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _ProfileAvatar(
          avatarUrl: avatarValue,
          avatarLabel: label.isNotEmpty
              ? label.substring(0, 1).toUpperCase()
              : 'U',
          size: 110,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Đổi ảnh'),
            ),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              label: const Text('Xoá ảnh', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.cardColor, required this.child});

  final Color cardColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.7)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.textPrimary,
    required this.textSecondary,
  });

  final String title;
  final String subtitle;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.textPrimary,
    required this.textSecondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.lavender.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.deepPurple),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.deepPurple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
