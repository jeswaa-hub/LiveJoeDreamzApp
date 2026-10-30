import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/models/merch_product_model.dart';

class MerchService {
  final Dio _dio = DioClient().dio;

  Future<List<MerchProductModel>> getProducts({String? category}) async {
    try {
      final params = <String, dynamic>{};
      if (category != null) params['category'] = category;
      final response = await _dio.get(ApiEndpoints.merch, queryParameters: params);
      final raw = response.data;
      final data = raw is Map ? (raw['data'] ?? raw['value'] ?? raw) : raw;
      if (data is List) {
        return data.map((j) => MerchProductModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<MerchProductModel>> getFeatured() async {
    try {
      final response = await _dio.get(ApiEndpoints.merchFeatured);
      final raw = response.data;
      final data = raw is Map ? (raw['data'] ?? raw['value'] ?? raw) : raw;
      if (data is List) {
        return data.map((j) => MerchProductModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
