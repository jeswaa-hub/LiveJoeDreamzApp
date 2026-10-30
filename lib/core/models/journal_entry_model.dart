import 'package:dream_community_app/core/config/api_config.dart';

class JournalEntryMediaModel {
  final int id;
  final String fileName;
  final String fileUrl;
  final String? fileType;

  JournalEntryMediaModel({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.fileType,
  });

  factory JournalEntryMediaModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryMediaModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      fileName: json['file_name'] ?? '',
      fileUrl: ApiConfig.resolveUrl(json['file_url']) ?? '',
      fileType: json['file_type'],
    );
  }
}

class JournalEntryModel {
  final int id;
  final String userId;
  final bool? _isFavorite;
  bool get isFavorite => _isFavorite == true;
  final String entryDate;
  final String? dream;
  final String? destination;
  final String? reason;
  final String? energy;
  final String? amigos;
  final String? mindset;
  final List<JournalEntryMediaModel> media;
  final String? createdAt;

  JournalEntryModel({
    required this.id,
    required this.userId,
    bool isFavorite = false,
    required this.entryDate,
    this.dream,
    this.destination,
    this.reason,
    this.energy,
    this.amigos,
    this.mindset,
    this.media = const [],
    this.createdAt,
  }) : _isFavorite = isFavorite;

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    var mediaList = <JournalEntryMediaModel>[];
    if (json['media'] != null && json['media'] is List) {
      mediaList = (json['media'] as List)
          .map((m) => JournalEntryMediaModel.fromJson(m))
          .toList();
    }

    return JournalEntryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id']?.toString() ?? '',
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1 || json['is_favorite'] == '1',
      entryDate: json['entry_date'] ?? '',
      dream: json['dream'],
      destination: json['destination'],
      reason: json['reason'],
      energy: json['energy'],
      amigos: json['amigos'],
      mindset: json['mindset'],
      media: mediaList,
      createdAt: json['created_at'],
    );
  }

  JournalEntryModel copyWith({
    bool? isFavorite,
  }) {
    return JournalEntryModel(
      id: id,
      userId: userId,
      isFavorite: isFavorite ?? this.isFavorite,
      entryDate: entryDate,
      dream: dream,
      destination: destination,
      reason: reason,
      energy: energy,
      amigos: amigos,
      mindset: mindset,
      media: media,
      createdAt: createdAt,
    );
  }

  String get displayTitle =>
      (dream != null && dream!.isNotEmpty) ? dream! : 'Journal Entry - $entryDate';
}
