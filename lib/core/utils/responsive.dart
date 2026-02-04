import 'package:flutter/material.dart';

enum DeviceSize { compact, medium, expanded, large }

class Responsive {
  static DeviceSize deviceSizeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return DeviceSize.compact;
    if (width < 1024) return DeviceSize.medium;
    if (width < 1440) return DeviceSize.expanded;
    return DeviceSize.large;
  }

  static bool isCompact(BuildContext context) =>
      deviceSizeOf(context) == DeviceSize.compact;
  
  static bool isMedium(BuildContext context) =>
      deviceSizeOf(context) == DeviceSize.medium;
  
  static bool isExpanded(BuildContext context) =>
      deviceSizeOf(context) == DeviceSize.expanded;
  
  static bool isLarge(BuildContext context) =>
      deviceSizeOf(context) == DeviceSize.large;

  static bool isTabletOrLarger(BuildContext context) =>
      !isCompact(context);
  
  static bool isDesktopOrLarger(BuildContext context) =>
      isExpanded(context) || isLarge(context);

  static double contentMaxWidth(BuildContext context) {
    switch (deviceSizeOf(context)) {
      case DeviceSize.compact:
        return 560;
      case DeviceSize.medium:
        return 820;
      case DeviceSize.expanded:
        return 1080;
      case DeviceSize.large:
        return 1200;
    }
  }

  static EdgeInsets pagePadding(BuildContext context) {
    switch (deviceSizeOf(context)) {
      case DeviceSize.compact:
        return const EdgeInsets.all(16);
      case DeviceSize.medium:
        return const EdgeInsets.all(24);
      case DeviceSize.expanded:
        return const EdgeInsets.all(28);
      case DeviceSize.large:
        return const EdgeInsets.all(32);
    }
  }

  static EdgeInsets cardPadding(BuildContext context) {
    switch (deviceSizeOf(context)) {
      case DeviceSize.compact:
        return const EdgeInsets.all(16);
      case DeviceSize.medium:
        return const EdgeInsets.all(20);
      case DeviceSize.expanded:
        return const EdgeInsets.all(24);
      case DeviceSize.large:
        return const EdgeInsets.all(28);
    }
  }

  static double spacing(BuildContext context) {
    switch (deviceSizeOf(context)) {
      case DeviceSize.compact:
        return 16;
      case DeviceSize.medium:
        return 20;
      case DeviceSize.expanded:
        return 24;
      case DeviceSize.large:
        return 28;
    }
  }

  static double smallSpacing(BuildContext context) {
    return spacing(context) * 0.5;
  }

  static double largeSpacing(BuildContext context) {
    return spacing(context) * 1.5;
  }

  static double responsiveFontSize(BuildContext context, double baseSize) {
    final deviceSize = deviceSizeOf(context);
    switch (deviceSize) {
      case DeviceSize.compact:
        return baseSize;
      case DeviceSize.medium:
        return baseSize * 1.1;
      case DeviceSize.expanded:
        return baseSize * 1.2;
      case DeviceSize.large:
        return baseSize * 1.3;
    }
  }

  static int crossAxisCount(BuildContext context, {
    int maxCount = 4,
    int minCount = 1,
    double itemWidth = 300,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final padding = pagePadding(context).horizontal;
    final availableWidth = screenWidth - padding;
    final count = (availableWidth / itemWidth).floor();
    return count.clamp(minCount, maxCount);
  }

  static double itemHeight(BuildContext context, double baseHeight) {
    switch (deviceSizeOf(context)) {
      case DeviceSize.compact:
        return baseHeight;
      case DeviceSize.medium:
        return baseHeight * 1.1;
      case DeviceSize.expanded:
        return baseHeight * 1.2;
      case DeviceSize.large:
        return baseHeight * 1.3;
    }
  }

  static bool isPortrait(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }
}

class ResponsiveContent extends StatelessWidget {
  final Widget child;

  const ResponsiveContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.contentMaxWidth(context),
        ),
        child: child,
      ),
    );
  }
}
