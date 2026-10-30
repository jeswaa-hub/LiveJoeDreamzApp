import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('About', style: AppColors.soraBold(16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App Logo & Name
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.cyan, AppColors.pink],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text('D', style: AppColors.soraBlack(36)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('D.R.E.A.M Community', style: AppColors.soraBold(18)),
                const SizedBox(height: 4),
                Text('Version 1.0.0', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text(
              'D.R.E.A.M Week is a 5-day coaching program designed to help you unlock your potential through daily challenges, mentorship, and community support. This app connects you with like-minded individuals on their journey to personal growth.',
              style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted, height: 1.6),
            ),
          ),

          const SizedBox(height: 24),

          // Links
          _linkTile(Icons.description_outlined, 'Terms of Service', () {
            _launchUrl(context, 'https://joedreamz.com/terms');
          }),
          _linkTile(Icons.privacy_tip_outlined, 'Privacy Policy', () {
            _launchUrl(context, 'https://joedreamz.com/privacy');
          }),
          _linkTile(Icons.star_outline, 'Rate this App', () {
            _launchUrl(context, 'https://play.google.com/store/apps/details?id=com.joedreamz.dreamcommunity');
          }),
          _linkTile(Icons.share_outlined, 'Share with Friends', () {
            _shareApp(context);
          }),

          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              'Made with passion by JoeDreamz',
              style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '© 2025 D.R.E.A.M Week. All rights reserved.',
              style: AppColors.geistMedium(10).copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _shareApp(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: 'Check out the D.R.E.A.M Community app! https://joedreamz.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied to clipboard!'), backgroundColor: AppColors.success),
    );
  }

  Widget _linkTile(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: AppColors.geistBold(13).copyWith(color: AppColors.textPrimary)),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
