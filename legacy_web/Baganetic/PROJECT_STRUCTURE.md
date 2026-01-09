# 🏛️ Baganetic Project Structure

## 📁 Project Organization

### 🎯 **Core Application Files**
```
Baganetic/
├── 📄 index.html                    # Main homepage
├── 📄 map.html                      # Interactive map page
├── 📄 pagodas.html                  # Pagoda listing page
├── 📄 pagodaDetils.html             # Individual pagoda details
├── 📄 ananda.html                   # Ananda pagoda specific page
├── 📄 shwegugyi.html                # Shwegugyi pagoda specific page
├── 📄 test-auth.html                # Authentication testing page
└── 📄 indexmm.html                  # Myanmar language homepage
```

### 🔧 **Backend Services**
```
├── 📄 app.py                        # Main Flask application (Port 5000)
├── 📄 admin_backend.py              # Admin backend service (Port 5002)
├── 📄 chatbot_backend.py            # AI Chatbot service (Port 5001)
├── 📄 pathfinder_backend.py         # Pathfinding service
├── 📄 server.js                     # Node.js server (Port 3000)
├── 📄 bagan_pathfinder.py           # A* pathfinding algorithm
├── 📄 improved_pathfinder.py        # Enhanced pathfinding
└── 📄 road_routing.py               # Road routing algorithms
```

### 🎨 **Frontend Assets**
```
├── 📁 assets/
│   ├── 📁 css/
│   │   ├── 📄 styles.css            # Main application styles
│   │   ├── 📄 admin.css             # Admin dashboard styles
│   │   ├── 📄 login-popup.css       # Authentication UI styles
│   │   └── 📄 floating-chatbot.css  # Chatbot UI styles
│   ├── 📁 js/
│   │   ├── 📄 script.js             # Main application logic
│   │   ├── 📄 auth.js               # Authentication management
│   │   ├── 📄 admin.js              # Admin dashboard logic
│   │   ├── 📄 pagoda-manager.js     # Pagoda data management
│   │   ├── 📄 floating-chatbot.js   # Chatbot interface
│   │   ├── 📄 pathfinder.js         # Pathfinding UI
│   │   ├── 📄 map-page.js           # Map page functionality
│   │   ├── 📄 pagodas-page.js       # Pagodas page functionality
│   │   ├── 📄 pagoda-details.js     # Pagoda details functionality
│   │   ├── 📄 pathfinder-ui.js      # Pathfinder user interface
│   │   ├── 📄 pagoda-loader.js      # Pagoda data loading
│   │   ├── 📄 api-client.js         # API communication
│   │   └── 📄 test-auth.js          # Authentication testing
│   ├── 📁 data/
│   │   └── 📄 pagodas.js            # Pagoda database
│   └── 📁 images/
│       ├── 📁 backgrounds/          # Background images
│       ├── 📁 pagodas/              # Pagoda-specific images
│       └── 📁 thumbnails/           # Thumbnail images
```

### 🗂️ **Templates & Configuration**
```
├── 📁 templates/
│   └── 📄 admin.html                # Admin dashboard template
├── 📄 package.json                  # Node.js dependencies
├── 📄 requirements.txt              # Python dependencies
├── 📄 chatbot_requirements.txt      # Chatbot-specific dependencies
├── 📄 env.template                  # Environment variables template
└── 📄 g(n) and h(n) values.xlsx     # Pathfinding algorithm data
```

### 🚀 **Startup Scripts**
```
├── 📄 start_all_servers.py          # Start all services
├── 📄 start_all_with_admin.py       # Start all services with admin
├── 📄 start_admin.py                # Start admin service only
├── 📄 start_chatbot.py              # Start chatbot service only
├── 📄 start_all.bat                 # Windows batch file for all services
├── 📄 start_all_with_admin.bat      # Windows batch with admin
├── 📄 start_admin.bat               # Windows admin startup
├── 📄 start_chatbot.bat             # Windows chatbot startup
├── 📄 start_all.sh                  # Linux/Mac startup script
├── 📄 quick_start.bat               # Quick Windows startup
├── 📄 quick-start.bat               # Alternative quick startup
├── 📄 quick-start.sh                # Quick Linux/Mac startup
└── 📄 restart-server.bat            # Server restart script
```

### 🧪 **Testing & Validation**
```
├── 📄 test_admin_verification.py    # Admin verification tests
├── 📄 test_chatbot.py               # Chatbot functionality tests
├── 📄 test_floating_chatbot.py      # Floating chatbot tests
├── 📄 test_persistence.html         # Data persistence tests
├── 📄 simple_validation.py          # Simple validation tests
├── 📄 validate_dataset.py           # Dataset validation
└── 📄 check_servers.py              # Server health checks
```

### 📚 **Documentation**
```
├── 📄 README.md                     # Main project documentation
├── 📄 README_PYTHON.md              # Python-specific documentation
├── 📄 PROJECT_SUMMARY.md            # Project overview
├── 📄 AUTHENTICATION_README.md      # Authentication system docs
├── 📄 ADMIN_README.md               # Admin system documentation
├── 📄 CHATBOT_README.md             # Chatbot documentation
├── 📄 QUICK_START.md                # Quick start guide
├── 📄 SETUP_INSTRUCTIONS.md         # Detailed setup instructions
├── 📄 SETUP_CHECKLIST.md            # Setup verification checklist
├── 📄 DEPLOYMENT_CHECKLIST.md       # Deployment guide
├── 📄 COMPLETE_TRANSITION_GUIDE.md  # System transition guide
├── 📄 SERVER_INTEGRATION.md         # Server integration docs
├── 📄 FLOATING_CHATBOT_INTEGRATION.md # Chatbot integration
├── 📄 ARCHITECTURE_DIAGRAM.md       # System architecture
├── 📄 PATHFINDING_IMPROVEMENTS.md   # Pathfinding enhancements
├── 📄 ROAD_ROUTING_FIX.md           # Road routing fixes
├── 📄 UI_IMPROVEMENTS_SUMMARY.md    # UI enhancement summary
├── 📄 BEAUTIFUL_UI_UPDATE.md        # UI update documentation
├── 📄 DASHBOARD_LAYOUT_FIX_SUMMARY.md # Dashboard fixes
├── 📄 PROFILE_FEATURES_IMPLEMENTATION.md # Profile features
├── 📄 SYSTEM_MANAGEMENT_ENHANCEMENT_SUMMARY.md # System management
├── 📄 ALIGNMENT_IMPROVEMENTS_SUMMARY.md # UI alignment fixes
└── 📄 ADMIN_VERIFICATION_UPDATE.md  # Admin verification updates
```

### 📊 **Flowcharts & Diagrams**
```
├── 📄 flowchart_generator.py        # Python flowchart generator
├── 📄 user_site_flowchart.png       # User site flowchart (image)
├── 📄 admin_site_flowchart.png      # Admin site flowchart (image)
├── 📄 system_architecture_flowchart.png # System architecture (image)
├── 📄 user_site_flowchart.md        # User site flowchart (Mermaid)
├── 📄 admin_site_flowchart.md       # Admin site flowchart (Mermaid)
├── 📄 system_architecture_flowchart.md # System architecture (Mermaid)
├── 📄 detailed_user_flowchart.md    # Detailed user flowchart (Mermaid)
├── 📄 detailed_admin_flowchart.md   # Detailed admin flowchart (Mermaid)
├── 📄 simple_user_flowchart.md      # Simple user flowchart (Mermaid)
├── 📄 simple_admin_flowchart.md     # Simple admin flowchart (Mermaid)
└── 📄 simple_system_flowchart.md    # Simple system flowchart (Mermaid)
```

### 🗃️ **Data & Cache**
```
├── 📄 cookies.txt                   # Browser cookies
├── 📁 node_modules/                 # Node.js dependencies
├── 📁 __pycache__/                  # Python cache files
└── 📄 package-lock.json             # Node.js dependency lock file
```

## 🎯 **Service Ports**
- **Port 3000**: Node.js Server (Frontend)
- **Port 5000**: Flask App (Main Backend)
- **Port 5001**: Chatbot Service
- **Port 5002**: Admin Backend

## 🔧 **Key Technologies**
- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Backend**: Python (Flask), Node.js (Express)
- **Database**: MongoDB
- **Authentication**: JWT, bcrypt
- **Pathfinding**: A* Algorithm
- **AI**: Natural Language Processing
- **Maps**: Leaflet.js
- **Styling**: Bootstrap, Custom CSS

## 📋 **Quick Access Commands**
```bash
# Start all services
python start_all_servers.py

# Start with admin
python start_all_with_admin.py

# Quick start (Windows)
quick_start.bat

# Quick start (Linux/Mac)
./quick-start.sh
```








