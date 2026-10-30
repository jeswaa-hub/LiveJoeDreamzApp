class AppNotification {
  final int id;
  final int userId;
  final String title;
  final String message;
  final String type;
  final String? link;
  final bool isRead;
  final String? readAt;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.type = 'info',
    this.link,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      link: json['link'],
      isRead: json['is_read'] == true || json['is_read'] == 1,
      readAt: json['read_at'],
      createdAt: json['created_at'] ?? '',
    );
  }

  AppNotification copyWith({
    bool? isRead,
    String? readAt,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      link: link,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  String get timeAgo {
    try {
      final raw = createdAt.endsWith('Z') ? createdAt : '${createdAt}Z';
      final date = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inSeconds < 0) return 'Just now';
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }
}
