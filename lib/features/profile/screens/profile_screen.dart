import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/features/profile/screens/settings_screen.dart';
import 'package:dream_community_app/features/community_tier/screens/community_tier_screen.dart';
import 'package:dream_community_app/features/profile/widgets/change_password_modal.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadUser();

    PendingApprovalSyncService.instance.onUserDataUpdated.addListener(_loadUser);
    PendingApprovalSyncService.instance.onAccessUnlocked.addListener(_loadUser);
  }

  @override
  void dispose() {
    PendingApprovalSyncService.instance.onUserDataUpdated.removeListener(_loadUser);
    PendingApprovalSyncService.instance.onAccessUnlocked.removeListener(_loadUser);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    await _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getCurrentUser();
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadUser();
  }

  Future<void> _navigateToSettings() async {
    if (_user == null) await _loadUser();
    if (!mounted || _user == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(user: _user!)),
    );
    if (result == true && mounted) {
      _loadUser();
    }
  }

  void _showChangePasswordModal() {
    ChangePasswordModal.show(context);
  }

  void _navigateToTierUpgrade() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommunityTierScreen()),
    );
  }

  void _showLogoutConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1527),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0x24FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withOpacity(0.12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 26),
            ),
            const SizedBox(height: 16),
            Text('Log Out?', style: AppColors.soraBold(18)),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to sign out of your D.R.E.A.M. Community account?',
              textAlign: TextAlign.center,
              style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x1AFFFFFF)),
                      ),
                      alignment: Alignment.center,
                      child: Text('Cancel', style: AppColors.geistBold(14).copyWith(color: AppColors.textSecondary)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await AuthService().logout();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text('Log Out', style: AppColors.geistBold(14).copyWith(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 2.5),
              )
            : RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppColors.cyan,
                backgroundColor: AppColors.surface,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 12),
                      _buildHeroIdentity(),
                      const SizedBox(height: 20),
                      _buildMetricsBento(),
                      const SizedBox(height: 20),
                      _buildAccountCredentialsBento(),
                      const SizedBox(height: 20),
                      _buildBioBento(),
                      const SizedBox(height: 24),
                      _buildLogout(),
                      const SizedBox(height: 110), // Bottom nav safe padding
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. TOP APP BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('My Profile', style: AppColors.soraBold(22)),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final v = _pulseController.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.12 + v * 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.cyan.withOpacity(0.3 + v * 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withOpacity(0.6),
                                    blurRadius: 4 + v * 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ACTIVE',
                              style: AppColors.geistBold(9).copyWith(
                                color: AppColors.cyan,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Personal identity & D.R.E.A.M. credentials',
                style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _navigateToSettings,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1527),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x22FFFFFF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. HERO IDENTITY BENTO (View-Only Showcase)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroIdentity() {
    final name = _user?.name ?? 'Dreamer';
    final rawUsername = _user?.username;
    final username = (rawUsername != null && rawUsername.isNotEmpty)
        ? '@$rawUsername'
        : '@${name.replaceAll(' ', '').toLowerCase()}';
    final email = _user?.email ?? '';
    final initial = _user?.initials ?? '?';
    final hasAvatar = _user?.resolvedAvatarUrl != null && _user!.resolvedAvatarUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F1A30),
              const Color(0xFF0B1222).withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x24FFFFFF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Avatar — view-only, no camera badge, no tap-to-edit
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final v = _pulseController.value;
                return Container(
                  width: 98,
                  height: 98,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.cyan, AppColors.pink],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withOpacity(0.25 + v * 0.2),
                        blurRadius: 14 + v * 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0A0E1A),
                    ),
                    child: ClipOval(
                      child: hasAvatar
                          ? Image.network(
                              _user!.resolvedAvatarUrl!,
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildAvatarFallback(initial),
                            )
                          : _buildAvatarFallback(initial),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // User Name
            Text(
              name,
              textAlign: TextAlign.center,
              style: AppColors.soraBold(20).copyWith(letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),

            // User Handle & Email Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    username,
                    style: AppColors.geistBold(13).copyWith(color: AppColors.cyan),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x44FFFFFF),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      if (email.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: email));
                        DreamToast.success(context, 'Email copied to clipboard!');
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            email,
                            style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy_rounded, color: AppColors.textMuted.withOpacity(0.5), size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String initial) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF10192C),
      ),
      child: Center(
        child: Text(
          initial,
          style: AppColors.soraBlack(32).copyWith(color: AppColors.cyan),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. MEMBERSHIP METRICS BENTO (CHUNK 2 - Max 3 choices)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMetricsBento() {
    final tier = _user?.tier ?? 'free';
    final tierDisplay = tier.isEmpty || tier == 'free' ? 'Free' : tier[0].toUpperCase() + tier.substring(1);
    final role = _user?.role ?? 'member';
    final roleDisplay = role.isEmpty ? 'Guest' : role[0].toUpperCase() + role.substring(1);
    final memberSince = _user?.createdAt != null
        ? _parseMemberSince(_user!.createdAt!)
        : 'Aug 2026';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1527),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x1FFFFFFF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _metricColumn('ROLE', roleDisplay, isCyan: true),
            _verticalDivider(),
            _metricColumn('PACKAGE', tierDisplay, isGlowing: true, onTap: _navigateToTierUpgrade),
            _verticalDivider(),
            _metricColumn('MEMBER SINCE', memberSince),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(
    String label,
    String value, {
    bool isCyan = false,
    bool isGlowing = false,
    VoidCallback? onTap,
  }) {
    final columnContent = Column(
      children: [
        Text(
          label,
          style: AppColors.geistBold(10).copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCyan)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final v = _pulseController.value;
                  return Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cyan.withOpacity(0.4 + v * 0.6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withOpacity(0.4 + v * 0.4),
                          blurRadius: 5 + v * 4,
                        ),
                      ],
                    ),
                  );
                },
              ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppColors.soraBold(15).copyWith(
                  color: isCyan
                      ? AppColors.cyan
                      : (isGlowing ? AppColors.pink : AppColors.textPrimary),
                  shadows: isGlowing
                      ? [
                          Shadow(
                            color: AppColors.pink.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Expanded(
      child: onTap != null
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: columnContent,
            )
          : columnContent,
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withOpacity(0.08),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. ACCOUNT & CONTACT CREDENTIALS BENTO (View-Only)
  // ─────────────────────────────────────────────────────────────
  Widget _buildAccountCredentialsBento() {
    final rawUsername = _user?.username;
    final username = (rawUsername != null && rawUsername.isNotEmpty) ? '@$rawUsername' : 'Not set';
    final email = _user?.email ?? 'Not set';
    final phone = (_user?.phone != null && _user!.phone!.isNotEmpty) ? _user!.phone! : 'Not set';
    final location = (_user?.location != null && _user!.location!.isNotEmpty) ? _user!.location! : 'Not set';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header — no "Edit" link, view-only
          Text(
            'ACCOUNT CREDENTIALS',
            style: AppColors.geistBold(11).copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1527),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              children: [
                _credentialRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Username',
                  value: username,
                ),
                _rowDivider(),
                _credentialRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email Address',
                  value: email,
                  copyable: true,
                ),
                _rowDivider(),
                _credentialRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone Number',
                  value: phone,
                  isPlaceholder: phone == 'Not set',
                ),
                _rowDivider(),
                _credentialRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: location,
                  isPlaceholder: location == 'Not set',
                ),
                _rowDivider(),
                _credentialRow(
                  icon: Icons.lock_outline_rounded,
                  label: 'Password',
                  value: '••••••••••••',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cyan.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_outlined, color: AppColors.cyan, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Change',
                          style: AppColors.geistBold(11).copyWith(color: AppColors.cyan),
                        ),
                      ],
                    ),
                  ),
                  onTap: _showChangePasswordModal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow({
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
    bool isPlaceholder = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ??
          (copyable && value.isNotEmpty && value != 'Not set'
              ? () {
                  Clipboard.setData(ClipboardData(text: value));
                  DreamToast.success(context, '$label copied to clipboard!');
                }
              : null),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.cyan, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppColors.geistBold(14).copyWith(
                      color: isPlaceholder ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (copyable && value != 'Not set')
              Icon(Icons.copy_rounded, color: AppColors.textMuted.withOpacity(0.6), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _rowDivider() {
    return Container(
      height: 1,
      color: Colors.white.withOpacity(0.05),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. DREAM VISION & BIO BENTO (View-Only)
  // ─────────────────────────────────────────────────────────────
  Widget _buildBioBento() {
    final bio = _user?.bio;
    final hasBio = bio != null && bio.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header — no "Edit" / "+ Add" link
          Text(
            'D.R.E.A.M. VISION & BIO',
            style: AppColors.geistBold(11).copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1527),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: hasBio
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u201C',
                        style: AppColors.soraBold(28).copyWith(
                          color: AppColors.cyan.withOpacity(0.6),
                          height: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bio,
                          style: AppColors.geistMedium(13).copyWith(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: AppColors.textMuted.withOpacity(0.4), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add your D.R.E.A.M. vision in Settings → Edit Profile',
                          style: AppColors.geistMedium(12).copyWith(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. LOGOUT
  // ─────────────────────────────────────────────────────────────
  Widget _buildLogout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _showLogoutConfirmation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1527),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: AppColors.error.withOpacity(0.9), size: 18),
              const SizedBox(width: 8),
              Text(
                'Log Out',
                style: AppColors.geistBold(14).copyWith(
                  color: AppColors.error.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _parseMemberSince(dynamic dateInput) {
    DateTime? date;
    if (dateInput is int) {
      date = dateInput > 10000000000
          ? DateTime.fromMillisecondsSinceEpoch(dateInput)
          : DateTime.fromMillisecondsSinceEpoch(dateInput * 1000);
    } else if (dateInput is String) {
      final raw = dateInput.endsWith('Z') ? dateInput : '${dateInput}Z';
      date = DateTime.tryParse(raw)?.toLocal();
    }
    if (date == null) return dateInput?.toString() ?? 'N/A';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }
}
