import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/models/journal_entry_model.dart';

class PickedMediaFile {
  final List<int> bytes;
  final String fileName;
  final bool isVideo;

  PickedMediaFile({
    required this.bytes,
    required this.fileName,
    this.isVideo = false,
  });
}

class JournalEntryService {
  final Dio _dio = DioClient().dio;

  Future<List<JournalEntryModel>> getEntries({String? search, String? filter}) async {
    try {
      final response = await _dio.get('/user/journals', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
      });

      final data = response.data;
      if (data['success'] == true && data['entries'] is List) {
        return (data['entries'] as List)
            .map((e) => JournalEntryModel.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print('[JournalEntryService Error] $e');
      return [];
    }
  }

  Future<bool> toggleFavorite(int id) async {
    try {
      final response = await _dio.post('/user/journals/$id/favorite');
      return response.data['success'] == true;
    } catch (e) {
      print('[JournalEntryService toggleFavorite error] $e');
      return false;
    }
  }

  Future<JournalEntryModel?> createEntry({
    required String entryDate,
    String? dream,
    String? destination,
    String? reason,
    String? energy,
    String? amigos,
    String? mindset,
    List<PickedMediaFile>? mediaFiles,
  }) async {
    try {
      final mapData = <String, dynamic>{
        'entry_date': entryDate,
        if (dream != null) 'dream': dream,
        if (destination != null) 'destination': destination,
        if (reason != null) 'reason': reason,
        if (energy != null) 'energy': energy,
        if (amigos != null) 'amigos': amigos,
        if (mindset != null) 'mindset': mindset,
      };

      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        final files = <MultipartFile>[];
        for (final item in mediaFiles) {
          files.add(MultipartFile.fromBytes(item.bytes, filename: item.fileName));
        }
        mapData['media[]'] = files;
      }

      final formData = FormData.fromMap(mapData);
      final response = await _dio.post('/user/journals', data: formData);

      final data = response.data;
      if (data['success'] == true && data['entry'] != null) {
        return JournalEntryModel.fromJson(data['entry']);
      }
      return null;
    } catch (e) {
      print('[JournalEntryService create error] $e');
      return null;
    }
  }

  Future<JournalEntryModel?> updateEntry({
    required int id,
    required String entryDate,
    String? dream,
    String? destination,
    String? reason,
    String? energy,
    String? amigos,
    String? mindset,
    List<PickedMediaFile>? mediaFiles,
    List<int>? deleteMediaIds,
  }) async {
    try {
      final mapData = <String, dynamic>{
        '_method': 'PUT',
        'entry_date': entryDate,
        if (dream != null) 'dream': dream,
        if (destination != null) 'destination': destination,
        if (reason != null) 'reason': reason,
        if (energy != null) 'energy': energy,
        if (amigos != null) 'amigos': amigos,
        if (mindset != null) 'mindset': mindset,
      };

      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        final files = <MultipartFile>[];
        for (final item in mediaFiles) {
          files.add(MultipartFile.fromBytes(item.bytes, filename: item.fileName));
        }
        mapData['media[]'] = files;
      }

      if (deleteMediaIds != null && deleteMediaIds.isNotEmpty) {
        for (var i = 0; i < deleteMediaIds.length; i++) {
          mapData['delete_media_ids[$i]'] = deleteMediaIds[i];
        }
      }

      final formData = FormData.fromMap(mapData);
      final response = await _dio.post('/user/journals/$id', data: formData);

      final data = response.data;
      if (data['success'] == true && data['entry'] != null) {
        return JournalEntryModel.fromJson(data['entry']);
      }
      return null;
    } catch (e) {
      print('[JournalEntryService update error] $e');
      return null;
    }
  }

  Future<bool> deleteEntry(int id) async {
    try {
      final response = await _dio.delete('/user/journals/$id');
      return response.data['success'] == true;
    } catch (e) {
      print('[JournalEntryService delete error] $e');
      return false;
    }
  }
}
