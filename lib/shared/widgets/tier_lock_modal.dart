import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

class TierLockModal extends StatelessWidget {
  final String featureName;

  const TierLockModal({
    super.key,
    this.featureName = 'Content',
  });

  static void show(BuildContext context, {String featureName = 'Content'}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => TierLockModal(featureName: featureName),
    );
  }

  IconData _resolveFeatureIcon() {
    final lower = featureName.toLowerCase();
    if (lower.contains('book')) return Icons.menu_book_rounded;
    if (lower.contains('chat')) return Icons.forum_rounded;
    if (lower.contains('media') || lower.contains('episode') || lower.contains('video') || lower.contains('activit')) {
      return Icons.play_circle_filled_rounded;
    }
    if (lower.contains('journal')) return Icons.auto_stories_rounded;
    return Icons.lock_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _resolveFeatureIcon();

    return Dialog(
      backgroundColor: const Color(0xFF070E17),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: AppColors.cyan.withOpacity(0.35), width: 1.2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.08),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Action Row (Close Only - Clean Minimalist Exit)
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Hero Glowing Feature Centerpiece
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.cyan.withOpacity(0.25),
                      const Color(0xFF091424),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.cyan.withOpacity(0.55),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: AppColors.cyan,
                    size: 34,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Eyebrow Tag
              Text(
                'VIP COMMUNITY FEATURE',
                style: AppColors.geistBold(10).copyWith(
                  color: AppColors.cyan,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 6),

              // Main Title
              Text(
                'Unlock $featureName',
                style: AppColors.soraBold(21).copyWith(
                  color: Colors.white,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                '$featureName is reserved for Community Tier members. Upgrade your membership to access the full D.R.E.A.M. experience.',
                style: AppColors.hankenMedium(12).copyWith(
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Perks List Box (Bento Minimalist Style with All Key VIP Features)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1424).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    _perkRow(Icons.podcasts_rounded, 'D.R.E.A.M Journal Episodes'),
                    const SizedBox(height: 10),
                    _perkRow(Icons.smart_display_rounded, 'D.R.E.A.M Activities Videos'),
                    const SizedBox(height: 10),
                    _perkRow(Icons.auto_stories_rounded, 'D.R.E.A.M Book Club'),
                    const SizedBox(height: 10),
                    _perkRow(Icons.forum_rounded, 'D.R.E.A.M Book Club Chat'),
                    const SizedBox(height: 10),
                    _perkRow(Icons.local_offer_rounded, 'Discounted on Merch 10% Off'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Primary Dominant CTA (Hick's Law: 1 High-Contrast Action)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/community-tier/pricing');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: const Color(0xFF050C16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 6,
                    shadowColor: AppColors.cyan.withOpacity(0.45),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, color: Color(0xFF050C16), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'EXPLORE COMMUNITY TIERS',
                        style: AppColors.soraBold(13).copyWith(
                          color: const Color(0xFF050C16),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Secondary Dismissal (Hick's Law: Effortless Exit)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: Text(
                    'Maybe later',
                    style: AppColors.geistMedium(13).copyWith(
                      color: AppColors.textMuted.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _perkRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.cyan.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
          ),
          child: Icon(icon, color: AppColors.cyan, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppColors.geistMedium(12).copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
