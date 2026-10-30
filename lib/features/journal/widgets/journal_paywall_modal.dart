import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/journal/screens/journal_checkout_screen.dart';
import 'package:dream_community_app/features/community_tier/services/tier_service.dart';

class JournalPaywallModal extends StatefulWidget {
  final VoidCallback? onUnlocked;

  const JournalPaywallModal({super.key, this.onUnlocked});

  static Future<void> show(BuildContext context, {VoidCallback? onUnlocked}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => JournalPaywallModal(onUnlocked: onUnlocked),
    );
  }

  @override
  State<JournalPaywallModal> createState() => _JournalPaywallModalState();
}

class _JournalPaywallModalState extends State<JournalPaywallModal> {
  double? _price;
  String _name = 'D.R.E.A.M. Journal';

  @override
  void initState() {
    super.initState();
    _loadProductInfo();
  }

  Future<void> _loadProductInfo() async {
    final info = await TierService().getJournalInfo();
    if (info != null && mounted) {
      setState(() {
        if (info['name'] != null) _name = info['name'];
        if (info['price'] != null) _price = (info['price'] as num).toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF070E17),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.cyan.withOpacity(0.4), width: 1.5),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Close Row (Clean right-aligned exit - No Badge Pill)
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
            const SizedBox(height: 16),

            // Title & Price Banner
            Text(
              _name,
              style: AppColors.soraBold(18).copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _price == null ? '...' : '\$${_price!.toStringAsFixed(2)}',
                  style: AppColors.soraBold(28).copyWith(color: AppColors.cyan),
                ),
                const SizedBox(width: 8),
                Text(
                  'ONE-TIME PAYMENT',
                  style: AppColors.geistBold(11).copyWith(color: AppColors.textMuted, letterSpacing: 1.2),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 20),

            // Included Perks List (No Emojis)
            Text(
              'INCLUDED LIFETIME PERKS',
              style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 1.8),
            ),
            const SizedBox(height: 12),
            _buildPerkItem(Icons.auto_awesome_rounded, 'Daily Guided Reflection Prompts'),
            _buildPerkItem(Icons.perm_media_rounded, 'Photo & Video Memory Attachments'),
            _buildPerkItem(Icons.lock_outline_rounded, '100% Private & Confidential Cloud Space'),
            _buildPerkItem(Icons.all_inclusive_rounded, 'Unlimited Lifetime Journal Reflections'),
            const SizedBox(height: 24),

            // Proceed to Real Dynamic Checkout Form Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => JournalCheckoutScreen(
                        onUnlocked: widget.onUnlocked,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'PROCEED TO CHECKOUT',
                      style: AppColors.soraBold(13).copyWith(letterSpacing: 1.1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Maybe Later Link
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Maybe later',
                  style: AppColors.geistMedium(13).copyWith(
                    color: Colors.white54,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerkItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.cyan, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppColors.geistMedium(13).copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
