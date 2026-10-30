import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/community_tier/services/tier_service.dart';
import 'package:dream_community_app/features/community_tier/services/stripe_payment_helper.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/shared/widgets/app_toast.dart';
import 'package:dream_community_app/shared/widgets/loading_overlay.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';
import 'package:dream_community_app/shared/widgets/minimalist_screen_loader.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/features/community_tier/screens/logged_in_payment_success_screen.dart';

import 'package:dream_community_app/features/community_tier/services/web_payment_handler.dart'
    if (dart.library.io) 'package:dream_community_app/features/community_tier/services/web_payment_handler_stub.dart';

class JournalCheckoutScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;

  const JournalCheckoutScreen({super.key, this.onUnlocked});

  @override
  State<JournalCheckoutScreen> createState() => _JournalCheckoutScreenState();
}

class _JournalCheckoutScreenState extends State<JournalCheckoutScreen>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late AnimationController _twinkleController;

  final _emailController = TextEditingController();

  String? _emailError;
  String _selectedPayment = 'stripe';
  bool _isProcessing = false;
  bool _isModalOpen = false;
  bool _isInitialLoading = true;
  String _productName = 'D.R.E.A.M. Journal';
  double? _price;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final stopwatch = Stopwatch()..start();
    try {
      await Future.wait([
        _loadLoggedInUserEmail(),
        _loadProductInfo(),
      ]);
    } catch (e) {
      debugPrint('Error initializing checkout data: $e');
    } finally {
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 650) {
        await Future.delayed(Duration(milliseconds: 650 - elapsed));
      }
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _loadProductInfo() async {
    try {
      final info = await TierService().getJournalInfo();
      if (info != null && mounted) {
        setState(() {
          if (info['name'] != null) _productName = info['name'];
          if (info['price'] != null) _price = (info['price'] as num).toDouble();
        });
      }
      if (_price == null && mounted) {
        setState(() => _price = 29.00);
      }
    } catch (e) {
      debugPrint('Error loading journal product info: $e');
      if (_price == null && mounted) {
        setState(() => _price = 29.00);
      }
    }
  }

  Future<void> _loadLoggedInUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr != null) {
        final map = jsonDecode(userDataStr);
        if (mounted) {
          setState(() {
            _user = UserModel.fromJson(map);
            if (map['email'] != null && (map['email'] as String).isNotEmpty) {
              _emailController.text = map['email'];
            }
          });
        }
      }
      final user = await AuthService().getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _user = user;
          _emailController.text = user.email;
        });
      }
    } catch (e) {
      debugPrint('Error loading user email: $e');
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
        'lifetime',
        platform: kIsWeb ? 'web' : 'mobile',
        email: email,
      );
      if (intentData == null || !mounted) {
        AppToast.show(context, 'Failed to initialize payment.', type: ToastType.error);
        return;
      }

      if (kIsWeb) {
        final checkoutUrl = intentData['checkout_url'] as String?;
        final sessionId = intentData['session_id'] as String?;
        if (checkoutUrl == null || sessionId == null) {
          AppToast.show(context, 'Invalid payment response.', type: ToastType.error);
          return;
        }

        final result = await WebPaymentHandler.processStripePayment(checkoutUrl: checkoutUrl);
        if (!result.success) {
          if (mounted) AppToast.show(context, result.error ?? 'Payment was cancelled.', type: ToastType.warning);
          return;
        }

        LoadingOverlayState.show(context, message: 'Verifying payment...');
        final processResult = await TierService().processStripe(
          email: email,
          paymentId: sessionId,
          billingCycle: 'lifetime',
        );
        LoadingOverlayState.hide();

        if (processResult.success) {
          await _saveJournalAccessAndComplete(email, processResult.token, processResult.user);
        } else if (mounted) {
          AppToast.show(context, processResult.message ?? 'Payment was cancelled.', type: ToastType.warning);
        }
      } else {
        final clientSecret = intentData['client_secret'] as String?;
        final paymentIntentId = intentData['payment_intent_id'] as String?;
        final publishableKey = intentData['publishable_key'] as String?;
        final checkoutUrl = intentData['checkout_url'] as String?;

        try {
          if (clientSecret != null) {
            await StripePaymentHelper.initAndPay(clientSecret, publishableKey: publishableKey);

            LoadingOverlayState.show(context, message: 'Finalizing payment...');
            final processResult = await TierService().processStripe(
              email: email,
              paymentId: paymentIntentId ?? clientSecret,
              billingCycle: 'lifetime',
            );
            LoadingOverlayState.hide();

            if (processResult.success) {
              await _saveJournalAccessAndComplete(email, processResult.token, processResult.user);
            } else if (mounted) {
              AppToast.show(context, processResult.message ?? 'Payment failed.', type: ToastType.error);
            }
          } else if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
            final res = await WebPaymentHandler.processStripePayment(checkoutUrl: checkoutUrl);
            if (res.success) {
              await _saveJournalAccessAndComplete(email, null, null);
            } else if (mounted) {
              AppToast.show(context, 'Payment was cancelled.', type: ToastType.warning);
            }
          }
        } catch (e) {
          LoadingOverlayState.hide();
          if (mounted) {
            if (e.toString().toLowerCase().contains('cancel')) {
              AppToast.show(context, 'Payment was cancelled.', type: ToastType.warning);
            } else {
              AppToast.show(context, 'Payment failed.', type: ToastType.error);
            }
          }
        }
      }
    } catch (e) {
      LoadingOverlayState.hide();
      if (mounted) AppToast.show(context, 'Stripe payment error: $e', type: ToastType.error);
    }
  }

  Future<void> _processPayPalPayment(String email) async {
    try {
      final data = await TierService().createPayPalOrder('lifetime', email: email);
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
          billingCycle: 'lifetime',
        );
        LoadingOverlayState.hide();

        if (processResult.success) {
          await _saveJournalAccessAndComplete(email, processResult.token, processResult.user);
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

        bool paid = false;
        String? payToken;
        dynamic payUser;
        for (var i = 0; i < 40; i++) {
          await Future.delayed(const Duration(seconds: 3));
          if (!mounted) { LoadingOverlayState.hide(); return; }
          try {
            final processResult = await TierService().processPayPal(
              email: email,
              paypalOrderId: orderId,
              billingCycle: 'lifetime',
            );
            if (processResult.success) {
              paid = true;
              payToken = processResult.token;
              payUser = processResult.user;
              break;
            }
          } catch (_) {}
        }
        LoadingOverlayState.hide();

        if (paid) {
          await _saveJournalAccessAndComplete(email, payToken, payUser);
        } else if (mounted) {
          AppToast.show(context, 'Payment was cancelled.', type: ToastType.warning);
        }
      }
    } catch (e) {
      LoadingOverlayState.hide();
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
        billingCycle: 'lifetime',
      );

      if (result == null || result['success'] != true || !mounted) {
        AppToast.show(context, result?['message'] ?? 'Failed to submit manual payment.', type: ToastType.error);
        return;
      }

      await _showQRModal(result, email);
    } catch (e) {
      if (mounted) AppToast.show(context, 'Manual payment error: $e', type: ToastType.error);
    }
  }

  Future<void> _saveJournalAccessAndComplete(String email, String? token, dynamic user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_journal_access', true);

    // Update cached user_data with journal access
    final userDataStr = prefs.getString('user_data');
    if (userDataStr != null) {
      try {
        final map = jsonDecode(userDataStr);
        map['has_journal_access'] = true;
        map['hasJournalAccess'] = true;
        map['tier'] = 'journal';
        await prefs.setString('user_data', jsonEncode(map));
      } catch (_) {}
    }

    // Save new token if provided
    if (token != null && token.isNotEmpty) {
      await prefs.setString('auth_token', token);
      // ignore: avoid_dynamic_calls
      if (user != null) {
        try {
          await prefs.setString('user_id', user.id.toString());
          await prefs.setString('user_data', jsonEncode({
            'id': user.id,
            'name': user.name,
            'email': user.email,
            'username': user.username,
            'role': user.role,
            'dream_role': user.dreamRole,
            'avatar_url': user.avatarUrl,
            'bio': user.bio,
            'location': user.location,
            'website': user.website,
            'phone': user.phone,
            'interests': user.interests,
            'badge_points': user.badgePoints,
            'show_in_directory': user.showInDirectory ? 1 : 0,
            'created_at': user.createdAt,
            'tier': user.tier,
            'has_admin_access': user.hasAdminAccess,
            'has_journal_access': true,
            'hasJournalAccess': true,
            'has_community_access': user.hasCommunityAccess,
            'hasCommunityAccess': user.hasCommunityAccess,
          }));
        } catch (_) {}
      }
      // ignore: avoid_dynamic_calls
    }

    // Refresh user data from server to sync permissions
    try {
      await AuthService().getCurrentUser();
    } catch (_) {}

    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    }
    if (mounted) {
      AppToast.show(context, 'D.R.E.A.M. Journal Unlocked Successfully!', type: ToastType.success);
      Navigator.pop(context, true);
    }
  }

  Future<void> _showQRModal(Map<String, dynamic> result, String email) async {
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
                      Text(method == 'venmo' ? 'Pay with Venmo' : 'Pay with Cash App',
                          style: AppColors.soraBold(18).copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('Scan the QR code below with your phone to complete payment.',
                          style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cyan, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          method == 'venmo' ? 'assets/images/VenmoQR.png' : 'assets/images/CashAppQR.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Product', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                                Text(_productName, style: AppColors.geistBold(12).copyWith(color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Email', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                                Text(email, style: AppColors.geistBold(12).copyWith(color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Access', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                                Text('Lifetime', style: AppColors.geistBold(12).copyWith(color: AppColors.cyan)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: AppColors.soraBold(13).copyWith(color: Colors.white)),
                                Text(
                                  _price == null ? '...' : '\$${_price!.toStringAsFixed(2)}',
                                  style: AppColors.soraBold(16).copyWith(color: AppColors.cyan),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: isConfirming ? null : () async {
                          if (purchaseId == null) return;
                          setModalState(() => isConfirming = true);
                          try {
                            await TierService().confirmManualPayment(purchaseId);
                            // Start live polling for immediate super admin approval sync
                            PendingApprovalSyncService.instance.startPolling(
                              purchaseId: purchaseId,
                              type: 'journal',
                              onApproved: (data) async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('has_journal_access', true);
                              },
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
                                userName: _user?.name ?? 'Member',
                                planName: 'Digital Dream Journal',
                                billingCycle: 'Lifetime',
                                amount: _price ?? 20.00,
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _isInitialLoading
          ? Scaffold(
              key: const ValueKey('checkout_loading'),
              backgroundColor: const Color(0xFF030712),
              body: Stack(
                children: [
                  const Positioned.fill(
                    child: MinimalistScreenLoader(
                      message: 'INITIALIZING CHECKOUT...',
                      duration: Duration(minutes: 5),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    child: SafeArea(
                      child: GestureDetector(
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
                    ),
                  ),
                ],
              ),
            )
          : Scaffold(
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
                          _buildHeaderBar(),
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
                'Journal Checkout',
                style: AppColors.soraBold(18).copyWith(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'Complete your Digital Dream Journal unlock',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    final displayPrice = _price ?? 20.00;
    return Container(
      width: double.infinity,
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
                  child: Icon(Icons.auto_stories_rounded, color: AppColors.cyan, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _productName,
                  style: AppColors.soraBold(14).copyWith(color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                ),
                child: Text(
                  'LIFETIME PASS',
                  style: AppColors.geistBold(9).copyWith(
                    color: AppColors.cyan,
                    letterSpacing: 0.8,
                  ),
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
              Text('Privacy & Security', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
              Text('100% Private & Encrypted', style: AppColors.geistBold(13).copyWith(color: const Color(0xFF69F0AE))),
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
                '\$${displayPrice.toStringAsFixed(2)}',
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

  Widget _buildUserChip() {
    final name = _user?.name ?? 'Member';
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : (_user?.email ?? 'user@test.com');
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
                'Complete your Digital Dream Journal unlock securely via PayPal.',
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
    final displayPrice = _price ?? 20.00;
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
                      'PAY \$${displayPrice.toStringAsFixed(2)} (LIFETIME ACCESS)',
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
