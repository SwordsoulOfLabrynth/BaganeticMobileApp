/**
 * Baganetic Pathfinder - Shortest Path Algorithm Implementation
 * Converts the Python A* algorithm to JavaScript for Node.js integration
 */

class PagodaPathFinder {
  constructor(graph) {
    this.graph = graph;
    this.pathCache = {}; // Cache for faster repeated queries
  }

  /**
   * Calculate the great circle distance between two points (km)
   * Using Haversine formula
   */
  haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth radius in km
    const dLat = this.toRadians(lat2 - lat1);
    const dLon = this.toRadians(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRadians(lat1)) *
        Math.cos(this.toRadians(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  toRadians(degrees) {
    return degrees * (Math.PI / 180);
  }

  /**
   * A* algorithm to find shortest path between pagodas
   */
  findPathAStar(start, goal) {
    // Check cache first
    const cacheKey = `${start}-${goal}`;
    if (this.pathCache[cacheKey]) {
      return this.pathCache[cacheKey];
    }

    const openSet = [];
    const closedSet = new Set();
    const cameFrom = {};
    const gScore = {};
    const fScore = {};

    // Initialize scores
    for (const node in this.graph) {
      gScore[node] = Infinity;
      fScore[node] = Infinity;
    }

    gScore[start] = 0;
    fScore[start] = this._heuristic(start, goal);

    // Add start node to open set
    openSet.push({ node: start, fScore: fScore[start] });

    while (openSet.length > 0) {
      // Find node with lowest fScore (more efficient than sorting)
      let minIndex = 0;
      for (let i = 1; i < openSet.length; i++) {
        if (openSet[i].fScore < openSet[minIndex].fScore) {
          minIndex = i;
        }
      }
      const current = openSet.splice(minIndex, 1)[0];
      
      // Skip if already processed
      if (closedSet.has(current.node)) {
        continue;
      }
      
      closedSet.add(current.node);

      if (current.node === goal) {
        // Reconstruct path
        const path = [];
        let node = goal;
        while (node !== undefined) {
          path.unshift(node);
          node = cameFrom[node];
        }

        // Cache the result
        this.pathCache[cacheKey] = path;
        return path;
      }

      // Check neighbors
      const neighbors = this.graph[current.node].neighbors || {};
      for (const neighbor in neighbors) {
        if (closedSet.has(neighbor)) {
          continue;
        }
        
        const neighborData = neighbors[neighbor];
        const tentativeGScore = gScore[current.node] + neighborData.g;

        if (tentativeGScore < gScore[neighbor]) {
          cameFrom[neighbor] = current.node;
          gScore[neighbor] = tentativeGScore;
          fScore[neighbor] = tentativeGScore + this._heuristic(neighbor, goal);

          // Add to open set if not already there
          if (!openSet.find((item) => item.node === neighbor)) {
            openSet.push({ node: neighbor, fScore: fScore[neighbor] });
          }
        }
      }
    }

    return null; // No path found
  }

  /**
   * Calculate heuristic (straight-line distance) for A* algorithm
   */
  _heuristic(node, goal) {
    if (!this.graph[node] || !this.graph[goal]) {
      return Infinity;
    }
    
    const nodeLoc = this.graph[node].location;
    const goalLoc = this.graph[goal].location;
    
    return this.haversineDistance(
      nodeLoc.lat, nodeLoc.lng,
      goalLoc.lat, goalLoc.lng
    );
  }

  /**
   * Calculate the total distance of a path
   */
  calculatePathDistance(path) {
    if (!path || path.length < 2) {
      return 0;
    }

    let total = 0;
    for (let i = 0; i < path.length - 1; i++) {
      const current = path[i];
      const next = path[i + 1];
      const neighbors = this.graph[current].neighbors || {};
      if (neighbors[next]) {
        total += neighbors[next].g;
      }
    }
    return total;
  }

  /**
   * Find pagodas near the given path
   */
  findNearbyPagodas(path, maxDistance = 1.0) {
    if (!path || path.length === 0) {
      return [];
    }

    // Convert path nodes to coordinates
    const pathCoords = path.map((pagoda) => {
      const location = this.graph[pagoda].location;
      return [location.lat, location.lng];
    });

    const nearby = [];
    for (const pagoda in this.graph) {
      if (path.includes(pagoda)) {
        continue; // Skip pagodas already in the path
      }

      const location = this.graph[pagoda].location;
      let minDist = Infinity;

      // Find minimum distance to path
      for (let i = 0; i < pathCoords.length - 1; i++) {
        const dist = this.pointToLineDistance(
          [location.lat, location.lng],
          pathCoords[i],
          pathCoords[i + 1]
        );
        minDist = Math.min(minDist, dist);
      }

      if (minDist <= maxDistance) {
        nearby.push({
          name: pagoda,
          distance: minDist,
          location: location,
        });
      }
    }

    return nearby.sort((a, b) => a.distance - b.distance);
  }

  /**
   * Approximate distance from a point to a line segment in km
   */
  pointToLineDistance(point, lineStart, lineEnd) {
    const distStart = this.haversineDistance(
      point[0],
      point[1],
      lineStart[0],
      lineStart[1]
    );
    const distEnd = this.haversineDistance(
      point[0],
      point[1],
      lineEnd[0],
      lineEnd[1]
    );
    return Math.min(distStart, distEnd);
  }

  /**
   * Get all available pagodas for pathfinding
   */
  getAvailablePagodas() {
    return Object.keys(this.graph).map((name) => ({
      name: name,
      location: this.graph[name].location,
    }));
  }
}

/**
 * Create pagoda graph from the existing pagoda database
 * This function converts the pagoda data into a graph structure suitable for pathfinding
 */
function createPagodaGraph(pagodaData) {
  const graph = {};

  // Initialize graph with pagoda locations
  pagodaData.forEach((pagoda) => {
    const name = pagoda.name;
    graph[name] = {
      heuristic: 0.0, // Will be calculated dynamically
      location: {
        lat: pagoda.location.coordinates.lat,
        lng: pagoda.location.coordinates.lng,
      },
      neighbors: {},
    };
  });

  // Calculate distances and create connections
  const pagodaNames = Object.keys(graph);

  for (let i = 0; i < pagodaNames.length; i++) {
    for (let j = i + 1; j < pagodaNames.length; j++) {
      const pagoda1 = pagodaNames[i];
      const pagoda2 = pagodaNames[j];

      const loc1 = graph[pagoda1].location;
      const loc2 = graph[pagoda2].location;

      // Calculate distance using Haversine formula
      const distance = calculateDistance(
        loc1.lat,
        loc1.lng,
        loc2.lat,
        loc2.lng
      );

      // Only connect pagodas that are reasonably close (within 10km)
      if (distance <= 10) {
        // Add bidirectional connection
        graph[pagoda1].neighbors[pagoda2] = { g: distance, h: 0 };
        graph[pagoda2].neighbors[pagoda1] = { g: distance, h: 0 };
      }
    }
  }

  return graph;
}

/**
 * Calculate distance between two coordinates using Haversine formula
 */
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // Earth radius in km
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}

// Export for Node.js
if (typeof module !== "undefined" && module.exports) {
  module.exports = { PagodaPathFinder, createPagodaGraph };
}
