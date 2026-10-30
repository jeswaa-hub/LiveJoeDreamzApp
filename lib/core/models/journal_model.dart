import 'package:dream_community_app/core/config/api_config.dart';

class JournalModel {
  final int id;
  final String title;
  final String? description;
  final String? videoUrl;
  final String? thumbnail;
  final String status;
  final int sortOrder;
  final String? createdAt;

  JournalModel({
    required this.id,
    required this.title,
    this.description,
    this.videoUrl,
    this.thumbnail,
    this.status = 'published',
    this.sortOrder = 0,
    this.createdAt,
  });

  factory JournalModel.fromJson(Map<String, dynamic> json) {
    return JournalModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      videoUrl: _resolveUrl(json['video_url']),
      thumbnail: _resolveUrl(json['thumbnail']),
      status: json['status'] ?? 'published',
      sortOrder: json['sort_order'] ?? 0,
      createdAt: json['created_at'],
    );
  }

  static String? _resolveUrl(String? path) => ApiConfig.resolveUrl(path);
}
