"""
Improved Baganetic Pathfinder
Creates a more realistic road network for Bagan pagodas
"""

import math
import heapq
from typing import List, Dict, Tuple, Optional
from road_routing import road_router

class ImprovedPagodaPathFinder:
    """
    Improved pathfinder with realistic road network connections
    """
    
    def __init__(self, pagoda_data: List[Dict]):
        self.pagoda_data = pagoda_data
        self.graph = self._build_realistic_graph()
        self.path_cache = {}
    
    def _build_realistic_graph(self):
        """
        Build a more realistic graph based on actual road patterns in Bagan
        """
        graph = {}
        
        # Initialize all pagodas
        for pagoda in self.pagoda_data:
            name = pagoda['name']
            graph[name] = {
                'location': pagoda['location']['coordinates'],
                'neighbors': {}
            }
        
        # Define realistic road connections based on actual Bagan road network
        # These are based on the main roads and paths that connect pagodas
        road_connections = {
            # Central area connections (main temple complex)
            'Ananda Temple': ['Thatbyinnyu Temple', 'Gawdawpalin Temple', 'Shwe Gu Gyi', 'Mahazedi Pagoda', 'Dhammayangyi Temple', 'Sulamani Temple'],
            'Thatbyinnyu Temple': ['Ananda Temple', 'Gawdawpalin Temple', 'Shwe Gu Gyi', 'Mahazedi Pagoda', 'Htilominlo Temple'],
            'Gawdawpalin Temple': ['Ananda Temple', 'Thatbyinnyu Temple', 'BuPaya Pagoda', 'Shwe Gu Gyi', 'Mahazedi Pagoda'],
            'Shwe Gu Gyi': ['Ananda Temple', 'Thatbyinnyu Temple', 'Gawdawpalin Temple', 'Mahazedi Pagoda', 'Dhammayangyi Temple'],
            'Mahazedi Pagoda': ['Ananda Temple', 'Thatbyinnyu Temple', 'Shwe Gu Gyi', 'BuPaya Pagoda', 'Dhammayangyi Temple'],
            'BuPaya Pagoda': ['Gawdawpalin Temple', 'Mahazedi Pagoda', 'Lawkananda Pagoda', 'Dhammayangyi Temple'],
            
            # Eastern area connections
            'Dhammayangyi Temple': ['Ananda Temple', 'Sulamani Temple', 'Manuha Temple', 'Gu Byauk Gyi Pagoda', 'Shwe Gu Gyi', 'Mahazedi Pagoda', 'BuPaya Pagoda'],
            'Sulamani Temple': ['Ananda Temple', 'Dhammayangyi Temple', 'Manuha Temple', 'Gu Byauk Gyi Pagoda', 'Pyathetgyi Temple', 'Thambula Temple'],
            'Manuha Temple': ['Dhammayangyi Temple', 'Sulamani Temple', 'Gu Byauk Gyi Pagoda', 'Sein Nyet NyiAma Gu Phaya'],
            'Gu Byauk Gyi Pagoda': ['Dhammayangyi Temple', 'Sulamani Temple', 'Manuha Temple', 'Sein Nyet NyiAma Gu Phaya', 'Pyathetgyi Temple'],
            'Sein Nyet NyiAma Gu Phaya': ['Gu Byauk Gyi Pagoda', 'Pyathetgyi Temple', 'Manuha Temple'],
            'Pyathetgyi Temple': ['Sulamani Temple', 'Sein Nyet NyiAma Gu Phaya', 'Dhammayazaka Pagoda', 'Gu Byauk Gyi Pagoda', 'Thambula Temple'],
            'Dhammayazaka Pagoda': ['Pyathetgyi Temple', 'Lawkananda Pagoda', 'Thambula Temple'],
            
            # Northern area connections
            'Shwezigon Pagoda': ['Htilominlo Temple', 'Alodawpyae Pagoda', 'Thatbyinnyu Temple'],
            'Htilominlo Temple': ['Shwezigon Pagoda', 'Alodawpyae Pagoda', 'Thatbyinnyu Temple'],
            'Alodawpyae Pagoda': ['Shwezigon Pagoda', 'Htilominlo Temple', 'Thatbyinnyu Temple'],
            
            # Southern area connections
            'Lawkananda Pagoda': ['BuPaya Pagoda', 'Dhammayazaka Pagoda', 'Thambula Temple'],
            'Thambula Temple': ['Lawkananda Pagoda', 'Iza Gawna Pagoda', 'Sulamani Temple', 'Pyathetgyi Temple', 'Dhammayazaka Pagoda'],
            'Iza Gawna Pagoda': ['Thambula Temple']
        }
        
        # Build the graph with realistic distances
        for pagoda, connections in road_connections.items():
            if pagoda in graph:
                for connected_pagoda in connections:
                    if connected_pagoda in graph:
                        distance = self._calculate_realistic_distance(
                            graph[pagoda]['location'],
                            graph[connected_pagoda]['location']
                        )
                        graph[pagoda]['neighbors'][connected_pagoda] = distance
                        # Ensure bidirectional connectivity
                        if 'neighbors' not in graph[connected_pagoda]:
                            graph[connected_pagoda]['neighbors'] = {}
                        graph[connected_pagoda]['neighbors'][pagoda] = distance
        
        # Augment graph with nearest-neighbor connections to reduce detours
        nearest_neighbors_k = 3
        nearest_max_km = 5.0
        names = list(graph.keys())
        for i, a in enumerate(names):
            loc_a = graph[a]['location']
            # distances to others
            dists = []
            for j, b in enumerate(names):
                if a == b:
                    continue
                loc_b = graph[b]['location']
                d = self._haversine_distance(loc_a['lat'], loc_a['lng'], loc_b['lat'], loc_b['lng'])
                dists.append((d, b))
            dists.sort(key=lambda x: x[0])
            for d, b in dists[:nearest_neighbors_k]:
                if d <= nearest_max_km and b not in graph[a]['neighbors']:
                    dist = self._calculate_realistic_distance(loc_a, graph[b]['location'])
                    graph[a]['neighbors'][b] = dist
                    graph[b]['neighbors'][a] = dist
        
        return graph
    
    def _calculate_realistic_distance(self, loc1: Dict, loc2: Dict) -> float:
        """
        Calculate realistic road distance between two pagodas
        """
        # Get straight-line distance
        straight_distance = self._haversine_distance(
            loc1['lat'], loc1['lng'],
            loc2['lat'], loc2['lng']
        )
        
        # Apply road factor based on distance
        # Longer distances have higher road factors due to road curvature
        if straight_distance < 0.5:
            road_factor = 1.1  # Very close, mostly straight paths
        elif straight_distance < 1.0:
            road_factor = 1.2  # Short distances, minor detours
        elif straight_distance < 2.0:
            road_factor = 1.3  # Medium distances, some road curves
        else:
            road_factor = 1.4  # Longer distances, more road curvature
        
        return straight_distance * road_factor
    
    def _haversine_distance(self, lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """Calculate great circle distance between two points in km"""
        R = 6371  # Earth radius in km
        
        dlat = math.radians(lat2 - lat1)
        dlng = math.radians(lng2 - lng1)
        
        a = (math.sin(dlat / 2) * math.sin(dlat / 2) +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
             math.sin(dlng / 2) * math.sin(dlng / 2))
        
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c
    
    def find_path_astar(self, start: str, goal: str) -> Optional[List[str]]:
        """
        Find shortest path using A* algorithm with proper heuristic
        """
        if start not in self.graph or goal not in self.graph:
            return None
        
        # Check cache first
        cache_key = f"{start}-{goal}"
        if cache_key in self.path_cache:
            return self.path_cache[cache_key]
        
        # A* algorithm implementation
        closed_set = set()
        came_from = {}
        g_score = {node: float('inf') for node in self.graph}
        g_score[start] = 0
        f_score = {node: float('inf') for node in self.graph}
        f_score[start] = self._heuristic(start, goal)
        open_set = [(f_score[start], start)]
        
        while open_set:
            current = heapq.heappop(open_set)[1]
            
            # Skip if already processed
            if current in closed_set:
                continue
                
            closed_set.add(current)
            
            if current == goal:
                # Reconstruct path
                path = []
                while current in came_from:
                    path.append(current)
                    current = came_from[current]
                path.append(start)
                path.reverse()
                
                # Cache the result
                self.path_cache[cache_key] = path
                return path
            
            # Check neighbors
            neighbors = self.graph.get(current, {}).get('neighbors', {})
            for neighbor, distance in neighbors.items():
                if neighbor in closed_set:
                    continue
                    
                tentative_g_score = g_score[current] + distance
                
                if tentative_g_score < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g_score
                    f_score[neighbor] = tentative_g_score + self._heuristic(neighbor, goal)
                    # Always push; skip stale entries when popped
                    heapq.heappush(open_set, (f_score[neighbor], neighbor))
        
        return None
    
    def _heuristic(self, node: str, goal: str) -> float:
        """Heuristic function for A* (straight-line distance)"""
        if node not in self.graph or goal not in self.graph:
            return float('inf')
        
        loc1 = self.graph[node]['location']
        loc2 = self.graph[goal]['location']
        
        return self._haversine_distance(
            loc1['lat'], loc1['lng'],
            loc2['lat'], loc2['lng']
        )
    
    def calculate_path_distance(self, path: List[str]) -> float:
        """Calculate total distance of a path"""
        if len(path) < 2:
            return 0.0
        
        total_distance = 0.0
        for i in range(len(path) - 1):
            current = path[i]
            next_pagoda = path[i + 1]
            
            if current in self.graph and next_pagoda in self.graph[current]['neighbors']:
                total_distance += self.graph[current]['neighbors'][next_pagoda]
            else:
                # Fallback to straight-line distance
                loc1 = self.graph[current]['location']
                loc2 = self.graph[next_pagoda]['location']
                total_distance += self._haversine_distance(
                    loc1['lat'], loc1['lng'],
                    loc2['lat'], loc2['lng']
                )
        
        return total_distance
    
    def find_nearby_pagodas(self, path: List[str], max_distance: float = 1.0) -> List[Dict]:
        """Find pagodas near the given path"""
        if not path:
            return []
        
        nearby = []
        path_coords = []
        
        # Get coordinates of path pagodas
        for pagoda in path:
            if pagoda in self.graph:
                loc = self.graph[pagoda]['location']
                path_coords.append((loc['lat'], loc['lng']))
        
        # Check all pagodas
        for pagoda_name in self.graph:
            if pagoda_name in path:
                continue  # Skip pagodas already in path
            
            loc = self.graph[pagoda_name]['location']
            min_distance = float('inf')
            
            # Find minimum distance to path
            for i in range(len(path_coords) - 1):
                distance = self._point_to_line_distance(
                    (loc['lat'], loc['lng']),
                    path_coords[i],
                    path_coords[i + 1]
                )
                min_distance = min(min_distance, distance)
            
            if min_distance <= max_distance:
                nearby.append({
                    'name': pagoda_name,
                    'distance': min_distance,
                    'location': loc
                })
        
        return sorted(nearby, key=lambda x: x['distance'])
    
    def _point_to_line_distance(self, point: Tuple[float, float], 
                               line_start: Tuple[float, float], 
                               line_end: Tuple[float, float]) -> float:
        """Calculate distance from a point to a line segment"""
        # Simplified point-to-line distance calculation
        dist_to_start = self._haversine_distance(
            point[0], point[1], line_start[0], line_start[1]
        )
        dist_to_end = self._haversine_distance(
            point[0], point[1], line_end[0], line_end[1]
        )
        
        return min(dist_to_start, dist_to_end)
    
    def get_enhanced_path_with_road_coordinates(self, start: str, end: str) -> Optional[Dict]:
        """
        Get enhanced path with real road-based coordinates for visualization
        """
        # Find the pagoda path using our A* algorithm
        pagoda_path = self.find_path_astar(start, end)
        if not pagoda_path:
            return None
        
        # Augment path with notable pagodas that are very close to the road between steps
        pagoda_path = self._augment_path_with_nearby_pagodas(pagoda_path, max_additions=3, threshold_km=0.35)
        
        # Get pagoda coordinates
        pagoda_coordinates = []
        for pagoda in pagoda_path:
            loc = self.graph[pagoda]['location']
            pagoda_coordinates.append({
                'lat': loc['lat'],
                'lng': loc['lng'],
                'name': pagoda
            })
        
        # Get real road-based coordinates
        try:
            road_coordinates = road_router.create_realistic_road_path(pagoda_coordinates)
            if not road_coordinates:
                # Fallback to simple interpolation if road routing fails
                road_coordinates = self._create_fallback_path(pagoda_coordinates)
        except Exception as e:
            print(f"Road routing failed: {e}")
            # Fallback to simple interpolation
            road_coordinates = self._create_fallback_path(pagoda_coordinates)
        
        # Calculate total distance using road coordinates
        total_distance = 0
        for i in range(len(road_coordinates) - 1):
            current = road_coordinates[i]
            next_coord = road_coordinates[i + 1]
            total_distance += self._haversine_distance(
                current['lat'], current['lng'],
                next_coord['lat'], next_coord['lng']
            )
        
        return {
            'path': pagoda_path,
            'coordinates': road_coordinates,
            'distance': total_distance,
            'distanceKm': total_distance,
            'pathLength': len(pagoda_path)
        }

    def _augment_path_with_nearby_pagodas(self, path: List[str], max_additions: int = 2, threshold_km: float = 0.3) -> List[str]:
        """Insert nearby pagodas that lie very close to any segment of the path.
        This makes the route pass by important pagodas along the road, when sensible.
        """
        if len(path) < 2:
            return path
        
        # Collect candidates not already in path
        candidates = []
        for name, data in self.graph.items():
            if name in path:
                continue
            candidates.append((name, data['location']))
        
        # For each segment, find closest candidates
        insertions = []  # list of tuples (segment_index_after, name, distance)
        for i in range(len(path) - 1):
            a = self.graph[path[i]]['location']
            b = self.graph[path[i + 1]]['location']
            for name, loc in candidates:
                d = self._point_to_line_distance((loc['lat'], loc['lng']), (a['lat'], a['lng']), (b['lat'], b['lng']))
                if d <= threshold_km:
                    insertions.append((i + 1, name, d))
        
        # Sort by closeness and insert up to max_additions without duplicates
        insertions.sort(key=lambda x: x[2])
        taken = set()
        offset = 0
        for idx, name, _ in insertions:
            if name in taken or name in path:
                continue
            path.insert(idx + offset, name)
            taken.add(name)
            offset += 1
            if len(taken) >= max_additions:
                break
        
        return path
    
    def _create_fallback_path(self, pagoda_coordinates: List[Dict]) -> List[Dict]:
        """Create a fallback path with simple interpolation if road routing fails"""
        if len(pagoda_coordinates) < 2:
            return pagoda_coordinates
        
        result = []
        
        for i in range(len(pagoda_coordinates) - 1):
            current = pagoda_coordinates[i]
            next_pagoda = pagoda_coordinates[i + 1]
            
            # Add the current pagoda
            result.append(current)
            
            # Add intermediate waypoints for better visualization
            intermediate_points = self._generate_road_waypoints(current, next_pagoda)
            result.extend(intermediate_points)
        
        # Add the final pagoda
        result.append(pagoda_coordinates[-1])
        
        return result
    
    def _generate_road_waypoints(self, start_loc: Dict, end_loc: Dict) -> List[Dict]:
        """Generate intermediate waypoints to simulate road curves"""
        waypoints = []
        
        # Calculate distance
        distance = self._haversine_distance(
            start_loc['lat'], start_loc['lng'],
            end_loc['lat'], end_loc['lng']
        )
        
        # Generate waypoints based on distance
        if distance < 0.5:
            # Very short distance, no intermediate points needed
            return waypoints
        
        # Generate 1-3 intermediate points
        num_points = min(max(1, int(distance / 0.8)), 3)
        
        for i in range(1, num_points + 1):
            ratio = i / (num_points + 1)
            
            # Add slight curve to simulate road behavior
            lat_offset = (hash(f"{start_loc['lat']}{end_loc['lat']}{i}") % 100 - 50) / 100000
            lng_offset = (hash(f"{start_loc['lng']}{end_loc['lng']}{i}") % 100 - 50) / 100000
            
            lat = start_loc['lat'] + (end_loc['lat'] - start_loc['lat']) * ratio + lat_offset
            lng = start_loc['lng'] + (end_loc['lng'] - start_loc['lng']) * ratio + lng_offset
            
            waypoints.append({
                'lat': lat,
                'lng': lng,
                'name': f"Waypoint {i}"
            })
        
        return waypoints
