import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/models/event_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventService {
  final Dio _dio = DioClient().dio;

  Future<List<EventModel>> getEvents({String? status}) async {
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      final response = await _dio.get(ApiEndpoints.events, queryParameters: params);
      final raw = response.data;
      final data = raw is Map ? (raw['data'] ?? raw['value'] ?? raw) : raw;
      if (data is List) {
        return data.map((j) => EventModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> toggleRsvp(int eventId, {String status = 'going'}) async {
    try {
      final response = await _dio.post('${ApiEndpoints.eventRsvp}/$eventId/rsvp', data: {'status': status});
      final raw = response.data;
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{'success': true};
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data['message'] ?? 'RSVP failed') : 'RSVP failed';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'RSVP failed'};
    }
  }

  Future<Map<int, String>> getMyRsvps() async {
    try {
      final response = await _dio.get(ApiEndpoints.myRsvps);
      final raw = response.data;
      final data = raw is Map ? (raw['data'] ?? raw) : raw;
      if (data is Map) {
        return data.map((key, value) => MapEntry(int.parse(key.toString()), value.toString()));
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
