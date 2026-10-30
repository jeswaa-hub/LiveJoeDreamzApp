class ApiEndpoints {
  // Mobile Auth (Laravel-powered)
  static const String login = '/mobile/auth/login';
  static const String logout = '/mobile/auth/logout';
  static const String user = '/mobile/auth/user';
  static const String forgotPassword = '/mobile/auth/forgot-password';

  // Profile
  static const String profile = '/mobile/auth/profile';
  static const String changePassword = '/mobile/auth/password';
  static const String uploadAvatar = '/mobile/auth/avatar';
  static const String deleteAvatar = '/mobile/auth/avatar';

  // Content
  static const String activities = '/mobile/activities';
  static const String journals = '/mobile/journals';
  static const String podcasts = '/mobile/podcasts';

  // Community
  static const String events = '/mobile/events';

  // Commerce
  static const String merch = '/mobile/merch';
  static const String merchFeatured = '/mobile/merch/featured';

  // Chat
  static const String chatMessages = '/chat/messages';
  static const String chatMembers = '/chat/members';
  static const String chatPresence = '/chat/presence';
  static const String chatPrompts = '/chat/prompts';

  // Newsletter
  static const String newsletterSubscribe = '/newsletter/subscribe';

  // Community Tier
  static const String communityTier = '/tier';
  static const String communityTierCheckEmail = '/tier/check-email';
  static const String journalPassInfo = '/journal-pass/info';

  // Notifications
  static const String notifications = '/notifications';

  // Podcast Guest Application
  static const String podcastApply = '/mobile/podcast/apply';

  // Events RSVP
  static const String eventRsvp = '/events';
  static const String myRsvps = '/events/my-rsvps';

  // Book Club
  static const String bookClub = '/mobile/book-club';
}
