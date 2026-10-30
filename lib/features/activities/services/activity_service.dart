import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/models/activity_model.dart';

class ActivityService {
  final Dio _dio = DioClient().dio;

  Future<List<ActivityModel>> getActivities() async {
    try {
      final response = await _dio.get(ApiEndpoints.activities);
      final raw = response.data;
      final data = raw is Map ? (raw['data'] ?? raw['value'] ?? raw) : raw;
      if (data is List) {
        return data.map((j) => ActivityModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<ActivityModel?> getActivity(int id) async {
    try {
      final response = await _dio.get('${ApiEndpoints.activities}/$id');
      return ActivityModel.fromJson(response.data['data'] ?? response.data);
    } on DioException {
      return null;
    }
  }
}
