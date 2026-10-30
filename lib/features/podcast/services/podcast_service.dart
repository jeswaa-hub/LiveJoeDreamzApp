import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/models/podcast_model.dart';

class PodcastService {
  final Dio _dio = DioClient().dio;

  Future<List<PodcastModel>> getEpisodes({int? season}) async {
    try {
      final params = <String, dynamic>{};
      if (season != null) params['season'] = season;
      final response = await _dio.get(ApiEndpoints.podcasts, queryParameters: params);
      final raw = response.data;
      final data = raw is Map ? (raw['data'] ?? raw['value'] ?? raw) : raw;
      if (data is List) {
        return data.map((j) => PodcastModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<PodcastModel?> getEpisode(String slug) async {
    try {
      final response = await _dio.get('${ApiEndpoints.podcasts}/$slug');
      final raw = response.data;
      return PodcastModel.fromJson(raw is Map ? (raw['data'] ?? raw) : raw);
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>> submitApplication({
    required String fullName,
    required String email,
    required String phone,
    String? bio,
    Map<String, String>? socialLinks,
    String? preferredDate,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.podcastApply, data: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        if (bio != null && bio.isNotEmpty) 'bio': bio,
        if (socialLinks != null && socialLinks.isNotEmpty) 'social_links': socialLinks,
        if (preferredDate != null) 'preferred_date': preferredDate,
      });
      final raw = response.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{'success': true, 'message': 'Submitted'};
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data['message'] ?? 'Submission failed') : 'Submission failed';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Submission failed'};
    }
  }
}
