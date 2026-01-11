import 'package:flutter/material.dart';
import 'home_content_screen.dart';
import '../pagodas/pagodas_list_screen.dart';
import '../map/map_screen.dart';
import '../trips/trips_screen.dart';
import '../profile/profile_screen.dart';

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
    _currentIndex = index < 0 ? 0 : (index > 4 ? 4 : index);
  }

  List<Widget> get _screens => [
    HomeContentScreen(onNavigateToTab: _onNavigateToTab),
    const PagodasListScreen(),
    MapScreen(initialPagoda: widget.initialMapPagoda),
    const TripsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.temple_buddhist),
            label: 'Pagodas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
