import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/utils/responsive.dart';

// Heritage Journal palette constants — accessible to all nav widget classes
const Color _navGold = Color(0xFFC19A49); // antique gold
const Color _navActive = Color(0xFFA34A2A); // terracotta
const Color _navUnselected = Color(0xFF786A5D); // warm muted brown

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
  static const Color _gold = _navGold;
  static const Color _goldDark = _navActive;
  static const Color _panelBackground = Color(0xFFFFFBF3);
  static const Color _panelBorder = Color(0xFFDCCCB3);

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
    return _buildWideNavigation(context, isDesktop: true);
  }

  Widget _buildTabletNavigation(BuildContext context) {
    return _buildWideNavigation(context, isDesktop: false);
  }

  Widget _buildWideNavigation(BuildContext context, {required bool isDesktop}) {
    return Container(
      decoration: const BoxDecoration(
        color: _panelBackground,
        border: Border(right: BorderSide(color: _panelBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: NavigationRail(
          backgroundColor: Colors.transparent,
          selectedIndex: widget.currentIndex,
          onDestinationSelected: widget.onNavigate,
          extended: isDesktop,
          minWidth: 84,
          minExtendedWidth: 196,
          groupAlignment: -0.92,
          labelType: isDesktop
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          useIndicator: true,
          indicatorColor: const Color(0x1FAE5038),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          selectedIconTheme: const IconThemeData(color: _goldDark, size: 24),
          unselectedIconTheme: const IconThemeData(
            color: _navUnselected,
            size: 22,
          ),
          selectedLabelTextStyle: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: _goldDark, fontWeight: FontWeight.w700),
          unselectedLabelTextStyle: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: _navUnselected, fontWeight: FontWeight.w500),
          leading: Padding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 14 : 10, 14, 10, 12),
            child: _buildWideLeading(isDesktop: isDesktop),
          ),
          destinations: widget.items
              .map(
                (item) => NavigationRailDestination(
                  icon: _buildWideDestinationIcon(item.icon),
                  selectedIcon: _buildWideDestinationIcon(
                    item.selectedIcon ?? item.icon,
                    isSelected: true,
                  ),
                  label: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildWideLeading({required bool isDesktop}) {
    final brandChip = _buildWideBrandChip(isDesktop: isDesktop);
    final shouldShowExtraLeading =
        widget.automaticallyImplyLeading && widget.leading != null;

    if (!shouldShowExtraLeading) {
      return brandChip;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [brandChip, const SizedBox(height: 10), widget.leading!],
    );
  }

  Widget _buildWideBrandChip({required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 12 : 0,
        vertical: isDesktop ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0x12AE5038),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33AE5038)),
      ),
      child: isDesktop
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildWideBrandIcon(isDesktop: isDesktop),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Baganetic',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _goldDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          : Center(child: _buildWideBrandIcon(isDesktop: isDesktop)),
    );
  }

  Widget _buildWideBrandIcon({required bool isDesktop}) {
    return Container(
      height: isDesktop ? 36 : 40,
      width: isDesktop ? 36 : 40,
      decoration: BoxDecoration(
        color: _gold,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.temple_buddhist, color: Colors.white, size: 22),
    );
  }

  Widget _buildWideDestinationIcon(IconData icon, {bool isSelected = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0x17AE5038) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: isSelected ? _goldDark : null),
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
    final moreItemIndexes = moreItems.map((item) => item.index).toSet();
    final isMoreItemSelected = moreItemIndexes.contains(widget.currentIndex);

    return _buildBottomNavigationBar(
      primaryItems: primaryItems,
      moreItems: moreItems,
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
    final middleButtonSize = isCompact ? 58.0 : 65.0;

    final popupHitHeight = moreItems.isNotEmpty
        ? (isCompact ? 260.0 : 280.0)
        : 0.0;

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
            height:
                navContainerHeight + (_isMoreMenuOpen ? popupHitHeight : 0.0),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
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
                          (item) => Expanded(
                            child: _BarNavItem(
                              icon: item.icon,
                              label: item.label,
                              isSelected: widget.currentIndex == item.index,
                              onTap: () {
                                _setMoreMenuOpen(false);
                                widget.onNavigate(item.index);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                              widget.onNavigate(moreItems[index].index);
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
                if (moreItems.isNotEmpty)
                  Positioned(
                    bottom: isCompact ? 16 : 20,
                    child: SizedBox.square(
                      dimension: middleButtonSize + (isCompact ? 14 : 18),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkResponse(
                          onTap: () => _setMoreMenuOpen(!_isMoreMenuOpen),
                          containedInkWell: true,
                          highlightColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: middleButtonSize,
                              width: middleButtonSize,
                              decoration: BoxDecoration(
                                color: isMoreItemSelected || _isMoreMenuOpen
                                    ? const Color(0xFFAE5038)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isMoreItemSelected || _isMoreMenuOpen
                                      ? const Color(0xFFAE5038)
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
                                    Icons.more_horiz_rounded,
                                    size: isCompact ? 27 : 30,
                                    color: isMoreItemSelected || _isMoreMenuOpen
                                        ? Colors.white
                                        : _navUnselected,
                                  ),
                                ),
                              ),
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
    final color = isSelected ? _navActive : _navUnselected;
    final showLabel = label.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x1AAE5038) : Colors.transparent,
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
    final extraHeight = radius + 120.0;

    return SizedBox(
      width: width,
      height: height + extraHeight,
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
    final iconColor = isSelected ? _navActive : _navUnselected;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
