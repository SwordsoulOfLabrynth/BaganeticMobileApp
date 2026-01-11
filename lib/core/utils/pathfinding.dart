import '../../data/models/pagoda_model.dart';
import 'helpers.dart';

class PathNode {
  final Pagoda pagoda;
  double g; // Cost from start
  double h; // Heuristic to goal
  PathNode? parent;
  
  PathNode({
    required this.pagoda,
    this.g = double.infinity,
    this.h = 0,
    this.parent,
  });
  
  double get f => g + h;
}

class PathfindingService {
  static const double _defaultNeighborRadiusKm = 5.0;
  static const int _fallbackNeighborCount = 3;

  static List<Pagoda> findPath(
    Pagoda start,
    Pagoda goal,
    List<Pagoda> allPagodas,
    {
    double neighborRadiusKm = _defaultNeighborRadiusKm,
    int fallbackNeighborCount = _fallbackNeighborCount,
    }
  ) {
    // Create nodes map
    Map<String, PathNode> nodes = {};
    for (var pagoda in allPagodas) {
      nodes[pagoda.id] = PathNode(pagoda: pagoda);
    }
    
    // Initialize start node
    var startNode = nodes[start.id]!;
    startNode.g = 0;
    startNode.h = Helpers.calculateDistance(
      start.latitude,
      start.longitude,
      goal.latitude,
      goal.longitude,
    );
    
    // Priority queue (open set)
    var openSet = PriorityQueue<PathNode>((a, b) => a.f.compareTo(b.f));
    openSet.add(startNode);
    
    Set<String> closedSet = {};
    
    while (openSet.isNotEmpty) {
      var current = openSet.removeFirst();
      
      // Check if we reached the goal
      if (current.pagoda.id == goal.id) {
        return _reconstructPath(current);
      }
      
      closedSet.add(current.pagoda.id);
      
      // Get neighbors (pagodas within 5km)
      var neighbors = _getNeighbors(
        current.pagoda,
        allPagodas,
        nodes,
        neighborRadiusKm: neighborRadiusKm,
        fallbackNeighborCount: fallbackNeighborCount,
      );
      
      for (var neighbor in neighbors) {
        if (closedSet.contains(neighbor.pagoda.id)) continue;
        
        double distance = Helpers.calculateDistance(
          current.pagoda.latitude,
          current.pagoda.longitude,
          neighbor.pagoda.latitude,
          neighbor.pagoda.longitude,
        );
        
        double tentativeG = current.g + distance;
        
        if (tentativeG < neighbor.g) {
          neighbor.parent = current;
          neighbor.g = tentativeG;
          neighbor.h = Helpers.calculateDistance(
            neighbor.pagoda.latitude,
            neighbor.pagoda.longitude,
            goal.latitude,
            goal.longitude,
          );
          
          if (!openSet.contains(neighbor)) {
            openSet.add(neighbor);
          } else {
            openSet.resort();
          }
        }
      }
    }
    
    // No path found, return empty list
    return [];
  }
  
  static List<PathNode> _getNeighbors(
    Pagoda current,
    List<Pagoda> allPagodas,
    Map<String, PathNode> nodes,
    {
    double neighborRadiusKm = _defaultNeighborRadiusKm,
    int fallbackNeighborCount = _fallbackNeighborCount,
    }
  ) {
    List<PathNode> neighbors = [];
    List<MapEntry<Pagoda, double>> candidates = [];
    
    for (var pagoda in allPagodas) {
      if (pagoda.id == current.id) continue;
      
      double distance = Helpers.calculateDistance(
        current.latitude,
        current.longitude,
        pagoda.latitude,
        pagoda.longitude,
      );
      
      // Only consider pagodas within 5km as neighbors
      if (distance <= neighborRadiusKm) {
        neighbors.add(nodes[pagoda.id]!);
      }

      candidates.add(MapEntry(pagoda, distance));
    }

    if (neighbors.isEmpty && fallbackNeighborCount > 0) {
      candidates.sort((a, b) => a.value.compareTo(b.value));
      for (final entry in candidates.take(fallbackNeighborCount)) {
        neighbors.add(nodes[entry.key.id]!);
      }
    }
    
    return neighbors;
  }
  
  static List<Pagoda> _reconstructPath(PathNode goalNode) {
    List<Pagoda> path = [];
    PathNode? current = goalNode;
    
    while (current != null) {
      path.insert(0, current.pagoda);
      current = current.parent;
    }
    
    return path;
  }
  
  static double calculatePathDistance(List<Pagoda> path) {
    if (path.length < 2) return 0;
    
    double totalDistance = 0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += Helpers.calculateDistance(
        path[i].latitude,
        path[i].longitude,
        path[i + 1].latitude,
        path[i + 1].longitude,
      );
    }
    
    return totalDistance;
  }
}

// Simple priority queue implementation
class PriorityQueue<T> {
  final List<T> _items = [];
  final Comparator<T> _comparator;
  
  PriorityQueue(this._comparator);
  
  void add(T item) {
    _items.add(item);
    _items.sort(_comparator);
  }

  void resort() {
    _items.sort(_comparator);
  }
  
  T removeFirst() {
    return _items.removeAt(0);
  }
  
  bool get isNotEmpty => _items.isNotEmpty;
  bool contains(T item) => _items.contains(item);
}
