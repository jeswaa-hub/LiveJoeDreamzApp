import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/features/merch/services/cart_store.dart';
import 'package:dream_community_app/features/community_tier/services/web_payment_handler.dart';
import 'package:dream_community_app/features/community_tier/services/stripe_payment_helper_mobile.dart'
    if (dart.library.html) 'package:dream_community_app/features/community_tier/services/stripe_payment_helper_web.dart'
    as stripe_helper;
import 'package:dio/dio.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';
import 'package:dream_community_app/features/community_tier/screens/logged_in_payment_success_screen.dart';

import 'package:dream_community_app/shared/widgets/space_background.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late AnimationController _twinkleController;

  String _paymentMethod = 'stripe';
  bool _isProcessing = false;
  bool _isPollingCancelled = false;
  UserModel? _user;

  // Shipping form
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (user != null && mounted) {
        setState(() => _user = user);

        // Pre-fill from profile
        final nameParts = user.name.split(' ');
        if (nameParts.length >= 2) {
          _firstNameCtrl.text = nameParts.first;
          _lastNameCtrl.text = nameParts.sublist(1).join(' ');
        } else {
          _firstNameCtrl.text = user.name;
        }
        _emailCtrl.text = user.email;
        if (user.phone != null && user.phone!.isNotEmpty) {
          _phoneCtrl.text = user.phone!;
        }
        if (user.location != null && user.location!.isNotEmpty) {
          _addressCtrl.text = user.location!;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _waitingOverlay?.remove();
    _waitingOverlay = null;
    _driftController.dispose();
    _twinkleController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  bool _validateShipping() {
    if (_firstNameCtrl.text.trim().isEmpty) { _showError('Please enter your first name.'); return false; }
    if (_lastNameCtrl.text.trim().isEmpty) { _showError('Please enter your last name.'); return false; }
    if (_emailCtrl.text.trim().isEmpty) { _showError('Please enter your email address.'); return false; }
    if (!_emailCtrl.text.contains('@')) { _showError('Please enter a valid email address.'); return false; }
    if (_addressCtrl.text.trim().isEmpty) { _showError('Please enter your shipping address.'); return false; }
    if (_cityCtrl.text.trim().isEmpty) { _showError('Please enter your city.'); return false; }
    if (_stateCtrl.text.trim().isEmpty) { _showError('Please enter your state.'); return false; }
    if (_zipCtrl.text.trim().isEmpty) { _showError('Please enter your ZIP code.'); return false; }
    if (_countryCtrl.text.trim().isEmpty) { _showError('Please enter your country.'); return false; }
    return true;
  }

  void _showError(String msg) {
    DreamToast.error(context, msg);
  }

  Future<void> _placeOrder() async {
    if (!_validateShipping()) return;
    if (CartStore().items.isEmpty) { _showError('Your cart is empty.'); return; }

    setState(() => _isProcessing = true);

    if (_paymentMethod == 'stripe') {
      await _processStripePayment();
    } else if (_paymentMethod == 'paypal') {
      await _processPayPalPayment();
    } else {
      await _processManualPayment();
    }
  }

  Future<void> _processStripePayment() async {
    try {
      final subtotal = CartStore().subtotal;
      final isMember = _user != null && _user!.hasCommunityAccess;
      final discount = isMember ? subtotal * 0.10 : 0.0;
      final total = subtotal - discount;
      final shipping = _getShippingData();
      final items = _getCartItems();

      final dio = DioClient().dio;
      final response = await dio.post('/mobile/merch/stripe/intent', data: {
        'amount': total,
        'discount': discount,
        'items': items,
        'shipping': shipping,
        'platform': kIsWeb ? 'web' : 'mobile',
      });

      final data = response.data;
      if (data['success'] != true) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError(data['message'] ?? 'Failed to initialize payment.');
        }
        return;
      }

      final clientSecret = data['client_secret'] as String?;
      final paymentIntentId = data['payment_intent_id'] as String?;
      final publishableKey = data['publishable_key'] as String?;
      final checkoutUrl = data['checkout_url'] as String?;
      final sessionId = data['session_id'] as String?;
      final paymentIdToVerify = (sessionId != null && sessionId.isNotEmpty) ? sessionId : paymentIntentId;

      if (!kIsWeb) {
        bool mobileSdkSuccess = false;
        try {
          await stripe_helper.StripePaymentHelper.initAndPay(
            clientSecret ?? '',
            merchantName: 'D.R.E.A.M Merch',
            publishableKey: publishableKey,
          );
          mobileSdkSuccess = true;
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('cancel') || errStr.contains('canceled')) {
            if (mounted) {
              setState(() => _isProcessing = false);
              _showError('Payment was cancelled.');
            }
            return;
          }
          // Fallback to browser checkoutUrl if native SDK is unsupported
          mobileSdkSuccess = false;
        }

        if (mobileSdkSuccess) {
          try {
            final confirmRes = await dio.post('/mobile/merch/stripe', data: {
              'payment_id': paymentIntentId,
            });
            if (confirmRes.data['success'] == true) {
              if (mounted) {
                setState(() => _isProcessing = false);
                await CartStore().clear();
                _showOrderConfirmation(
                  orderNumber: confirmRes.data['order_number'] as String? ?? paymentIntentId,
                  orderId: confirmRes.data['order_id'] as int?,
                  amount: total,
                  paymentMethod: 'Stripe Card',
                );
              }
              return;
            } else {
              if (mounted) {
                setState(() => _isProcessing = false);
                _showError(confirmRes.data['message'] ?? 'Payment verification failed.');
              }
              return;
            }
          } catch (e) {
            if (mounted) {
              setState(() => _isProcessing = false);
              _showError('Payment verification failed.');
            }
            return;
          }
        }
      }

      // Browser / Web Stripe Checkout flow with active polling
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Invalid checkout URL.');
        }
        return;
      }

      final uri = Uri.parse(checkoutUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Failed to open payment page.');
        }
        return;
      }

      _isPollingCancelled = false;
      _showWaitingOverlay(onCancel: () {
        _isPollingCancelled = true;
        _hideWaitingOverlay();
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Payment was cancelled.');
        }
      });

      bool paid = false;
      String? paidOrderNum;
      int? paidOrderId;
      for (var i = 0; i < 40; i++) {
        if (_isPollingCancelled) break;
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted || _isPollingCancelled) break;

        try {
          final verifyRes = await dio.post('/mobile/merch/stripe', data: {
            'payment_id': paymentIdToVerify,
          });
          if (verifyRes.data['success'] == true) {
            paid = true;
            paidOrderNum = verifyRes.data['order_number'] as String?;
            paidOrderId = verifyRes.data['order_id'] as int?;
            break;
          }
        } catch (_) {
          // Expected 400 while payment is not completed yet
        }
      }

      _hideWaitingOverlay();

      if (mounted) {
        setState(() => _isProcessing = false);
        if (paid) {
          await CartStore().clear();
          _showOrderConfirmation(
            orderNumber: paidOrderNum,
            orderId: paidOrderId,
            amount: total,
            paymentMethod: 'Stripe Card',
          );
        } else if (!_isPollingCancelled) {
          _showError('Payment was not completed or was cancelled.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        String msg = 'Payment failed.';
        if (e is DioException) {
          msg = e.response?.data?['message'] ?? e.message ?? 'Payment server error.';
        } else {
          msg = e.toString();
        }
        _showError(msg);
      }
    }
  }

  Map<String, dynamic> _getShippingData() {
    return {
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'zip': _zipCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
    };
  }

  List<Map<String, dynamic>> _getCartItems() {
    return CartStore().items.map((item) => {
      'name': item['name'],
      'price': item['price'],
      'qty': item['qty'] ?? 1,
      'size': item['size'],
      'color': item['color'],
    }).toList();
  }

  OverlayEntry? _waitingOverlay;
  void _showWaitingOverlay({VoidCallback? onCancel}) {
    _waitingOverlay?.remove();
    _waitingOverlay = OverlayEntry(builder: (_) => Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1524),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44, height: 44,
                child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.cyan)),
              ),
              const SizedBox(height: 20),
              Text(
                'Waiting for payment...',
                style: AppColors.soraBold(16).copyWith(decoration: TextDecoration.none, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your payment in the browser window/tab.\nThis screen will automatically update once verified.',
                style: AppColors.hankenMedium(12).copyWith(color: AppColors.textMuted, decoration: TextDecoration.none),
                textAlign: TextAlign.center,
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      'Cancel Payment',
                      style: AppColors.soraSemiBold(13).copyWith(color: Colors.redAccent, decoration: TextDecoration.none),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ));
    Overlay.of(context).insert(_waitingOverlay!);
  }

  void _hideWaitingOverlay() {
    _waitingOverlay?.remove();
    _waitingOverlay = null;
  }

  Future<void> _processPayPalPayment() async {
    try {
      final subtotal = CartStore().subtotal;
      final isMember = _user != null && _user!.hasCommunityAccess;
      final discount = isMember ? subtotal * 0.10 : 0.0;
      final total = subtotal - discount;
      final shipping = _getShippingData();
      final items = _getCartItems();

      final dio = DioClient().dio;
      final response = await dio.post('/mobile/merch/paypal/create-order', data: {
        'amount': total,
        'discount': discount,
        'items': items,
        'shipping': shipping,
      });

      final data = response.data;
      if (data['success'] != true) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError(data['message'] ?? 'Failed to create PayPal order.');
        }
        return;
      }

      final orderId = data['order_id'] as String?;
      final approveUrl = data['approve_url'] as String?;
      if (orderId == null) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Invalid PayPal response.');
        }
        return;
      }

      if (kIsWeb) {
        final result = await WebPaymentHandler.processPayPalPayment(orderId: orderId, approveUrl: approveUrl);
        if (!result.success) {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showError(result.error ?? 'Failed to open PayPal.');
          }
          return;
        }
      } else {
        if (approveUrl == null) {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showError('Invalid PayPal response.');
          }
          return;
        }

        final uri = Uri.parse(approveUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showError('Failed to launch PayPal URL.');
          }
          return;
        }
      }

      // Show waiting overlay with explicit cancel option
      _isPollingCancelled = false;
      _showWaitingOverlay(onCancel: () {
        _isPollingCancelled = true;
        _hideWaitingOverlay();
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Payment was cancelled.');
        }
      });

      // Poll backend to verify payment (up to 40 attempts * 3s = 120s)
      bool paid = false;
      String? paidOrderNum;
      int? paidOrderId;
      for (var i = 0; i < 40; i++) {
        if (_isPollingCancelled) break;
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted || _isPollingCancelled) break;

        try {
          final verifyRes = await dio.post('/mobile/merch/paypal', data: {
            'paypal_order_id': orderId,
          });
          if (verifyRes.data['success'] == true) {
            paid = true;
            paidOrderNum = verifyRes.data['order_number'] as String?;
            paidOrderId = verifyRes.data['order_id'] as int?;
            break;
          }
        } catch (_) {
          // Expected 400 while payment is pending / not approved yet
        }
      }

      _hideWaitingOverlay();

      if (mounted) {
        setState(() => _isProcessing = false);
        if (paid) {
          await CartStore().clear();
          _showOrderConfirmation(
            orderNumber: paidOrderNum,
            orderId: paidOrderId,
            amount: total,
            paymentMethod: 'PayPal',
          );
        } else if (!_isPollingCancelled) {
          _showError('Payment was not completed or was cancelled.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('PayPal payment failed: $e');
      }
    }
  }

  Future<void> _processManualPayment() async {
    try {
      final subtotal = CartStore().subtotal;
      final isMember = _user != null && _user!.hasCommunityAccess;
      final discount = isMember ? subtotal * 0.10 : 0.0;
      final total = subtotal - discount;
      final shipping = _getShippingData();
      final items = _getCartItems();

      final dio = DioClient().dio;
      final response = await dio.post('/mobile/merch/manual', data: {
        'payment_method': _paymentMethod,
        'amount': total,
        'discount': discount,
        'items': items,
        'shipping': shipping,
      });

      final data = response.data;
      if (data['success'] != true) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError(data['message'] ?? 'Failed to create order.');
        }
        return;
      }

      final orderNumber = data['order_number'] as String?;
      final orderId = data['order_id'] as int?;
      if (mounted) {
        setState(() => _isProcessing = false);
        _showQrModal(orderNumber: orderNumber, orderId: orderId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Failed to create order: $e');
      }
    }
  }

  void _showQrModal({String? orderNumber, int? orderId}) {
    final method = _paymentMethod;
    final subtotal = CartStore().subtotal;
    final isMember = _user != null && _user!.hasCommunityAccess;
    final discount = isMember ? subtotal * 0.10 : 0.0;
    final payableTotal = subtotal - discount;
    final orderNum = orderNumber ?? 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => PopScope(
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
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 28, color: AppColors.cyan),
                ),
                const SizedBox(height: 16),

                Text(
                  method == 'venmo' ? 'Pay with Venmo' : 'Pay with Cash App',
                  style: AppColors.soraBold(18).copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scan the QR code below with your phone to send payment.',
                  style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // QR Code Container
                Container(
                  width: 180,
                  height: 180,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order Number', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                          Text(orderNum, style: AppColors.soraBold(13).copyWith(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Payable', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                          Text('\$${payableTotal.toStringAsFixed(2)}', style: AppColors.soraBold(14).copyWith(color: AppColors.cyan)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Open your ${method == 'venmo' ? 'Venmo' : 'Cash App'} and scan the QR code to send the exact amount. Once sent, tap "I\'VE PAID" below.',
                  style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await CartStore().clear();
                    if (!mounted) return;

                    if (orderId != null) {
                      PendingApprovalSyncService.instance.startPolling(
                        purchaseId: orderId,
                        type: 'merch',
                      );
                    }

                    final fullName = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoggedInPaymentSuccessScreen(
                          purchaseId: orderId,
                          accessCode: orderNumber ?? 'PENDING_APPROVAL',
                          userName: fullName.isNotEmpty ? fullName : (_user?.name ?? 'Valued Customer'),
                          planName: 'D.R.E.A.M Merch Order',
                          billingCycle: 'Standard Delivery',
                          amount: payableTotal,
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
                      gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B4D8)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: AppColors.cyan.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "I'VE PAID",
                        style: AppColors.soraBold(13).copyWith(
                          color: const Color(0xFF050C16),
                          letterSpacing: 1.2,
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
  }

  Future<void> _showOrderConfirmation({
    String? orderNumber,
    int? orderId,
    double? amount,
    String? paymentMethod,
  }) async {
    await CartStore().clear();
    if (!mounted) return;

    final subtotal = CartStore().subtotal;
    final isMember = _user != null && _user!.hasCommunityAccess;
    final discount = isMember ? subtotal * 0.10 : 0.0;
    final payableTotal = amount ?? (subtotal - discount);
    final fullName = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoggedInPaymentSuccessScreen(
          purchaseId: orderId,
          accessCode: orderNumber ?? 'CONFIRMED',
          userName: fullName.isNotEmpty ? fullName : (_user?.name ?? 'Valued Customer'),
          planName: 'D.R.E.A.M Merch Order',
          billingCycle: 'Standard Delivery',
          amount: payableTotal,
          paymentMethod: paymentMethod ?? 'Card / Stripe',
          isManualPending: false,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = CartStore().subtotal;
    final isMember = _user != null && _user!.hasCommunityAccess;
    final discount = isMember ? subtotal * 0.10 : 0.0;
    final total = subtotal - discount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SpaceBackground(
        driftController: _driftController,
        twinkleController: _twinkleController,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header Bar
                _buildHeaderBar(),
                const SizedBox(height: 20),

                // 2. Bento Order Summary Card
                _buildOrderSummary(subtotal, discount, total, isMember),
                const SizedBox(height: 20),

                // 3. Shipping & Contact Details
                _buildShippingSection(),
                const SizedBox(height: 20),

                // 4. Mode of Payment Grid
                _buildPaymentMethods(),
                const SizedBox(height: 14),

                // 5. Payment info helper
                _buildPaymentMethodInfo(),
                const SizedBox(height: 24),

                // 6. Dominant Place Order CTA Button
                _buildPlaceOrderButton(total),
                const SizedBox(height: 14),

                // 7. Security Footnote
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
                'Merch Checkout',
                style: AppColors.soraBold(18).copyWith(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'Review your cart & shipping details',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(double subtotal, double discount, double total, bool isMember) {
    final itemCount = CartStore().totalQty;

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
                  child: Icon(Icons.shopping_bag_outlined, color: AppColors.cyan, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: AppColors.soraBold(14).copyWith(color: Colors.white),
                    ),
                    Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'items'} in your cart',
                      style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 11, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      'FREE SHIPPING',
                      style: AppColors.geistBold(9).copyWith(
                        color: AppColors.success,
                        letterSpacing: 0.8,
                      ),
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
              Text('Subtotal', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
              Text('\$${subtotal.toStringAsFixed(2)}', style: AppColors.geistBold(13).copyWith(color: Colors.white)),
            ],
          ),
          if (isMember) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('VIP Member Savings', style: AppColors.geistMedium(13).copyWith(color: AppColors.success)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('10% OFF', style: AppColors.geistBold(9).copyWith(color: AppColors.success)),
                    ),
                  ],
                ),
                Text('-\$${discount.toStringAsFixed(2)}', style: AppColors.geistBold(13).copyWith(color: AppColors.success)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Standard Shipping', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
              Text('FREE', style: AppColors.geistBold(13).copyWith(color: AppColors.success)),
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
                '\$${total.toStringAsFixed(2)}',
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

  Widget _buildShippingSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF091220).withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: AppColors.cyan, size: 17),
              const SizedBox(width: 8),
              Text(
                'SHIPPING & CONTACT DETAILS',
                style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _formRow([
            _styledField('FIRST NAME', 'First name', _firstNameCtrl, icon: Icons.person_outline_rounded),
            _styledField('LAST NAME', 'Last name', _lastNameCtrl),
          ]),
          const SizedBox(height: 12),
          _styledField('EMAIL ADDRESS', 'your@email.com', _emailCtrl, icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _styledField('PHONE NUMBER (OPTIONAL)', '+1 (555) 000-0000', _phoneCtrl, icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _styledField('STREET ADDRESS', '123 Dream Ave, Apt 4B', _addressCtrl, icon: Icons.home_outlined),
          const SizedBox(height: 12),
          _formRow([
            _styledField('CITY', 'City', _cityCtrl, icon: Icons.location_city_rounded),
            _styledField('STATE / PROVINCE', 'State', _stateCtrl),
          ]),
          const SizedBox(height: 12),
          _formRow([
            _styledField('ZIP / POSTAL CODE', 'ZIP code', _zipCtrl),
            _styledField('COUNTRY', 'Country (e.g. USA)', _countryCtrl),
          ]),
        ],
      ),
    );
  }

  Widget _formRow(List<Widget> children) {
    return Row(
      children: [
        Expanded(child: children[0]),
        if (children.length > 1) ...[
          const SizedBox(width: 10),
          Expanded(child: children[1]),
        ],
      ],
    );
  }

  Widget _styledField(
    String label,
    String hint,
    TextEditingController ctrl, {
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppColors.geistBold(9).copyWith(
            color: AppColors.textMuted.withOpacity(0.7),
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: AppColors.geistMedium(13).copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted.withOpacity(0.35)),
            prefixIcon: icon != null ? Icon(icon, color: AppColors.cyan.withOpacity(0.8), size: 16) : null,
            filled: true,
            isDense: true,
            fillColor: const Color(0xFF060D18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          ),
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
    final isSelected = _paymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = id),
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
    if (_paymentMethod == 'stripe') {
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
                    ? 'You will be redirected to Stripe checkout to securely complete your payment.'
                    : 'Card payment processed securely via Stripe.',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    } else if (_paymentMethod == 'paypal') {
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
                'Complete your purchase seamlessly via your PayPal account.',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    } else {
      final isVenmo = _paymentMethod == 'venmo';
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
                'A dedicated ${isVenmo ? 'Venmo' : 'Cash App'} QR code will be generated to complete your payment.',
                style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPlaceOrderButton(double total) {
    return GestureDetector(
      onTap: _isProcessing ? null : _placeOrder,
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
                      'PLACE ORDER — \$${total.toStringAsFixed(2)}',
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
