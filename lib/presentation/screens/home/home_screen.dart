import 'package:flutter/material.dart';
import '../../../core/services/ai_chatbot_service.dart';
import '../../../core/utils/ai_assistant_launcher.dart';
import 'home_content_screen.dart';
import '../pagodas/pagodas_list_screen.dart';
import '../map/map_screen.dart';
import '../community/community_feed_screen.dart';
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
  late List<Widget> _screens;

  void _onNavigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _screens = _buildScreens();
    final index = widget.initialIndex;
    final maxIndex = _screens.length - 1;
    _currentIndex = index < 0 ? 0 : (index > maxIndex ? maxIndex : index);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMapPagoda?.id != widget.initialMapPagoda?.id) {
      _screens = _buildScreens();
    }
  }

  List<Widget> _buildScreens() => [
    HomeContentScreen(onNavigateToTab: _onNavigateToTab), // 0
    const PagodasListScreen(), // 1
    MapScreen(initialPagoda: widget.initialMapPagoda), // 2
    const CommunityFeedScreen(), // 3
    const ProfileScreen(), // 4
  ];

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openChat(BuildContext context) async {
    await AIAssistantLauncher.open(
      context,
      entryContext: const AIEntryContext.global(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Navigation order: Home, Pagodas, Map, Community, Profile
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
        icon: Icons.forum_outlined,
        label: l10n.translate('nav.community'),
        index: 3,
      ),
      NavigationItem(
        icon: Icons.person,
        label: l10n.translate('nav.profile'),
        index: 4,
      ),
    ];

    if (Responsive.isTabletOrLarger(context)) {
      return _buildWideLayout(context, navigationItems);
    }

    return _buildMobileLayout(context, navigationItems);
  }

  Widget _buildWideLayout(
    BuildContext context,
    List<NavigationItem> navigationItems,
  ) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openChat(context),
        icon: const Icon(Icons.support_agent_outlined),
        label: Text(context.l10n.translate('chat.fabLabel')),
      ),
      body: Row(
        children: [
          AdaptiveNavigation(
            currentIndex: _currentIndex,
            onNavigate: _onTabSelected,
            items: navigationItems,
          ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
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
        icon: const Icon(Icons.support_agent_outlined),
        label: Text(context.l10n.translate('chat.fabLabel')),
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
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
