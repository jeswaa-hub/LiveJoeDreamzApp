import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/models/book_club_model.dart';

class BookClubService {
  final Dio _dio = DioClient().dio;

  Future<List<BookClubBookModel>> getBooks() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.bookClub,
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch},
        options: Options(
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ),
      );
      final raw = response.data;
      final list = raw is Map ? (raw['books'] ?? raw['data'] ?? []) : raw;
      if (list is List) {
        return list.map((j) => BookClubBookModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<BookClubNoteModel?> saveNote(int bookId, String content, {String? timestampFormatted}) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.bookClub}/$bookId/notes',
        data: {
          'content': content,
          if (timestampFormatted != null) 'timestamp_formatted': timestampFormatted,
        },
      );
      if (response.data != null && response.data['note'] != null) {
        return BookClubNoteModel.fromJson(response.data['note']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteNote(int bookId, int noteId) async {
    try {
      await _dio.delete('${ApiEndpoints.bookClub}/$bookId/notes/$noteId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<BookClubMediaModel?> uploadMedia(int bookId, String filePath, {String? caption}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      });
      final response = await _dio.post(
        '${ApiEndpoints.bookClub}/$bookId/media',
        data: formData,
      );
      if (response.data != null && response.data['media'] != null) {
        return BookClubMediaModel.fromJson(response.data['media']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteMedia(int bookId, int mediaId) async {
    try {
      await _dio.delete('${ApiEndpoints.bookClub}/$bookId/media/$mediaId');
      return true;
    } catch (_) {
      return false;
    }
  }
}
