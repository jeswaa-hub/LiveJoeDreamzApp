import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/features/community_tier/services/tier_service.dart';
import 'package:dream_community_app/features/community_tier/services/stripe_payment_helper.dart';
import 'package:dream_community_app/features/community_tier/screens/logged_in_payment_success_screen.dart';
import 'package:dream_community_app/shared/widgets/app_toast.dart';
import 'package:dream_community_app/shared/widgets/loading_overlay.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';

import 'package:dream_community_app/features/community_tier/services/web_payment_handler.dart'
    if (dart.library.io) 'package:dream_community_app/features/community_tier/services/web_payment_handler_stub.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

class LoggedInCheckoutScreen extends StatefulWidget {
  final TierInfo tierInfo;
  final String billingCycle;
  final UserModel? user;

  const LoggedInCheckoutScreen({
    super.key,
    required this.tierInfo,
    required this.billingCycle,
    this.user,
  });

  @override
  State<LoggedInCheckoutScreen> createState() => _LoggedInCheckoutScreenState();
}

class _LoggedInCheckoutScreenState extends State<LoggedInCheckoutScreen>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late AnimationController _twinkleController;

  String _selectedPayment = 'stripe'; // 'stripe', 'paypal', 'venmo', 'cashapp'
  bool _isProcessing = false;
  bool _isModalOpen = false;

  late double _price;
  late String _cycleLabel;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _price = widget.billingCycle == 'annual' ? widget.tierInfo.annualPrice : widget.tierInfo.monthlyPrice;
    _cycleLabel = widget.billingCycle == 'annual' ? 'Annual' : 'Monthly';
  }

  @override
  void dispose() {
    _driftController.dispose();
    _twinkleController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_isProcessing || _isModalOpen) return;
    final email = widget.user?.email ?? 'user@test.com';

    setState(() => _isProcessing = true);

    switch (_selectedPayment) {
      case 'stripe':
        await _processStripePayment(email);
        break;
      case 'paypal':
        await _processPayPalPayment(email);
        break;
      case 'venmo':
      case 'cashapp':
        await _processManualPayment(email);
        break;
    }

    if (mounted) {
      LoadingOverlayState.hide();
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processStripePayment(String email) async {
    try {
      final intentData = await TierService().createStripeIntent(
        widget.billingCycle,
        platform: kIsWeb ? 'web' : 'mobile',
        email: email,
      );
      if (intentData == null || !mounted) {
        AppToast.show(context, 'Failed to initialize payment.', type: ToastType.error);
        return;
      }

      final checkoutUrl = intentData['checkout_url'] as String?;
      final sessionId = intentData['session_id'] as String?;
      final clientSecret = intentData['client_secret'] as String?;
      final paymentIntentId = intentData['payment_intent_id'] as String?;
      final publishableKey = intentData['publishable_key'] as String?;

      if (kIsWeb) {
        if (checkoutUrl == null || sessionId == null) {
          AppToast.show(context, 'Invalid payment response.', type: ToastType.error);
          return;
        }

        final result = await WebPaymentHandler.processStripePayment(checkoutUrl: checkoutUrl);
        if (!result.success) {
          if (mounted) AppToast.show(context, result.error ?? 'Payment failed.', type: ToastType.error);
          return;
        }

        LoadingOverlayState.show(context, message: 'Verifying payment...');
        final processResult = await TierService().processStripe(
          email: email,
          paymentId: sessionId,
          billingCycle: widget.billingCycle,
        );
        LoadingOverlayState.hide();

        if (processResult.success && processResult.accessCode != null) {
          if (processResult.token != null && processResult.user != null) {
            await TierService().saveAuth(processResult.token!, processResult.user!);
          }
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => LoggedInPaymentSuccessScreen(
                  accessCode: processResult.accessCode!,
                  userName: widget.user?.name ?? 'Member',
                  planName: 'D.R.E.A.M. Community Membership',
                  billingCycle: _cycleLabel,
                  amount: _price,
                  paymentMethod: 'Stripe',
                ),
              ),
              (route) => false,
            );
          }
        } else if (mounted) {
          AppToast.show(context, processResult.message ?? 'Payment failed.', type: ToastType.error);
        }
      } else {
        bool success = false;

        try {
          await StripePaymentHelper.initAndPay(clientSecret ?? '', publishableKey: publishableKey);
          success = true;
        } catch (e) {
          if (checkoutUrl != null && checkoutUrl.isNotEmpty && !e.toString().toLowerCase().contains('cancel')) {
            final res = await WebPaymentHandler.processStripePayment(checkoutUrl: checkoutUrl);
            if (res.success && sessionId != null) {
              LoadingOverlayState.show(context, message: 'Verifying payment...');
              final processResult = await TierService().processStripe(
                email: email,
                paymentId: sessionId,
                billingCycle: widget.billingCycle,
              );
              LoadingOverlayState.hide();
              if (processResult.success && processResult.accessCode != null) {
                if (processResult.token != null && processResult.user != null) {
                  await TierService().saveAuth(processResult.token!, processResult.user!);
                }
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoggedInPaymentSuccessScreen(
                        accessCode: processResult.accessCode!,
                        userName: widget.user?.name ?? 'Member',
                        planName: 'D.R.E.A.M. Community Membership',
                        billingCycle: _cycleLabel,
                        amount: _price,
                        paymentMethod: 'Stripe',
                      ),
                    ),
                    (route) => false,
                  );
                }
                return;
              }
            }
          }
          if (mounted) {
            if (e.toString().toLowerCase().contains('cancel')) {
              AppToast.show(context, 'Payment was cancelled.', type: ToastType.warning);
            } else {
              AppToast.show(context, 'Payment failed.', type: ToastType.error);
            }
          }
          return;
        }

        if (success && paymentIntentId != null) {
          final result = await TierService().processStripe(
            email: email,
            paymentId: paymentIntentId,
            billingCycle: widget.billingCycle,
          );

          if (result.success && result.accessCode != null) {
            if (result.token != null && result.user != null) {
              await TierService().saveAuth(result.token!, result.user!);
            }
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => LoggedInPaymentSuccessScreen(
                    accessCode: result.accessCode!,
                    userName: widget.user?.name ?? 'Member',
                    planName: 'D.R.E.A.M. Community Membership',
                    billingCycle: _cycleLabel,
                    amount: _price,
                    paymentMethod: 'Stripe',
                  ),
                ),
                (route) => false,
              );
            }
          } else if (mounted) {
            AppToast.show(context, result.message ?? 'Payment failed.', type: ToastType.error);
          }
        }
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'Payment failed: $e', type: ToastType.error);
    }
  }

  Future<void> _processPayPalPayment(String email) async {
    try {
      final data = await TierService().createPayPalOrder(widget.billingCycle, email: email);
      if (data == null || data['success'] != true || !mounted) {
        AppToast.show(context, data?['message'] ?? 'Failed to create PayPal order.', type: ToastType.error);
        return;
      }

      final orderId = data['order_id'] as String?;
      final approveUrl = data['approve_url'] as String?;
      if (orderId == null) {
        AppToast.show(context, 'Invalid PayPal response.', type: ToastType.error);
        return;
      }

      if (kIsWeb) {
        final result = await WebPaymentHandler.processPayPalPayment(orderId: orderId, approveUrl: approveUrl);
        if (!result.success) {
          if (mounted) AppToast.show(context, 'Payment was cancelled.', type: ToastType.warning);
          return;
        }

        LoadingOverlayState.show(context, message: 'Verifying payment...');
        final processResult = await TierService().processPayPal(
          email: email,
          paypalOrderId: orderId,
          billingCycle: widget.billingCycle,
        );
        LoadingOverlayState.hide();

        if (processResult.success && processResult.accessCode != null) {
          if (processResult.token != null && processResult.user != null) {
            await TierService().saveAuth(processResult.token!, processResult.user!);
          }
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => LoggedInPaymentSuccessScreen(
                  accessCode: processResult.accessCode!,
                  userName: widget.user?.name ?? 'Member',
                  planName: 'D.R.E.A.M. Community Membership',
                  billingCycle: _cycleLabel,
                  amount: _price,
                  paymentMethod: 'PayPal',
                ),
              ),
              (route) => false,
            );
          }
        } else if (mounted) {
          AppToast.show(context, processResult.message ?? 'Payment was cancelled.', type: ToastType.warning);
        }
      } else {
        if (approveUrl == null) {
          if (mounted) AppToast.show(context, 'Invalid PayPal response.', type: ToastType.error);
          return;
        }

        final uri = Uri.parse(approveUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        LoadingOverlayState.show(context, message: 'Waiting for PayPal payment...');

        for (var i = 0; i < 20; i++) {
          await Future.delayed(const Duration(seconds: 3));
          if (!mounted) { LoadingOverlayState.hide(); return; }
          try {
            final processResult = await TierService().processPayPal(
              email: email,
              paypalOrderId: orderId,
              billingCycle: widget.billingCycle,
            );
            if (processResult.success && processResult.accessCode != null) {
              if (processResult.token != null && processResult.user != null) {
                await TierService().saveAuth(processResult.token!, processResult.user!);
              }
              LoadingOverlayState.hide();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoggedInPaymentSuccessScreen(
                      accessCode: processResult.accessCode!,
                      userName: widget.user?.name ?? 'Member',
                      planName: 'D.R.E.A.M. Community Membership',
                      billingCycle: _cycleLabel,
                      amount: _price,
                      paymentMethod: 'PayPal',
                    ),
                  ),
                  (route) => false,
                );
              }
              return;
            }
          } catch (_) {}
        }

        LoadingOverlayState.hide();
        if (mounted) {
          AppToast.show(context, 'Payment was cancelled.', type: ToastType.warning);
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().toLowerCase().contains('cancel')) {
          AppToast.show(context, 'Payment was cancelled.', type: ToastType.warning);
        } else {
          AppToast.show(context, 'Payment failed: $e', type: ToastType.error);
        }
      }
    }
  }

  Future<void> _processManualPayment(String email) async {
    try {
      final result = await TierService().processManual(
        email: email,
        paymentMethod: _selectedPayment,
        billingCycle: widget.billingCycle,
      );

      if (result == null || result['success'] != true) {
        if (mounted) {
          AppToast.show(context, result?['message'] ?? 'Payment failed.', type: ToastType.error);
        }
        return;
      }

      if (mounted) {
        await _showQRModal(result);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Payment error: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _showQRModal(Map<String, dynamic> result) async {
    if (_isModalOpen || !mounted) return;
    _isModalOpen = true;

    final method = _selectedPayment;
    final purchaseId = result['purchase_id'] as int?;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (ctx) {
          bool isConfirming = false;
          return StatefulBuilder(
            builder: (ctx, setModalState) => PopScope(
              canPop: false,
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
                decoration: BoxDecoration(
                  color: const Color(0xFF070E17),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.4), width: 1.5),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Accent Bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Icon Header
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cyan.withOpacity(0.4)),
                          boxShadow: [
                            BoxShadow(color: AppColors.cyan.withOpacity(0.2), blurRadius: 16),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            method == 'venmo' ? Icons.payment_rounded : Icons.account_balance_wallet_rounded,
                            color: AppColors.cyan,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Scan & Pay with ${method == 'venmo' ? 'Venmo' : 'Cash App'}',
                        style: AppColors.soraBold(17).copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please send the exact total amount below',
                        style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),

                      // QR Box
                      Container(
                        width: 210,
                        height: 210,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cyan.withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(color: AppColors.cyan.withOpacity(0.25), blurRadius: 24, spreadRadius: 2),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            method == 'venmo' ? 'assets/images/VenmoQR.png' : 'assets/images/CashAppQR.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.textMuted),
                                  const SizedBox(height: 8),
                                  Text('Scan QR to Pay', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Order Summary Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Plan', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                                Text(widget.tierInfo.name, style: AppColors.soraBold(13).copyWith(color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Cycle', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                                Text(_cycleLabel, style: AppColors.geistMedium(13).copyWith(color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Amount', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                                Text('\$${_price.toStringAsFixed(2)}', style: AppColors.soraBold(14).copyWith(color: AppColors.cyan)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Open your ${method == 'venmo' ? 'Venmo' : 'Cash App'} and scan the QR code to send the exact amount. Once sent, tap "I\'VE COMPLETED PAYMENT" below.',
                        style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: isConfirming ? null : () async {
                          if (purchaseId == null) return;
                          setModalState(() => isConfirming = true);
                          try {
                            await TierService().confirmManualPayment(purchaseId);
                            // Start polling immediately for real-time approval sync
                            PendingApprovalSyncService.instance.startPolling(
                              purchaseId: purchaseId,
                              type: 'community',
                            );
                          } catch (_) {}
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoggedInPaymentSuccessScreen(
                                purchaseId: purchaseId,
                                accessCode: 'PENDING_APPROVAL',
                                userName: widget.user?.name ?? 'Member',
                                planName: 'D.R.E.A.M. Community Membership',
                                billingCycle: _cycleLabel,
                                amount: _price,
                                paymentMethod: method == 'venmo' ? 'Venmo' : 'Cash App',
                                isManualPending: true,
                              ),
                            ),
                            (route) => false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: isConfirming
                                ? LinearGradient(colors: [AppColors.cyan.withOpacity(0.4), AppColors.cyan.withOpacity(0.4)])
                                : const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B4D8)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: AppColors.cyan.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Center(
                            child: isConfirming
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF050C16)),
                                  )
                                : Text(
                                    "I'VE COMPLETED PAYMENT",
                                    style: AppColors.soraBold(13).copyWith(
                                      color: const Color(0xFF050C16),
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _isModalOpen = false;
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
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Header Bar
                  _buildHeader(),
                  const SizedBox(height: 20),

                  // 2. Bento Order Summary Card
                  _buildOrderSummary(),
                  const SizedBox(height: 20),

                  // 3. User Identity Pill
                  _buildUserChip(),
                  const SizedBox(height: 20),

                  // 4. Mode of Payment Grid
                  _buildPaymentMethods(),
                  const SizedBox(height: 14),

                  // 5. Payment info helper
                  _buildPaymentMethodInfo(),
                  const SizedBox(height: 24),

                  // 6. Dominant CTA Pay Button
                  _buildPayButton(),
                  const SizedBox(height: 14),

                  // 7. Security Note
                  _buildSecurityNote(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 19),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tier Checkout',
                style: AppColors.soraBold(18).copyWith(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'Complete your ${widget.tierInfo.name} membership',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserChip() {
    final name = widget.user?.name ?? 'Member';
    final email = widget.user?.email ?? 'user@test.com';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF070F1C).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user_rounded, color: AppColors.cyan, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOGGED IN ACCOUNT',
                  style: AppColors.geistBold(9).copyWith(color: AppColors.cyan, letterSpacing: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  '$name • $email',
                  style: AppColors.geistMedium(13).copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0C192E),
            Color(0xFF060E1A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.cyan.withOpacity(0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_rounded, color: AppColors.cyan, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tierInfo.name,
                      style: AppColors.soraBold(14).copyWith(color: Colors.white),
                    ),
                    Text(
                      '${_cycleLabel} • Official Community Membership',
                      style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Billing Cycle', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
              Text(_cycleLabel, style: AppColors.geistBold(13).copyWith(color: Colors.white)),
            ],
          ),
          if (widget.billingCycle == 'annual') ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Annual Savings', style: AppColors.geistMedium(13).copyWith(color: AppColors.success)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('20% OFF', style: AppColors.geistBold(9).copyWith(color: AppColors.success)),
                    ),
                  ],
                ),
                Text('Included', style: AppColors.geistBold(13).copyWith(color: AppColors.success)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Access Level', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
              Text('VIP Member Pass', style: AppColors.geistBold(13).copyWith(color: AppColors.cyan)),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppColors.soraBold(15).copyWith(color: Colors.white)),
              Text(
                '\$${_price.toStringAsFixed(2)}',
                style: AppColors.soraBold(20).copyWith(
                  color: AppColors.cyan,
                  shadows: [
                    Shadow(color: AppColors.cyan.withOpacity(0.4), blurRadius: 10),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MODE OF PAYMENT',
          style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 1.5),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            _paymentCard('stripe', 'Stripe', Icons.credit_card_rounded, const Color(0xFF635BFF)),
            _paymentCard('paypal', 'PayPal', Icons.account_balance_wallet_rounded, const Color(0xFF0070BA)),
            _paymentCard('venmo', 'Venmo', Icons.qr_code_rounded, const Color(0xFF3D95CE)),
            _paymentCard('cashapp', 'Cash App', Icons.attach_money_rounded, const Color(0xFF00D632)),
          ],
        ),
      ],
    );
  }

  Widget _paymentCard(String id, String label, IconData icon, Color brandColor) {
    final isSelected = _selectedPayment == id;
    return GestureDetector(
      onTap: () {
        if (_isProcessing || _isModalOpen) return;
        setState(() => _selectedPayment = id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withOpacity(0.12) : const Color(0xFF0A1424).withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? brandColor : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: isSelected ? brandColor : AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppColors.geistBold(12).copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: brandColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: brandColor.withOpacity(0.6), blurRadius: 4),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodInfo() {
    if (_selectedPayment == 'stripe') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF635BFF).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF635BFF).withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF635BFF), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kIsWeb
                    ? 'You will be redirected to Stripe checkout to securely complete payment.'
                    : 'Card payment processed securely via Stripe.',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    } else if (_selectedPayment == 'paypal') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0070BA).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0070BA).withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF0070BA), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Complete your membership securely via PayPal.',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    } else {
      final isVenmo = _selectedPayment == 'venmo';
      final color = isVenmo ? const Color(0xFF3D95CE) : const Color(0xFF00D632);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'A dedicated ${isVenmo ? 'Venmo' : 'Cash App'} QR code will be presented to complete your payment.',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPayButton() {
    return GestureDetector(
      onTap: _isProcessing ? null : _processPayment,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: _isProcessing
              ? LinearGradient(colors: [AppColors.cyan.withOpacity(0.4), AppColors.cyan.withOpacity(0.4)])
              : const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B4D8)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: _isProcessing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF050C16)),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded, color: Color(0xFF050C16), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'PAY \$${_price.toStringAsFixed(2)} (${_cycleLabel.toUpperCase()})',
                      style: AppColors.soraBold(13).copyWith(
                        color: const Color(0xFF050C16),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 13, color: AppColors.textMuted.withOpacity(0.6)),
        const SizedBox(width: 6),
        Text(
          'Secured by Stripe & 256-bit Encrypted SSL',
          style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.6)),
        ),
      ],
    );
  }
}
