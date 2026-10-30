import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dream_community_app/core/config/api_config.dart';

class StripePaymentHelper {
  static Future<void> initAndPay(String clientSecret, {String? merchantName, String? publishableKey}) async {
    Stripe.publishableKey = publishableKey ?? ApiConfig.stripePublishableKey;
    await Stripe.instance.applySettings();

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: merchantName ?? 'D.R.E.A.M Community',
        style: ThemeMode.dark,
      ),
    );

    await Stripe.instance.presentPaymentSheet();
  }
}
