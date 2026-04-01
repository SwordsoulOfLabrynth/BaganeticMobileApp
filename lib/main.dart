import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/community_provider.dart';
import 'presentation/providers/language_provider.dart';
import 'presentation/providers/pagoda_provider.dart';
import 'presentation/providers/trip_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'core/services/offline_map_service.dart';
import 'core/services/offline_route_service.dart';
import 'core/services/logger.dart';
import 'core/services/firestore_instance.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureDesktopDatabase();

  // Initialize Firebase
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    firebaseReady = true;
    FirestoreInstance.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    Logger.info(
      'Firestore DB: ${FirestoreInstance.configuredDatabaseId.isEmpty ? '(default)' : FirestoreInstance.configuredDatabaseId}',
    );
  } catch (e) {
    Logger.error('Firebase initialization failed', e);
  }

  runApp(const MyApp());

  unawaited(_initializeBackgroundServices(firebaseReady: firebaseReady));
}

void _configureDesktopDatabase() {
  if (kIsWeb) return;
  try {
    final target = defaultTargetPlatform;
    if (target == TargetPlatform.windows || target == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } catch (e) {
    Logger.error('Failed to configure desktop database', e);
  }
}

Future<void> _initializeBackgroundServices({
  required bool firebaseReady,
}) async {
  if (!firebaseReady) {
    Logger.info(
      'Skipping Firestore-dependent background work (Firebase not ready)',
    );
  }

  try {
    await FMTCObjectBoxBackend().initialise();
    const store = FMTCStore(AppConstants.mapTileStore);
    if (!await store.manage.ready) {
      await store.manage.create();
    }
    unawaited(OfflineMapService.instance.startBackgroundPrefetch());
  } catch (e) {
    Logger.error('Map tile caching initialization failed', e);
  }

  unawaited(OfflineRouteService.instance.startBackgroundSync());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PagodaProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return MaterialApp(
            onGenerateTitle: (context) =>
                AppLocalizations.of(context).translate('app.title'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            locale: languageProvider.locale,
            supportedLocales: const [Locale('en'), Locale('my')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale == null) {
                return supportedLocales.first;
              }
              for (final supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode) {
                  return supportedLocale;
                }
              }
              return supportedLocales.first;
            },
            home: const HomeScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
