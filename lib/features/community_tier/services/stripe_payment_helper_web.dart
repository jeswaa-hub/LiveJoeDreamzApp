// Web stub — Stripe PaymentSheet can't run on web.
// Web payments are handled by WebPaymentHandler (url_launcher → Stripe Checkout).
class StripePaymentHelper {
  static Future<void> initAndPay(String clientSecret, {String? merchantName, String? publishableKey}) async {
    // No-op on web — checkout_screen.dart uses WebPaymentHandler instead
  }
}
