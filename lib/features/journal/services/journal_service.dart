import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/models/journal_model.dart';

class JournalService {
  final Dio _dio = DioClient().dio;

  Future<List<JournalModel>> getJournals() async {
    try {
      final response = await _dio.get(ApiEndpoints.journals);
      final raw = response.data;
      final data = raw is Map ? (raw['data'] ?? raw['value'] ?? raw) : raw;
      if (data is List) {
        return data.map((j) => JournalModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<JournalModel?> getJournal(int id) async {
    try {
      final response = await _dio.get('${ApiEndpoints.journals}/$id');
      final raw = response.data;
      return JournalModel.fromJson(raw is Map ? (raw['data'] ?? raw) : raw);
    } on DioException {
      return null;
    }
  }
}
