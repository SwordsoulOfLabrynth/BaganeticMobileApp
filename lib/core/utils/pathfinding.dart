import '../../data/models/pagoda_model.dart';
import 'helpers.dart';

typedef PathDistanceCalculator = double Function(Pagoda a, Pagoda b);

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
  static const double _improvementEpsilonKm = 0.0005;

  static List<Pagoda> findPath(
    Pagoda start,
    Pagoda goal,
    List<Pagoda> allPagodas, {
    double neighborRadiusKm = _defaultNeighborRadiusKm,
    int fallbackNeighborCount = _fallbackNeighborCount,
  }) {
    // Create nodes map
    final Map<String, PathNode> nodes = {};
    for (var pagoda in allPagodas) {
      nodes[pagoda.id] = PathNode(pagoda: pagoda);
    }

    // Initialize start node
    final startNode = nodes[start.id]!;
    startNode.g = 0;
    startNode.h = Helpers.calculateDistance(
      start.latitude,
      start.longitude,
      goal.latitude,
      goal.longitude,
    );

    // Priority queue (open set). We push updated priorities as new items and
    // skip stale entries on pop, so no full-queue resort is needed.
    final openSet = PriorityQueue<_PathQueueItem>((a, b) {
      return a.fScore.compareTo(b.fScore);
    });
    openSet.add(_PathQueueItem(nodeId: start.id, fScore: startNode.f));

    final Set<String> closedSet = {};

    while (openSet.isNotEmpty) {
      final currentItem = openSet.removeFirst();
      final current = nodes[currentItem.nodeId];
      if (current == null) {
        continue;
      }
      if (closedSet.contains(current.pagoda.id)) {
        continue;
      }
      if (currentItem.fScore > current.f + _improvementEpsilonKm) {
        // Stale queue item.
        continue;
      }

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

          openSet.add(
            _PathQueueItem(nodeId: neighbor.pagoda.id, fScore: neighbor.f),
          );
        }
      }
    }

    // No path found, return empty list
    return [];
  }

  static List<PathNode> _getNeighbors(
    Pagoda current,
    List<Pagoda> allPagodas,
    Map<String, PathNode> nodes, {
    double neighborRadiusKm = _defaultNeighborRadiusKm,
    int fallbackNeighborCount = _fallbackNeighborCount,
  }) {
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

  static List<Pagoda> optimizeRouteOrder(
    List<Pagoda> pagodas, {
    bool keepFirst = true,
    int maxIterations = 200,
    PathDistanceCalculator? distanceCalculator,
  }) {
    if (pagodas.length <= 2) return pagodas;

    final distance = distanceCalculator ?? _haversineDistance;

    // Build initial order using nearest-neighbor heuristic.
    final initial = keepFirst
        ? _nearestNeighborOrder(pagodas.first, pagodas, distance: distance)
        : _nearestNeighborOrder(
            _chooseStartForFreeRoute(pagodas),
            pagodas,
            distance: distance,
          );

    // Improve with 2-opt local search.
    final optimized = List<Pagoda>.from(initial);
    final int n = optimized.length;
    // Start from index 1 when keepFirst to preserve the first stop.
    final int startIdx = keepFirst ? 1 : 0;
    int iterations = 0;
    bool improved = true;

    while (improved && iterations < maxIterations) {
      improved = false;
      iterations += 1;
      for (int i = startIdx; i < n - 1; i++) {
        for (int k = i + 1; k < n; k++) {
          final delta = _twoOptDelta(optimized, i, k, distance);
          if (delta < -_improvementEpsilonKm) {
            _reverseSegment(optimized, i, k);
            improved = true;
          }
        }
      }
    }

    return optimized;
  }

  static List<Pagoda> _nearestNeighborOrder(
    Pagoda start,
    List<Pagoda> candidates, {
    required PathDistanceCalculator distance,
  }) {
    final List<Pagoda> ordered = [start];
    final List<Pagoda> pool = candidates
        .where((pagoda) => pagoda.id != start.id)
        .toList();

    while (pool.isNotEmpty) {
      final current = ordered.last;
      double minDistance = double.infinity;
      Pagoda? nearest;
      for (final pagoda in pool) {
        final currentDistance = distance(current, pagoda);
        if (currentDistance < minDistance) {
          minDistance = currentDistance;
          nearest = pagoda;
        }
      }
      if (nearest == null) {
        break;
      }
      ordered.add(nearest);
      pool.remove(nearest);
    }

    return ordered;
  }

  static Pagoda _chooseStartForFreeRoute(List<Pagoda> pagodas) {
    if (pagodas.length <= 1) {
      return pagodas.first;
    }

    final centroidLat =
        pagodas.fold<double>(0, (sum, pagoda) => sum + pagoda.latitude) /
        pagodas.length;
    final centroidLon =
        pagodas.fold<double>(0, (sum, pagoda) => sum + pagoda.longitude) /
        pagodas.length;

    Pagoda best = pagodas.first;
    double bestDistance = double.infinity;
    for (final pagoda in pagodas) {
      final centroidDistance = Helpers.calculateDistance(
        pagoda.latitude,
        pagoda.longitude,
        centroidLat,
        centroidLon,
      );
      if (centroidDistance < bestDistance) {
        bestDistance = centroidDistance;
        best = pagoda;
      }
    }

    return best;
  }

  static double _twoOptDelta(
    List<Pagoda> route,
    int i,
    int k,
    PathDistanceCalculator distance,
  ) {
    final Pagoda b = route[i];
    final Pagoda c = route[k];
    final Pagoda? a = i > 0 ? route[i - 1] : null;
    final Pagoda? d = (k + 1 < route.length) ? route[k + 1] : null;

    var oldDistance = 0.0;
    var newDistance = 0.0;

    if (a != null) {
      oldDistance += distance(a, b);
      newDistance += distance(a, c);
    }
    if (d != null) {
      oldDistance += distance(c, d);
      newDistance += distance(b, d);
    }

    return newDistance - oldDistance;
  }

  static void _reverseSegment(List<Pagoda> route, int i, int k) {
    while (i < k) {
      final temp = route[i];
      route[i] = route[k];
      route[k] = temp;
      i++;
      k--;
    }
  }

  static double _haversineDistance(Pagoda a, Pagoda b) {
    return Helpers.calculateDistance(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  static double calculatePathDistance(
    List<Pagoda> path, {
    PathDistanceCalculator? distanceCalculator,
  }) {
    if (path.length < 2) return 0;
    final distance = distanceCalculator ?? _haversineDistance;

    double totalDistance = 0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += distance(path[i], path[i + 1]);
    }

    return totalDistance;
  }
}

/// Binary min-heap priority queue – O(log n) insert and extract-min.
class PriorityQueue<T> {
  final List<T> _items = [];
  final Comparator<T> _comparator;

  PriorityQueue(this._comparator);

  void add(T item) {
    _items.add(item);
    _siftUp(_items.length - 1);
  }

  T removeFirst() {
    final first = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _siftDown(0);
    }
    return first;
  }

  bool get isNotEmpty => _items.isNotEmpty;

  void _siftUp(int index) {
    while (index > 0) {
      final parent = (index - 1) ~/ 2;
      if (_comparator(_items[index], _items[parent]) >= 0) break;
      _swap(index, parent);
      index = parent;
    }
  }

  void _siftDown(int index) {
    final length = _items.length;
    while (true) {
      int smallest = index;
      final left = 2 * index + 1;
      final right = 2 * index + 2;
      if (left < length && _comparator(_items[left], _items[smallest]) < 0) {
        smallest = left;
      }
      if (right < length && _comparator(_items[right], _items[smallest]) < 0) {
        smallest = right;
      }
      if (smallest == index) break;
      _swap(index, smallest);
      index = smallest;
    }
  }

  void _swap(int a, int b) {
    final temp = _items[a];
    _items[a] = _items[b];
    _items[b] = temp;
  }
}

class _PathQueueItem {
  final String nodeId;
  final double fScore;

  const _PathQueueItem({required this.nodeId, required this.fScore});
}
