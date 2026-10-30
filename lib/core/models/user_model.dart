import 'package:dream_community_app/core/config/api_config.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? username;
  final String role;
  final String? dreamRole;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final String? website;
  final String? phone;
  final List<String>? interests;
  final int badgePoints;
  final bool showInDirectory;
  final String? tier;
  final bool hasAdminAccess;
  final bool hasJournalAccess;
  final bool isFreeTier;
  final bool hasCommunityAccess;
  final bool hasPodcastAccess;
  final bool hasActivitiesAccess;
  final bool hasJournalVideosAccess;
  final bool hasChatAccess;
  final bool hasEventsAccess;
  final bool hasMerchAccess;
  final bool hasBookClubAccess;
  final List<String> allowedRoutes;
  final int? createdAt;
  final bool isOnline;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    required this.role,
    this.dreamRole,
    this.avatarUrl,
    this.bio,
    this.location,
    this.website,
    this.phone,
    this.interests,
    this.badgePoints = 0,
    this.showInDirectory = true,
    this.tier,
    this.hasAdminAccess = false,
    this.hasJournalAccess = false,
    this.isFreeTier = true,
    this.hasCommunityAccess = false,
    this.hasPodcastAccess = false,
    this.hasActivitiesAccess = false,
    this.hasJournalVideosAccess = false,
    this.hasChatAccess = false,
    this.hasEventsAccess = false,
    this.hasMerchAccess = false,
    this.hasBookClubAccess = false,
    this.allowedRoutes = const [],
    this.createdAt,
    this.isOnline = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawTier = (json['tier'] ?? '').toString().toLowerCase();
    final role = (json['role'] ?? '').toString().toLowerCase();
    final isAdmin = role == 'admin' || role == 'super_admin' || json['has_admin_access'] == true || json['hasAdminAccess'] == true;
    final isTierMember = rawTier.isNotEmpty && rawTier != 'free' && rawTier != 'guest';
    // Journal tier does NOT grant community access
    final isNonJournalTier = isTierMember && rawTier != 'journal';

    final allowedRoutes = json['allowed_routes'] != null
        ? List<String>.from(json['allowed_routes'])
        : (json['allowedRoutes'] != null ? List<String>.from(json['allowedRoutes']) : <String>[]);

    final communityAccess = isAdmin ||
        json['has_community_access'] == true ||
        json['hasCommunityAccess'] == true ||
        isNonJournalTier ||
        rawTier == 'community' ||
        allowedRoutes.contains('community');

    // Podcast is 100% Free for everyone on the platform - NEVER locked!
    const podcastAccess = true;

    final activitiesAccess = isAdmin ||
        communityAccess ||
        isNonJournalTier ||
        json['has_activities_access'] == true ||
        json['hasActivitiesAccess'] == true ||
        allowedRoutes.contains('guest.dream-activities') ||
        allowedRoutes.contains('guest.dream-activity') ||
        allowedRoutes.contains('submit.assignment');

    final journalVideosAccess = isAdmin ||
        communityAccess ||
        isNonJournalTier ||
        json['has_journal_videos_access'] == true ||
        json['hasJournalVideosAccess'] == true ||
        allowedRoutes.contains('guest.journal-videos') ||
        allowedRoutes.contains('guest.journal-video');

    final journalAccess = isAdmin ||
        communityAccess ||
        isTierMember ||
        json['has_journal_access'] == true ||
        json['hasJournalAccess'] == true ||
        allowedRoutes.contains('guest.journal-entries');

    final chatAccess = isAdmin ||
        communityAccess ||
        isNonJournalTier ||
        json['has_chat_access'] == true ||
        json['hasChatAccess'] == true ||
        allowedRoutes.contains('guest.chat') ||
        allowedRoutes.contains('community');

    final eventsAccess = true;
    final merchAccess = true;

    final bookClubAccess = isAdmin ||
        communityAccess ||
        isNonJournalTier ||
        json['has_book_club_access'] == true ||
        json['hasBookClubAccess'] == true ||
        allowedRoutes.contains('guest.book-club');

    final freeTier = !isTierMember && !isAdmin && !communityAccess;

    return UserModel(
      id: json['id']?.toString() ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'],
      role: json['role'] ?? 'guest',
      dreamRole: json['dreamRole'] ?? json['dream_role'],
      avatarUrl: ApiConfig.resolveUrl(json['avatarUrl'] ?? json['avatar_url']),
      bio: json['bio'],
      location: json['location'],
      website: json['website'],
      phone: json['phone'],
      interests: json['interests'] != null
          ? List<String>.from(json['interests'])
          : null,
      badgePoints: json['badgePoints'] ?? json['badge_points'] ?? 0,
      showInDirectory: json['showInDirectory'] == true ||
          json['show_in_directory'] == true ||
          json['show_in_directory'] == 1,
      tier: json['tier'],
      hasAdminAccess: isAdmin,
      hasJournalAccess: journalAccess,
      isFreeTier: freeTier,
      hasCommunityAccess: communityAccess,
      hasPodcastAccess: podcastAccess,
      hasActivitiesAccess: activitiesAccess,
      hasJournalVideosAccess: journalVideosAccess,
      hasChatAccess: chatAccess,
      hasEventsAccess: eventsAccess,
      hasMerchAccess: merchAccess,
      hasBookClubAccess: bookClubAccess,
      allowedRoutes: allowedRoutes,
      createdAt: json['createdAt'] ?? json['created_at'],
      isOnline: json['isOnline'] == true || json['is_online'] == true,
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get displayName => name;

  String? get resolvedAvatarUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    if (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://')) return avatarUrl;
    final encoded = avatarUrl!.split('/').map(Uri.encodeComponent).join('/');
    return '${ApiConfig.assetUrl}/$encoded';
  }

  bool get isTierMember => hasCommunityAccess || (!isFreeTier && tier != null && tier != 'free' && tier != 'guest' && tier!.isNotEmpty);
}
