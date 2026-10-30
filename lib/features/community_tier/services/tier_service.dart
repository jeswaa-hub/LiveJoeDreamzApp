import 'dart:convert';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class TierFeatureItem {
  final int id;
  final String title;
  final String? description;
  final String? imageUrl;

  TierFeatureItem({required this.id, required this.title, this.description, this.imageUrl});

  factory TierFeatureItem.fromJson(Map<String, dynamic> json) {
    return TierFeatureItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
    );
  }
}

class TierInfo {
  final String name;
  final String? description;
  final double monthlyPrice;
  final double annualPrice;
  final int annualSavingsPct;
  final List<TierFeatureItem> features;

  TierInfo({
    required this.name,
    this.description,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.annualSavingsPct,
    required this.features,
  });

  factory TierInfo.fromJson(Map<String, dynamic> json) {
    return TierInfo(
      name: json['name'] ?? 'Community',
      description: json['description'],
      monthlyPrice: (json['monthly_price'] ?? 31).toDouble(),
      annualPrice: (json['annual_price'] ?? 298).toDouble(),
      annualSavingsPct: json['annual_savings_pct'] ?? 20,
      features: (json['features'] as List<dynamic>?)
              ?.map((f) => TierFeatureItem.fromJson(f))
              .toList() ??
          [],
    );
  }
}

class CheckoutResult {
  final bool success;
  final String? accessCode;
  final String? token;
  final UserModel? user;
  final String? message;

  CheckoutResult({required this.success, this.accessCode, this.token, this.user, this.message});
}

class TierService {
  final Dio _dio = DioClient().dio;

  /// Get community tier info (public — no auth required)
  Future<TierInfo?> getTierInfo() async {
    try {
      final response = await _dio.get('${ApiEndpoints.communityTier}/info');
      return TierInfo.fromJson(response.data);
    } on DioException {
      return null;
    }
  }

  /// Get journal pass info dynamically from API/DB
  Future<Map<String, dynamic>?> getJournalInfo() async {
    try {
      final response = await _dio.get(ApiEndpoints.journalPassInfo);
      return response.data;
    } on DioException {
      return null;
    }
  }

  /// Check if email has a pending purchase
  Future<bool> checkEmail(String email) async {
    try {
      final response = await _dio.get('${ApiEndpoints.communityTierCheckEmail}/$email');
      return response.data['exists'] == true;
    } on DioException {
      return false;
    }
  }

  /// Create Stripe payment intent (checkout_url for web, client_secret for mobile)
  Future<Map<String, dynamic>?> createStripeIntent(String billingCycle, {String platform = 'mobile', String? email}) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.communityTier}/stripe/intent',
        data: {
          'billing_cycle': billingCycle,
          'platform': platform,
          if (email != null) 'email': email,
        },
      );
      return response.data;
    } on DioException {
      return null;
    }
  }

  /// Process Stripe payment (after client-side confirmation)
  Future<CheckoutResult> processStripe({
    required String email,
    required String paymentId,
    required String billingCycle,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.communityTier}/stripe',
        data: {
          'email': email,
          'payment_id': paymentId,
          'billing_cycle': billingCycle,
        },
      );
      final data = response.data;
      return CheckoutResult(
        success: data['success'] == true,
        accessCode: data['access_code'],
        token: data['token'],
        user: data['user'] != null ? UserModel.fromJson(data['user']) : null,
        message: data['message'],
      );
    } on DioException catch (e) {
      return CheckoutResult(success: false, message: e.response?.data?['message'] ?? 'Payment failed');
    }
  }

  /// Create PayPal order
  Future<Map<String, dynamic>?> createPayPalOrder(String billingCycle, {String? email}) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.communityTier}/paypal/create-order',
        data: {
          'billing_cycle': billingCycle,
          if (email != null) 'email': email,
        },
      );
      return response.data;
    } on DioException {
      return null;
    }
  }

  /// Process PayPal payment
  Future<CheckoutResult> processPayPal({
    required String email,
    required String paypalOrderId,
    required String billingCycle,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.communityTier}/paypal',
        data: {
          'email': email,
          'paypal_order_id': paypalOrderId,
          'billing_cycle': billingCycle,
        },
      );
      final data = response.data;
      return CheckoutResult(
        success: data['success'] == true,
        accessCode: data['access_code'],
        token: data['token'],
        user: data['user'] != null ? UserModel.fromJson(data['user']) : null,
      );
    } on DioException catch (e) {
      return CheckoutResult(success: false, message: e.response?.data?['message'] ?? 'PayPal payment failed');
    }
  }

  /// Process manual payment (Venmo/CashApp)
  Future<Map<String, dynamic>?> processManual({
    required String email,
    required String paymentMethod,
    required String billingCycle,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.communityTier}/manual',
        data: {
          'email': email,
          'payment_method': paymentMethod,
          'billing_cycle': billingCycle,
        },
      );
      return response.data;
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data?['message'] ?? 'Payment failed'};
    }
  }

  /// Confirm manual payment
  Future<bool> confirmManualPayment(int purchaseId) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.communityTier}/confirm-payment',
        data: {'purchase_id': purchaseId},
      );
      return response.data['success'] == true;
    } on DioException {
      return false;
    }
  }

  /// Poll tier purchase status (for web payment completion detection)
  Future<Map<String, dynamic>?> getTierStatus(int purchaseId) async {
    try {
      final response = await _dio.get('${ApiEndpoints.communityTier}/status/$purchaseId');
      return response.data;
    } on DioException {
      return null;
    }
  }

  /// Save auth token and user data after successful purchase
  Future<void> saveAuth(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_id', user.id);
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
    }));
    DioClient.setToken(token);
  }
}
