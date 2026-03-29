import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../auth/login_register_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final bool shouldLogout = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Đăng xuất'),
              content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }
      
      await AuthService.instance.signOut();

      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading dialog
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đăng xuất: \$error')),
        );
      }
    }
  }

  Widget _buildProfileHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;

    // Derived values
    final String displayName = (user?.displayName.trim().isNotEmpty == true)
        ? user!.displayName
        : (authProvider.authUser?.email?.split('@').first ?? 'Người dùng');
        
    final String email = user?.email ?? authProvider.authUser?.email ?? '';

    final String initial = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U';

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.deepPurple,
          backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
          child: user?.avatarUrl == null
              ? Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required Widget child,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userSettings = authProvider.userModel?.settings ?? {};
    final bool isPushEnabled = userSettings['pushNotification'] as bool? ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: authProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  _buildProfileHeader(context),
                  const SizedBox(height: 32),
                  
                  // Settings List
                  _buildSettingsItem(
                    context: context,
                    child: SwitchListTile(
                      value: themeProvider.isDarkMode,
                      onChanged: (val) => themeProvider.toggleTheme(),
                      title: const Text('Giao diện (Sáng/Tối)', style: TextStyle(fontWeight: FontWeight.w500)),
                      secondary: Icon(
                        themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppColors.deepPurple,
                      ),
                      activeThumbColor: AppColors.deepPurple,
                    ),
                  ),

                  _buildSettingsItem(
                    context: context,
                    child: SwitchListTile(
                      value: isPushEnabled,
                      onChanged: (val) => authProvider.togglePushNotifications(val),
                      title: const Text('Thông báo nhắc nhở', style: TextStyle(fontWeight: FontWeight.w500)),
                      secondary: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.deepPurple,
                      ),
                      activeThumbColor: AppColors.deepPurple,
                    ),
                  ),

                  _buildSettingsItem(
                    context: context,
                    child: ListTile(
                      leading: const Icon(Icons.download_rounded, color: AppColors.deepPurple),
                      title: const Text('Xuất dữ liệu', style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tính năng đang phát triển')),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Logout Button
                  OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout_rounded, color: Colors.red),
                    label: const Text(
                      'Đăng xuất',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}