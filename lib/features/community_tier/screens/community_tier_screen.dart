import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/community_tier/services/tier_service.dart';
import 'package:dream_community_app/features/community_tier/screens/checkout_screen.dart';
import 'package:dream_community_app/features/community_tier/screens/success_screen.dart';
import 'package:dream_community_app/features/auth/screens/register_screen.dart';
import 'package:dream_community_app/shared/widgets/app_toast.dart';
import 'package:dream_community_app/shared/widgets/loading_overlay.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';
import 'package:dream_community_app/shared/widgets/minimalist_screen_loader.dart';

class CommunityTierScreen extends StatefulWidget {
  const CommunityTierScreen({super.key});

  @override
  State<CommunityTierScreen> createState() => _CommunityTierScreenState();
}

class _CommunityTierScreenState extends State<CommunityTierScreen>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late AnimationController _twinkleController;

  TierInfo? _tierInfo;
  bool _isLoading = true;
  bool _isOpeningFreeAccount = false;
  bool _isNavigatingToCheckout = false;
  String _selectedCycle = 'annual'; // default to annual (better value)

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _loadTierInfo();
    if (kIsWeb) _checkPaymentReturn();
  }

  Future<void> _checkPaymentReturn() async {
    final uri = Uri.base;
    final params = uri.queryParameters;
    final hash = uri.fragment;

    bool isSuccess = params['payment'] == 'success' || hash.contains('payment=success');
    if (!isSuccess) return;

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remembered_email') ?? prefs.getString('pending_tier_email') ?? 'user@test.com';

    final sessionId = params['session_id'];
    final paypalOrderId = params['paypal_order_id'];

    if (!mounted) return;
    LoadingOverlayState.show(context, message: 'Confirming payment...');

    if (sessionId != null && sessionId.isNotEmpty) {
      final processResult = await TierService().processStripe(
        email: email,
        paymentId: sessionId,
        billingCycle: 'annual',
      );
      LoadingOverlayState.hide();

      if (processResult.success && processResult.accessCode != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => SuccessScreen(
              accessCode: processResult.accessCode!,
              userName: email.split('@').first,
            ),
          ),
          (route) => false,
        );
        return;
      }
    }

    if (paypalOrderId != null && paypalOrderId.isNotEmpty) {
      final processResult = await TierService().processPayPal(
        email: email,
        paypalOrderId: paypalOrderId,
        billingCycle: 'annual',
      );
      LoadingOverlayState.hide();

      if (processResult.success && processResult.accessCode != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => SuccessScreen(
              accessCode: processResult.accessCode!,
              userName: email.split('@').first,
            ),
          ),
          (route) => false,
        );
        return;
      }
    }

    final purchaseId = prefs.getInt('pending_tier_purchase_id');
    if (purchaseId != null) {
      const maxAttempts = 20;
      for (var i = 0; i < maxAttempts; i++) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        final status = await TierService().getTierStatus(purchaseId);
        if (status != null && status['payment_status'] == 'completed') {
          await prefs.remove('pending_tier_purchase_id');
          await prefs.remove('pending_tier_email');
          LoadingOverlayState.hide();

          final accessCode = status['access_code'] as String? ?? 'ACTIVE';
          final userName = email.split('@').first;
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => SuccessScreen(
                accessCode: accessCode,
                userName: userName,
              )),
              (route) => false,
            );
          }
          return;
        }
      }
    }

    await prefs.remove('pending_tier_purchase_id');
    await prefs.remove('pending_tier_email');
    LoadingOverlayState.hide();
    if (mounted) AppToast.show(context, 'Payment could not be confirmed. Please check your email.', type: ToastType.warning);
  }

  @override
  void dispose() {
    _driftController.dispose();
    _twinkleController.dispose();
    super.dispose();
  }

  Future<void> _loadTierInfo() async {
    final info = await TierService().getTierInfo();
    if (mounted) {
      setState(() {
        _tierInfo = info;
        _isLoading = false;
      });
    }
  }

  void _goToCheckout() {
    if (_tierInfo == null || _isNavigatingToCheckout) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          tierInfo: _tierInfo!,
          billingCycle: _selectedCycle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF030712),
        body: MinimalistScreenLoader(
          message: 'LOADING MEMBERSHIP...',
          duration: Duration(minutes: 5),
        ),
      );
    }

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
            child: _tierInfo == null
                ? _buildError()
                : Column(
                    children: [
                      // 1. Top Navigation Bar (Easy to navigate & exit)
                      _buildHeaderBar(),

                      // 2. Scrollable Body Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                          child: Column(
                            children: [
                              // Hero Branding & Title
                              _buildHero(),
                              const SizedBox(height: 28),

                              // Interactive Billing Plan Selector
                              _buildBillingSelector(),
                              const SizedBox(height: 24),

                              // What's Included Feature Cards
                              _buildWhatsIncluded(),
                              const SizedBox(height: 28),

                              // Main High-Contrast CTA Button
                              _buildCTAButton(),
                              const SizedBox(height: 12),

                              // Secondary Free Account Button
                              _buildFreeAccountButton(),
                              const SizedBox(height: 20),

                              // Secondary Member Sign In Link
                              _buildLoginLink(),
                              const SizedBox(height: 16),
                            ],
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

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Screen Label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.cyan,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'D.R.E.A.M. MEMBERSHIP',
                style: AppColors.geistBold(11).copyWith(
                  color: AppColors.cyan,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          // Top-Right Quick Sign In
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.login_rounded, size: 14, color: AppColors.cyan),
                  const SizedBox(width: 5),
                  Text(
                    'Sign In',
                    style: AppColors.geistBold(12).copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Ambient Glowing Logo Container
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withOpacity(0.16),
                blurRadius: 36,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/DreamCommunityLogo.webp',
            width: 86,
            height: 86,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.star_rounded, size: 40, color: AppColors.cyan),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Headline
        Text(
          'Are you living your\nD.R.E.A.M?',
          textAlign: TextAlign.center,
          style: AppColors.soraBold(26).copyWith(
            color: Colors.white,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBillingSelector() {
    final info = _tierInfo!;
    final monthlyPrice = info.monthlyPrice;
    final annualPrice = info.annualPrice;
    final isAnnual = _selectedCycle == 'annual';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Monthly Plan Card
          Expanded(
            child: _buildPlanCard(
              title: 'MONTHLY',
              priceDisplay: '\$${monthlyPrice.toStringAsFixed(0)}',
              period: '/mo',
              subtext: 'Billed monthly',
              badgeText: null,
              isSelected: !isAnnual,
              onTap: () => setState(() => _selectedCycle = 'monthly'),
            ),
          ),
          const SizedBox(width: 14),

          // Annual Plan Card (Best Value)
          Expanded(
            child: _buildPlanCard(
              title: 'ANNUAL',
              priceDisplay: '\$${annualPrice.toStringAsFixed(2)}',
              period: '/yr',
              subtext: '\$${(annualPrice / 12).toStringAsFixed(2)}/mo equivalent',
              badgeText: 'SAVE 20%',
              isSelected: isAnnual,
              onTap: () => setState(() => _selectedCycle = 'annual'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String priceDisplay,
    required String period,
    required String subtext,
    required String? badgeText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF0C2436), Color(0xFF071420)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    AppColors.surface.withOpacity(0.5),
                    const Color(0xFF070F1A).withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.cyan : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row (Plan Title + Radio Check / Badge)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppColors.geistBold(11).copyWith(
                      color: isSelected ? AppColors.cyan : AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.cyan : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppColors.cyan : Colors.white.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 12, color: Color(0xFF050C16))
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Price & Period
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    priceDisplay,
                    maxLines: 1,
                    style: AppColors.soraBold(20).copyWith(
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    period,
                    maxLines: 1,
                    style: AppColors.geistMedium(11).copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),

              // Subtext
              Text(
                subtext,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppColors.geistMedium(10).copyWith(
                  color: isSelected ? Colors.white70 : AppColors.textMuted.withOpacity(0.7),
                ),
              ),

              // Savings Tag (Typography styling, NO BADGE PILL)
              const SizedBox(height: 4),
              if (badgeText != null)
                Text(
                  '✦ $badgeText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppColors.geistBold(10).copyWith(
                    color: const Color(0xFF69F0AE),
                    letterSpacing: 0.8,
                  ),
                )
              else
                Opacity(
                  opacity: 0.0,
                  child: Text(
                    '✦ PLACEHOLDER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppColors.geistBold(10).copyWith(
                      color: Colors.transparent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsIncluded() {
    final perks = [
      {
        'icon': Icons.podcasts_rounded,
        'title': 'D.R.E.A.M Journal Episodes',
        'color': AppColors.cyan,
      },
      {
        'icon': Icons.smart_display_rounded,
        'title': 'D.R.E.A.M Activities Videos',
        'color': AppColors.cyan,
      },
      {
        'icon': Icons.auto_stories_rounded,
        'title': 'D.R.E.A.M Book Club',
        'color': AppColors.cyan,
      },
      {
        'icon': Icons.forum_rounded,
        'title': 'D.R.E.A.M Book Club Chat',
        'color': AppColors.cyan,
      },
      {
        'icon': Icons.local_offer_rounded,
        'title': 'Discounted on Merch 10% Off',
        'color': AppColors.cyan,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF070F1A).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.cyan, size: 16),
              const SizedBox(width: 8),
              Text(
                "WHAT'S INCLUDED IN YOUR PASS",
                style: AppColors.geistBold(11).copyWith(
                  color: AppColors.cyan,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 16),

          // Perk Items List
          ...perks.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isLast = idx == perks.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (item['color'] as Color).withOpacity(0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item['title'] as String,
                      style: AppColors.soraBold(13).copyWith(
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF69F0AE),
                    size: 18,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCTAButton() {
    final info = _tierInfo!;
    final isAnnual = _selectedCycle == 'annual';
    final priceStr = isAnnual
        ? '\$${info.annualPrice.toStringAsFixed(2)}/yr'
        : '\$${info.monthlyPrice.toStringAsFixed(0)}/mo';

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isNavigatingToCheckout ? null : _goToCheckout,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyan,
          foregroundColor: const Color(0xFF040A12),
          disabledBackgroundColor: AppColors.cyan.withOpacity(0.6),
          elevation: 6,
          shadowColor: AppColors.cyan.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isNavigatingToCheckout
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF040A12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'INITIALIZING...',
                    style: AppColors.soraBold(13).copyWith(
                      letterSpacing: 1.1,
                      color: const Color(0xFF040A12),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'JOIN TODAY • $priceStr',
                    style: AppColors.soraBold(14).copyWith(
                      letterSpacing: 1.1,
                      color: const Color(0xFF040A12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded, color: Color(0xFF040A12), size: 19),
                ],
              ),
      ),
    );
  }

  Widget _buildFreeAccountButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          );
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: _isOpeningFreeAccount
                ? AppColors.cyan.withOpacity(0.6)
                : Colors.white.withOpacity(0.18),
            width: 1.2,
          ),
          backgroundColor: AppColors.surface.withOpacity(0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isOpeningFreeAccount
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyan),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'LOADING SETUP...',
                    style: AppColors.geistBold(12).copyWith(
                      color: AppColors.cyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_outlined, color: AppColors.cyan, size: 18),
                  const SizedBox(width: 9),
                  Text(
                    'CREATE FREE ACCOUNT',
                    style: AppColors.soraBold(13).copyWith(
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white.withOpacity(0.5), size: 15),
                ],
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text.rich(
          TextSpan(
            text: 'Already a member? ',
            style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted),
            children: [
              TextSpan(
                text: 'Sign in to your account',
                style: AppColors.geistBold(13).copyWith(
                  color: AppColors.cyan,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.cyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Unable to load membership plans',
              style: AppColors.soraBold(16).copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Back', style: AppColors.geistBold(13).copyWith(color: Colors.white)),
                ),
                const SizedBox(width: 14),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadTierInfo();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Retry', style: AppColors.geistBold(13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

