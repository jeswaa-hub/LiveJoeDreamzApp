import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/models/chat_message_model.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/core/models/book_club_prompt_model.dart';

class ChatService {
  final Dio _dio = DioClient().dio;

  Future<List<ChatMessageModel>> getMessages({int? bookId, String? pillar}) async {
    try {
      final queryParams = <String, dynamic>{
        '_t': DateTime.now().millisecondsSinceEpoch,
      };
      if (bookId != null) queryParams['book_id'] = bookId;
      if (pillar != null && pillar.isNotEmpty && pillar != 'ALL') {
        queryParams['pillar'] = pillar;
      }

      final response = await _dio.get(
        ApiEndpoints.chatMessages,
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        ),
      );
      final raw = response.data;
      final list = raw is Map ? (raw['messages'] ?? raw['data'] ?? raw['value'] ?? []) : raw;
      if (list is List) {
        return list.map((j) => ChatMessageModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      if (list is Map) {
        return list.values
            .whereType<Map>()
            .map((j) => ChatMessageModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<ChatMessageModel?> sendMessage(
    String content, {
    String? parentId,
    List<String>? mentions,
    int? bookClubBookId,
    String? promptTag,
  }) async {
    try {
      final data = <String, dynamic>{'content': content};
      if (parentId != null) data['parent_id'] = parentId;
      if (mentions != null && mentions.isNotEmpty) data['mentions'] = mentions;
      if (bookClubBookId != null) data['book_club_book_id'] = bookClubBookId;
      if (promptTag != null && promptTag.isNotEmpty) data['prompt_tag'] = promptTag;

      final response = await _dio.post(ApiEndpoints.chatMessages, data: data);
      return ChatMessageModel.fromJson(response.data['message']);
    } on DioException {
      return null;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      await _dio.delete('${ApiEndpoints.chatMessages}/$messageId');
      return true;
    } on DioException {
      return false;
    }
  }

  Future<List<UserModel>> getMembers() async {
    try {
      final response = await _dio.get(ApiEndpoints.chatMembers);
      final raw = response.data;
      final list = raw is Map ? (raw['members'] ?? raw['data'] ?? raw['value'] ?? []) : raw;
      if (list is List) {
        return list.map((j) => UserModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> sendPresence() async {
    try {
      await _dio.post(ApiEndpoints.chatPresence);
    } catch (_) {}
  }

  Future<List<BookClubPromptModel>> getPrompts({int? bookId}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.chatPrompts,
        queryParameters: bookId != null ? {'book_id': bookId} : null,
      );
      final raw = response.data;
      final list = raw is Map ? (raw['prompts'] ?? raw['data'] ?? []) : raw;
      if (list is List && list.isNotEmpty) {
        return list.map((j) => BookClubPromptModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return BookClubPromptModel.defaultPrompts;
    } catch (_) {
      return BookClubPromptModel.defaultPrompts;
    }
  }
}
