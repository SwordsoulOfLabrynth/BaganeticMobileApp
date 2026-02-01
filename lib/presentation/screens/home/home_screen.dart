import 'package:flutter/material.dart';
import 'home_content_screen.dart';
import '../pagodas/pagodas_list_screen.dart';
import '../discovery/discovery_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../../../core/localization/app_localizations.dart';

import '../../../data/models/pagoda_model.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final Pagoda? initialMapPagoda;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
    this.initialMapPagoda,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onNavigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    final index = widget.initialIndex;
    final maxIndex = _screens.length - 1;
    _currentIndex = index < 0 ? 0 : (index > maxIndex ? maxIndex : index);
  }

  List<Widget> get _screens => [
    HomeContentScreen(onNavigateToTab: _onNavigateToTab),
    const PagodasListScreen(),
    const DiscoveryScreen(),
    MapScreen(initialPagoda: widget.initialMapPagoda),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD4AF37),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: l10n.translate('nav.home'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.temple_buddhist),
            label: l10n.translate('nav.pagodas'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: l10n.translate('nav.discovery'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: l10n.translate('nav.mapTrips'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: l10n.translate('nav.profile'),
          ),
        ],
      ),
    );
  }
}
