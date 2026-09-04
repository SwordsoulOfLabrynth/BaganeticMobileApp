import 'package:flutter/material.dart';
import '../../../core/services/ai_chatbot_service.dart';
import '../../../core/utils/ai_assistant_launcher.dart';
import 'home_content_screen.dart';
import '../discover/discover_screen.dart';
import '../map/map_screen.dart';
import '../community/community_feed_screen.dart';
import '../chat/chat_screen.dart';
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
  bool _isChatOpen = false;
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
    const DiscoverScreen(), // 1
    MapScreen(initialPagoda: widget.initialMapPagoda), // 2
    const CommunityFeedScreen(), // 3
    ProfileScreen(onBack: () => _onNavigateToTab(0)), // 4
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

    // Navigation order: Home, Discover, Map, Community (Profile = avatar in app bar)
    final navigationItems = [
      NavigationItem(
        icon: Icons.home,
        label: l10n.translate('nav.home'),
        index: 0,
      ),
      NavigationItem(
        icon: Icons.temple_buddhist,
        label: l10n.translate('nav.discover'),
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          IgnorePointer(
            ignoring: !_isChatOpen,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              offset: _isChatOpen ? Offset.zero : const Offset(0, 1),
              child: ChatScreen(embedded: true, onClose: _toggleMobileChat),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _StitchBottomNavigation(
        currentIndex: _currentIndex,
        onNavigate: _onTabSelected,
        onChat: _toggleMobileChat,
      ),
    );
  }

  void _toggleMobileChat() {
    setState(() => _isChatOpen = !_isChatOpen);
  }
}

class _StitchBottomNavigation extends StatelessWidget {
  const _StitchBottomNavigation({
    required this.currentIndex,
    required this.onNavigate,
    required this.onChat,
  });

  final int currentIndex;
  final ValueChanged<int> onNavigate;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = <(IconData, String, int)>[
      (Icons.home_outlined, l10n.translate('nav.home'), 0),
      (Icons.explore_outlined, l10n.translate('nav.discover'), 1),
      (Icons.map_outlined, l10n.translate('nav.map'), 2),
      (Icons.forum_outlined, l10n.translate('nav.community'), 3),
    ];
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              color: const Color(0xFF2B1D14),
              child: Row(
                children: [
                  _StitchNavItem(
                    item: items[0],
                    selected: currentIndex == 0,
                    onTap: onNavigate,
                  ),
                  _StitchNavItem(
                    item: items[1],
                    selected: currentIndex == 1,
                    onTap: onNavigate,
                  ),
                  const Expanded(child: SizedBox()),
                  _StitchNavItem(
                    item: items[2],
                    selected: currentIndex == 2,
                    onTap: onNavigate,
                  ),
                  _StitchNavItem(
                    item: items[3],
                    selected: currentIndex == 3,
                    onTap: onNavigate,
                  ),
                ],
              ),
            ),
            Positioned(
              top: -26,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: const Color(0xFFC19A49),
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0xFF2B1D14), width: 4),
                  ),
                  child: InkWell(
                    onTap: onChat,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 64,
                      height: 64,
                      child: Icon(
                        Icons.smart_toy_outlined,
                        size: 29,
                        color: Color(0xFF2B1D14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StitchNavItem extends StatelessWidget {
  const _StitchNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final (IconData, String, int) item;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFC19A49) : const Color(0xFFBDAEA4);
    return Expanded(
      child: InkWell(
        onTap: () => onTap(item.$3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.$1, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              item.$2,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
