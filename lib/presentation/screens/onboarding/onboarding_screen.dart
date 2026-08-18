import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';

/// Stores whether the first-run introduction has been dismissed on this device.
class OnboardingPreference {
  OnboardingPreference._();

  static const _completedKey = 'onboarding_completed_v1';

  static Future<bool> hasCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completedKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
  }
}

/// A first-run introduction driven by explicit controls rather than horizontal
/// swiping, so it feels like an app flow instead of an image gallery.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  var _page = 0;
  var _isFinishing = false;

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    await widget.onFinished();
  }

  void _next() {
    if (_page == _onboardingSlides.length - 1) {
      _finish();
      return;
    }
    setState(() => _page += 1);
  }

  void _previous() {
    if (_page == 0 || _isFinishing) return;
    setState(() => _page -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _onboardingSlides[_page];
    final isLast = _page == _onboardingSlides.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              _OnboardingHeader(
                page: _page,
                pageCount: _onboardingSlides.length,
                onSkip: _isFinishing ? null : _finish,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.035, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _SlideContent(
                    key: ValueKey(slide.title),
                    slide: slide,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _ProgressDots(
                currentPage: _page,
                pageCount: _onboardingSlides.length,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _page == 0 || _isFinishing ? null : _previous,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      child: const Text('BACK'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isFinishing ? null : _next,
                        child: _isFinishing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(isLast ? 'START EXPLORING' : 'CONTINUE'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.page,
    required this.pageCount,
    required this.onSkip,
  });

  final int page;
  final int pageCount;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.paperColor,
            border: Border.all(color: AppTheme.borderColor),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.temple_buddhist_outlined,
            color: AppTheme.primaryColor,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Baganetic', style: Theme.of(context).textTheme.titleLarge),
              Text(
                'STEP ${page + 1} OF $pageCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('SKIP'),
        ),
      ],
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({super.key, required this.slide});

  final _OnboardingSlideData slide;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: PageStorageKey('onboarding-${slide.title}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeatureIllustration(kind: slide.kind),
          const SizedBox(height: 28),
          Text(
            slide.eyebrow,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.primaryColor,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(slide.title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 14),
          Text(
            slide.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          _FeatureNote(icon: slide.noteIcon, text: slide.note),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FeatureIllustration extends StatelessWidget {
  const _FeatureIllustration({required this.kind});

  final _OnboardingArtKind kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      _OnboardingArtKind.discover => 'Bagan pagodas at sunrise',
      _OnboardingArtKind.plan => 'A sample route across Bagan',
      _OnboardingArtKind.community => 'A community travel tip',
    };
    return Semantics(
      label: label,
      child: Container(
        height: 270,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: switch (kind) {
          _OnboardingArtKind.discover => const _DiscoverIllustration(),
          _OnboardingArtKind.plan => const _PlanIllustration(),
          _OnboardingArtKind.community => const _CommunityIllustration(),
        },
      ),
    );
  }
}

class _DiscoverIllustration extends StatelessWidget {
  const _DiscoverIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/stitch/bagan_sunrise.jpg',
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF786A5D)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x11000000), Color(0xA62B1D14)],
            ),
          ),
        ),
        const Positioned(
          top: 16,
          left: 16,
          child: _ArtworkChip(
            icon: Icons.auto_awesome_outlined,
            label: 'DISCOVER',
          ),
        ),
        const Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: Text(
            'Stories, places, and sacred sites—kept close at hand.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanIllustration extends StatelessWidget {
  const _PlanIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _RouteMapPainter())),
        const Positioned(
          top: 16,
          left: 16,
          child: _ArtworkChip(
            icon: Icons.alt_route_rounded,
            label: 'PLAN A ROUTE',
          ),
        ),
        const _MapPin(label: '1', alignment: Alignment(0.34, -0.42)),
        const _MapPin(label: '2', alignment: Alignment(-0.26, 0.04)),
        const _MapPin(label: '3', alignment: Alignment(0.42, 0.56)),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            color: AppTheme.cardColor,
            child: const Text(
              '3 STOPS  ·  8.4 KM  ·  OFFLINE READY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommunityIllustration extends StatelessWidget {
  const _CommunityIllustration();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ArtworkChip(icon: Icons.forum_outlined, label: 'LOCAL TIP'),
            const Spacer(),
            Text(
              'Arrive at Shwesandaw by 5:30.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'The east terrace fills first — bring a small flashlight for the stairs.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
            ),
            const Spacer(),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 8),
            const Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.paperColor,
                  child: Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'MARIA G.  ·  5H AGO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                Spacer(),
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 17,
                  color: AppTheme.accentColor,
                ),
                SizedBox(width: 4),
                Text('42', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkChip extends StatelessWidget {
  const _ArtworkChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: AppTheme.cardColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.label, required this.alignment});

  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppTheme.accentColor,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 2),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _FeatureNote extends StatelessWidget {
  const _FeatureNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.paperColor.withValues(alpha: 0.62),
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.currentPage, required this.pageCount});

  final int currentPage;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Introduction step ${currentPage + 1} of $pageCount',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(pageCount, (index) {
          final selected = index == currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
              borderRadius: BorderRadius.circular(99),
            ),
          );
        }),
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final river = Paint()
      ..color = const Color(0xFFD3E7E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12;
    final roads = Paint()
      ..color = const Color(0xFFD8D1C1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final route = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(size.width * .82, -12)
      ..cubicTo(
        size.width * .66,
        size.height * .30,
        size.width * .88,
        size.height * .68,
        size.width * .70,
        size.height + 20,
      );
    canvas.drawPath(riverPath, river);
    for (var i = 0; i < 6; i++) {
      final y = 18.0 + i * 42;
      canvas.drawPath(
        Path()
          ..moveTo(-12, y)
          ..quadraticBezierTo(
            size.width * .45,
            y + (i.isEven ? 22 : -10),
            size.width + 12,
            y + 28,
          ),
        roads,
      );
    }
    for (var i = 0; i < 5; i++) {
      final x = 20.0 + i * 62;
      canvas.drawPath(
        Path()
          ..moveTo(x, -12)
          ..quadraticBezierTo(
            x + (i.isEven ? 34 : -18),
            size.height * .52,
            x + 18,
            size.height + 12,
          ),
        roads,
      );
    }
    final path = Path()
      ..moveTo(size.width * .62, size.height * .22)
      ..cubicTo(
        size.width * .56,
        size.height * .34,
        size.width * .32,
        size.height * .34,
        size.width * .37,
        size.height * .52,
      )
      ..cubicTo(
        size.width * .40,
        size.height * .64,
        size.width * .67,
        size.height * .67,
        size.width * .69,
        size.height * .78,
      );
    canvas.drawPath(path, outline);
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) => false;
}

enum _OnboardingArtKind { discover, plan, community }

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.note,
    required this.noteIcon,
    required this.kind,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String note;
  final IconData noteIcon;
  final _OnboardingArtKind kind;
}

const _onboardingSlides = <_OnboardingSlideData>[
  _OnboardingSlideData(
    eyebrow: 'DISCOVER BAGAN',
    title: 'Find places worth the stop.',
    description:
        'Explore pagodas, temples, and local stories across Bagan. Save the places you want to return to.',
    note: 'Your saved places stay together in Your Journal.',
    noteIcon: Icons.bookmark_border_rounded,
    kind: _OnboardingArtKind.discover,
  ),
  _OnboardingSlideData(
    eyebrow: 'PLAN WITH CONFIDENCE',
    title: 'Make the route yours.',
    description:
        'Build a journey stop by stop, use curated routes, and keep essential map details available offline.',
    note: 'Ferry transfers are shown as terminals, never as a fictional road.',
    noteIcon: Icons.alt_route_rounded,
    kind: _OnboardingArtKind.plan,
  ),
  _OnboardingSlideData(
    eyebrow: 'TRAVEL WITH LOCAL RHYTHM',
    title: 'Useful notes from fellow travelers.',
    description:
        'Check community tips for practical details, then add your own experience when it can help someone else.',
    note: 'You can browse community advice before creating an account.',
    noteIcon: Icons.forum_outlined,
    kind: _OnboardingArtKind.community,
  ),
];
