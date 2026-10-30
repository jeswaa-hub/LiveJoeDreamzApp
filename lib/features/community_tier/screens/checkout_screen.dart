import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/community_tier/services/tier_service.dart';
import 'package:dream_community_app/features/community_tier/services/stripe_payment_helper.dart';
import 'package:dream_community_app/features/community_tier/screens/success_screen.dart';
import 'package:dream_community_app/shared/widgets/app_toast.dart';
import 'package:dream_community_app/shared/widgets/loading_overlay.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';

// Import web payment handler only on web
import 'package:dream_community_app/features/community_tier/services/web_payment_handler.dart'
    if (dart.library.io) 'package:dream_community_app/features/community_tier/services/web_payment_handler_stub.dart';

class CheckoutScreen extends StatefulWidget {
  final TierInfo tierInfo;
  final String billingCycle;

  const CheckoutScreen({super.key, required this.tierInfo, required this.billingCycle});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late AnimationController _twinkleController;

  final _emailController = TextEditingController();

  String? _emailError;
  String _selectedPayment = 'stripe';
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
    
    if (widget.billingCycle == 'annual') {
      _cycleLabel = 'Annual';
    } else if (widget.billingCycle == 'monthly') {
      _cycleLabel = 'Monthly';
    } else {
      _cycleLabel = 'Lifetime Pass';
    }

    _loadLoggedInUserEmail();
  }

  Future<void> _loadLoggedInUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString('user_data');
    if (userDataStr != null) {
      final map = jsonDecode(userDataStr);
      if (map['email'] != null && (map['email'] as String).isNotEmpty) {
        if (mounted) {
          setState(() {
            _emailController.text = map['email'];
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _driftController.dispose();
    _twinkleController.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final email = _emailController.text.trim();
    setState(() {
      if (email.isEmpty) {
        _emailError = 'Email is required';
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _emailError = 'Invalid email format';
      } else {
        _emailError = null;
      }
    });
    return _emailError == null;
  }

  Future<void> _processPayment() async {
    if (_isProcessing || _isModalOpen) return;
    if (!_validateEmail()) {
      AppToast.show(context, _emailError!, type: ToastType.error);
      return;
    }

    final email = _emailController.text.trim();

    // Check if email already has a pending purchase
    final hasPending = await TierService().checkEmail(email);
    if (hasPending && mounted) {
      AppToast.show(context, 'A pending purchase exists for this email. Please complete it first.', type: ToastType.warning);
      return;
    }

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

      if (kIsWeb) {
        // Web: Checkout Session → open in new tab → process after
        final checkoutUrl = intentData['checkout_url'] as String?;
        final sessionId = intentData['session_id'] as String?;
        if (checkoutUrl == null || sessionId == null) {
          AppToast.show(context, 'Invalid payment response.', type: ToastType.error);
          return;
        }

        final result = await WebPaymentHandler.processStripePayment(checkoutUrl: checkoutUrl);
        if (!result.success) {
          if (mounted) AppToast.show(context, result.error ?? 'Payment failed.', type: ToastType.error);
          return;
        }

        // User returned from Stripe — process payment on backend
        LoadingOverlayState.show(context, message: 'Verifying payment...');
        final processResult = await TierService().processStripe(
          email: email,
          paymentId: sessionId,
          billingCycle: widget.billingCycle,
        );
        LoadingOverlayState.hide();

        if (processResult.success && processResult.token != null && processResult.user != null) {
          await TierService().saveAuth(processResult.token!, processResult.user!);
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => SuccessScreen(
                accessCode: processResult.accessCode!,
                userName: processResult.user!.name,
              )),
              (route) => false,
            );
          }
        } else if (mounted) {
          AppToast.show(context, processResult.message ?? 'Payment failed.', type: ToastType.error);
        }
      } else {
        // Mobile: PaymentIntent → flutter_stripe PaymentSheet
        final clientSecret = intentData['client_secret'] as String?;
        final paymentIntentId = intentData['payment_intent_id'] as String?;
        final publishableKey = intentData['publishable_key'] as String?;
        if (clientSecret == null || paymentIntentId == null) {
          AppToast.show(context, 'Invalid payment response.', type: ToastType.error);
          return;
        }

        final checkoutUrl = intentData['checkout_url'] as String?;
        final sessionId = intentData['session_id'] as String?;
        bool success = false;

        try {
          await StripePaymentHelper.initAndPay(clientSecret, publishableKey: publishableKey);
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
              if (processResult.success && processResult.token != null && processResult.user != null) {
                await TierService().saveAuth(processResult.token!, processResult.user!);
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => SuccessScreen(
                      accessCode: processResult.accessCode!,
                      userName: processResult.user!.name,
                    )),
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

        // Payment succeeded — create purchase on backend
        final result = await TierService().processStripe(
          email: email,
          paymentId: paymentIntentId,
          billingCycle: widget.billingCycle,
        );

        if (result.success && result.token != null && result.user != null) {
          await TierService().saveAuth(result.token!, result.user!);
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => SuccessScreen(
                accessCode: result.accessCode!,
                userName: result.user!.name,
              )),
              (route) => false,
            );
          }
        } else if (mounted) {
          AppToast.show(context, result.message ?? 'Payment failed.', type: ToastType.error);
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

        // User returned from PayPal — process payment on backend
        LoadingOverlayState.show(context, message: 'Verifying payment...');
        final processResult = await TierService().processPayPal(
          email: email,
          paypalOrderId: orderId,
          billingCycle: widget.billingCycle,
        );
        LoadingOverlayState.hide();

        if (processResult.success && processResult.token != null && processResult.user != null) {
          await TierService().saveAuth(processResult.token!, processResult.user!);
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => SuccessScreen(
                accessCode: processResult.accessCode!,
                userName: processResult.user!.name,
              )),
              (route) => false,
            );
          }
        } else if (mounted) {
          AppToast.show(context, processResult.message ?? 'Payment was cancelled.', type: ToastType.warning);
        }
      } else {
        // Mobile — open PayPal in browser
        if (approveUrl == null) {
          if (mounted) AppToast.show(context, 'Invalid PayPal response.', type: ToastType.error);
          return;
        }

        final uri = Uri.parse(approveUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        // Show waiting overlay — user is paying in browser
        LoadingOverlayState.show(context, message: 'Waiting for PayPal payment...');

        // Poll backend to verify payment (up to 60s)
        bool paid = false;
        for (var i = 0; i < 20; i++) {
          await Future.delayed(const Duration(seconds: 3));
          if (!mounted) { LoadingOverlayState.hide(); return; }
          try {
            final processResult = await TierService().processPayPal(
              email: email,
              paypalOrderId: orderId,
              billingCycle: widget.billingCycle,
            );
            if (processResult.success && processResult.token != null && processResult.user != null) {
              await TierService().saveAuth(processResult.token!, processResult.user!);
              LoadingOverlayState.hide();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => SuccessScreen(
                    accessCode: processResult.accessCode!,
                    userName: processResult.user!.name,
                  )),
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
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cyan.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(color: AppColors.cyan.withOpacity(0.2), blurRadius: 16),
                    ],
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 28, color: AppColors.cyan),
                ),
                const SizedBox(height: 16),

                Text(method == 'venmo' ? 'Pay with Venmo' : 'Pay with Cash App', style: AppColors.soraBold(18).copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text('Scan the QR code below with your phone to complete payment.', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
                const SizedBox(height: 20),

                // QR Code Container
                Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cyan, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(method == 'venmo' ? 'assets/images/VenmoQR.png' : 'assets/images/CashAppQR.png', fit: BoxFit.cover),
                ),
                const SizedBox(height: 20),

                // Order summary details
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Purchase', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                        Expanded(
                          child: Text(
                            widget.tierInfo.name,
                            style: AppColors.soraBold(13).copyWith(color: Colors.white),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Amount', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                        Text('\$${_price.toStringAsFixed(2)}', style: AppColors.soraBold(14).copyWith(color: AppColors.cyan)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Open your ${method == 'venmo' ? 'Venmo' : 'Cash App'} and scan the QR code to send the exact amount. Once sent, click "I\'VE COMPLETED PAYMENT" below.',
                  style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Primary CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isConfirming ? null : () async {
                      if (purchaseId == null) return;
                      setModalState(() => isConfirming = true);
                      try {
                        await TierService().confirmManualPayment(purchaseId);
                      } catch (_) {}
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => SuccessScreen(
                          accessCode: '',
                          userName: 'Member',
                          isManualPending: true,
                          paymentMethod: method,
                          purchaseId: purchaseId,
                        )),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConfirming ? AppColors.cyan.withOpacity(0.5) : AppColors.cyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: isConfirming
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF050C16)),
                          )
                        : Text("I'VE COMPLETED PAYMENT", style: AppColors.soraBold(13).copyWith(letterSpacing: 1.1)),
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
      body: SpaceBackground(
        driftController: _driftController,
        twinkleController: _twinkleController,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header Bar
                _buildHeaderBar(),
                const SizedBox(height: 20),

                // 2. Bento Order Summary Card
                _buildOrderSummary(),
                const SizedBox(height: 20),

                // 3. Account Email Card
                _buildEmailInput(),
                const SizedBox(height: 20),

                // 4. Mode of Payment Grid
                _buildPaymentMethods(),
                const SizedBox(height: 28),

                // 5. Pay Button
                _buildPayButton(),
                const SizedBox(height: 14),

                // 6. Security Note
                _buildSecurityNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
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
                'Community Checkout',
                style: AppColors.soraBold(18).copyWith(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'Complete your purchase to join the D.R.E.A.M Community',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    final isAnnual = widget.billingCycle == 'annual';
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
                      '${_cycleLabel} • Full Community Access & Perks',
                      style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
              Text('\$${_price.toStringAsFixed(2)}', style: AppColors.geistMedium(12).copyWith(color: Colors.white)),
            ],
          ),
          if (isAnnual) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 13, color: Color(0xFF69F0AE)),
                    const SizedBox(width: 4),
                    Text('Annual Savings', style: AppColors.geistMedium(12).copyWith(color: const Color(0xFF69F0AE))),
                  ],
                ),
                Text('20% OFF Applied', style: AppColors.geistBold(11).copyWith(color: const Color(0xFF69F0AE))),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppColors.soraBold(14).copyWith(color: Colors.white)),
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

  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCOUNT EMAIL',
          style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: AppColors.geistMedium(14).copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'you@email.com',
            hintStyle: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted.withOpacity(0.5)),
            prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.cyan, size: 18),
            filled: true,
            fillColor: const Color(0xFF070F1C).withOpacity(0.85),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cyan, width: 1.2),
            ),
            errorText: _emailError,
            errorStyle: AppColors.geistMedium(11).copyWith(color: AppColors.error),
          ),
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Your VIP membership access code will be sent to this email.',
          style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.65)),
        ),
      ],
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
            _paymentCard('stripe', 'Stripe', _buildStripeIcon(), const Color(0xFF635BFF)),
            _paymentCard('paypal', 'PayPal', _buildPayPalIcon(), const Color(0xFF0070BA)),
            _paymentCard('venmo', 'Venmo', _buildVenmoIcon(), const Color(0xFF3D95CE)),
            _paymentCard('cashapp', 'Cash App', _buildCashAppIcon(), const Color(0xFF00D632)),
          ],
        ),
      ],
    );
  }

  Widget _paymentCard(String id, String label, Widget icon, Color brandColor) {
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
                  icon,
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

  Widget _buildStripeIcon() {
    return SvgPicture.string(
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M13.976 9.15c-2.172-.806-3.356-1.426-3.356-2.409 0-.831.683-1.305 1.901-1.305 2.227 0 4.515.858 6.09 1.631l.89-5.494C18.252.975 15.697 0 12.165 0 9.667 0 7.589.654 6.104 1.872 4.56 3.147 3.757 4.992 3.757 7.218c0 4.039 2.467 5.76 6.476 7.219 2.585.92 3.445 1.574 3.445 2.583 0 .98-.84 1.545-2.354 1.545-1.875 0-4.965-.921-6.99-2.109l-.9 5.555C5.175 22.99 8.385 24 11.714 24c2.641 0 4.843-.624 6.328-1.813 1.664-1.305 2.525-3.236 2.525-5.732 0-4.128-2.524-5.851-6.594-7.305h.003z" fill="currentColor"/></svg>',
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(
        _selectedPayment == 'stripe' ? const Color(0xFF635BFF) : AppColors.textMuted,
        BlendMode.srcIn,
      ),
    );
  }

  Widget _buildPayPalIcon() {
    return SvgPicture.string(
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M15.607 4.653H8.941L6.645 19.251H1.82L4.862 0h7.995c3.754 0 6.375 2.294 6.473 5.513-.648-.478-2.105-.86-3.722-.86m6.57 5.546c0 3.41-3.01 6.853-6.958 6.853h-2.493L11.595 24H6.74l1.845-11.538h3.592c4.208 0 7.346-3.634 7.153-6.949a5.24 5.24 0 0 1 2.848 4.686M9.653 5.546h6.408c.907 0 1.942.222 2.363.541-.195 2.741-2.655 5.483-6.441 5.483H8.714Z" fill="currentColor"/></svg>',
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(
        _selectedPayment == 'paypal' ? const Color(0xFF0070BA) : AppColors.textMuted,
        BlendMode.srcIn,
      ),
    );
  }

  Widget _buildVenmoIcon() {
    return SvgPicture.string(
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M21.772 13.119c-.267 0-.381-.251-.38-.655 0-.533.121-1.575.712-1.575.267 0 .357.243.357.598 0 .533-.13 1.632-.689 1.632Zm.502-3.377c-1.677 0-2.405 1.285-2.405 2.658 0 1.042.421 1.874 1.693 1.874 1.717 0 2.438-1.406 2.438-2.763 0-1.025-.462-1.769-1.726-1.769Zm-3.833 0c-.558 0-.964.17-1.393.477-.154-.275-.462-.477-.932-.477-.542 0-.947.219-1.247.437l-.04-.364H13.54l-.688 4.354h1.506l.479-3.053c.129-.065.323-.154.518-.154.145 0 .267.049.267.267 0 .056-.016.145-.024.218l-.429 2.722h1.498l.478-3.053c.138-.073.324-.154.51-.154.146 0 .268.049.268.267 0 .056-.017.145-.025.218l-.429 2.722h1.499l.461-2.908c.025-.153.049-.388.049-.549 0-.582-.267-.97-1.037-.97Zm-6.871 0c-.575 0-.98.219-1.287.421l-.017-.348H8.962l-.689 4.354H9.78l.478-3.053c.13-.065.324-.154.518-.154.147 0 .268.049.268.242 0 .081-.024.227-.032.299l-.422 2.666h1.499l.462-2.908c.024-.153.049-.388.049-.549 0-.582-.268-.97-1.03-.97Zm-5.631 1.834c.041-.485.413-.824.697-.824.162 0 .299.097.299.291 0 .404-.713.533-.996.533Zm.843-1.834c-1.604 0-2.382 1.39-2.382 2.698 0 1.01.478 1.817 1.814 1.817.527 0 1.07-.113 1.418-.282l.186-1.26c-.494.25-.874.347-1.271.347-.365 0-.64-.194-.64-.687.826-.008 2.252-.347 2.252-1.453 0-.687-.494-1.18-1.377-1.18Zm-4.239.267c.089.186.146.412.146.743 0 .606-.429 1.494-.777 2.06l-.373-2.989L0 9.969l.705 4.2h1.757c.77-1.01 1.718-2.448 1.718-3.554 0-.347-.073-.622-.235-.889l-1.402.283Z" fill="currentColor"/></svg>',
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(
        _selectedPayment == 'venmo' ? const Color(0xFF3D95CE) : AppColors.textMuted,
        BlendMode.srcIn,
      ),
    );
  }

  Widget _buildCashAppIcon() {
    return SvgPicture.string(
      '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M23.59 3.475a5.1 5.1 0 00-3.05-3.05c-1.31-.42-2.5-.42-4.92-.42H8.36c-2.4 0-3.61 0-4.9.4a5.1 5.1 0 00-3.05 3.06C0 4.765 0 5.965 0 8.365v7.27c0 2.41 0 3.6.4 4.9a5.1 5.1 0 003.05 3.05c1.3.41 2.5.41 4.9.41h7.28c2.41 0 3.61 0 4.9-.4a5.1 5.1 0 003.06-3.06c.41-1.3.41-2.5.41-4.9v-7.25c0-2.41 0-3.61-.41-4.91zm-6.17 4.63l-.93.93a.5.5 0 01-.67.01 5 5 0 00-3.22-1.18c-.97 0-1.94.32-1.94 1.21 0 .9 1.04 1.2 2.24 1.65 2.1.7 3.84 1.58 3.84 3.64 0 2.24-1.74 3.78-4.58 3.95l-.26 1.2a.49.49 0 01-.48.39H9.63l-.09-.01a.5.5 0 01-.38-.59l.28-1.27a6.54 6.54 0 01-2.88-1.57v-.01a.48.48 0 010-.68l1-.97a.49.49 0 01.67 0c.91.86 2.13 1.34 3.39 1.32 1.3 0 2.17-.55 2.17-1.42 0-.87-.88-1.1-2.54-1.72-1.76-.63-3.43-1.52-3.43-3.6 0-2.42 2.01-3.6 4.39-3.71l.25-1.23a.48.48 0 01.48-.38h1.78l.1.01c.26.06.43.31.37.57l-.27 1.37c.9.3 1.75.77 2.48 1.39l.02.02c.19.2.19.5 0 .68z" fill="currentColor"/></svg>',
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(
        _selectedPayment == 'cashapp' ? const Color(0xFF00D632) : AppColors.textMuted,
        BlendMode.srcIn,
      ),
    );
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
                      'JOIN D.R.E.A.M COMMUNITY • \$${_price.toStringAsFixed(2)}',
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
