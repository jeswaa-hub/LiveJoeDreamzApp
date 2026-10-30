class EventModel {
  final int id;
  final String title;
  final String? description;
  final String activityType;
  final String? location;
  final bool isVirtual;
  final String? virtualLink;
  final String? startsAt;
  final String? endsAt;
  final int? maxParticipants;
  final int currentParticipants;
  final String status;
  final int rsvpCount;
  final String? createdAt;

  EventModel({
    required this.id,
    required this.title,
    this.description,
    this.activityType = 'event',
    this.location,
    this.isVirtual = false,
    this.virtualLink,
    this.startsAt,
    this.endsAt,
    this.maxParticipants,
    this.currentParticipants = 0,
    this.status = 'upcoming',
    this.rsvpCount = 0,
    this.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      activityType: json['activity_type'] ?? 'event',
      location: json['location'],
      isVirtual: json['is_virtual'] == true || json['is_virtual'] == 1,
      virtualLink: json['virtual_link'],
      startsAt: json['starts_at'],
      endsAt: json['ends_at'],
      maxParticipants: json['max_participants'],
      currentParticipants: json['current_participants'] ?? 0,
      status: json['status'] ?? 'upcoming',
      rsvpCount: json['rsvp_count'] ?? 0,
      createdAt: json['created_at'],
    );
  }

  String get dateFormatted {
    if (startsAt == null) return '';
    final raw = startsAt!.endsWith('Z') ? startsAt! : '${startsAt!}Z';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[dt.weekday % 7]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String get timeFormatted {
    if (startsAt == null) return '';
    final rawStart = startsAt!.endsWith('Z') ? startsAt! : '${startsAt!}Z';
    final start = DateTime.tryParse(rawStart)?.toLocal();
    final rawEnd = endsAt != null ? (endsAt!.endsWith('Z') ? endsAt! : '${endsAt!}Z') : null;
    final end = rawEnd != null ? DateTime.tryParse(rawEnd)?.toLocal() : null;
    if (start == null) return '';
    final s = '${start.hour > 12 ? start.hour - 12 : start.hour}:${start.minute.toString().padLeft(2, '0')} ${start.hour >= 12 ? 'PM' : 'AM'}';
    if (end == null) return s;
    final e = '${end.hour > 12 ? end.hour - 12 : end.hour}:${end.minute.toString().padLeft(2, '0')} ${end.hour >= 12 ? 'PM' : 'AM'}';
    return '$s — $e';
  }

  String get participantsFormatted {
    if (maxParticipants != null) return '$currentParticipants / $maxParticipants';
    return '$currentParticipants';
  }
}
