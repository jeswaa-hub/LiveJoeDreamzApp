import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';

class NewsletterService {
  final Dio _dio = DioClient().dio;

  Future<String?> subscribe({required String email, required String phone}) async {
    try {
      final response = await _dio.post(ApiEndpoints.newsletterSubscribe, data: {
        'email': email,
        'phone': phone,
      });
      return response.data['message'] as String?;
    } on DioException catch (e) {
      return e.response?.data?['message'] ?? 'Subscription failed. Please try again.';
    } catch (e) {
      return 'Subscription failed. Please try again.';
    }
  }
}
