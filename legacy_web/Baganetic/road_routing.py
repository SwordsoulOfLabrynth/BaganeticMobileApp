"""
Road Routing Module for Baganetic
Integrates with OpenStreetMap routing services to get actual road-based paths
"""

import requests
import math
from typing import List, Dict, Tuple, Optional
import time

class RoadRouter:
    """
    Handles road-based routing using OpenStreetMap routing services
    """
    
    def __init__(self):
        self.osrm_url = "http://router.project-osrm.org/route/v1/driving"
        self.graphhopper_url = "https://graphhopper.com/api/1/route"
        self.graphhopper_api_key = None  # You can add a GraphHopper API key for better routing
        
    def get_road_route(self, start_lat: float, start_lng: float, 
                      end_lat: float, end_lng: float) -> Optional[List[Dict]]:
        """
        Get road-based route between two points using OSRM
        """
        try:
            # Format coordinates for OSRM (longitude, latitude)
            start_coords = f"{start_lng},{start_lat}"
            end_coords = f"{end_lng},{end_lat}"
            
            url = f"{self.osrm_url}/{start_coords};{end_coords}"
            params = {
                'overview': 'full',
                'geometries': 'geojson',
                'steps': 'false',  # We don't need turn-by-turn instructions
                'annotations': 'false'
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get('code') == 'Ok' and data.get('routes'):
                route = data['routes'][0]
                geometry = route['geometry']
                
                # Convert GeoJSON coordinates to our format
                coordinates = []
                for coord in geometry['coordinates']:
                    coordinates.append({
                        'lng': coord[0],
                        'lat': coord[1],
                        'name': f"Road waypoint"
                    })
                
                return coordinates
            else:
                print(f"OSRM routing failed: {data.get('message', 'Unknown error')}")
                return None
                
        except requests.exceptions.RequestException as e:
            print(f"OSRM request failed: {e}")
            return None
        except Exception as e:
            print(f"Error getting road route: {e}")
            return None
    
    def get_multi_waypoint_route(self, coordinates: List[Tuple[float, float]]) -> Optional[List[Dict]]:
        """
        Get road-based route through multiple waypoints
        """
        if len(coordinates) < 2:
            return None
            
        try:
            # Format coordinates for OSRM
            coord_string = ";".join([f"{lng},{lat}" for lat, lng in coordinates])
            
            url = f"{self.osrm_url}/{coord_string}"
            params = {
                'overview': 'full',
                'geometries': 'geojson',
                'steps': 'false',
                'annotations': 'false',
                'continue_straight': 'false'  # Allow route optimization
            }
            
            response = requests.get(url, params=params, timeout=15)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get('code') == 'Ok' and data.get('routes'):
                route = data['routes'][0]
                geometry = route['geometry']
                
                # Convert GeoJSON coordinates to our format
                coordinates = []
                for coord in geometry['coordinates']:
                    coordinates.append({
                        'lng': coord[0],
                        'lat': coord[1],
                        'name': f"Road waypoint"
                    })
                
                return coordinates
            else:
                print(f"OSRM multi-waypoint routing failed: {data.get('message', 'Unknown error')}")
                return None
                
        except requests.exceptions.RequestException as e:
            print(f"OSRM multi-waypoint request failed: {e}")
            return None
        except Exception as e:
            print(f"Error getting multi-waypoint route: {e}")
            return None
    
    def get_graphhopper_route(self, start_lat: float, start_lng: float, 
                             end_lat: float, end_lng: float) -> Optional[List[Dict]]:
        """
        Get road-based route using GraphHopper (requires API key)
        """
        if not self.graphhopper_api_key:
            return None
            
        try:
            params = {
                'key': self.graphhopper_api_key,
                'point': [f"{start_lat},{start_lng}", f"{end_lat},{end_lng}"],
                'vehicle': 'car',
                'points_encoded': 'false',
                'instructions': 'false'
            }
            
            response = requests.get(self.graphhopper_url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get('paths'):
                path = data['paths'][0]
                coordinates = []
                
                for point in path.get('points', {}).get('coordinates', []):
                    coordinates.append({
                        'lng': point[0],
                        'lat': point[1],
                        'name': f"Road waypoint"
                    })
                
                return coordinates
            else:
                print(f"GraphHopper routing failed: {data.get('message', 'Unknown error')}")
                return None
                
        except requests.exceptions.RequestException as e:
            print(f"GraphHopper request failed: {e}")
            return None
        except Exception as e:
            print(f"Error getting GraphHopper route: {e}")
            return None
    
    def create_realistic_road_path(self, pagoda_coordinates: List[Dict]) -> List[Dict]:
        """
        Create a realistic road-based path through multiple pagodas
        """
        if len(pagoda_coordinates) < 2:
            return pagoda_coordinates
        
        # Try to get a multi-waypoint route from OSRM
        coordinates = [(coord['lat'], coord['lng']) for coord in pagoda_coordinates]
        road_coordinates = self.get_multi_waypoint_route(coordinates)
        
        if road_coordinates:
            # Add pagoda names to the coordinates
            result = []
            pagoda_index = 0
            
            for coord in road_coordinates:
                # Check if this coordinate is close to a pagoda
                if pagoda_index < len(pagoda_coordinates):
                    pagoda = pagoda_coordinates[pagoda_index]
                    distance = self._calculate_distance(
                        coord['lat'], coord['lng'],
                        pagoda['lat'], pagoda['lng']
                    )
                    
                    # If close to a pagoda, use the pagoda's exact coordinates and name
                    if distance < 0.05:  # Within 50 meters
                        result.append({
                            'lat': pagoda['lat'],
                            'lng': pagoda['lng'],
                            'name': pagoda['name']
                        })
                        pagoda_index += 1
                    else:
                        result.append(coord)
                else:
                    result.append(coord)
            
            return result
        else:
            # Fallback to individual segments
            return self._create_segmented_road_path(pagoda_coordinates)
    
    def _create_segmented_road_path(self, pagoda_coordinates: List[Dict]) -> List[Dict]:
        """
        Create road path by connecting segments between pagodas
        """
        result = []
        
        for i in range(len(pagoda_coordinates) - 1):
            current = pagoda_coordinates[i]
            next_pagoda = pagoda_coordinates[i + 1]
            
            # Add the current pagoda
            result.append(current)
            
            # Get road route between current and next pagoda
            road_segment = self.get_road_route(
                current['lat'], current['lng'],
                next_pagoda['lat'], next_pagoda['lng']
            )
            
            if road_segment:
                # Add intermediate road points (skip first to avoid duplication)
                result.extend(road_segment[1:])
            else:
                # Fallback: add a simple intermediate point
                result.append({
                    'lat': (current['lat'] + next_pagoda['lat']) / 2,
                    'lng': (current['lng'] + next_pagoda['lng']) / 2,
                    'name': f"Waypoint {i + 1}"
                })
        
        # Add the final pagoda
        result.append(pagoda_coordinates[-1])
        
        return result
    
    def _calculate_distance(self, lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """Calculate distance between two coordinates in km"""
        R = 6371  # Earth radius in km
        
        dlat = math.radians(lat2 - lat1)
        dlng = math.radians(lng2 - lng1)
        
        a = (math.sin(dlat / 2) * math.sin(dlat / 2) +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
             math.sin(dlng / 2) * math.sin(dlng / 2))
        
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c

# Global router instance
road_router = RoadRouter()
