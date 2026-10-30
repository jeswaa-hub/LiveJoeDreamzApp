import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/features/community_tier/services/tier_service.dart';
import 'package:dream_community_app/features/community_tier/screens/logged_in_checkout_screen.dart';
import 'package:dream_community_app/features/community_tier/screens/logged_in_payment_success_screen.dart';
import 'package:dream_community_app/shared/widgets/loading_overlay.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';

class LoggedInTierPricingScreen extends StatefulWidget {
  const LoggedInTierPricingScreen({super.key});

  @override
  State<LoggedInTierPricingScreen> createState() => _LoggedInTierPricingScreenState();
}

class _LoggedInTierPricingScreenState extends State<LoggedInTierPricingScreen>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late AnimationController _twinkleController;

  UserModel? _currentUser;
  bool _isLoading = true;
  String _selectedCycle = 'annual'; // 'monthly' or 'annual'
  TierInfo? _tierInfo;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _loadData();
    if (kIsWeb) _checkPaymentReturn();
  }

  Future<void> _checkPaymentReturn() async {
    final uri = Uri.base;
    final params = uri.queryParameters;
    final hash = uri.fragment;

    bool isSuccess = params['payment'] == 'success' || hash.contains('payment=success');
    if (!isSuccess) return;

    final user = await AuthService().getCurrentUser();
    final email = user?.email ?? 'user@test.com';

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
            builder: (_) => LoggedInPaymentSuccessScreen(
              accessCode: processResult.accessCode!,
              userName: user?.name ?? 'Valued Member',
              planName: 'D.R.E.A.M. Community Pass',
              billingCycle: 'Annual',
              amount: 298.00,
              paymentMethod: 'Stripe',
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
            builder: (_) => LoggedInPaymentSuccessScreen(
              accessCode: processResult.accessCode!,
              userName: user?.name ?? 'Valued Member',
              planName: 'D.R.E.A.M. Community Pass',
              billingCycle: 'Annual',
              amount: 298.00,
              paymentMethod: 'PayPal',
            ),
          ),
          (route) => false,
        );
        return;
      }
    }

    LoadingOverlayState.hide();
  }

  @override
  void dispose() {
    _driftController.dispose();
    _twinkleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await AuthService().getCurrentUser();
    final tier = await TierService().getTierInfo();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _tierInfo = tier;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SpaceBackground(
              driftController: _driftController,
              twinkleController: _twinkleController,
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
                : Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Community Membership',
                                textAlign: TextAlign.center,
                                style: AppColors.soraBold(24).copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 20),
                              _buildCycleToggle(),
                              const SizedBox(height: 20),
                              _buildPricingCard(),
                              const SizedBox(height: 24),
                              _buildFeaturesList(),
                              const SizedBox(height: 28),
                              _buildCheckoutButton(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1929),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2D42)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Community Membership',
            style: AppColors.soraBold(18).copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleToggle() {
    final isAnnual = _selectedCycle == 'annual';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A2D42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedCycle = 'monthly'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: !isAnnual ? AppColors.cyan : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Monthly',
                style: AppColors.soraBold(13).copyWith(
                  color: !isAnnual ? const Color(0xFF051424) : AppColors.textMuted,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedCycle = 'annual'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isAnnual ? AppColors.cyan : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Annually (Save 20%)',
                style: AppColors.soraBold(13).copyWith(
                  color: isAnnual ? const Color(0xFF051424) : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    final isAnnual = _selectedCycle == 'annual';
    final double monthlyPrice = _tierInfo?.monthlyPrice ?? 31.0;
    final double annualPrice = _tierInfo?.annualPrice ?? 298.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A2D42), width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            'All-Access Membership',
            style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isAnnual
                    ? '\$${annualPrice.toStringAsFixed(2)}'
                    : '\$${monthlyPrice.toStringAsFixed(2)}',
                style: AppColors.soraBold(36).copyWith(color: Colors.white),
              ),
              Text(
                isAnnual ? ' / year' : ' / month',
                style: AppColors.geistMedium(14).copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isAnnual ? 'Includes 2 months free' : 'Flexible monthly renewal',
            style: AppColors.geistMedium(12).copyWith(color: AppColors.cyan),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {'icon': Icons.forum_rounded, 'title': 'Community & Group Chat'},
      {'icon': Icons.auto_stories_rounded, 'title': 'Book Club Discussions'},
      {'icon': Icons.play_circle_rounded, 'title': 'Video Lessons & Reflection Episodes'},
      {'icon': Icons.local_offer_rounded, 'title': '10% Discount on Merch Store'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'WHAT\'S INCLUDED',
            style: AppColors.geistBold(11).copyWith(color: AppColors.textMuted, letterSpacing: 1.5),
          ),
        ),
        ...features.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cyan.withOpacity(0.1),
                      border: Border.all(color: AppColors.cyan.withOpacity(0.25)),
                    ),
                    child: Icon(item['icon'] as IconData, color: AppColors.cyan, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['title'] as String,
                      style: AppColors.hankenMedium(14).copyWith(color: Colors.white.withOpacity(0.92)),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildCheckoutButton() {
    return GestureDetector(
      onTap: () {
        if (_tierInfo != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LoggedInCheckoutScreen(
                tierInfo: _tierInfo!,
                billingCycle: _selectedCycle,
                user: _currentUser,
              ),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cyan,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CONTINUE TO CHECKOUT',
              style: AppColors.soraBold(14).copyWith(color: const Color(0xFF051424), letterSpacing: 0.5),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Color(0xFF051424), size: 18),
          ],
        ),
      ),
    );
  }
}
