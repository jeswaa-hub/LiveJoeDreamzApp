import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class WebPaymentHandler {
  /// Process Stripe payment on web
  /// - checkoutUrl: Stripe Checkout Session URL (merch)
  /// - clientSecret: PaymentIntent client secret (community tier — fallback)
  static Future<WebPaymentResult> processStripePayment({
    String? checkoutUrl,
    String? clientSecret,
  }) async {
    try {
      // Prefer Checkout Session URL if available
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        final url = Uri.parse(checkoutUrl);
        final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
        if (launched) {
          return WebPaymentResult(success: true, message: 'Payment page opened.');
        } else {
          return WebPaymentResult(success: false, error: 'Failed to open payment page.');
        }
      }

      // Fallback: redirect to Stripe Checkout using client secret (won't work without Checkout Session)
      return WebPaymentResult(
        success: false,
        error: 'Stripe Checkout Session URL is required. Please use the mobile app.',
      );
    } catch (e) {
      return WebPaymentResult(success: false, error: e.toString());
    }
  }

  /// Process PayPal payment on web — opens PayPal in new tab.
  /// Merch flow: caller polls order-status to detect completion.
  /// Community tier flow: pass onApprove to process after user returns.
  static Future<WebPaymentResult> processPayPalPayment({
    required String orderId,
    String? approveUrl,
    String? email,
    String? billingCycle,
    Future<void> Function(String email, String paypalOrderId, String billingCycle)? onApprove,
  }) async {
    try {
      // Use approve URL from PayPal API (handles sandbox vs live automatically)
      // Fallback to live paypal.com if not provided
      final url = approveUrl ?? 'https://www.paypal.com/checkoutnow?token=$orderId';
      final paypalUrl = Uri.parse(url);
      final launched = await launchUrl(paypalUrl, mode: LaunchMode.externalApplication);

      if (launched) {
        // Community tier: call onApprove immediately (user returns to this tab)
        if (onApprove != null && email != null && billingCycle != null) {
          await onApprove(email, orderId, billingCycle);
        }
        return WebPaymentResult(success: true, message: 'PayPal opened.');
      } else {
        return WebPaymentResult(success: false, error: 'Failed to open PayPal.');
      }
    } catch (e) {
      return WebPaymentResult(success: false, error: e.toString());
    }
  }
}

class WebPaymentResult {
  final bool success;
  final String? error;
  final String? message;

  WebPaymentResult({required this.success, this.error, this.message});
}
