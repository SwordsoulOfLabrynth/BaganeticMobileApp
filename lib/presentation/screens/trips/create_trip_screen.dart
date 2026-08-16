import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/services/ai_chatbot_service.dart';
import '../../../core/utils/ai_assistant_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/pathfinding.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/offline_route_service.dart';
import '../../../core/services/multimodal_route_service.dart';
import '../../widgets/sign_in_required_view.dart';

class CreateTripScreen extends StatefulWidget {
  final Pagoda? initialPagoda;
  final Trip? existingTrip;

  const CreateTripScreen({super.key, this.initialPagoda, this.existingTrip});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  TripTransportMode _selectedTransportMode = TripTransportMode.walk;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedStartTime = const TimeOfDay(hour: 5, minute: 30);
  List<Pagoda> _selectedPagodas = [];
  bool _isCalculatingRoute = false;
  bool _loadedExistingStops = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingTrip != null) {
      final trip = widget.existingTrip!;
      _nameController.text = trip.name;
      _descriptionController.text = trip.description ?? '';
      _selectedTransportMode = trip.transportMode;
      _selectedDate = trip.date;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadExistingStops();
      });
    } else if (widget.initialPagoda != null) {
      _selectedPagodas = [widget.initialPagoda!];
    }
  }

  void _loadExistingStops() {
    if (_loadedExistingStops || widget.existingTrip == null) return;
    final provider = context.read<PagodaProvider>();
    final allPagodas = provider.allPagodas;
    if (allPagodas.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadExistingStops();
        }
      });
      return;
    }

    final byId = {for (final pagoda in allPagodas) pagoda.id: pagoda};
    final ordered = <Pagoda>[];
    for (final stop in widget.existingTrip!.stops) {
      final match = byId[stop.pagodaId];
      if (match != null) {
        ordered.add(match);
      }
    }

    setState(() {
      _selectedPagodas = ordered;
      _loadedExistingStops = true;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = _selectedDate.isBefore(now) ? _selectedDate : now;
    final lastDate = _selectedDate.isAfter(now.add(const Duration(days: 365)))
        ? _selectedDate
        : now.add(const Duration(days: 365));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedStartTime = picked);
    }
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPagodas.isEmpty) {
      Helpers.showSnackBar(
        context,
        context.l10n.translate('trip.selectAtLeastOne'),
        isError: true,
      );
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final isEditing = widget.existingTrip != null;
      final tripProvider = context.read<TripProvider>();
      final ownerUserId = tripProvider.currentOwnerId;
      final graph = await OfflineRouteService.instance.loadGraph();
      final routeGraph = await PathfindingService.loadGraph();
      // Create trip stops
      final List<TripStop> stops = [];
      for (int i = 0; i < _selectedPagodas.length; i++) {
        final pagoda = _selectedPagodas[i];
        double? distanceToNext;

        if (i < _selectedPagodas.length - 1) {
          final nextPagoda = _selectedPagodas[i + 1];
          final requiresFerry = PathfindingService.requiresRiverCrossingBetween(
            pagoda.id,
            nextPagoda.id,
            routeGraph,
          );
          if (!requiresFerry) {
            distanceToNext = _graphAwareDistanceBetween(
              pagoda,
              nextPagoda,
              graph,
            );
          }
        }

        stops.add(
          TripStop(
            pagodaId: pagoda.id,
            pagodaName: pagoda.name,
            latitude: pagoda.latitude,
            longitude: pagoda.longitude,
            order: i,
            distanceToNext: distanceToNext,
          ),
        );
      }

      final now = DateTime.now();
      final trip = Trip(
        id: isEditing ? widget.existingTrip!.id : const Uuid().v4(),
        ownerUserId: isEditing && widget.existingTrip!.ownerUserId.isNotEmpty
            ? widget.existingTrip!.ownerUserId
            : ownerUserId,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        transportMode: _selectedTransportMode,
        date: _selectedDate,
        stops: stops,
        createdAt: isEditing ? widget.existingTrip!.createdAt : now,
        updatedAt: now,
      );

      await tripProvider.saveTrip(trip);

      if (mounted) {
        Helpers.showSnackBar(
          context,
          context.l10n.translate(
            isEditing ? 'trip.updateSuccess' : 'trip.saveSuccess',
          ),
        );
        Navigator.pop(context, trip);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          context.l10n.translate(
            widget.existingTrip != null ? 'trip.updateError' : 'trip.saveError',
            args: {'error': e.toString()},
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = false;
        });
      }
    }
  }

  Future<void> _optimizeRoute() async {
    if (_selectedPagodas.length < 2) {
      Helpers.showSnackBar(
        context,
        context.l10n.translate('trip.selectAtLeastTwo'),
        isError: true,
      );
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final provider = context.read<PagodaProvider>();
      final allPagodas = provider.allPagodas;
      final routeGraph = await PathfindingService.loadGraph();
      final usesFerry =
          PathfindingService.routeRequiresRiverCrossing(
            _selectedPagodas.map((pagoda) => pagoda.id),
            routeGraph,
          ) ||
          await MultimodalRouteService.instance.routeUsesFerry(
            _selectedPagodas.map((pagoda) => pagoda.id),
          );
      if (!mounted) return;

      if (_selectedPagodas.length == 2) {
        if (usesFerry) {
          // With two fixed stops there is no order to optimize. The map still
          // builds the road-ferry-road plan when the trip is viewed.
          Helpers.showSnackBar(
            context,
            context.l10n.translate('trip.routeAlreadyOptimal'),
          );
          return;
        }

        // Use A* for 2 pagodas
        final result = await PathfindingService.findPath(
          _selectedPagodas[0],
          _selectedPagodas[1],
          allPagodas,
        );
        if (!mounted) return;
        final path = result.path;

        if (path.isNotEmpty) {
          final isSameOrder =
              path.length == _selectedPagodas.length &&
              path.asMap().entries.every(
                (entry) => entry.value.id == _selectedPagodas[entry.key].id,
              );
          if (isSameOrder) {
            Helpers.showSnackBar(
              context,
              context.l10n.translate('trip.routeAlreadyOptimal'),
            );
          } else {
            setState(() {
              _selectedPagodas = path;
            });
            Helpers.showSnackBar(
              context,
              context.l10n.translate('trip.routeOptimized'),
            );
          }
        } else {
          Helpers.showSnackBar(
            context,
            context.l10n.translate(
              result.requiresRiverCrossing
                  ? 'trip.riverCrossingRequired'
                  : 'trip.noRouteFound',
            ),
            isError: true,
          );
        }
      } else {
        final distanceCalculator = usesFerry
            ? await _buildFerryAwareDistanceCalculator(_selectedPagodas)
            : _buildDistanceCalculator(
                await OfflineRouteService.instance.loadGraph(),
              );
        if (!mounted) return;

        // Nearest neighbor + 2-opt improvement for multiple pagodas
        final optimized = PathfindingService.optimizeRouteOrder(
          _selectedPagodas,
          keepFirst: true,
          distanceCalculator: distanceCalculator,
        );

        final isSameOrder =
            optimized.length == _selectedPagodas.length &&
            optimized.asMap().entries.every(
              (entry) => entry.value.id == _selectedPagodas[entry.key].id,
            );
        if (isSameOrder) {
          Helpers.showSnackBar(
            context,
            context.l10n.translate('trip.routeAlreadyOptimal'),
          );
        } else {
          setState(() {
            _selectedPagodas = optimized;
          });
          Helpers.showSnackBar(
            context,
            context.l10n.translate('trip.routeOptimized'),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Helpers.showSnackBar(
        context,
        context.l10n.translate(
          'trip.optimizeError',
          args: {'error': e.toString()},
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = false;
        });
      }
    }
  }

  PathDistanceCalculator _buildDistanceCalculator(OfflineGraphData? graph) {
    final cache = <String, double>{};
    return (Pagoda a, Pagoda b) {
      final key = a.id.compareTo(b.id) <= 0
          ? '${a.id}|${b.id}'
          : '${b.id}|${a.id}';
      final cached = cache[key];
      if (cached != null) {
        return cached;
      }

      final distance = _graphAwareDistanceBetween(a, b, graph);

      cache[key] = distance;
      return distance;
    };
  }

  /// Pre-computes every pair using the same road-ferry-road plan shown on the
  /// map. This lets the normal nearest-neighbour + 2-opt optimizer place a
  /// ferry stop sensibly instead of refusing to optimize the whole journey.
  Future<PathDistanceCalculator> _buildFerryAwareDistanceCalculator(
    List<Pagoda> pagodas,
  ) async {
    final distances = <String, double>{};
    final graph = await OfflineRouteService.instance.loadGraph();

    String keyFor(Pagoda a, Pagoda b) =>
        a.id.compareTo(b.id) <= 0 ? '${a.id}|${b.id}' : '${b.id}|${a.id}';

    for (var index = 0; index < pagodas.length; index++) {
      for (
        var otherIndex = index + 1;
        otherIndex < pagodas.length;
        otherIndex++
      ) {
        final from = pagodas[index];
        final to = pagodas[otherIndex];
        final hasFerry = await MultimodalRouteService.instance.routeUsesFerry([
          from.id,
          to.id,
        ]);
        if (!hasFerry) {
          distances[keyFor(from, to)] = _graphAwareDistanceBetween(
            from,
            to,
            graph,
          );
          continue;
        }

        final plan = await MultimodalRouteService.instance.buildPlan(
          RouteEndpoint(
            pagodaId: from.id,
            location: LatLng(from.latitude, from.longitude),
          ),
          RouteEndpoint(
            pagodaId: to.id,
            location: LatLng(to.latitude, to.longitude),
          ),
        );
        distances[keyFor(from, to)] = plan.distanceKm;
      }
    }

    return (Pagoda a, Pagoda b) {
      final distance = distances[keyFor(a, b)];
      if (distance != null && distance > 0) {
        return distance;
      }
      return Helpers.calculateDistance(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
    };
  }

  double _graphAwareDistanceBetween(
    Pagoda from,
    Pagoda to,
    OfflineGraphData? graph,
  ) {
    if (graph != null) {
      final graphDistance = OfflineRouteService.instance.estimateGraphDistance(
        graph,
        LatLng(from.latitude, from.longitude),
        LatLng(to.latitude, to.longitude),
      );
      if (graphDistance != null) {
        return graphDistance;
      }
    }

    return Helpers.calculateDistance(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final horizontalPadding = MediaQuery.sizeOf(context).width < 400
        ? 24.0
        : 36.0;
    final isLoggedIn = context.select<AuthProvider, bool>(
      (auth) => auth.user != null,
    );
    final isEditing = widget.existingTrip != null;

    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.translate(isEditing ? 'trip.editTitle' : 'trip.createTitle'),
          ),
          actions: [
            IconButton(
              onPressed: () => AIAssistantLauncher.open(
                context,
                entryContext: widget.existingTrip != null
                    ? AIEntryContext.trip(widget.existingTrip!.id)
                    : widget.initialPagoda != null
                    ? AIEntryContext.pagoda(widget.initialPagoda!.id)
                    : const AIEntryContext.global(),
              ),
              icon: const Icon(Icons.support_agent_outlined),
              tooltip: l10n.translate('chat.fabLabel'),
            ),
          ],
        ),
        body: SignInRequiredView(
          icon: Icons.route,
          message: l10n.translate('trips.signInPrompt'),
          onSignIn: () {
            AuthGate.openSignIn(context);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F2E9),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2B1D14), size: 31),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          l10n.translate(
            isEditing ? 'trip.journalEditTitle' : 'trip.journalNewTitle',
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isCalculatingRoute)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveTrip,
              child: Text(
                l10n.translate(isEditing ? 'common.update' : 'common.save'),
                style: const TextStyle(
                  color: Color(0xFFC19A49),
                  fontSize: 16,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ResponsiveContent(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              44,
              horizontalPadding,
              36,
            ),
            children: [
              _JourneyLabel(l10n.translate('trip.nameLabel')),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: l10n.translate('trip.nameHint'),
                  hintStyle: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 23,
                    color: Color(0xFFC8BEB5),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.translate('trip.nameRequired');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 52),
              Row(
                children: [
                  Expanded(
                    child: _JourneyDateTime(
                      label: l10n.translate('trip.date'),
                      icon: Icons.calendar_today_outlined,
                      value: Helpers.formatDate(_selectedDate),
                      onTap: () => _selectDate(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _JourneyDateTime(
                      label: l10n.translate('trip.startTime'),
                      icon: Icons.access_time_rounded,
                      value: _selectedStartTime.format(context),
                      onTap: () => _selectStartTime(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 58),
              _JourneyLabel(l10n.translate('trip.transportMode')),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _TransportChip(
                      label: l10n.translate('trip.transportMode.bike'),
                      icon: Icons.electric_bike_outlined,
                      selected:
                          _selectedTransportMode == TripTransportMode.bike,
                      onTap: () => setState(
                        () => _selectedTransportMode = TripTransportMode.bike,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TransportChip(
                      label: l10n.translate('trip.transportMode.car'),
                      icon: Icons.directions_car_outlined,
                      selected: _selectedTransportMode == TripTransportMode.car,
                      onTap: () => setState(
                        () => _selectedTransportMode = TripTransportMode.car,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TransportChip(
                      label: l10n.translate('trip.transportMode.walk'),
                      icon: Icons.directions_walk_rounded,
                      selected:
                          _selectedTransportMode == TripTransportMode.walk,
                      onTap: () => setState(
                        () => _selectedTransportMode = TripTransportMode.walk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 58),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _JourneyLabel(l10n.translate('trip.stops')),
                  TextButton.icon(
                    onPressed: () => _showPagodaSelector(context),
                    icon: const Icon(Icons.add, color: Color(0xFFC19A49)),
                    label: Text(
                      l10n.translate('trip.addStop'),
                      style: const TextStyle(
                        letterSpacing: 2,
                        color: Color(0xFFC19A49),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isCalculatingRoute ? null : _optimizeRoute,
                  icon: _isCalculatingRoute
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.route, size: 18),
                  label: Text(
                    l10n.translate(
                      _isCalculatingRoute ? 'trip.optimizing' : 'trip.optimize',
                    ),
                  ),
                ),
              ),
              if (_selectedPagodas.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.translate('trip.noneSelected'),
                      style: const TextStyle(color: Color(0xFF756159)),
                    ),
                  ),
                )
              else
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = _selectedPagodas.removeAt(oldIndex);
                      _selectedPagodas.insert(newIndex, item);
                    });
                  },
                  children: _selectedPagodas.asMap().entries.map((entry) {
                    final index = entry.key;
                    final pagoda = entry.value;
                    return Container(
                      key: ValueKey(pagoda.id),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .62),
                        border: Border.all(color: const Color(0xFFE5D0A3)),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.drag_indicator_rounded,
                          color: Color(0xFFD6CBC1),
                        ),
                        title: Text(
                          l10n.pagodaName(
                            pagoda.id,
                            pagoda.name,
                            remoteMyanmar: pagoda.nameMyanmar,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF5C4B42),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFFD6CBC1),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedPagodas.removeAt(index);
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showPagodaSelector(context),
                icon: const Icon(Icons.location_on_outlined),
                label: Text(
                  l10n.translate('trip.addFromMap'),
                  style: const TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  side: const BorderSide(color: Color(0xFFDABF85)),
                ),
              ),
              const SizedBox(height: 84),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isCalculatingRoute ? null : _saveTrip,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFAE5038),
                    padding: const EdgeInsets.symmetric(vertical: 23),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n.translate(
                      isEditing ? 'trip.updateJourney' : 'trip.createJourney',
                    ),
                    style: const TextStyle(
                      letterSpacing: 2.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPagodaSelector(BuildContext context) async {
    final provider = context.read<PagodaProvider>();
    final allPagodas = provider.allPagodas;
    final l10n = context.l10n;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.translate('trip.selectPagodas'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.translate('common.done')),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: allPagodas.length,
                  itemBuilder: (context, index) {
                    final pagoda = allPagodas[index];
                    final isSelected = _selectedPagodas.any(
                      (p) => p.id == pagoda.id,
                    );

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setModalState(() {
                          if (value == true) {
                            _selectedPagodas.add(pagoda);
                          } else {
                            _selectedPagodas.removeWhere(
                              (p) => p.id == pagoda.id,
                            );
                          }
                        });
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      title: Text(
                        l10n.pagodaName(
                          pagoda.id,
                          pagoda.name,
                          remoteMyanmar: pagoda.nameMyanmar,
                        ),
                      ),
                      secondary: const Icon(Icons.temple_buddhist),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyLabel extends StatelessWidget {
  const _JourneyLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 15,
      letterSpacing: 2.5,
      color: Color(0xFF786A63),
      fontWeight: FontWeight.w800,
    ),
  );
}

class _JourneyDateTime extends StatelessWidget {
  const _JourneyDateTime({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 1.5,
          color: Color(0xFF786A63),
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: onTap,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF625C58)),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFD0AA58), size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    color: Color(0xFF2B1D14),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _TransportChip extends StatelessWidget {
  const _TransportChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      height: 64,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2B1D14) : Colors.transparent,
        border: Border.all(
          color: selected ? const Color(0xFF2B1D14) : const Color(0xFFE3CD99),
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF2B1D14),
              size: 20,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : const Color(0xFF2B1D14),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
