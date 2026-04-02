import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_constants.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/firestore_instance.dart';
import 'core/services/logger.dart';
import 'core/services/offline_map_service.dart';
import 'core/services/offline_route_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/community_provider.dart';
import 'presentation/providers/language_provider.dart';
import 'presentation/providers/pagoda_provider.dart';
import 'presentation/providers/trip_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _configureDesktopDatabase();

  runApp(const MyApp());
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

Future<_BootstrapResult> _bootstrapApp() async {
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    firebaseReady = true;
    final firestore = FirestoreInstance.instanceOrNull;
    if (firestore != null) {
      firestore.settings = const Settings(persistenceEnabled: true);
    }
    Logger.info(
      'Firestore DB: ${FirestoreInstance.configuredDatabaseId.isEmpty ? '(default)' : FirestoreInstance.configuredDatabaseId}',
    );
  } catch (e, stackTrace) {
    Logger.error('Firebase initialization failed', e, stackTrace);
  }

  return _BootstrapResult(firebaseReady: firebaseReady);
}

class _BootstrapResult {
  const _BootstrapResult({required this.firebaseReady});

  final bool firebaseReady;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppBootstrapShell();
  }
}

class _AppBootstrapShell extends StatefulWidget {
  const _AppBootstrapShell();

  @override
  State<_AppBootstrapShell> createState() => _AppBootstrapShellState();
}

class _AppBootstrapShellState extends State<_AppBootstrapShell> {
  late final Future<_BootstrapResult> _bootstrapFuture;
  bool _backgroundServicesStarted = false;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrapApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapResult>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        final isReady = snapshot.connectionState == ConnectionState.done;
        final result =
            snapshot.data ?? const _BootstrapResult(firebaseReady: false);

        if (isReady && !_backgroundServicesStarted) {
          _backgroundServicesStarted = true;
          unawaited(_startBackgroundServices(result));
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            if (isReady) ChangeNotifierProvider(create: (_) => AuthProvider()),
            if (isReady)
              ChangeNotifierProvider(create: (_) => PagodaProvider()),
            if (isReady) ChangeNotifierProvider(create: (_) => TripProvider()),
            if (isReady)
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
                home: isReady ? const HomeScreen() : const _StartupScreen(),
                routes: isReady
                    ? {
                        '/login': (context) => const LoginScreen(),
                        '/home': (context) => const HomeScreen(),
                      }
                    : const {},
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _startBackgroundServices(_BootstrapResult result) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _initializeBackgroundServices(firebaseReady: result.firebaseReady);
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFCF6), Color(0xFFF4E6BF), Color(0xFFE6C978)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.temple_buddhist_rounded,
                      size: 64,
                      color: Color(0xFFB8860B),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Starting Baganetic',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4C3410),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Preparing app services and offline data...',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6A5630),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
