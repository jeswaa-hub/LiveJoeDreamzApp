import 'package:dream_community_app/core/config/api_config.dart';

class PodcastModel {
  final int id;
  final String title;
  final String slug;
  final String? description;
  final int? episodeNumber;
  final int? seasonNumber;
  final int? durationSeconds;
  final String? audioUrl;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? guestName;
  final String? guestTitle;
  final List<String>? tags;
  final String status;
  final String? publishedAt;
  final String? createdAt;

  PodcastModel({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.episodeNumber,
    this.seasonNumber,
    this.durationSeconds,
    this.audioUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.guestName,
    this.guestTitle,
    this.tags,
    this.status = 'draft',
    this.publishedAt,
    this.createdAt,
  });

  factory PodcastModel.fromJson(Map<String, dynamic> json) {
    return PodcastModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      episodeNumber: json['episode_number'],
      seasonNumber: json['season_number'],
      durationSeconds: json['duration_seconds'],
      audioUrl: _resolveUrl(json['audio_url']),
      videoUrl: _resolveUrl(json['video_url']),
      thumbnailUrl: _resolveUrl(json['thumbnail_url']),
      guestName: json['guest_name'],
      guestTitle: json['guest_title'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      status: json['status'] ?? 'draft',
      publishedAt: json['published_at'],
      createdAt: json['created_at'],
    );
  }

  static String? _resolveUrl(String? path) => ApiConfig.resolveUrl(path);

  String get durationFormatted {
    if (durationSeconds == null) return '';
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get seasonEpisode {
    if (seasonNumber != null && episodeNumber != null) {
      return 'S$seasonNumber E$episodeNumber';
    }
    if (episodeNumber != null) return 'E$episodeNumber';
    return '';
  }
}
