import 'package:dream_community_app/core/config/api_config.dart';

class BookClubNoteModel {
  final int id;
  final String content;
  final int? timestampSeconds;
  final String? timestampFormatted;
  final String? createdAt;

  BookClubNoteModel({
    required this.id,
    required this.content,
    this.timestampSeconds,
    this.timestampFormatted,
    this.createdAt,
  });

  factory BookClubNoteModel.fromJson(Map<String, dynamic> json) {
    return BookClubNoteModel(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      timestampSeconds: json['timestamp_seconds'],
      timestampFormatted: json['timestamp_formatted'],
      createdAt: json['created_at'],
    );
  }
}

class BookClubMediaModel {
  final int id;
  final String mediaType;
  final String mediaUrl;
  final String? originalName;
  final String? caption;
  final String? createdAt;

  BookClubMediaModel({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    this.originalName,
    this.caption,
    this.createdAt,
  });

  factory BookClubMediaModel.fromJson(Map<String, dynamic> json) {
    return BookClubMediaModel(
      id: json['id'] ?? 0,
      mediaType: json['media_type'] ?? 'image',
      mediaUrl: ApiConfig.resolveUrl(json['media_url']) ?? '',
      originalName: json['original_name'],
      caption: json['caption'],
      createdAt: json['created_at'],
    );
  }
}

class BookClubBookModel {
  final int id;
  final String month;
  final String letter;
  final String pillar;
  final String title;
  final String? subtitle;
  final String author;
  final String? narrator;
  final String? duration;
  final double rating;
  final String? ratingsCount;
  final String? goodreadsRating;
  final String? coverImage;
  final String? audibleUrl;
  final String? purchaseUrl;
  final String? summary;
  final int sortOrder;
  final List<BookClubNoteModel> userNotes;
  final List<BookClubMediaModel> userMedia;

  BookClubBookModel({
    required this.id,
    required this.month,
    required this.letter,
    required this.pillar,
    required this.title,
    this.subtitle,
    required this.author,
    this.narrator,
    this.duration,
    this.rating = 5.0,
    this.ratingsCount,
    this.goodreadsRating,
    this.coverImage,
    this.audibleUrl,
    this.purchaseUrl,
    this.summary,
    this.sortOrder = 0,
    this.userNotes = const [],
    this.userMedia = const [],
  });

  BookClubBookModel copyWith({
    int? id,
    String? month,
    String? letter,
    String? pillar,
    String? title,
    String? subtitle,
    String? author,
    String? narrator,
    String? duration,
    double? rating,
    String? ratingsCount,
    String? goodreadsRating,
    String? coverImage,
    String? audibleUrl,
    String? purchaseUrl,
    String? summary,
    int? sortOrder,
    List<BookClubNoteModel>? userNotes,
    List<BookClubMediaModel>? userMedia,
  }) {
    return BookClubBookModel(
      id: id ?? this.id,
      month: month ?? this.month,
      letter: letter ?? this.letter,
      pillar: pillar ?? this.pillar,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      duration: duration ?? this.duration,
      rating: rating ?? this.rating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      goodreadsRating: goodreadsRating ?? this.goodreadsRating,
      coverImage: coverImage ?? this.coverImage,
      audibleUrl: audibleUrl ?? this.audibleUrl,
      purchaseUrl: purchaseUrl ?? this.purchaseUrl,
      summary: summary ?? this.summary,
      sortOrder: sortOrder ?? this.sortOrder,
      userNotes: userNotes ?? this.userNotes,
      userMedia: userMedia ?? this.userMedia,
    );
  }

  factory BookClubBookModel.fromJson(Map<String, dynamic> json) {
    return BookClubBookModel(
      id: json['id'] ?? 0,
      month: json['month'] ?? '',
      letter: json['letter'] ?? 'D',
      pillar: json['pillar'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      author: json['author'] ?? '',
      narrator: json['narrator'],
      duration: json['duration'],
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 5.0,
      ratingsCount: json['ratings_count'],
      goodreadsRating: json['goodreads_rating'],
      coverImage: ApiConfig.resolveUrl(json['cover_image']),
      audibleUrl: json['audible_url'],
      purchaseUrl: json['purchase_url'],
      summary: json['summary'],
      sortOrder: json['sort_order'] ?? 0,
      userNotes: (json['user_notes'] as List? ?? [])
          .map((n) => BookClubNoteModel.fromJson(n as Map<String, dynamic>))
          .toList(),
      userMedia: (json['user_media'] as List? ?? [])
          .map((m) => BookClubMediaModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
