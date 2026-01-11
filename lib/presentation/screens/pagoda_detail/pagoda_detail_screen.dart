import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/pagoda_model.dart';
import '../../providers/pagoda_provider.dart';
import '../trips/create_trip_screen.dart';
import '../home/home_screen.dart';
import '../../widgets/pagoda_image_widget.dart';

class PagodaDetailScreen extends StatefulWidget {
  final Pagoda pagoda;

  const PagodaDetailScreen({super.key, required this.pagoda});

  @override
  State<PagodaDetailScreen> createState() => _PagodaDetailScreenState();
}

class _PagodaDetailScreenState extends State<PagodaDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  List<String> _buildImageList(Pagoda pagoda) {
    final List<String> images = [];
    if (pagoda.imageUrl.trim().isNotEmpty) {
      images.add(pagoda.imageUrl);
    }
    for (final image in pagoda.images) {
      if (image.trim().isNotEmpty && !images.contains(image)) {
        images.add(image);
      }
    }
    return images;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = _buildImageList(widget.pagoda);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.pagoda.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 2),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.length <= 1)
                    PagodaImageWidget(
                      imageUrl: images.isNotEmpty ? images.first : '',
                      fit: BoxFit.cover,
                      height: 320,
                      width: double.infinity,
                      placeholder: Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.temple_buddhist, size: 100),
                      ),
                    )
                  else
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      physics: const PageScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return PagodaImageWidget(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          height: 320,
                          width: double.infinity,
                          placeholder: Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.temple_buddhist, size: 100),
                          ),
                        );
                      },
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x7A000000),
                        ],
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      left: 8,
                      bottom: 10,
                      child: _CarouselNavButton(
                        icon: Icons.chevron_left,
                        onTap: () {
                          if (_currentImageIndex > 0) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                  if (images.length > 1)
                    Positioned(
                      right: 8,
                      bottom: 10,
                      child: _CarouselNavButton(
                        icon: Icons.chevron_right,
                        onTap: () {
                          if (_currentImageIndex < images.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                  if (images.length > 1)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            images.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 6,
                              width: index == _currentImageIndex ? 18 : 6,
                              decoration: BoxDecoration(
                                color: index == _currentImageIndex
                                    ? Colors.white
                                    : Colors.white70,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  widget.pagoda.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: widget.pagoda.isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  context.read<PagodaProvider>().toggleFavorite(widget.pagoda.id);
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(widget.pagoda.category),
                        backgroundColor: const Color(0xFFD4AF37),
                        labelStyle: const TextStyle(color: Colors.white),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        label: Text(
                          '${widget.pagoda.latitude.toStringAsFixed(4)}, ${widget.pagoda.longitude.toStringAsFixed(4)}',
                        ),
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        avatar: Icon(
                          Icons.location_on,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Category',
                          value: widget.pagoda.category,
                          icon: Icons.category,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: 'Year',
                          value: widget.pagoda.yearBuilt?.toString() ?? 'Unknown',
                          icon: Icons.event,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: 'Age',
                          value: widget.pagoda.yearBuilt == null
                              ? 'Unknown'
                              : '${DateTime.now().year - widget.pagoda.yearBuilt!} yrs',
                          icon: Icons.history,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'Overview',
                    child: Text(
                      widget.pagoda.description,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionCard(
                    title: 'Quick Facts',
                    child: Column(
                      children: [
                        if (widget.pagoda.architecturalStyle != null)
                          _InfoTile(
                            icon: Icons.architecture,
                            label: 'Architectural Style',
                            value: widget.pagoda.architecturalStyle!,
                          ),
                        if (widget.pagoda.yearBuilt != null)
                          _InfoTile(
                            icon: Icons.event,
                            label: 'Year Built',
                            value: widget.pagoda.yearBuilt.toString(),
                          ),
                        _InfoTile(
                          icon: Icons.place,
                          label: 'Location',
                          value:
                              '${widget.pagoda.latitude.toStringAsFixed(4)}, ${widget.pagoda.longitude.toStringAsFixed(4)}',
                        ),
                      ],
                    ),
                  ),
                  if (widget.pagoda.historicalInfo != null) ...[
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Historical Information',
                      child: Text(
                        widget.pagoda.historicalInfo!,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateTripScreen(
                              initialPagoda: widget.pagoda,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_road),
                      label: const Text('Add to Trip'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(
                              initialIndex: 2,
                              initialMapPagoda: widget.pagoda,
                            ),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('View on Map'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 26),
          onPressed: onTap,
          tooltip: 'Change image',
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
