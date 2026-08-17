class AppConstants {
  // App Info
  static const String appName = 'Baganetic';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String pagodas = 'pagodas';
  static const String users = 'users';
  static const String trips = 'trips';
  static const String favorites = 'favorites';
  static const String feedbacks = 'feedbacks';
  static const String roadReports = 'roadReports';
  static const String aiChatMessages = 'aiChatMessages';
  static const String communityPosts = 'communityPosts';
  static const String communityComments = 'comments';
  static const String communityPostVotes = 'votes';
  static const String pagodaStatusActive = 'active';
  static const String pagodaStatusArchived = 'archived';

  // Database
  static const String dbName = 'baganetic.db';
  static const int dbVersion = 14;
  static const String guestOwnerId = '__guest__';

  // Tables
  static const String tablePagodas = 'pagodas';
  static const String tableTrips = 'trips';
  static const String tableTripStops = 'trip_stops';
  static const String tableFavorites = 'favorites';
  static const String tableFeedbacks = 'feedbacks';
  static const String tableCommunityPosts = 'community_posts';
  static const String tableCommunityComments = 'community_comments';
  static const String tableCommunityPostVotes = 'community_post_votes';
  static const String tableAiChatMessagesLocal = 'ai_chat_messages_local';

  // Map
  static const double baganLatitude = 21.1717;
  static const double baganLongitude = 94.8589;
  static const double defaultZoom = 13.0;
  static const String mapTileStore = 'baganetic_map_store';
  static const String mapTileUrlTemplate =
      'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
  static const String mapFallbackTileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const List<String> mapTileSubdomains = ['a', 'b', 'c'];
  static const String mapTileUserAgent = 'com.baganetic.baganetic_mobile';

  // Offline routing graph
  static const String offlineGraphUrl = '';
  static const Duration offlineGraphSyncInterval = Duration(hours: 24);

  // Pagoda Categories
  static const String allCategory = 'All';
  static const List<String> categories = [allCategory, 'Temple', 'Pagoda'];

  // Assets
  static const String placeholderImage = 'assets/images/placeholder.png';
  static const String logoImage = 'assets/images/logo.png';
}
