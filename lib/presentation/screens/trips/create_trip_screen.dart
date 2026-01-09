import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
import '../../../data/models/pagoda_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/pathfinding.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<Pagoda> _selectedPagodas = [];
  bool _isCalculatingRoute = false;
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      Helpers.showSnackBar(context, 'Please select at least one pagoda', isError: true);
      return;
    }
    
    setState(() {
      _isCalculatingRoute = true;
    });
    
    try {
      // Create trip stops
      List<TripStop> stops = [];
      for (int i = 0; i < _selectedPagodas.length; i++) {
        final pagoda = _selectedPagodas[i];
        double? distanceToNext;
        
        if (i < _selectedPagodas.length - 1) {
          final nextPagoda = _selectedPagodas[i + 1];
          distanceToNext = Helpers.calculateDistance(
            pagoda.latitude,
            pagoda.longitude,
            nextPagoda.latitude,
            nextPagoda.longitude,
          );
        }
        
        stops.add(TripStop(
          pagodaId: pagoda.id,
          pagodaName: pagoda.name,
          latitude: pagoda.latitude,
          longitude: pagoda.longitude,
          order: i,
          distanceToNext: distanceToNext,
        ));
      }
      
      final trip = Trip(
        id: const Uuid().v4(),
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        date: _selectedDate,
        stops: stops,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await context.read<TripProvider>().saveTrip(trip);
      
      if (mounted) {
        Helpers.showSnackBar(context, 'Trip saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error saving trip: $e', isError: true);
      }
    } finally {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
  }
  
  Future<void> _optimizeRoute() async {
    if (_selectedPagodas.length < 2) {
      Helpers.showSnackBar(
        context,
        'Select at least 2 pagodas to optimize route',
        isError: true,
      );
      return;
    }
    
    setState(() {
      _isCalculatingRoute = true;
    });
    
    try {
      final provider = context.read<PagodaProvider>();
      final allPagodas = provider.pagodas;
      
      if (_selectedPagodas.length == 2) {
        // Use A* for 2 pagodas
        final path = PathfindingService.findPath(
          _selectedPagodas[0],
          _selectedPagodas[1],
          allPagodas,
        );
        
        if (path.isNotEmpty) {
          setState(() {
            _selectedPagodas = path;
          });
          Helpers.showSnackBar(context, 'Route optimized!');
        }
      } else {
        // Simple nearest neighbor for multiple pagodas
        List<Pagoda> optimized = [_selectedPagodas[0]];
        List<Pagoda> remaining = List.from(_selectedPagodas.sublist(1));
        
        while (remaining.isNotEmpty) {
          final current = optimized.last;
          double minDistance = double.infinity;
          Pagoda? nearest;
          
          for (var pagoda in remaining) {
            final distance = Helpers.calculateDistance(
              current.latitude,
              current.longitude,
              pagoda.latitude,
              pagoda.longitude,
            );
            if (distance < minDistance) {
              minDistance = distance;
              nearest = pagoda;
            }
          }
          
          if (nearest != null) {
            optimized.add(nearest);
            remaining.remove(nearest);
          }
        }
        
        setState(() {
          _selectedPagodas = optimized;
        });
        Helpers.showSnackBar(context, 'Route optimized!');
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Error optimizing route: $e', isError: true);
    } finally {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Trip'),
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
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Trip Name',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a trip name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(Helpers.formatDate(_selectedDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDate(context),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Selected Pagodas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _optimizeRoute,
                  icon: const Icon(Icons.route),
                  label: const Text('Optimize'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedPagodas.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No pagodas selected',
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
                      title: Text(pagoda.name),
                      subtitle: Text(pagoda.category),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
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
              label: const Text('Add Pagodas'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showPagodaSelector(BuildContext context) async {
    final provider = context.read<PagodaProvider>();
    final allPagodas = provider.pagodas;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Pagodas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: allPagodas.length,
                itemBuilder: (context, index) {
                  final pagoda = allPagodas[index];
                  final isSelected = _selectedPagodas.any((p) => p.id == pagoda.id);
                  
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedPagodas.add(pagoda);
                        } else {
                          _selectedPagodas.removeWhere((p) => p.id == pagoda.id);
                        }
                      });
                      Navigator.pop(context);
                    },
                    title: Text(pagoda.name),
                    subtitle: Text(pagoda.category),
                    secondary: const Icon(Icons.temple_buddhist),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
