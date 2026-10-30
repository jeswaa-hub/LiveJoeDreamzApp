// Web stub — PayPal is handled by WebPaymentHandler (url_launcher → PayPal).
class PayPalHelper {
  static Future<void> initAndPay({
    required String orderId,
    required String clientId,
    required void Function(String payerId) onApprove,
    required void Function(String error) onError,
  }) async {
    // No-op on web — checkout_screen.dart uses WebPaymentHandler instead
  }
}
