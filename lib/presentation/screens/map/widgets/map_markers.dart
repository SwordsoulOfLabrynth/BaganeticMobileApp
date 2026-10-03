import 'package:flutter/material.dart';

import '../../../../core/utils/responsive.dart';

class ModeToggleItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const ModeToggleItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : activeColor,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : activeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.responsiveFontSize(context, 13),
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

class MapCategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  const MapCategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    this.showLabel = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Center(
            child: showLabel
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: selected ? Colors.white : color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF30251D),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : Tooltip(
                    message: label,
                    child: Icon(
                      icon,
                      size: 20,
                      color: selected ? Colors.white : color,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class PathMapMarker extends StatelessWidget {
  final bool isStart;
  final bool isEnd;
  final int? pathOrder;
  final Animation<double> pulse;

  const PathMapMarker({
    super.key,
    required this.isStart,
    required this.isEnd,
    required this.pathOrder,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final isPathNode = pathOrder != null;
    final markerColor = isStart
        ? Colors.green
        : isEnd
        ? Colors.red
        : isPathNode
        ? Colors.blue
        : const Color(0xFF8B4513);

    final child = isStart
        ? const Text(
            'A',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          )
        : isEnd
        ? const Text(
            'B',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          )
        : isPathNode
        ? Text(
            '$pathOrder',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          )
        : const Icon(Icons.temple_buddhist, color: Colors.white, size: 20);

    final marker = Container(
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(child: child),
    );

    if (!isStart && !isEnd) {
      return marker;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.4,
          ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.45, end: 0.0).animate(pulse),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        marker,
      ],
    );
  }
}

class PagodaMapMarker extends StatelessWidget {
  final bool isSelected;
  final Animation<double> pulse;

  const PagodaMapMarker({
    super.key,
    required this.isSelected,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF8B4513),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.temple_buddhist, color: Colors.white, size: 20),
    );

    if (!isSelected) {
      return marker;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.4,
          ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 0.0).animate(pulse),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFD4AF37),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        marker,
      ],
    );
  }
}

class TravelPlaceMapMarker extends StatelessWidget {
  const TravelPlaceMapMarker({
    super.key,
    required this.icon,
    required this.color,
    required this.isSelected,
  });

  final IconData icon;
  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFFFFD995) : Colors.white,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.28 : 0.16),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    );
  }
}

class MapClusterMarker extends StatelessWidget {
  final int count;
  final Color color;

  const MapClusterMarker({
    super.key,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFBF3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class MapAreaMarker extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const MapAreaMarker({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFBF3).withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF30251D),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripMapMarker extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final Animation<double> pulse;

  const TripMapMarker({
    super.key,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final marker = Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFF5C3A17) : Colors.white,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (!isSelected) {
      return marker;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(
            begin: 0.82,
            end: 1.38,
          ).animate(CurvedAnimation(parent: pulse, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.42, end: 0.0).animate(pulse),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        marker,
      ],
    );
  }
}
