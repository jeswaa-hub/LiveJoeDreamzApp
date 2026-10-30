import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/auth/screens/login_screen.dart';
import 'package:dream_community_app/features/home/screens/community_hub_screen.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';

class SuccessScreen extends StatefulWidget {
  final String accessCode;
  final String userName;
  final bool isManualPending;
  final String? paymentMethod;
  final int? purchaseId;

  const SuccessScreen({
    super.key,
    required this.accessCode,
    required this.userName,
    this.isManualPending = false,
    this.paymentMethod,
    this.purchaseId,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late AnimationController _twinkleController;
  late AnimationController _scaleController;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleController.forward();
  }

  @override
  void dispose() {
    _driftController.dispose();
    _twinkleController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.accessCode));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => widget.isManualPending ? const LoginScreen() : const CommunityHubScreen(initialIndex: 0)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SpaceBackground(
            driftController: _driftController,
            twinkleController: _twinkleController,
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // Success icon
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (widget.isManualPending ? AppColors.warning : AppColors.success).withOpacity(0.15),
                        border: Border.all(color: (widget.isManualPending ? AppColors.warning : AppColors.success).withOpacity(0.3), width: 2),
                        boxShadow: [
                          BoxShadow(color: (widget.isManualPending ? AppColors.warning : AppColors.success).withOpacity(0.2), blurRadius: 30),
                        ],
                      ),
                      child: Icon(
                        widget.isManualPending ? Icons.schedule_rounded : Icons.check_rounded,
                        color: widget.isManualPending ? AppColors.warning : AppColors.success,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Title
                  Text(
                    widget.isManualPending ? 'Payment Pending' : 'Welcome to the Community!',
                    textAlign: TextAlign.center,
                    style: AppColors.soraBold(24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.isManualPending
                        ? 'Your payment is being verified by our team. You will receive your access code via email once confirmed.'
                        : 'Your D.R.E.A.M Community membership is now active.',
                    textAlign: TextAlign.center,
                    style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  // Access code card (only for non-pending)
                  if (!widget.isManualPending) ...[
                    _buildAccessCodeCard(),
                    const SizedBox(height: 24),
                  ],
                  // What's next
                  _buildWhatNext(),
                  const SizedBox(height: 32),
                  // Go to Home button
                  _buildHomeButton(),
                  if (!widget.isManualPending) ...[
                    const SizedBox(height: 20),
                    // Copy code option
                    _buildCopyButton(),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: AppColors.cyan.withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Text(
            'YOUR ACCESS CODE',
            style: AppColors.geistBold(10).copyWith(color: AppColors.cyan, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.accessCode,
                  style: AppColors.soraBold(20).copyWith(
                    color: AppColors.cyan,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Save this code — you\'ll need it to log in',
            style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatNext() {
    final items = widget.isManualPending
        ? [
            {'icon': Icons.verified, 'label': 'Our team will verify your payment', 'color': AppColors.cyan},
            {'icon': Icons.login, 'label': 'Access granted once verified', 'color': AppColors.success},
          ]
        : [
            {'icon': Icons.podcasts_rounded, 'label': 'Listen to D.R.E.A.M Podcast episodes', 'color': AppColors.cyan},
            {'icon': Icons.auto_stories_rounded, 'label': 'Explore D.R.E.A.M Book Club', 'color': AppColors.cyan},
            {'icon': Icons.chat_bubble_rounded, 'label': 'Join D.R.E.A.M Book Club Chat', 'color': AppColors.pink},
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT\'S NEXT',
            style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['label'] as String,
                    style: AppColors.geistMedium(13).copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildHomeButton() {
    return GestureDetector(
      onTap: _goHome,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.cyan, Color(0xFF0891B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: AppColors.cyan.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
          child: Text(
            widget.isManualPending ? 'GO TO LOGIN' : 'GO TO HOME',
            style: AppColors.geistBold(14).copyWith(color: Colors.white, letterSpacing: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyButton() {
    return GestureDetector(
      onTap: _copyCode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              color: _copied ? AppColors.success : AppColors.textMuted,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _copied ? 'Copied!' : 'Copy Access Code',
              style: AppColors.geistBold(12).copyWith(
                color: _copied ? AppColors.success : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
