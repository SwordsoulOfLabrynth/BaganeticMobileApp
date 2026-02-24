class AppConstants {
  // App Info
  static const String appName = 'Baganetic';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String pagodas = 'pagodas';
  static const String users = 'users';
  static const String trips = 'trips';
  static const String favorites = 'favorites';

  // Database
  static const String dbName = 'baganetic.db';
  static const int dbVersion = 9;
  static const String guestOwnerId = '__guest__';

  // Tables
  static const String tablePagodas = 'pagodas';
  static const String tableTrips = 'trips';
  static const String tableTripStops = 'trip_stops';
  static const String tableFavorites = 'favorites';

  // Map
  static const double baganLatitude = 21.1717;
  static const double baganLongitude = 94.8589;
  static const double defaultZoom = 13.0;
  static const String mapTileStore = 'baganetic_map_store';
  static const String mapTileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Offline routing graph
  static const String offlineGraphUrl = '';
  static const Duration offlineGraphSyncInterval = Duration(hours: 24);

  // Pagoda Categories
  static const List<String> categories = [
    'All',
    'Temple',
    'Pagoda',
    'Stupa',
    'Monastery',
  ];

  // Assets
  static const String placeholderImage = 'assets/images/placeholder.png';
  static const String logoImage = 'assets/images/logo.png';
}
