import 'package:flutter/material.dart';
import 'home_content_screen.dart';
import '../chat/chat_screen.dart';
import '../pagodas/pagodas_list_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
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
    MapScreen(initialPagoda: widget.initialMapPagoda), // 2
    const ProfileScreen(), // 3
  ];

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openChat(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Navigation order: Home, Pagodas, Map, Profile
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
        icon: Icons.map_outlined,
        label: l10n.translate('nav.mapTrips'),
        index: 2,
      ),
      NavigationItem(
        icon: Icons.person,
        label: l10n.translate('nav.profile'),
        index: 3,
      ),
    ];

    if (Responsive.isDesktopOrLarger(context)) {
      return _buildDesktopLayout(context, navigationItems);
    } else {
      return _buildMobileLayout(context, navigationItems);
    }
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List<NavigationItem> navigationItems,
  ) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openChat(context),
        icon: const Icon(Icons.auto_awesome),
        label: Text(context.l10n.translate('chat.fabLabel')),
      ),
      body: Row(
        children: [
          AdaptiveNavigation(
            currentIndex: _currentIndex,
            onNavigate: _onTabSelected,
            items: navigationItems,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<NavigationItem> navigationItems,
  ) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openChat(context),
        icon: const Icon(Icons.auto_awesome),
        label: Text(context.l10n.translate('chat.fabLabel')),
      ),
      body: Stack(fit: StackFit.expand, children: [_screens[_currentIndex]]),
      bottomNavigationBar: _buildMobileBottomNavigationBar(
        context,
        navigationItems,
      ),
    );
  }

  Widget _buildMobileBottomNavigationBar(
    BuildContext context,
    List<NavigationItem> navigationItems,
  ) {
    return AdaptiveNavigation(
      currentIndex: _currentIndex,
      onNavigate: _onTabSelected,
      items: navigationItems,
    );
  }
}
