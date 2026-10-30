class ChatMessageModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String? userRole;
  final String content;
  final String? parentId;
  final String? parentContent;
  final String? parentUserId;
  final String? parentUserName;
  final int? bookClubBookId;
  final String? bookTitle;
  final String? bookLetter;
  final String? bookPillar;
  final String? promptTag;
  final bool isPinned;
  final bool isEdited;
  final bool isDeleted;
  final List<String>? mentions;
  final DateTime? createdAt;

  ChatMessageModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatar,
    this.userRole,
    required this.content,
    this.parentId,
    this.parentContent,
    this.parentUserId,
    this.parentUserName,
    this.bookClubBookId,
    this.bookTitle,
    this.bookLetter,
    this.bookPillar,
    this.promptTag,
    this.isPinned = false,
    this.isEdited = false,
    this.isDeleted = false,
    this.mentions,
    this.createdAt,
  });

  static String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

  static String? _strNull(dynamic v) {
    if (v == null) return null;
    return v.toString();
  }

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final raw = v.endsWith('Z') ? v : '${v}Z';
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    String msgId = _str(json['id']);
    String userId = '';
    String? userName;
    String? userAvatar;
    String? userRole;

    if (json['user'] is Map) {
      final u = json['user'];
      userId = _str(u['id']);
      userName = _strNull(u['name']);
      userAvatar = _strNull(u['avatar_url']);
      userRole = _strNull(u['role']);
    } else {
      userId = _str(json['user_id']);
      userName = _strNull(json['user_name']);
      userAvatar = _strNull(json['user_avatar']);
      userRole = _strNull(json['user_role']);
    }

    String? bookTitle;
    String? bookLetter;
    String? bookPillar;
    if (json['book'] is Map) {
      final b = json['book'];
      bookTitle = _strNull(b['title']);
      bookLetter = _strNull(b['letter']);
      bookPillar = _strNull(b['pillar']);
    }

    int? bookId;
    if (json['book_club_book_id'] != null) {
      bookId = int.tryParse(json['book_club_book_id'].toString());
    }

    return ChatMessageModel(
      id: msgId,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      userRole: userRole,
      content: _str(json['content']),
      parentId: _strNull(json['parent_id']),
      parentContent: json['parent'] is Map ? _str(json['parent']['content']) : _strNull(json['parent_content']),
      parentUserId: json['parent'] is Map ? _str(json['parent']['user_id']) : _strNull(json['parent_user_id']),
      parentUserName: json['parent'] is Map ? _str(json['parent']['user_name']) : _strNull(json['parent_user_name']),
      bookClubBookId: bookId,
      bookTitle: bookTitle,
      bookLetter: bookLetter,
      bookPillar: bookPillar,
      promptTag: _strNull(json['prompt_tag']),
      isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
      isEdited: json['is_edited'] == true || json['isEdited'] == true,
      isDeleted: json['is_deleted'] == true || json['isDeleted'] == true || (json['deleted_at'] != null && json['deleted_at'].toString().isNotEmpty),
      mentions: json['mentions'] is List
          ? (json['mentions'] as List).map((e) => _str(e)).toList()
          : null,
      createdAt: _date(json['created_at'] ?? json['createdAt']),
    );
  }

  String get timeFormatted {
    if (createdAt == null) return '';
    final dt = createdAt!.toLocal();
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  bool get isSuperAdmin => userRole == 'super_admin' || userRole == 'admin';

  String get initials {
    if (userName == null || userName!.isEmpty) return '?';
    final parts = userName!.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return userName![0].toUpperCase();
  }
}
