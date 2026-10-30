import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dream_community_app/core/config/api_config.dart';

class CommentService {
  final String baseUrl = ApiConfig.baseUrl;
  final String? token;

  CommentService({this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<List<Map<String, dynamic>>> getComments({
    required String videoType,
    required int videoId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comments?video_type=$videoType&video_id=$videoId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> addComment({
    required String videoType,
    required int videoId,
    required String content,
    int? parentId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comments'),
        headers: _headers,
        body: jsonEncode({
          'video_type': videoType,
          'video_id': videoId,
          'content': content,
          if (parentId != null) 'parent_id': parentId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/comments/$commentId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> toggleLike(int commentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comments/$commentId/like'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> toggleVideoLike({
    required String videoType,
    required int videoId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/video-likes/$videoType/$videoId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkVideoLike({
    required String videoType,
    required int videoId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/video-likes/$videoType/$videoId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
