import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/features/profile/screens/edit_profile_screen.dart';
import 'package:dream_community_app/features/profile/screens/about_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) setState(() => _notificationsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final initial = u.initials;
    final hasAvatar = u.resolvedAvatarUrl != null && u.resolvedAvatarUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings', style: AppColors.soraBold(16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // ── PROFILE CARD ──
          _settingsCard(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => EditProfileScreen(user: widget.user),
                  ));
                  if (result == true && mounted) Navigator.pop(context, true);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: hasAvatar
                    ? ClipOval(
                        child: Image.network(
                          u.resolvedAvatarUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.background),
                            child: Center(child: Text(initial, style: AppColors.soraBold(20))),
                          ),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.background,
                        ),
                        child: Center(child: Text(initial, style: AppColors.soraBold(20))),
                      ),
                title: Text(u.name, style: AppColors.soraBold(14)),
                subtitle: Text('@${u.username ?? u.name.replaceAll(' ', '').toLowerCase()}', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                trailing: Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── NOTIFICATIONS ──
          _settingsCard(
            child: Material(
              color: Colors.transparent,
              child: _toggleTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── LOGOUT BUTTON ──
          GestureDetector(
            onTap: () async {
              await AuthService().logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Log Out',
                    style: AppColors.geistBold(14).copyWith(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _settingsCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _divider() {
    return Container(height: 1, color: Colors.white.withOpacity(0.05));
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: AppColors.geistMedium(14).copyWith(color: AppColors.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.cyan,
            activeTrackColor: AppColors.cyan.withOpacity(0.3),
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppColors.geistMedium(14).copyWith(color: AppColors.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
