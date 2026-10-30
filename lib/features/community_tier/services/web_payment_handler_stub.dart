import 'dart:async';

/// Stub implementation for mobile - WebPaymentHandler is only available on web
class WebPaymentHandler {
  static Future<WebPaymentResult> processStripePayment({
    String? checkoutUrl,
    String? clientSecret,
  }) async {
    throw UnsupportedError('WebPaymentHandler is only available on web');
  }

  static Future<WebPaymentResult> processPayPalPayment({
    required String orderId,
    String? approveUrl,
    String? email,
    String? billingCycle,
    Future<void> Function(String email, String paypalOrderId, String billingCycle)? onApprove,
  }) async {
    throw UnsupportedError('WebPaymentHandler is only available on web');
  }
}

class WebPaymentResult {
  final bool success;
  final String? error;
  final String? message;

  WebPaymentResult({required this.success, this.error, this.message});
}
