import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/ai_chatbot_service.dart';
import '../../../core/utils/ai_assistant_launcher.dart';
import '../../../data/models/trip_model.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/localization/app_localizations.dart';
import 'create_trip_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Trip _trip;
  late TripTransportMode _selectedTransportMode;
  late Future<Map<String, String>> _pagodaImageAssetsFuture;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _selectedTransportMode = widget.trip.transportMode;
    _pagodaImageAssetsFuture = _loadPagodaImageAssets();
  }

  Future<Map<String, String>> _loadPagodaImageAssets() async {
    final raw = await rootBundle.loadString('assets/data/sample_pagodas.json');
    final pagodas = jsonDecode(raw) as List<dynamic>;

    return {
      for (final pagoda in pagodas.whereType<Map<String, dynamic>>())
        if (pagoda['id'] is String && pagoda['imageUrl'] is String)
          pagoda['id'] as String: pagoda['imageUrl'] as String,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F2E9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(_trip.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_outlined),
            onPressed: () => AIAssistantLauncher.open(
              context,
              entryContext: AIEntryContext.trip(_trip.id),
            ),
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: _editTrip),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                context.l10n.translate(
                  'tripDetail.summary',
                  args: {
                    'date': Helpers.formatDate(_trip.date).toUpperCase(),
                    'count': '${_trip.stops.length}',
                    'distance': Helpers.formatDistance(
                      context,
                      _trip.getTotalDistance(),
                    ).toUpperCase(),
                    'mode': Helpers.transportModeLabel(
                      context,
                      _selectedTransportMode,
                    ).toUpperCase(),
                  },
                ),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: Color(0xFF655D56),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _buildMap(),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildItinerary(),
                const Divider(height: 55, color: Color(0xFFE1D4B8)),
                Text(
                  context.l10n.translate('tripDetail.roadNotes'),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.7,
                    color: Color(0xFF756C65),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E9DC),
                    border: Border.all(color: const Color(0xFFE6DAC5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 10, color: Color(0xFFAE5038)),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          context.l10n.translate('tripDetail.roadNotesBody'),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.55,
                            color: Color(0xFF51463E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_trip.stops.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final mapHeight = screenWidth >= 1000
        ? 260.0
        : screenWidth >= 600
        ? 180.0
        : 100.0;

    return Container(
      height: mapHeight,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF322018),
        borderRadius: BorderRadius.circular(8),
        image: const DecorationImage(
          image: AssetImage('assets/images/stitch/bagan_sunrise.jpg'),
          fit: BoxFit.cover,
          opacity: 0.22,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, color: Color(0xFFE1BA5A)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.l10n.translate(
                'tripDetail.routeSummary',
                args: {
                  'count': '${_trip.stops.length}',
                  'distance': Helpers.formatDistance(
                    context,
                    _trip.getTotalDistance(),
                  ).toUpperCase(),
                },
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _trip.name,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              Helpers.formatDate(_trip.date),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
        if (_trip.description != null) ...[
          const SizedBox(height: 12),
          Text(_trip.description!, style: const TextStyle(fontSize: 16)),
        ],
      ],
    );
  }

  // ignore: unused_element
  Widget _buildStats() {
    final estimatedTravelDuration = Helpers.formatDuration(
      context,
      _trip
          .copyWith(transportMode: _selectedTransportMode)
          .getEstimatedTravelDuration(),
    );
    final durationCalculation = context.l10n.translate(
      'tripDetail.durationCalculation',
      args: {
        'mode': Helpers.transportModeLabel(context, _selectedTransportMode),
        'distance': Helpers.formatDistance(context, _trip.getTotalDistance()),
        'speed': Helpers.formatSpeed(
          context,
          _selectedTransportMode.averageSpeedKph,
        ),
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth >= 600
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                icon: Icons.location_on,
                label: context.l10n.translate('tripDetail.stops'),
                value: '${_trip.stops.length}',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                icon: Icons.straighten,
                label: context.l10n.translate('tripDetail.distance'),
                value: Helpers.formatDistance(
                  context,
                  _trip.getTotalDistance(),
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                icon: Helpers.transportModeIcon(_selectedTransportMode),
                label: context.l10n.translate('tripDetail.travelTime'),
                value: estimatedTravelDuration,
                supportingText: durationCalculation,
              ),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildTransportModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.translate('trip.transportMode'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TripTransportMode.values.map((mode) {
            final isSelected = _selectedTransportMode == mode;
            return ChoiceChip(
              selected: isSelected,
              avatar: Icon(Helpers.transportModeIcon(mode), size: 18),
              label: Text(Helpers.transportModeLabel(context, mode)),
              onSelected: isSelected
                  ? null
                  : (_) => setState(() {
                      _selectedTransportMode = mode;
                    }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    String? supportingText,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFD4AF37)),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (supportingText != null) ...[
              const SizedBox(height: 4),
              Text(
                supportingText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItinerary() {
    return FutureBuilder<Map<String, String>>(
      future: _pagodaImageAssetsFuture,
      builder: (context, snapshot) {
        final imageAssets = snapshot.data ?? const <String, String>{};

        return Column(
          children: List.generate(_trip.stops.length, (index) {
            final stop = _trip.stops[index];
            final isLast = index == _trip.stops.length - 1;
            final image =
                imageAssets[stop.pagodaId] ??
                'assets/images/stitch/bagan_sunrise.jpg';
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 33,
                  child: Column(
                    children: [
                      Container(
                        width: 27,
                        height: 27,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF8EF),
                          border: Border.all(color: const Color(0xFFD1A447)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A711E),
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 1,
                          // This list is measured by a surrounding scroll view,
                          // so it has no bounded height. A flex child here throws
                          // during layout and leaves multi-stop trips blank.
                          height: 330,
                          color: const Color(0xFFE8DCC5),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 160,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBF3),
                            border: Border.all(color: const Color(0xFFE8DEC9)),
                          ),
                          child: Image.asset(
                            image,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 17),
                        Text(
                          context.l10n.pagodaName(
                            stop.pagodaId,
                            stop.pagodaName,
                          ),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontSize: 23,
                                color: const Color(0xFF2B1D14),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.translate(
                            'tripDetail.arrive',
                            args: {'time': _arrivalTime(index)},
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            color: Color(0xFFAE5038),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          stop.notes ?? _defaultStopNote(index),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFF51463E),
                          ),
                        ),
                        if (!isLast)
                          Padding(
                            padding: const EdgeInsets.only(top: 19),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.electric_bike_outlined,
                                  size: 15,
                                  color: Color(0xFF6F635A),
                                ),
                                const SizedBox(width: 18),
                                Text(
                                  context.l10n.translate(
                                    'tripDetail.nextLeg',
                                    args: {
                                      'distance': stop.distanceToNext == null
                                          ? '12 ${context.l10n.translate('common.minutesShort')}'
                                          : Helpers.formatDistance(
                                              context,
                                              stop.distanceToNext!,
                                            ).toUpperCase(),
                                      'mode': Helpers.transportModeLabel(
                                        context,
                                        _selectedTransportMode,
                                      ).toUpperCase(),
                                    },
                                  ),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    letterSpacing: .7,
                                    color: Color(0xFF6F635A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  String _arrivalTime(int index) {
    final minutes = 345 + index * 55;
    final hour = (minutes ~/ 60) % 12 == 0 ? 12 : (minutes ~/ 60) % 12;
    return '${hour.toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')} AM';
  }

  String _defaultStopNote(int index) => switch (index % 3) {
    0 =>
      'Best sunrise viewpoint — arrive before first light to secure a spot overlooking the plains.',
    1 =>
      'Explore the terracotta corridors in the early light. The four standing Buddhas are particularly striking.',
    _ =>
      'Massive brickwork and mysterious inner passages. Take your time with this remarkable temple.',
  };

  Future<void> _editTrip() async {
    final updatedTrip = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTripScreen(existingTrip: _trip),
      ),
    );

    if (!mounted) return;
    if (updatedTrip is Trip) {
      setState(() {
        _trip = updatedTrip;
      });
    }
  }
}
