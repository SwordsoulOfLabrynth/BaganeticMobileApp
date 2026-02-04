import 'package:flutter/material.dart';
import 'home_content_screen.dart';
import '../pagodas/pagodas_list_screen.dart';
import '../discovery/discovery_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/responsive.dart';
import '../../widgets/adaptive_navigation.dart';

import '../../../data/models/pagoda_model.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final Pagoda? initialMapPagoda;

  const HomeScreen({super.key, this.initialIndex = 0, this.initialMapPagoda});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isNavPopupOpen = false;

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
    HomeContentScreen(onNavigateToTab: _onNavigateToTab), // 0
    const PagodasListScreen(), // 1
    const DiscoveryScreen(), // 2 - accessed via popup menu
    const ChatScreen(), // 3 - accessed via popup menu
    MapScreen(initialPagoda: widget.initialMapPagoda), // 4
    const ProfileScreen(), // 5
  ];

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavPopupStateChanged(bool isOpen) {
    if (_isNavPopupOpen == isOpen) return;
    setState(() {
      _isNavPopupOpen = isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    
    // Navigation order: Home, Pagoda, Chat (popup menu), Map, Profile
    final navigationItems = [
      NavigationItem(
        icon: Icons.home,
        label: l10n.translate('nav.home'),
        index: 0,
      ),
      NavigationItem(
        icon: Icons.temple_buddhist,
        label: l10n.translate('nav.pagodas'),
        index: 1,
      ),
      NavigationItem(
        icon: Icons.apps_rounded,
        label: '', // No label for popup menu
        index: 2, // This will be a popup menu for Chat and Discovery
      ),
      NavigationItem(
        icon: Icons.map_outlined,
        label: l10n.translate('nav.mapTrips'),
        index: 4, // Map is at index 4 in screens array
      ),
      NavigationItem(
        icon: Icons.person,
        label: l10n.translate('nav.profile'),
        index: 5, // Profile is at index 5 in screens array
      ),
    ];

    if (Responsive.isDesktopOrLarger(context)) {
      return _buildDesktopLayout(context, navigationItems);
    } else {
      return _buildMobileLayout(context, navigationItems);
    }
  }

  Widget _buildDesktopLayout(BuildContext context, List<NavigationItem> navigationItems) {
    return Scaffold(
      body: Row(
        children: [
          AdaptiveNavigation(
            currentIndex: _currentIndex,
            onNavigate: _onTabSelected,
            items: navigationItems,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _screens[_currentIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, List<NavigationItem> navigationItems) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _screens[_currentIndex],
          if (_isNavPopupOpen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              color: const Color(0x55000000),
            ),
        ],
      ),
      bottomNavigationBar: _buildMobileBottomNavigationBar(context, navigationItems),
    );
  }

  Widget _buildMobileBottomNavigationBar(BuildContext context, List<NavigationItem> navigationItems) {
    return AdaptiveNavigation(
      currentIndex: _currentIndex,
      onNavigate: _onTabSelected,
      items: navigationItems,
      onPopupMenuStateChanged: _onNavPopupStateChanged,
    );
  }
}
