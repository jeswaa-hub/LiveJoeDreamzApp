// Stub for web — flutter_stripe uses Platform which doesn't exist on web
// This stub provides the same API surface so conditional import works

class PaymentSheetParameters {
  final String? paymentIntentClientSecret;
  final String? merchantDisplayName;
  final dynamic style;
  PaymentSheetParameters({this.paymentIntentClientSecret, this.merchantDisplayName, this.style});
}

class SetupPaymentSheetParameters {
  final String? paymentIntentClientSecret;
  final String? merchantDisplayName;
  final dynamic style;
  final bool customFlow;
  SetupPaymentSheetParameters({this.paymentIntentClientSecret, this.merchantDisplayName, this.style, this.customFlow = false});
}

class StripeException implements Exception {
  final dynamic error;
  StripeException({this.error});
}

class LocalizedErrorMessage {
  final String? message;
  LocalizedErrorMessage({this.message});
}

class Stripe {
  static String? publishableKey;
  static final Stripe _instance = Stripe._();
  factory Stripe() => _instance;
  Stripe._();

  static Future<void> applySettings() async {}
  Future<void> initPaymentSheet({dynamic paymentSheetParameters}) async {}
  Future<void> presentPaymentSheet() async {}
}

class ThemeMode { 
  static const dark = 'dark';
}
