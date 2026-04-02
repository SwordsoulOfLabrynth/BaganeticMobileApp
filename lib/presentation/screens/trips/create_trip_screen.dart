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
      // Create trip stops
      final List<TripStop> stops = [];
      for (int i = 0; i < _selectedPagodas.length; i++) {
        final pagoda = _selectedPagodas[i];
        double? distanceToNext;

        if (i < _selectedPagodas.length - 1) {
          final nextPagoda = _selectedPagodas[i + 1];
          distanceToNext = _graphAwareDistanceBetween(
            pagoda,
            nextPagoda,
            graph,
          );
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

      if (_selectedPagodas.length == 2) {
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
            context.l10n.translate('trip.noRouteFound'),
            isError: true,
          );
        }
      } else {
        final graph = await OfflineRouteService.instance.loadGraph();
        if (!mounted) return;
        final distanceCalculator = _buildDistanceCalculator(graph);

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
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ResponsiveContent(
          child: ListView(
            padding: Responsive.pagePadding(context),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.translate('trip.nameLabel'),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.translate('trip.nameRequired');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.translate('trip.descriptionOptional'),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(l10n.translate('trip.date')),
                subtitle: Text(Helpers.formatDate(_selectedDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectDate(context),
              ),
              const Divider(height: 32),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    l10n.translate('trip.selectedPagodas'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _optimizeRoute,
                    icon: const Icon(Icons.route),
                    label: Text(l10n.translate('trip.optimize')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedPagodas.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.translate('trip.noneSelected'),
                      style: TextStyle(color: Colors.grey[600]),
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
                    return Card(
                      key: ValueKey(pagoda.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFD4AF37),
                          child: Text('${index + 1}'),
                        ),
                        title: Text(l10n.pagodaName(pagoda.id, pagoda.name)),
                        subtitle: Text(l10n.categoryLabel(pagoda.category)),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
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
              ElevatedButton.icon(
                onPressed: () => _showPagodaSelector(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.translate('trip.addPagodas')),
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
                      title: Text(l10n.pagodaName(pagoda.id, pagoda.name)),
                      subtitle: Text(l10n.categoryLabel(pagoda.category)),
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
