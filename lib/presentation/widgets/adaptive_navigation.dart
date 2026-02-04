import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/responsive.dart';

class AdaptiveNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  final List<NavigationItem> items;
  final ValueChanged<bool>? onPopupMenuStateChanged;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const AdaptiveNavigation({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    required this.items,
    this.onPopupMenuStateChanged,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  State<AdaptiveNavigation> createState() => _AdaptiveNavigationState();
}

class _AdaptiveNavigationState extends State<AdaptiveNavigation> {
  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktopOrLarger(context)) {
      return _buildDesktopNavigation(context);
    } else if (Responsive.isTabletOrLarger(context)) {
      return _buildTabletNavigation(context);
    } else {
      return _buildMobileNavigation(context);
    }
  }

  Widget _buildDesktopNavigation(BuildContext context) {
    return NavigationRail(
      selectedIndex: widget.currentIndex,
      onDestinationSelected: widget.onNavigate,
      extended: Responsive.isLarge(context),
      leading: widget.leading,
      destinations: widget.items
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon ?? item.icon),
              label: Text(item.label),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTabletNavigation(BuildContext context) {
    return Row(
      children: [
        if (widget.automaticallyImplyLeading && widget.leading != null)
          widget.leading!,
        NavigationRail(
          selectedIndex: widget.currentIndex,
          onDestinationSelected: widget.onNavigate,
          extended: false,
          destinations: widget.items
              .map(
                (item) => NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon ?? item.icon),
                  label: Text(item.label),
                ),
              )
              .toList(),
        ),
        Expanded(child: Container()),
      ],
    );
  }

  Widget _buildMobileNavigation(BuildContext context) {
    return _MobileBottomNavigation(
      currentIndex: widget.currentIndex,
      onNavigate: widget.onNavigate,
      items: widget.items,
      onPopupMenuStateChanged: widget.onPopupMenuStateChanged,
    );
  }
}

class _MobileBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  final List<NavigationItem> items;
  final ValueChanged<bool>? onPopupMenuStateChanged;

  const _MobileBottomNavigation({
    required this.currentIndex,
    required this.onNavigate,
    required this.items,
    this.onPopupMenuStateChanged,
  });

  @override
  State<_MobileBottomNavigation> createState() =>
      _MobileBottomNavigationState();
}

class _MobileBottomNavigationState extends State<_MobileBottomNavigation> {
  bool _isMoreMenuOpen = false;

  void _setMoreMenuOpen(bool value) {
    if (_isMoreMenuOpen == value) return;
    setState(() => _isMoreMenuOpen = value);
    widget.onPopupMenuStateChanged?.call(_isMoreMenuOpen);
  }

  @override
  void dispose() {
    if (_isMoreMenuOpen) {
      widget.onPopupMenuStateChanged?.call(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryItems = _getPrimaryItems();
    final moreItems = _getMoreItems();
    // Check if we have a popup menu item (index 2 with apps_rounded icon and empty label)
    final hasPopupMenu = widget.items.length > 2 && 
                         widget.items[2].icon == Icons.apps_rounded && 
                         widget.items[2].label.isEmpty;
    final List<NavigationItem> popupMenuItems = hasPopupMenu 
        ? [
            NavigationItem(icon: Icons.forum_outlined, label: context.l10n.translate('nav.chat'), index: 3),
            NavigationItem(icon: Icons.explore, label: context.l10n.translate('nav.discovery'), index: 2),
          ]
        : [];
    final moreItemIndexes = (hasPopupMenu
            ? [2, 3]
            : moreItems.map((item) => item.index))
        .toSet();
    final isMoreItemSelected = moreItemIndexes.contains(widget.currentIndex);

    return _buildBottomNavigationBar(
      primaryItems: primaryItems,
      moreItems: hasPopupMenu ? popupMenuItems : moreItems,
      isMoreItemSelected: isMoreItemSelected,
    );
  }

  List<NavigationItem> _getPrimaryItems() {
    // Show all items if 5 or fewer, otherwise show first 4
    const maxPrimaryItems = 5;
    if (widget.items.length <= maxPrimaryItems) {
      return widget.items;
    }
    return widget.items.take(maxPrimaryItems - 1).toList();
  }

  List<NavigationItem> _getMoreItems() {
    // Only show "More" menu if we have more than 5 items
    const maxPrimaryItems = 5;
    if (widget.items.length <= maxPrimaryItems) {
      return [];
    }
    return widget.items.skip(maxPrimaryItems - 1).toList();
  }

  Widget _buildBottomNavigationBar({
    required List<NavigationItem> primaryItems,
    required List<NavigationItem> moreItems,
    required bool isMoreItemSelected,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;
    final navBarHeight = isCompact ? 62.0 : 66.0;
    final navContainerHeight = navBarHeight;
    final hasPopupMenu = widget.items.length > 2 && 
                         widget.items[2].icon == Icons.apps_rounded && 
                         widget.items[2].label.isEmpty;
    final middleButtonSize = isCompact ? 58.0 : 65.0;

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 12 : 16,
            isCompact ? 12 : 16,
            isCompact ? 12 : 16,
            isCompact ? 12 : 16,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: navContainerHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                if (moreItems.isNotEmpty)
                  Positioned(
                    bottom: isCompact ? 36 : 40,
                    child: IgnorePointer(
                      ignoring: !_isMoreMenuOpen,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        offset: _isMoreMenuOpen
                            ? Offset.zero
                            : const Offset(0, 0.18),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _isMoreMenuOpen ? 1 : 0,
                          child: _BubbleMoreMenu(
                            items: moreItems,
                            currentIndex: widget.currentIndex,
                            onTap: (index) {
                              // Handle popup menu items (Chat and Discovery)
                              final hasPopupMenu = widget.items.length > 2 && 
                                                   widget.items[2].icon == Icons.apps_rounded && 
                                                   widget.items[2].label.isEmpty;
                              if (hasPopupMenu) {
                                // Navigate to Chat (index 3) or Discovery (index 2) based on selection
                                final targetIndex = index == 0 ? 3 : 2; // Chat is index 3, Discovery is index 2
                                widget.onNavigate(targetIndex);
                              } else {
                                final globalIndex = widget.items.indexOf(
                                  moreItems[index],
                                );
                                widget.onNavigate(globalIndex);
                              }
                              _setMoreMenuOpen(false);
                            },
                            width: isCompact ? 200 : 224,
                            height: isCompact ? 112 : 122,
                            radius: isCompact ? 60 : 68,
                          ),
                        ),
                      ),
                    ),
                  ),
                Container(
                  height: navBarHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x12000000)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ...primaryItems.map(
                        (item) {
                          final isPopupMenu = item.icon == Icons.apps_rounded && item.label.isEmpty;
                          if (isPopupMenu) {
                            return const Expanded(child: SizedBox());
                          }
                          return Expanded(
                            child: _BarNavItem(
                              icon: item.icon,
                              label: item.label,
                              isSelected: widget.currentIndex == item.index,
                              onTap: () {
                                _setMoreMenuOpen(false);
                                widget.onNavigate(item.index);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Only show floating button if we have a popup menu
                if (hasPopupMenu && moreItems.isNotEmpty)
                  Positioned(
                    bottom: isCompact ? 30 : 34,
                    child: GestureDetector(
                      onTap: () => _setMoreMenuOpen(!_isMoreMenuOpen),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: middleButtonSize,
                        width: middleButtonSize,
                        decoration: BoxDecoration(
                          color: isMoreItemSelected || _isMoreMenuOpen
                              ? const Color(0xFFD4AF37)
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isMoreItemSelected || _isMoreMenuOpen
                                ? const Color(0xFFD4AF37)
                                : const Color(0x19000000),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedRotation(
                            turns: _isMoreMenuOpen ? 0.125 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: Icon(
                              Icons.apps_rounded,
                              size: isCompact ? 27 : 30,
                              color: isMoreItemSelected || _isMoreMenuOpen
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = const Color(0xFFD4AF37);
    final color = isSelected ? selectedColor : Colors.grey.shade700;
    final showLabel = label.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x1AD4AF37) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: color),
            if (showLabel) ...[
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BubbleMoreMenu extends StatelessWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double width;
  final double height;
  final double radius;

  const _BubbleMoreMenu({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.width,
    required this.height,
    required this.radius,
  });

  List<double> _anglesForCount(int count) {
    switch (count) {
      case 1:
        return const [90];
      case 2:
        return const [128, 52];
      case 3:
        return const [150, 90, 30];
      case 4:
        return const [165, 120, 60, 15];
      default:
        return List<double>.generate(
          count,
          (index) => 170 - (140 * (index / (count - 1))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final angles = _anglesForCount(items.length);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final rad = angles[i] * (math.pi / 180);
          final dx = math.cos(rad) * radius;
          final dy = math.sin(rad) * radius;

          return Transform.translate(
            offset: Offset(dx, -dy),
            child: _BubbleNavItem(
              icon: item.icon,
              label: item.label,
              isSelected: currentIndex == item.index,
              onTap: () => onTap(i),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BubbleNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BubbleNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = const Color(0xFFD4AF37);
    final iconColor = isSelected ? selectedColor : Colors.grey.shade700;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 23, color: iconColor),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 76,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: iconColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final int index;

  const NavigationItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.index,
  });
}
