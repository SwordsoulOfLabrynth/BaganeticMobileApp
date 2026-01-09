"""
Baganetic Flask Application
A comprehensive web application for exploring Bagan's ancient pagodas with pathfinding
"""

from flask import Flask, render_template, request, jsonify, session
from flask_cors import CORS
from typing import List, Dict, Any
import os
import json
import math
from datetime import datetime
import hashlib
import secrets

# Optional: MongoDB (preferred source of truth)
try:
    from pymongo import MongoClient
except Exception:  # pragma: no cover
    MongoClient = None  # type: ignore
import json
import os
import math
from datetime import datetime
import hashlib
import secrets

app = Flask(__name__, static_folder="assets", template_folder="templates")
app.secret_key = secrets.token_hex(16)
CORS(app)

# Flask server only handles A* pathfinding API
# Frontend is served by Node.js on port 3000

# Import pathfinder (use the improved implementation only)
from improved_pathfinder import ImprovedPagodaPathFinder

def _load_pagodas_from_mongo() -> List[Dict[str, Any]]:
    """Preferred: load pagoda documents from MongoDB."""
    uri = os.getenv("MONGODB_URI", "mongodb://localhost:27017/baganetic_users")
    if MongoClient is None:
        raise RuntimeError("pymongo not installed")

    client = MongoClient(uri)
    # Database from URI or default
    db_name = (client.get_default_database().name
               if client.get_default_database() is not None else "baganetic_users")
    db = client[db_name]
    # Common collection name in this project
    collection = db.get_collection("pagodas")
    docs = list(collection.find({}, {"_id": 0}))
    return docs


def _load_pagodas_from_js() -> List[Dict[str, Any]]:
    """Fallback: best-effort parse of assets/data/pagodas.js into Python objects."""
    try:
        with open("assets/data/pagodas.js", "r", encoding="utf-8") as f:
            content = f.read()
        # Very simple extraction: look for "pagodas: [ ... ]"
        start_key = "pagodas: ["
        start_idx = content.find(start_key)
        if start_idx == -1:
            raise ValueError("pagodas array not found")
        start_idx += len("pagodas: ")
        # naive bracket matching to find matching ]
        depth, i = 0, start_idx
        while i < len(content):
            if content[i] == "[":
                depth += 1
            elif content[i] == "]":
                depth -= 1
                if depth == 0:
                    end_idx = i + 1
                    break
            i += 1
        else:
            raise ValueError("unterminated pagodas array")

        array_text = content[start_idx:end_idx]
        # Make it JSON-ish quickly (quotes for keys)
        replacements = [
            ("id:", '"id":'),
            ("name:", '"name":'),
            ("shortName:", '"shortName":'),
            ("type:", '"type":'),
            ("location:", '"location":'),
            ("coordinates:", '"coordinates":'),
            ("lat:", '"lat":'),
            ("lng:", '"lng":'),
            ("images:", '"images":'),
            ("main:", '"main":'),
            ("thumbnail:", '"thumbnail":'),
            ("description:", '"description":'),
            ("short:", '"short":'),
            ("long:", '"long":'),
        ]
        for a, b in replacements:
            array_text = array_text.replace(a, b)
        data = json.loads(f"{{\"pagodas\": {array_text}}}")
        return data["pagodas"]
    except Exception as e:
        print(f"Fallback JS parse failed: {e}")
        # Minimal sample so the app can run
        return [
            {
                "id": "ananda",
                "name": "Ananda Temple",
                "location": {"coordinates": {"lat": 21.170806, "lng": 94.867856}},
            },
            {
                "id": "gawdawpalin",
                "name": "Gawdawpalin Temple",
                "location": {"coordinates": {"lat": 21.173, "lng": 94.857}},
            },
        ]


def load_pagoda_data() -> List[Dict[str, Any]]:
    """Load pagoda data, preferring MongoDB if available.

    Coordinates in the database are treated as the source of truth.
    """
    # Check if fallback mode is enabled
    fallback_mode = os.getenv("FALLBACK_MODE", "false").lower() == "true"
    
    if fallback_mode:
        print("Running in fallback mode - using JSON data files")
        return _load_pagodas_from_js()
    
    # 1) Try MongoDB first
    try:
        if MongoClient is not None:
            docs = _load_pagodas_from_mongo()
            if docs:
                return docs
    except Exception as e:
        print(f"MongoDB load failed: {e}")
        print("Falling back to JSON data files")

    # 2) Fallback to JS file
    return _load_pagodas_from_js()

def _build_graph():
    data = load_pagoda_data()
    # Use improved pathfinder for better route optimization
    improved_pf = ImprovedPagodaPathFinder(data)
    # Expose the internal graph for endpoints that list pagodas
    graph = improved_pf.graph
    return data, graph, improved_pf

# Lazy in-memory cache (rebuilt per request to reflect DB updates)
def _fresh_graph():
    return _build_graph()

# Frontend routes are handled by Node.js server
# Flask only provides API endpoints for pathfinding

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    fallback_mode = os.getenv("FALLBACK_MODE", "false").lower() == "true"
    return jsonify({
        'status': 'healthy', 
        'service': 'Flask A* Pathfinding API',
        'fallback_mode': fallback_mode,
        'mongodb_available': not fallback_mode
    })

@app.route('/api/pagodas')
def get_pagodas():
    """Get all pagodas"""
    try:
        data = load_pagoda_data()
        pagodas = []
        for pagoda in data:
            # Accept both DB shape and JS fallback
            name = pagoda.get('name') or pagoda.get('title')
            loc = pagoda.get('location', {})
            coords = loc.get('coordinates', loc)
            lat = coords.get('lat')
            lng = coords.get('lng')
            pagodas.append({
                'id': pagoda.get('id') or pagoda.get('_id') or name,
                'name': name,
                'shortName': pagoda.get('shortName', name),
                'type': pagoda.get('type', 'Pagoda'),
                'location': {'lat': lat, 'lng': lng},
                'featured': pagoda.get('featured', False),
                'description': (pagoda.get('description') or {}).get('short', ''),
                'images': {
                    'main': ((pagoda.get('images') or {}).get('main')),
                    'thumbnail': ((pagoda.get('images') or {}).get('thumbnail')),
                },
            })
        return jsonify({'success': True, 'data': pagodas})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/pagodas/<pagoda_id>')
def get_pagoda(pagoda_id):
    """Get specific pagoda by ID"""
    try:
        data = load_pagoda_data()
        for pagoda in data:
            if pagoda['id'] == pagoda_id:
                return jsonify({'success': True, 'data': pagoda})
        return jsonify({'success': False, 'error': 'Pagoda not found'}), 404
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/pathfinder/pagodas')
def get_pathfinder_pagodas():
    """Get pagodas for pathfinder"""
    try:
        _data, graph, _pf = _fresh_graph()
        pagodas = []
        for name, data in graph.items():
            pagodas.append({
                'name': name,
                'location': {
                    'lat': data['location']['lat'],
                    'lng': data['location']['lng']
                }
            })
        return jsonify({'success': True, 'data': pagodas})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/pathfinder/find-path', methods=['POST'])
def find_path():
    """Find shortest path between two pagodas"""
    try:
        data = request.get_json()
        start = data.get('start')
        end = data.get('end')
        
        if not start or not end:
            return jsonify({'success': False, 'error': 'Start and end pagodas are required'}), 400
        
        if start == end:
            return jsonify({'success': False, 'error': 'Start and end pagodas must be different'}), 400
        
        _data, graph, pf = _fresh_graph()
        if start not in graph or end not in graph:
            return jsonify({'success': False, 'error': 'Invalid pagoda name'}), 400
        
        # Use enhanced pathfinding with real road coordinates
        enhanced_path = pf.get_enhanced_path_with_road_coordinates(start, end)
        
        if not enhanced_path:
            return jsonify({'success': False, 'error': 'No path found between the selected pagodas'}), 404
        
        # Find nearby pagodas along the path
        nearby_pagodas = pf.find_nearby_pagodas(enhanced_path['path'], 1.0)
        
        return jsonify({
            'success': True,
            'data': {
                'path': enhanced_path['path'],
                'distance': round(enhanced_path['distance'], 2),
                'distanceKm': round(enhanced_path['distanceKm'], 2),
                'nearbyPagodas': nearby_pagodas,
                'coordinates': enhanced_path['coordinates'],
                'pathLength': enhanced_path['pathLength']
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/pathfinder/nearby/<pagoda_name>')
def get_nearby_pagodas(pagoda_name):
    """Get nearby pagodas"""
    try:
        distance = request.args.get('distance', 1.0, type=float)
        
        _data, graph, pf = _fresh_graph()
        if pagoda_name not in graph:
            return jsonify({'success': False, 'error': 'Invalid pagoda name'}), 400
        
        nearby_pagodas = pf.find_nearby_pagodas([pagoda_name], distance)
        
        return jsonify({
            'success': True,
            'data': nearby_pagodas
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# Chatbot API proxy endpoints
@app.route('/api/chatbot/chat', methods=['POST'])
def chatbot_chat_proxy():
    """Proxy chatbot chat requests"""
    try:
        import requests
        response = requests.post('http://localhost:5001/api/chatbot/chat', 
                               json=request.get_json(), 
                               timeout=10)
        return response.json(), response.status_code
    except requests.exceptions.ConnectionError:
        return jsonify({'success': False, 'error': 'Chatbot server is not running. Please start the chatbot server on port 5001.'}), 503
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/chatbot/history/<user_id>')
def chatbot_history_proxy(user_id):
    """Proxy chatbot history requests"""
    try:
        import requests
        response = requests.get(f'http://localhost:5001/api/chatbot/history/{user_id}', 
                              timeout=10)
        return response.json(), response.status_code
    except requests.exceptions.ConnectionError:
        return jsonify({'success': True, 'data': []}), 200  # Return empty history if chatbot is down
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/chatbot/clear/<user_id>', methods=['POST'])
def chatbot_clear_proxy(user_id):
    """Proxy chatbot clear requests"""
    try:
        import requests
        response = requests.post(f'http://localhost:5001/api/chatbot/clear/{user_id}', 
                               timeout=10)
        return response.json(), response.status_code
    except requests.exceptions.ConnectionError:
        return jsonify({'success': True, 'message': 'Chat history cleared'}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/chatbot/pagodas')
def chatbot_pagodas_proxy():
    """Proxy chatbot pagodas requests"""
    try:
        import requests
        response = requests.get('http://localhost:5001/api/chatbot/pagodas', 
                              timeout=10)
        return response.json(), response.status_code
    except requests.exceptions.ConnectionError:
        # Return pagoda data from main app if chatbot is down
        try:
            data = load_pagoda_data()
            return jsonify({'success': True, 'data': data}), 200
        except:
            return jsonify({'success': False, 'error': 'Chatbot server is not running'}), 503
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/chatbot/health')
def chatbot_health_proxy():
    """Proxy chatbot health requests"""
    try:
        import requests
        response = requests.get('http://localhost:5001/api/chatbot/health', 
                              timeout=10)
        return response.json(), response.status_code
    except requests.exceptions.ConnectionError:
        return jsonify({
            'status': 'unhealthy',
            'service': 'Baganetic AI Chatbot',
            'error': 'Chatbot server is not running on port 5001'
        }), 503
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    # Avoid non-ASCII characters to prevent Windows console Unicode errors
    print("Starting Baganetic Flask Application...")
    data, graph, _pf = _fresh_graph()
    print(f"Loaded {len(data)} pagodas")
    print(f"Pathfinder initialized with {len(graph)} nodes")
    app.run(debug=True, host='0.0.0.0', port=5000)
