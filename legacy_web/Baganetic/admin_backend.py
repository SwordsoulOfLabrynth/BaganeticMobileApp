"""
Baganetic Admin Backend - Integrated with existing MongoDB and User System
Comprehensive admin API for managing the Baganetic application
"""

from flask import Flask, request, jsonify, session, render_template
from flask_cors import CORS
import os
import json
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import math
from werkzeug.utils import secure_filename
import requests
import logging
import pymongo
from bson import ObjectId

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__, static_folder="assets", template_folder="templates")
# Use a stable secret for sessions so they persist across restarts (configurable via env)
app.secret_key = os.getenv("ADMIN_SESSION_SECRET", "baganetic-admin-secret-change-me")
# Session cookie behavior (Lax is fine for same-site; adjust to 'None' with HTTPS in prod if cross-site)
app.config['SESSION_COOKIE_SAMESITE'] = os.getenv("ADMIN_SESSION_SAMESITE", "Lax")
app.config['SESSION_COOKIE_SECURE'] = os.getenv("ADMIN_SESSION_SECURE", "false").lower() == "true"
# Enable CORS with credentials for admin routes only
CORS(
    app,
    supports_credentials=True,
    resources={
        r"/admin/*": {
            "origins": [
                "http://localhost:5002",
                "http://127.0.0.1:5002",
                "http://localhost:3000",
                "http://127.0.0.1:3000",
            ]
        }
    },
)

# Admin configuration
ADMIN_CONFIG = {
    "username": os.getenv("ADMIN_USERNAME", "admin"),
    "password": os.getenv("ADMIN_PASSWORD", "baganetic2025!"),
    # Idle timeout in seconds (default 15m); can override via ADMIN_SESSION_IDLE_S
    "session_timeout": int(os.getenv("ADMIN_SESSION_IDLE_S", "900")),
    # Absolute timeout in seconds (default 60m); can override via ADMIN_SESSION_ABSOLUTE_S
    "absolute_timeout": int(os.getenv("ADMIN_SESSION_ABSOLUTE_S", "3600")),
    "max_login_attempts": 5,
    "lockout_duration": 900,  # 15 minutes
}

# MongoDB connection
MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://127.0.0.1:27017/baganetic_users")
FALLBACK_MODE = os.getenv("FALLBACK_MODE", "false").lower() == "true"
client = None
db = None

# In-memory storage for admin sessions and logs
admin_sessions = {}
login_attempts = {}
admin_logs = []

def connect_to_mongodb():
    """Connect to MongoDB database"""
    global client, db
    try:
        client = pymongo.MongoClient(MONGODB_URI)
        db = client.get_default_database()
        if db is None:
            db = client["baganetic_users"]
        logger.info("✅ Connected to MongoDB")
        return True
    except Exception as e:
        logger.error(f"❌ Failed to connect to MongoDB: {e}")
        return False

def get_users_collection():
    """Get users collection"""
    if db is None:
        connect_to_mongodb()
    return db.users if db is not None else None

def get_pagodas_collection():
    """Get pagodas collection"""
    if db is None:
        connect_to_mongodb()
    return db.pagodas if db is not None else None

def load_pagoda_data_from_db() -> List[Dict[str, Any]]:
    """Load pagoda data from MongoDB or fallback"""
    if FALLBACK_MODE:
        logger.info("Running in fallback mode - using JSON data files")
        return load_pagoda_data_from_js()
    
    try:
        pagodas_collection = get_pagodas_collection()
        if pagodas_collection is not None:
            pagodas = list(pagodas_collection.find({}, {"_id": 0}))
            if pagodas:
                logger.info(f"✅ Loaded {len(pagodas)} pagodas from MongoDB")
                return pagodas
        
        # Fallback to JS file if no database data
        logger.info("⚠️  No pagoda data in MongoDB, falling back to JS file")
        return load_pagoda_data_from_js()
    except Exception as e:
        logger.error(f"Failed to load pagoda data from DB: {e}")
        logger.info("Falling back to JSON data files")
        return load_pagoda_data_from_js()

def load_pagoda_data_from_js() -> List[Dict[str, Any]]:
    """Load pagoda data from the main application"""
    try:
        # Try to get data from main Flask app
        response = requests.get('http://localhost:5000/api/pagodas', timeout=5)
        if response.status_code == 200:
            return response.json().get('data', [])
    except:
        pass
    
    # Fallback to local file
    try:
        with open("assets/data/pagodas.js", "r", encoding="utf-8") as f:
            content = f.read()
        # Simple extraction of pagoda data
        start_key = "pagodas: ["
        start_idx = content.find(start_key)
        if start_idx == -1:
            return []
        start_idx += len("pagodas: ")
        
        # Find matching closing bracket
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
            return []
        
        array_text = content[start_idx:end_idx]
        # Make it JSON-compatible
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
            ("featured:", '"featured":'),
            ("status:", '"status":'),
        ]
        for a, b in replacements:
            array_text = array_text.replace(a, b)
        
        data = json.loads(f'{{"pagodas": {array_text}}}')
        return data["pagodas"]
    except Exception as e:
        logger.error(f"Failed to load pagoda data: {e}")
        return []

def save_pagoda_data_to_db(pagodas: List[Dict[str, Any]]) -> bool:
    """Save pagoda data to MongoDB"""
    try:
        pagodas_collection = get_pagodas_collection()
        if pagodas_collection is None:
            logger.error("No pagodas collection available")
            return False
        
        # Upsert each pagoda by stable id to avoid empty-window races
        valid_ids = set()
        for pagoda in pagodas or []:
            pagoda_id = (pagoda or {}).get('id')
            if not pagoda_id:
                # Skip invalid entries without an id
                continue
            valid_ids.add(pagoda_id)
            normalized = apply_pagoda_defaults(pagoda.copy())
            pagodas_collection.update_one(
                { 'id': pagoda_id },
                { '$set': normalized },
                upsert=True,
            )

        # Prune orphans that are no longer present
        if valid_ids:
            pagodas_collection.delete_many({ 'id': { '$nin': list(valid_ids) } })
        
        logger.info(f"✅ Saved {len(valid_ids)} pagodas to MongoDB (upserted, pruned orphans)")
        return True
    except Exception as e:
        logger.error(f"Failed to save pagoda data to DB: {e}")
        return False

def save_pagoda_data_to_js(pagodas: List[Dict[str, Any]]) -> bool:
    """Save pagoda data back to the file"""
    try:
        # Create the JavaScript file content
        content = f"""// Comprehensive Pagoda Database for Baganetic
// This file contains all pagoda information in a structured, easy-to-manage format
// Updated by admin on {datetime.now().isoformat()}

console.log("📚 Loading PAGODA_DATABASE...");

const PAGODA_DATABASE = {{
  // Main pagoda data with comprehensive information
  pagodas: {json.dumps(pagodas, indent=4, ensure_ascii=False)},

  // Utility functions for working with pagoda data
  utils: {{
    // Get pagoda by ID
    getPagoda(id) {{
      return this.pagodas.find((pagoda) => pagoda.id === id);
    }},

    // Get featured pagodas
    getFeaturedPagodas() {{
      return this.pagodas.filter((pagoda) => pagoda.featured);
    }},

    // Search pagodas
    searchPagodas(query) {{
      if (!query) return this.pagodas;

      const searchTerm = query.toLowerCase();
      return this.pagodas.filter((pagoda) => {{
        return (
          pagoda.name.toLowerCase().includes(searchTerm) ||
          pagoda.shortName.toLowerCase().includes(searchTerm) ||
          pagoda.description.short.toLowerCase().includes(searchTerm) ||
          pagoda.tags.some((tag) => tag.toLowerCase().includes(searchTerm)) ||
          pagoda.location.city.toLowerCase().includes(searchTerm)
        );
      }});
    }},

    // Get pagodas by type
    getPagodasByType(type) {{
      return this.pagodas.filter(
        (pagoda) => pagoda.type.toLowerCase() === type.toLowerCase()
      );
    }},

    // Get pagodas by location
    getPagodasByLocation(city) {{
      return this.pagodas.filter(
        (pagoda) => pagoda.location.city.toLowerCase() === city.toLowerCase()
      );
    }},

    // Get random pagodas
    getRandomPagodas(count = 3) {{
      const shuffled = [...this.pagodas].sort(() => 0.5 - Math.random());
      return shuffled.slice(0, count);
    }},

    // Get pagoda statistics
    getStatistics: function () {{
      return {{
        total: PAGODA_DATABASE.pagodas.length,
        temples: PAGODA_DATABASE.pagodas.filter((p) => p.type === "Temple").length,
        pagodas: PAGODA_DATABASE.pagodas.filter((p) => p.type === "Pagoda").length,
        featured: PAGODA_DATABASE.pagodas.filter((p) => p.featured).length,
        locations: [
          ...new Set(PAGODA_DATABASE.pagodas.map((p) => p.location.city)),
        ].length,
      }};
    }},

    // Get nearest pagodas to a given pagoda ID
    getNearestPagodas: function (pagodaId, limit = 5) {{
      const pagoda = PAGODA_DATABASE.pagodas.find((p) => p.id === pagodaId);
      if (!pagoda || !pagoda.distances) return [];

      return Object.entries(pagoda.distances)
        .map(([id, distance]) => {{
          const targetPagoda = PAGODA_DATABASE.pagodas.find((p) => p.id === id);
          if (!targetPagoda) return null;
          return {{
            id,
            name: targetPagoda.name,
            distance,
            thumbnail: targetPagoda.images.thumbnail,
          }};
        }})
        .filter((item) => item !== null)
        .sort((a, b) => a.distance - b.distance)
        .slice(0, limit);
    }},
  }},
}};

// Make it available globally
if (typeof window !== "undefined") {{
  window.PAGODA_DATABASE = PAGODA_DATABASE;
  console.log(
    "✅ PAGODA_DATABASE loaded with",
    PAGODA_DATABASE.pagodas.length,
    "pagodas"
  );
}}

// For Node.js environments
if (typeof module !== "undefined" && module.exports) {{
  module.exports = PAGODA_DATABASE;
}}"""
        
        with open("assets/data/pagodas.js", "w", encoding="utf-8") as f:
            f.write(content)
        
        # Also save Myanmar language data
        save_myanmar_pagoda_data(pagodas)
        
        return True
    except Exception as e:
        logger.error(f"Failed to save pagoda data: {e}")
        return False

def save_myanmar_pagoda_data(pagodas: List[Dict[str, Any]]) -> bool:
    """Save Myanmar language pagoda data to separate file"""
    try:
        # Extract Myanmar language data
        mm_pagodas = []
        for pagoda in pagodas:
            mm_pagoda = {
                "id": pagoda.get("id", ""),
                "name": pagoda.get("nameMm", ""),
                "description": {
                    "short": pagoda.get("description", {}).get("shortMm", ""),
                    "long": pagoda.get("description", {}).get("longMm", "")
                },
                "type": "ဘုရား" if pagoda.get("type") == "Temple" else "စေတီ",
                "featured": pagoda.get("featured", False),
                "location": {
                    "city": "ပုဂံ",
                    "country": "မြန်မာ",
                    "coordinates": {
                        "lat": pagoda.get("location", {}).get("coordinates", {}).get("lat"),
                        "lng": pagoda.get("location", {}).get("coordinates", {}).get("lng")
                    }
                },
                "history": {
                    "built": pagoda.get("history", {}).get("built", "")
                },
                "images": pagoda.get("images", {}),
                "tags": ["ဘုရား", "ဗုဒ္ဓဘာသာ", "သမိုင်းဝင်"]
            }
            mm_pagodas.append(mm_pagoda)
        
        # Create Myanmar JavaScript file content
        content = f"""// Myanmar Pagoda Data
// This file contains Myanmar language data for pagodas to be used on MM pages
// Updated by admin on {datetime.now().isoformat()}

window.PAGODA_DATABASE_MM = {{
  pagodas: {json.dumps(mm_pagodas, indent=2, ensure_ascii=False)}
}};

// Make it available globally
if (typeof window !== "undefined") {{
  window.PAGODA_DATABASE_MM = window.PAGODA_DATABASE_MM;
  console.log(
    "✅ PAGODA_DATABASE_MM loaded with",
    window.PAGODA_DATABASE_MM.pagodas.length,
    "pagodas"
  );
}}

// For Node.js environments
if (typeof module !== "undefined" && module.exports) {{
  module.exports = window.PAGODA_DATABASE_MM;
}}"""
        
        with open("assets/data/pagodas-mm.js", "w", encoding="utf-8") as f:
            f.write(content)
        
        logger.info(f"✅ Saved Myanmar language data for {len(mm_pagodas)} pagodas")
        return True
    except Exception as e:
        logger.error(f"Failed to save Myanmar pagoda data: {e}")
        return False

def apply_pagoda_defaults(pagoda: Dict[str, Any]) -> Dict[str, Any]:
    """Ensure required pagoda fields exist and are well-typed.

    This prevents 500s and keeps the user-side dataset consistent even when
    some inputs are missing or malformed.
    """
    if pagoda is None:
        return {}
    # Top-level defaults
    pagoda.setdefault('id', '')
    pagoda.setdefault('name', '')
    pagoda.setdefault('shortName', pagoda.get('name', ''))
    pagoda.setdefault('nameMm', '')
    pagoda.setdefault('shortNameMm', '')
    pagoda.setdefault('type', 'Temple')
    pagoda.setdefault('featured', False)
    pagoda.setdefault('status', 'active')
    pagoda.setdefault('detailPage', '')
    pagoda.setdefault('detailPageMm', '')
    # Descriptions
    pagoda.setdefault('description', {})
    pagoda['description'].setdefault('short', '')
    pagoda['description'].setdefault('long', '')
    pagoda['description'].setdefault('shortMm', '')
    pagoda['description'].setdefault('longMm', '')
    # Images
    pagoda.setdefault('images', {})
    pagoda['images'].setdefault('main', '')
    pagoda['images'].setdefault('thumbnail', '')
    pagoda['images'].setdefault('gallery', [])
    # Location
    pagoda.setdefault('location', {})
    pagoda['location'].setdefault('city', 'Bagan')
    pagoda['location'].setdefault('region', 'Mandalay Region')
    pagoda['location'].setdefault('country', 'Myanmar')
    pagoda['location'].setdefault('coordinates', {})
    # Coerce coordinates to float where possible
    try:
        if 'lat' in pagoda['location']['coordinates']:
            pagoda['location']['coordinates']['lat'] = (
                float(pagoda['location']['coordinates']['lat'])
                if pagoda['location']['coordinates']['lat'] not in (None, '') else None
            )
    except Exception:
        pagoda['location']['coordinates']['lat'] = None
    try:
        if 'lng' in pagoda['location']['coordinates']:
            pagoda['location']['coordinates']['lng'] = (
                float(pagoda['location']['coordinates']['lng'])
                if pagoda['location']['coordinates']['lng'] not in (None, '') else None
            )
    except Exception:
        pagoda['location']['coordinates']['lng'] = None
    # Misc
    pagoda.setdefault('tags', [])
    pagoda.setdefault('distances', {})
    return pagoda

def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Compute great-circle distance between two lat/lng pairs in kilometers."""
    try:
        R = 6371.0
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = (
            math.sin(dlat / 2) * math.sin(dlat / 2)
            + math.cos(math.radians(lat1))
            * math.cos(math.radians(lat2))
            * math.sin(dlon / 2)
            * math.sin(dlon / 2)
        )
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return float(R * c)
    except Exception:
        return 0.0

def recompute_all_distances(pagodas: List[Dict[str, Any]]) -> None:
    """Precompute pairwise straight-line distances and store in `distances` maps.

    This runs on the admin backend during create/update so the frontend can
    read nearest pagodas immediately without computing on the client.
    """
    # Build simple index of coords
    coords = {}
    for p in pagodas:
        try:
            lat = p.get('location', {}).get('coordinates', {}).get('lat')
            lng = p.get('location', {}).get('coordinates', {}).get('lng')
            if isinstance(lat, str):
                lat = float(lat) if lat.strip() != '' else None
            if isinstance(lng, str):
                lng = float(lng) if lng.strip() != '' else None
            if isinstance(lat, (int, float)) and isinstance(lng, (int, float)):
                coords[p.get('id')] = (float(lat), float(lng))
        except Exception:
            continue

    for p in pagodas:
        pid = p.get('id')
        p['distances'] = {}
        if pid not in coords:
            continue
        plat, plng = coords[pid]
        for oid, (olat, olng) in coords.items():
            if oid == pid:
                continue
            dist = _haversine_km(plat, plng, olat, olng)
            # Keep a few decimals for readability/size
            p['distances'][oid] = round(dist, 3)

def is_admin_authenticated() -> bool:
    """Check if admin is authenticated"""
    session_id = session.get('admin_session_id')
    if not session_id or session_id not in admin_sessions:
        return False
    
    session_data = admin_sessions[session_id]
    now = datetime.now()
    # Absolute timeout check
    if 'created' in session_data and (now - session_data['created']).total_seconds() > ADMIN_CONFIG.get('absolute_timeout', 3600):
        del admin_sessions[session_id]
        return False
    # Idle timeout check (sliding window based on 'expires')
    if now > session_data['expires']:
        del admin_sessions[session_id]
        return False
    
    return True

def require_admin_auth(f):
    """Decorator to require admin authentication"""
    def decorated_function(*args, **kwargs):
        if not is_admin_authenticated():
            return jsonify({'success': False, 'error': 'Admin authentication required'}), 401
        # Refresh sliding expiration on each authenticated request
        try:
            session_id = session.get('admin_session_id')
            if session_id and session_id in admin_sessions:
                now = datetime.now()
                # Maintain absolute timeout cap based on 'created'
                created = admin_sessions[session_id].get('created', now)
                absolute_deadline = created + timedelta(seconds=ADMIN_CONFIG.get('absolute_timeout', 3600))
                new_idle_expiry = now + timedelta(seconds=ADMIN_CONFIG['session_timeout'])
                # The effective expiry is the earlier of idle expiry and absolute deadline
                admin_sessions[session_id]['last_activity'] = now
                admin_sessions[session_id]['expires'] = min(new_idle_expiry, absolute_deadline)
        except Exception:
            # Best effort only; do not block the request on refresh issues
            pass
        return f(*args, **kwargs)
    decorated_function.__name__ = f.__name__
    return decorated_function

def log_admin_action(action: str, details: str = ""):
    """Log admin actions"""
    admin_logs.append({
        'timestamp': datetime.now().isoformat(),
        'action': action,
        'details': details,
        'session_id': session.get('admin_session_id', 'unknown')
    })
    # Keep only last 1000 logs
    if len(admin_logs) > 1000:
        admin_logs.pop(0)

# Authentication endpoints
@app.route('/admin/login', methods=['POST'])
def admin_login():
    """Admin login endpoint"""
    data = request.get_json()
    username = data.get('username', '').strip()
    password = data.get('password', '')
    
    # Check for brute force attempts
    client_ip = request.remote_addr
    if client_ip in login_attempts:
        attempts = login_attempts[client_ip]
        if attempts['count'] >= ADMIN_CONFIG['max_login_attempts']:
            if datetime.now() < attempts['lockout_until']:
                return jsonify({
                    'success': False, 
                    'error': f'Too many login attempts. Try again in {int((attempts["lockout_until"] - datetime.now()).total_seconds() / 60)} minutes'
                }), 429
    
    # Validate credentials
    if username == ADMIN_CONFIG['username'] and password == ADMIN_CONFIG['password']:
        # Reset login attempts
        if client_ip in login_attempts:
            del login_attempts[client_ip]
        
        # Create session
        session_id = secrets.token_hex(32)
        admin_sessions[session_id] = {
            'username': username,
            'created': datetime.now(),
            'expires': datetime.now() + timedelta(seconds=ADMIN_CONFIG['session_timeout']),
            'last_activity': datetime.now()
        }
        
        session['admin_session_id'] = session_id
        log_admin_action('LOGIN', f'Admin {username} logged in')
        
        return jsonify({
            'success': True,
            'message': 'Login successful',
            'session_id': session_id
        })
    else:
        # Record failed attempt
        if client_ip not in login_attempts:
            login_attempts[client_ip] = {'count': 0, 'lockout_until': None}
        
        login_attempts[client_ip]['count'] += 1
        if login_attempts[client_ip]['count'] >= ADMIN_CONFIG['max_login_attempts']:
            login_attempts[client_ip]['lockout_until'] = datetime.now() + timedelta(seconds=ADMIN_CONFIG['lockout_duration'])
        
        log_admin_action('LOGIN_FAILED', f'Failed login attempt for {username}')
        return jsonify({'success': False, 'error': 'Invalid credentials'}), 401

@app.route('/admin/logout', methods=['POST'])
@require_admin_auth
def admin_logout():
    """Admin logout endpoint"""
    session_id = session.get('admin_session_id')
    if session_id in admin_sessions:
        username = admin_sessions[session_id]['username']
        del admin_sessions[session_id]
        log_admin_action('LOGOUT', f'Admin {username} logged out')
    
    session.pop('admin_session_id', None)
    return jsonify({'success': True, 'message': 'Logged out successfully'})

@app.route('/admin/status')
@require_admin_auth
def admin_status():
    """Get admin session status"""
    session_id = session.get('admin_session_id')
    session_data = admin_sessions.get(session_id, {})
    return jsonify({
        'success': True,
        'authenticated': True,
        'username': session_data.get('username'),
        'session_expires': session_data.get('expires').isoformat() if session_data.get('expires') else None,
        'fallback_mode': FALLBACK_MODE,
        'mongodb_available': not FALLBACK_MODE
    })

# Dashboard endpoints
@app.route('/admin/dashboard/stats')
@require_admin_auth
def dashboard_stats():
    """Get dashboard statistics"""
    try:
        pagodas = load_pagoda_data_from_db()
        users_collection = get_users_collection()
        
        # Calculate statistics
        stats = {
            'total_pagodas': len(pagodas),
            'featured_pagodas': len([p for p in pagodas if p.get('featured', False)]),
            'temples': len([p for p in pagodas if p.get('type') == 'Temple']),
            'pagodas': len([p for p in pagodas if p.get('type') == 'Pagoda']),
            'active_pagodas': len([p for p in pagodas if p.get('status') == 'active']),
            'locations': len(set(p.get('location', {}).get('city', '') for p in pagodas)),
            'recent_logs': len([log for log in admin_logs if 
                              datetime.fromisoformat(log['timestamp']) > datetime.now() - timedelta(hours=24)])
        }
        
        # Get user statistics from MongoDB
        if users_collection is not None:
            try:
                total_users = users_collection.count_documents({})
                # Use admin verification instead of email verification
                verified_users = users_collection.count_documents({'isAdminVerified': True})
                recent_users = users_collection.count_documents({
                    'createdAt': {'$gte': datetime.now() - timedelta(days=7)}
                })
                
                stats.update({
                    'total_users': total_users,
                    'verified_users': verified_users,
                    'recent_users': recent_users
                })
            except Exception as e:
                logger.error(f"Failed to get user stats: {e}")
                stats.update({
                    'total_users': 0,
                    'verified_users': 0,
                    'recent_users': 0
                })
        else:
            stats.update({
                'total_users': 0,
                'verified_users': 0,
                'recent_users': 0
            })
        
        # Check system health
        system_health = {
            'main_app': False,
            'chatbot': False,
            'database': False,
            'node_server': False
        }
        
        # Check main app
        try:
            response = requests.get('http://localhost:5000/api/health', timeout=3)
            system_health['main_app'] = response.status_code == 200
        except:
            pass
        
        # Check chatbot
        try:
            response = requests.get('http://localhost:5001/api/chatbot/health', timeout=3)
            system_health['chatbot'] = response.status_code == 200
        except:
            pass
        
        # Check Node.js server
        try:
            response = requests.get('http://localhost:3000/api/health', timeout=3)
            system_health['node_server'] = response.status_code == 200
        except:
            pass
        
        # Check database
        try:
            users_collection = get_users_collection()
            system_health['database'] = (users_collection is not None) and len(pagodas) > 0
        except:
            system_health['database'] = False
        
        return jsonify({
            'success': True,
            'stats': stats,
            'system_health': system_health
        })
    except Exception as e:
        logger.error(f"Error getting dashboard stats: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/admin/dashboard/logs')
@require_admin_auth
def dashboard_logs():
    """Get recent admin logs"""
    try:
        limit = request.args.get('limit', 50, type=int)
        recent_logs = admin_logs[-limit:] if admin_logs else []
        return jsonify({
            'success': True,
            'logs': recent_logs
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# User management endpoints
@app.route('/admin/users')
@require_admin_auth
def get_users():
    """Get all users for admin management"""
    try:
        users_collection = get_users_collection()
        if users_collection is None:
            return jsonify({'success': False, 'error': 'Database not available'}), 500
        
        # Get users with pagination
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 20, type=int)
        skip = (page - 1) * limit
        
        users = list(users_collection.find(
            {},
            {
                'password': 0,
                'passwordResetToken': 0,
                'emailVerificationToken': 0
            }
        ).skip(skip).limit(limit).sort('createdAt', -1))
        
        # Convert ObjectId to string for JSON serialization
        for user in users:
            user['_id'] = str(user['_id'])
            if 'createdAt' in user:
                user['createdAt'] = user['createdAt'].isoformat()
            if 'lastLogin' in user:
                user['lastLogin'] = user['lastLogin'].isoformat() if user['lastLogin'] else None
        
        total_users = users_collection.count_documents({})
        
        return jsonify({
            'success': True,
            'data': users,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total_users,
                'pages': (total_users + limit - 1) // limit
            }
        })
    except Exception as e:
        logger.error(f"Error getting users: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/admin/users/<user_id>', methods=['DELETE'])
@require_admin_auth
def delete_user(user_id):
    """Delete a user"""
    try:
        users_collection = get_users_collection()
        if users_collection is None:
            return jsonify({'success': False, 'error': 'Database not available'}), 500
        
        # Convert string ID to ObjectId
        try:
            object_id = ObjectId(user_id)
        except:
            return jsonify({'success': False, 'error': 'Invalid user ID'}), 400
        
        result = users_collection.delete_one({'_id': object_id})
        
        if result.deleted_count > 0:
            log_admin_action('DELETE_USER', f'Deleted user: {user_id}')
            return jsonify({'success': True, 'message': 'User deleted successfully'})
        else:
            return jsonify({'success': False, 'error': 'User not found'}), 404
            
    except Exception as e:
        logger.error(f"Error deleting user: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/admin/users/<user_id>', methods=['PUT'])
@require_admin_auth
def update_user(user_id):
    """Update user information"""
    try:
        users_collection = get_users_collection()
        if users_collection is None:
            return jsonify({'success': False, 'error': 'Database not available'}), 500
        
        # Convert string ID to ObjectId
        try:
            object_id = ObjectId(user_id)
        except:
            return jsonify({'success': False, 'error': 'Invalid user ID'}), 400
        
        # Get update data from request
        update_data = request.get_json()
        if not update_data:
            return jsonify({'success': False, 'error': 'No update data provided'}), 400
        
        # Prepare update fields
        update_fields = {}
        allowed_fields = ['isEmailVerified', 'role', 'fullName', 'email', 'isAdminVerified']
        
        for field in allowed_fields:
            if field in update_data:
                update_fields[field] = update_data[field]
        
        if not update_fields:
            return jsonify({'success': False, 'error': 'No valid fields to update'}), 400
        
        # Add updated timestamp
        update_fields['updatedAt'] = datetime.now()
        
        # Update the user
        result = users_collection.update_one(
            {'_id': object_id},
            {'$set': update_fields}
        )
        
        if result.modified_count > 0:
            log_admin_action('UPDATE_USER', f'Updated user: {user_id} with fields: {list(update_fields.keys())}')
            return jsonify({'success': True, 'message': 'User updated successfully'})
        else:
            return jsonify({'success': False, 'error': 'User not found or no changes made'}), 404
            
    except Exception as e:
        logger.error(f"Error updating user: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/admin/users/<user_id>/verify', methods=['POST'])
@require_admin_auth
def verify_user(user_id):
    """Verify a user (admin-controlled verification)"""
    try:
        users_collection = get_users_collection()
        if users_collection is None:
            return jsonify({'success': False, 'error': 'Database not available'}), 500
        
        # Convert string ID to ObjectId
        try:
            object_id = ObjectId(user_id)
        except:
            return jsonify({'success': False, 'error': 'Invalid user ID'}), 400
        
        # Update user verification status
        result = users_collection.update_one(
            {'_id': object_id},
            {
                '$set': {
                    'isAdminVerified': True,
                    'isEmailVerified': True,  # Also set email verified for backward compatibility
                    'verifiedAt': datetime.now(),
                    'verifiedBy': 'admin',
                    'updatedAt': datetime.now()
                }
            }
        )
        
        if result.modified_count > 0:
            log_admin_action('VERIFY_USER', f'Verified user: {user_id}')
            return jsonify({'success': True, 'message': 'User verified successfully'})
        else:
            return jsonify({'success': False, 'error': 'User not found'}), 404
            
    except Exception as e:
        logger.error(f"Error verifying user: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/admin/users/<user_id>/unverify', methods=['POST'])
@require_admin_auth
def unverify_user(user_id):
    """Unverify a user (admin-controlled verification)"""
    try:
        users_collection = get_users_collection()
        if users_collection is None:
            return jsonify({'success': False, 'error': 'Database not available'}), 500
        
        # Convert string ID to ObjectId
        try:
            object_id = ObjectId(user_id)
        except:
            return jsonify({'success': False, 'error': 'Invalid user ID'}), 400
        
        # Update user verification status
        result = users_collection.update_one(
            {'_id': object_id},
            {
                '$set': {
                    'isAdminVerified': False,
                    'isEmailVerified': False,  # Also unset email verified
                    'verifiedAt': None,
                    'verifiedBy': None,
                    'updatedAt': datetime.now()
                }
            }
        )
        
        if result.modified_count > 0:
            log_admin_action('UNVERIFY_USER', f'Unverified user: {user_id}')
            return jsonify({'success': True, 'message': 'User unverified successfully'})
        else:
            return jsonify({'success': False, 'error': 'User not found'}), 404
            
    except Exception as e:
        logger.error(f"Error unverifying user: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/admin/users/<user_id>/role', methods=['POST'])
@require_admin_auth
def update_user_role(user_id):
    """Update user role (user/admin)"""
    try:
        users_collection = get_users_collection()
        if users_collection is None:
            return jsonify({'success': False, 'error': 'Database not available'}), 500
        
        # Convert string ID to ObjectId
        try:
            object_id = ObjectId(user_id)
        except:
            return jsonify({'success': False, 'error': 'Invalid user ID'}), 400
        
        # Get role from request
        data = request.get_json()
        if not data or 'role' not in data:
            return jsonify({'success': False, 'error': 'Role not provided'}), 400
        
        new_role = data['role']
        if new_role not in ['user', 'admin']:
            return jsonify({'success': False, 'error': 'Invalid role. Must be "user" or "admin"'}), 400
        
        # Update user role
        result = users_collection.update_one(
            {'_id': object_id},
            {
                '$set': {
                    'role': new_role,
                    'updatedAt': datetime.now()
                }
            }
        )
        
        if result.modified_count > 0:
            log_admin_action('UPDATE_USER_ROLE', f'Updated user {user_id} role to: {new_role}')
            return jsonify({'success': True, 'message': f'User role updated to {new_role}'})
        else:
            return jsonify({'success': False, 'error': 'User not found'}), 404
            
    except Exception as e:
        logger.error(f"Error updating user role: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# Pagoda management endpoints
@app.route('/admin/pagodas')
@require_admin_auth
def get_pagodas():
    """Get all pagodas for admin management"""
    try:
        pagodas = load_pagoda_data_from_db() or []
        # Normalize structure for front-end
        pagodas = [apply_pagoda_defaults(p.copy()) for p in pagodas]
        return jsonify({'success': True, 'data': pagodas})
    except Exception as e:
        logger.error(f"Error getting pagodas: {e}")
        # Harden: avoid 500s on listing; return empty with warning
        return jsonify({'success': True, 'data': [], 'warning': 'Failed to load pagodas'}), 200

@app.route('/admin/pagodas/<pagoda_id>')
@require_admin_auth
def get_pagoda(pagoda_id):
    """Get specific pagoda"""
    try:
        pagodas = load_pagoda_data_from_db() or []
        pagoda = next((p for p in pagodas if p.get('id') == pagoda_id), None)
        if not pagoda:
            return jsonify({'success': False, 'error': 'Pagoda not found'}), 404
        pagoda = apply_pagoda_defaults(pagoda.copy())
        return jsonify({'success': True, 'data': pagoda})
    except Exception as e:
        logger.error(f"Error getting pagoda {pagoda_id}: {e}")
        return jsonify({'success': False, 'error': 'Failed to retrieve pagoda'}), 500

@app.route('/admin/pagodas', methods=['POST'])
@require_admin_auth
def create_pagoda():
    """Create new pagoda"""
    try:
        # Support both JSON and multipart (with file upload)
        data = request.get_json(silent=True)
        uploaded_detail = None
        uploaded_detail_mm = None
        main_image = None
        thumbnail = None
        gallery_files = []
        if data is None and request.form:
            raw = request.form.get('data') or request.form.get('payload')
            data = json.loads(raw) if raw else {}
            uploaded_detail = request.files.get('detailHtml')
            uploaded_detail_mm = request.files.get('detailHtmlMm')
            main_image = request.files.get('mainImage')
            thumbnail = request.files.get('thumbnail')
            gallery_files = request.files.getlist('gallery') if 'gallery' in request.files else []
        else:
            uploaded_detail = request.files.get('detailHtml') if hasattr(request, 'files') else None
            uploaded_detail_mm = request.files.get('detailHtmlMm') if hasattr(request, 'files') else None
            main_image = request.files.get('mainImage') if hasattr(request, 'files') else None
            thumbnail = request.files.get('thumbnail') if hasattr(request, 'files') else None
            gallery_files = request.files.getlist('gallery') if hasattr(request, 'files') else []
        
        # Validate required fields
        required_fields = ['id', 'name', 'shortName', 'type', 'location']
        for field in required_fields:
            if field not in data:
                return jsonify({'success': False, 'error': f'Missing required field: {field}'}), 400
        
        # Check if ID already exists
        pagodas = load_pagoda_data_from_db() or []
        if any(p.get('id') == data['id'] for p in pagodas):
            return jsonify({'success': False, 'error': 'Pagoda ID already exists'}), 400
        
        # Create asset directory for this pagoda
        asset_dir = os.path.join(os.getcwd(), 'assets', 'images', 'pagodas', data['name'] if data.get('name') else data['id'])
        try:
            os.makedirs(asset_dir, exist_ok=True)
        except Exception as mkerr:
            logger.warning(f"Failed to create asset dir {asset_dir}: {mkerr}")

        # Handle optional dedicated detail HTML page
        if uploaded_detail and uploaded_detail.filename:
            filename = secure_filename(f"{data['id']}.html")
            save_path = os.path.join(os.getcwd(), filename)
            uploaded_detail.save(save_path)
            data['detailPage'] = filename
        
        # Handle optional dedicated Myanmar detail HTML page
        if uploaded_detail_mm and uploaded_detail_mm.filename:
            filename_mm = secure_filename(f"{data['id']}mm.html")
            save_path_mm = os.path.join(os.getcwd(), filename_mm)
            uploaded_detail_mm.save(save_path_mm)
            data['detailPageMm'] = filename_mm

        # Handle images
        data.setdefault('images', {})
        if main_image and main_image.filename:
            main_name = secure_filename(main_image.filename)
            main_path = os.path.join(asset_dir, main_name)
            main_image.save(main_path)
            rel_path = os.path.relpath(main_path, os.getcwd()).replace('\\', '/')
            data['images']['main'] = f"./{rel_path}"
            # default thumbnail if not provided
            if not data['images'].get('thumbnail'):
                data['images']['thumbnail'] = f"./{rel_path}"
        if thumbnail and thumbnail.filename:
            thumb_name = secure_filename(thumbnail.filename)
            thumb_path = os.path.join(asset_dir, thumb_name)
            thumbnail.save(thumb_path)
            rel_thumb = os.path.relpath(thumb_path, os.getcwd()).replace('\\', '/')
            data['images']['thumbnail'] = f"./{rel_thumb}"
        if gallery_files:
            gallery_paths = []
            for gf in gallery_files:
                if not gf or not gf.filename:
                    continue
                gname = secure_filename(gf.filename)
                gpath = os.path.join(asset_dir, gname)
                gf.save(gpath)
                rel = os.path.relpath(gpath, os.getcwd()).replace('\\', '/')
                gallery_paths.append(f"./{rel}")
            if gallery_paths:
                data['images']['gallery'] = gallery_paths

        # Apply defaults and types
        data = apply_pagoda_defaults(data)
        
        # Add to pagodas and recompute distances
        pagodas.append(data)
        recompute_all_distances(pagodas)
        
        # Save to both database and JS file
        db_success = save_pagoda_data_to_db(pagodas)
        js_success = save_pagoda_data_to_js(pagodas)
        
        if db_success or js_success:
            log_admin_action('CREATE_PAGODA', f'Created pagoda: {data["name"]} ({data["id"]})')
            message = 'Pagoda created successfully'
            if not (db_success and js_success):
                message += ' (partially synced)'
            return jsonify({'success': True, 'message': message, 'data': data})
        else:
            return jsonify({'success': False, 'error': 'Failed to save pagoda data'}), 500
            
    except Exception as e:
        logger.error(f"Error creating pagoda: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/admin/pagodas/<pagoda_id>', methods=['PUT'])
@require_admin_auth
def update_pagoda(pagoda_id):
    """Update existing pagoda"""
    try:
        # Accept JSON or multipart with optional file replacement
        data = request.get_json(silent=True)
        uploaded_detail = None
        uploaded_detail_mm = None
        main_image = None
        thumbnail = None
        gallery_files = []
        if data is None and request.form:
            raw = request.form.get('data') or request.form.get('payload')
            data = json.loads(raw) if raw else {}
            uploaded_detail = request.files.get('detailHtml')
            uploaded_detail_mm = request.files.get('detailHtmlMm')
            main_image = request.files.get('mainImage')
            thumbnail = request.files.get('thumbnail')
            gallery_files = request.files.getlist('gallery') if 'gallery' in request.files else []
        else:
            uploaded_detail = request.files.get('detailHtml') if hasattr(request, 'files') else None
            uploaded_detail_mm = request.files.get('detailHtmlMm') if hasattr(request, 'files') else None
            main_image = request.files.get('mainImage') if hasattr(request, 'files') else None
            thumbnail = request.files.get('thumbnail') if hasattr(request, 'files') else None
            gallery_files = request.files.getlist('gallery') if hasattr(request, 'files') else []
        if not data:
            return jsonify({'success': False, 'error': 'No update payload provided'}), 400
        pagodas = load_pagoda_data_from_db() or []
        
        # Find pagoda
        pagoda_index = next((i for i, p in enumerate(pagodas) if p.get('id') == pagoda_id), None)
        if pagoda_index is None:
            return jsonify({'success': False, 'error': 'Pagoda not found'}), 404
        
        # Update pagoda
        old_pagoda = pagodas[pagoda_index].copy()
        # Prevent changing the primary key via PUT path
        if 'id' in data:
            data.pop('id')
        # If a new detail HTML is uploaded, save and update field
        if uploaded_detail and uploaded_detail.filename:
            filename = secure_filename(f"{pagoda_id}.html")
            save_path = os.path.join(os.getcwd(), filename)
            uploaded_detail.save(save_path)
            data['detailPage'] = filename
        
        # If a new Myanmar detail HTML is uploaded, save and update field
        if uploaded_detail_mm and uploaded_detail_mm.filename:
            filename_mm = secure_filename(f"{pagoda_id}mm.html")
            save_path_mm = os.path.join(os.getcwd(), filename_mm)
            uploaded_detail_mm.save(save_path_mm)
            data['detailPageMm'] = filename_mm

        # Handle image updates
        asset_dir = os.path.join(os.getcwd(), 'assets', 'images', 'pagodas', (data.get('name') or pagoda_id))
        try:
            os.makedirs(asset_dir, exist_ok=True)
        except Exception:
            pass
        data.setdefault('images', {})
        if main_image and main_image.filename:
            main_name = secure_filename(main_image.filename)
            main_path = os.path.join(asset_dir, main_name)
            main_image.save(main_path)
            rel_path = os.path.relpath(main_path, os.getcwd()).replace('\\', '/')
            data['images']['main'] = f"./{rel_path}"
            if not data['images'].get('thumbnail'):
                data['images']['thumbnail'] = f"./{rel_path}"
        if thumbnail and thumbnail.filename:
            thumb_name = secure_filename(thumbnail.filename)
            thumb_path = os.path.join(asset_dir, thumb_name)
            thumbnail.save(thumb_path)
            rel_thumb = os.path.relpath(thumb_path, os.getcwd()).replace('\\', '/')
            data['images']['thumbnail'] = f"./{rel_thumb}"
        if gallery_files:
            gallery_paths = []
            for gf in gallery_files:
                if not gf or not gf.filename:
                    continue
                gname = secure_filename(gf.filename)
                gpath = os.path.join(asset_dir, gname)
                gf.save(gpath)
                rel = os.path.relpath(gpath, os.getcwd()).replace('\\', '/')
                gallery_paths.append(f"./{rel}")
            if gallery_paths:
                data['images']['gallery'] = gallery_paths

        pagodas[pagoda_index].update(data)
        pagodas[pagoda_index] = apply_pagoda_defaults(pagodas[pagoda_index])
        # Recompute distances for all after update
        recompute_all_distances(pagodas)
        
        # Save to both database and JS file
        db_success = save_pagoda_data_to_db(pagodas)
        js_success = save_pagoda_data_to_js(pagodas)
        
        if db_success or js_success:
            log_admin_action('UPDATE_PAGODA', f'Updated pagoda: {pagoda_id}')
            message = 'Pagoda updated successfully'
            if not (db_success and js_success):
                message += ' (partially synced)'
            return jsonify({'success': True, 'message': message, 'data': pagodas[pagoda_index]})
        else:
            return jsonify({'success': False, 'error': 'Failed to save pagoda data'}), 500
            
    except Exception as e:
        logger.error(f"Error updating pagoda: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/admin/pagodas/<pagoda_id>', methods=['DELETE'])
@require_admin_auth
def delete_pagoda(pagoda_id):
    """Delete pagoda"""
    try:
        pagodas = load_pagoda_data_from_db() or []
        
        # Find and remove pagoda
        original_count = len(pagodas)
        pagodas = [p for p in pagodas if p.get('id') != pagoda_id]
        
        if len(pagodas) == original_count:
            return jsonify({'success': False, 'error': 'Pagoda not found'}), 404
        
        # Save to both database and JS file
        db_success = save_pagoda_data_to_db(pagodas)
        js_success = save_pagoda_data_to_js(pagodas)
        
        if db_success or js_success:
            log_admin_action('DELETE_PAGODA', f'Deleted pagoda: {pagoda_id}')
            message = 'Pagoda deleted successfully'
            if not (db_success and js_success):
                message += ' (partially synced)'
            return jsonify({'success': True, 'message': message})
        else:
            return jsonify({'success': False, 'error': 'Failed to save pagoda data'}), 500
            
    except Exception as e:
        logger.error(f"Error deleting pagoda: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# Toggle featured flag for a pagoda
@app.route('/admin/pagodas/<pagoda_id>/feature', methods=['POST'])
@require_admin_auth
def toggle_pagoda_featured(pagoda_id):
    """Toggle or set the featured status for a single pagoda.

    Body: { "featured": bool } (optional; if absent, will toggle)
    """
    try:
        pagodas_collection = get_pagodas_collection()
        if pagodas_collection is None:
            return jsonify({'success': False, 'error': 'Database not available'}), 500

        body = request.get_json(silent=True) or {}
        doc = pagodas_collection.find_one({ 'id': pagoda_id }, { '_id': 0 }) or {}
        current = bool(doc.get('featured', False))
        new_value = bool(body['featured']) if 'featured' in body else (not current)

        # Update single document
        result = pagodas_collection.update_one(
            { 'id': pagoda_id },
            { '$set': { 'featured': new_value, 'updatedAt': datetime.now() } }
        )

        if result.matched_count == 0:
            return jsonify({'success': False, 'error': 'Pagoda not found'}), 404

        # Regenerate JS file for frontend fallback consistency
        try:
            all_pagodas = list(pagodas_collection.find({}, { '_id': 0 }))
            save_pagoda_data_to_js(all_pagodas)
        except Exception as gen_err:
            logger.warning(f"Failed to regenerate pagodas.js after feature toggle: {gen_err}")

        log_admin_action('TOGGLE_FEATURED', f'{pagoda_id} -> {new_value}')
        return jsonify({'success': True, 'message': 'Featured updated', 'featured': new_value})
    except Exception as e:
        logger.error(f"Error toggling featured for {pagoda_id}: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# Maintenance: recompute and persist distances for all pagodas
@app.route('/admin/pagodas/recompute-distances', methods=['POST'])
@require_admin_auth
def admin_recompute_distances():
    try:
        pagodas = load_pagoda_data_from_db() or []
        # Normalize all first to ensure numeric coords
        pagodas = [apply_pagoda_defaults(p.copy()) for p in pagodas]
        recompute_all_distances(pagodas)
        db_success = save_pagoda_data_to_db(pagodas)
        js_success = save_pagoda_data_to_js(pagodas)
        if db_success or js_success:
            log_admin_action('UPDATE_PAGODA', 'Recomputed distances for all pagodas')
            return jsonify({'success': True, 'message': 'Distances recomputed for all pagodas', 'count': len(pagodas)})
        return jsonify({'success': False, 'error': 'Failed to persist recomputed distances'}), 500
    except Exception as e:
        logger.error(f"Error recomputing distances: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# System management endpoints
@app.route('/admin/system/health')
@require_admin_auth
def system_health():
    """Get detailed system health information"""
    try:
        health_info = {
            'main_app': {'status': 'down', 'response_time': None, 'error': None},
            'chatbot': {'status': 'down', 'response_time': None, 'error': None},
            'node_server': {'status': 'down', 'response_time': None, 'error': None},
            'database': {'status': 'down', 'error': None}
        }
        
        # Check main app
        try:
            start_time = datetime.now()
            response = requests.get('http://localhost:5000/api/health', timeout=5)
            response_time = (datetime.now() - start_time).total_seconds()
            
            if response.status_code == 200:
                health_info['main_app'] = {
                    'status': 'up',
                    'response_time': round(response_time, 3),
                    'data': response.json()
                }
            else:
                health_info['main_app']['error'] = f'HTTP {response.status_code}'
        except Exception as e:
            health_info['main_app']['error'] = str(e)
        
        # Check chatbot
        try:
            start_time = datetime.now()
            response = requests.get('http://localhost:5001/api/chatbot/health', timeout=5)
            response_time = (datetime.now() - start_time).total_seconds()
            
            if response.status_code == 200:
                health_info['chatbot'] = {
                    'status': 'up',
                    'response_time': round(response_time, 3),
                    'data': response.json()
                }
            else:
                health_info['chatbot']['error'] = f'HTTP {response.status_code}'
        except Exception as e:
            health_info['chatbot']['error'] = str(e)
        
        # Check Node.js server
        try:
            start_time = datetime.now()
            response = requests.get('http://localhost:3000/api/health', timeout=5)
            response_time = (datetime.now() - start_time).total_seconds()
            
            if response.status_code == 200:
                health_info['node_server'] = {
                    'status': 'up',
                    'response_time': round(response_time, 3),
                    'data': response.json()
                }
            else:
                health_info['node_server']['error'] = f'HTTP {response.status_code}'
        except Exception as e:
            health_info['node_server']['error'] = str(e)
        
        # Check database
        try:
            # Test database connection
            users_collection = get_users_collection()
            if users_collection is not None:
                user_count = users_collection.count_documents({})
                health_info['database'] = {
                    'status': 'up',
                    'user_count': user_count,
                    'connection': 'MongoDB'
                }
            else:
                health_info['database']['error'] = 'No users collection'
        except Exception as e:
            health_info['database']['error'] = str(e)
        
        return jsonify({
            'success': True,
            'health': health_info,
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/admin/system/restart/<service>', methods=['POST'])
@require_admin_auth
def restart_service(service):
    """Restart a service (placeholder for actual implementation)"""
    try:
        if service not in ['main_app', 'chatbot', 'node_server']:
            return jsonify({'success': False, 'error': 'Invalid service'}), 400
        
        log_admin_action('RESTART_SERVICE', f'Attempted to restart {service}')
        
        # In a real implementation, you would restart the actual services
        # For now, just return success
        return jsonify({
            'success': True,
            'message': f'Restart command sent for {service}'
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# Admin interface route
@app.route('/admin')
def admin_interface():
    """Serve the admin interface"""
    return render_template('admin.html')

if __name__ == '__main__':
    print("Starting Baganetic Admin Backend (Integrated)...")
    print(f"Admin username: {ADMIN_CONFIG['username']}")
    print("Admin interface available at: http://localhost:5002/admin")
    
    # Connect to MongoDB
    if connect_to_mongodb():
        print("✅ Connected to MongoDB")
    else:
        print("⚠️  MongoDB connection failed - using fallback mode")
    
    app.run(debug=True, host='0.0.0.0', port=5002)
