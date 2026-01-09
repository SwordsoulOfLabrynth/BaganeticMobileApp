# 📁 Baganetic Project Structure

This document outlines the organized structure of the Baganetic project after cleanup and consolidation.

## 🏗️ Directory Structure

```
Baganetic/
├── 📁 docs/                    # Consolidated documentation
│   ├── README.md              # Main project overview
│   ├── SETUP.md               # Complete setup guide
│   ├── ADMIN.md               # Admin dashboard documentation
│   ├── CHATBOT.md             # AI chatbot documentation
│   └── PROJECT_STRUCTURE.md   # This file
├── 📁 scripts/                 # Startup and utility scripts
│   ├── start_all.py           # Start all services
│   ├── start_admin.py         # Start admin system only
│   ├── start_chatbot.py       # Start chatbot only
│   ├── start_all.bat          # Windows: Start all services
│   ├── start_admin.bat        # Windows: Start admin system
│   └── start_chatbot.bat      # Windows: Start chatbot
├── 📁 assets/                  # Frontend assets
│   ├── 📁 css/                # Stylesheets
│   │   ├── styles.css         # Main application styles
│   │   ├── admin.css          # Admin dashboard styles
│   │   ├── login-popup.css    # Authentication UI styles
│   │   └── floating-chatbot.css # Chatbot UI styles
│   ├── 📁 js/                 # JavaScript files
│   │   ├── script.js          # Main application logic
│   │   ├── auth.js            # Authentication management
│   │   ├── admin.js           # Admin dashboard functionality
│   │   ├── pagoda-manager.js  # Pagoda data management
│   │   ├── pathfinder.js      # A* pathfinding algorithm
│   │   ├── floating-chatbot.js # Chatbot UI integration
│   │   └── [other JS files]   # Additional functionality
│   ├── 📁 images/             # Application images
│   │   ├── 📁 pagodas/        # Pagoda photos
│   │   ├── 📁 backgrounds/    # Background images
│   │   └── 📁 thumbnails/     # Image thumbnails
│   └── 📁 data/               # Data files
│       └── pagodas.js         # Pagoda database
├── 📁 templates/               # HTML templates
│   └── admin.html             # Admin dashboard template
├── 📄 Core Application Files
│   ├── app.py                 # Main Flask application
│   ├── admin_backend.py       # Admin system backend
│   ├── chatbot_backend.py     # AI chatbot backend
│   ├── server.js              # Node.js server (optional)
│   ├── bagan_pathfinder.py    # A* pathfinding algorithm
│   ├── improved_pathfinder.py # Enhanced pathfinding
│   └── road_routing.py        # Road routing system
├── 📄 Configuration Files
│   ├── package.json           # Node.js dependencies
│   ├── requirements.txt       # Python dependencies
│   ├── chatbot_requirements.txt # Chatbot dependencies
│   ├── env.template           # Environment variables template
│   └── .env                   # Environment variables (create from template)
├── 📄 HTML Pages
│   ├── index.html             # Homepage
│   ├── map.html               # Interactive map
│   ├── pagodas.html           # Pagoda listing
│   ├── pagodaDetils.html      # Individual pagoda details
│   ├── ananda.html            # Ananda pagoda page
│   ├── shwegugyi.html         # Shwegugyi pagoda page
│   ├── indexmm.html           # Myanmar language homepage
│   └── test-auth.html         # Authentication testing page
├── 📄 Utility Files
│   ├── check_servers.py       # Server health monitoring
│   ├── validate_dataset.py    # Data validation
│   ├── flowchart_generator.py # Flowchart generation
│   └── simple_validation.py   # Simple validation utilities
├── 📄 Test Files
│   ├── test_chatbot.py        # Chatbot functionality tests
│   ├── test_admin_verification.py # Admin system tests
│   ├── test_floating_chatbot.py # Chatbot UI tests
│   └── test_persistence.html  # Data persistence tests
└── 📄 Documentation
    ├── README.md              # Main project documentation
    ├── FILE_INDEX.md          # File index and descriptions
    └── PROJECT_STRUCTURE.md   # This file
```

## 🎯 Key Components

### 📚 Documentation (`docs/`)
- **README.md**: Main project overview and quick start
- **SETUP.md**: Complete installation and setup guide
- **ADMIN.md**: Admin dashboard documentation
- **CHATBOT.md**: AI chatbot documentation
- **PROJECT_STRUCTURE.md**: This file

### 🚀 Scripts (`scripts/`)
- **start_all.py**: Start all services (main app, admin, chatbot)
- **start_admin.py**: Start admin system only
- **start_chatbot.py**: Start chatbot only
- **start_all.bat**: Windows batch file for all services
- **start_admin.bat**: Windows batch file for admin
- **start_chatbot.bat**: Windows batch file for chatbot

### 🎨 Frontend (`assets/`)
- **CSS**: Organized stylesheets for different components
- **JavaScript**: Modular JavaScript files for functionality
- **Images**: Organized image assets by category
- **Data**: Pagoda database and configuration files

### 🖥️ Backend
- **app.py**: Main Flask application server
- **admin_backend.py**: Admin system backend
- **chatbot_backend.py**: AI chatbot backend
- **server.js**: Node.js server (optional)

### 🗺️ Pathfinding
- **bagan_pathfinder.py**: Core A* pathfinding algorithm
- **improved_pathfinder.py**: Enhanced pathfinding with optimizations
- **road_routing.py**: Road network integration

## 🔧 Configuration

### Environment Variables
Create a `.env` file from `env.template`:
```env
# Server Configuration
PORT=5000
NODE_ENV=development

# Database Configuration
MONGODB_URI=mongodb://localhost:27017/baganetic_users

# Security
JWT_SECRET=your-super-secret-jwt-key-here
SESSION_SECRET=your-session-secret-key-here

# Admin Configuration
ADMIN_USERNAME=admin
ADMIN_PASSWORD=baganetic2025!

# Optional: Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

### Dependencies
- **Python**: `requirements.txt` and `chatbot_requirements.txt`
- **Node.js**: `package.json` (optional)

## 🚀 Quick Start

### Start All Services
```bash
# Python
python scripts/start_all.py

# Windows
scripts/start_all.bat
```

### Start Individual Services
```bash
# Admin only
python scripts/start_admin.py

# Chatbot only
python scripts/start_chatbot.py

# Main app only
python app.py
```

## 📊 Services and Ports

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| Main App | 5000 | http://localhost:5000 | Main Baganetic application |
| Admin System | 5002 | http://localhost:5002/admin | Admin dashboard |
| AI Chatbot | 5001 | http://localhost:5001 | Chatbot service |
| Node.js Server | 3000 | http://localhost:3000 | Frontend server (optional) |

## 🔍 File Purposes

### Core Application
- **app.py**: Main Flask server with pagoda data and API endpoints
- **admin_backend.py**: Admin dashboard backend with CRUD operations
- **chatbot_backend.py**: AI chatbot with natural language processing

### Frontend Assets
- **script.js**: Main application logic and UI interactions
- **auth.js**: Authentication state management
- **admin.js**: Admin dashboard functionality
- **pathfinder.js**: Frontend pathfinding algorithm
- **pagoda-manager.js**: Pagoda data management

### Data and Configuration
- **pagodas.js**: Complete pagoda database with 19+ pagodas
- **package.json**: Node.js dependencies and scripts
- **requirements.txt**: Python dependencies
- **env.template**: Environment variables template

### Testing and Utilities
- **test_*.py**: Various test files for different components
- **validate_dataset.py**: Data validation utilities
- **check_servers.py**: Server health monitoring
- **flowchart_generator.py**: Documentation generation

## 🎯 Development Workflow

1. **Setup**: Follow `docs/SETUP.md` for installation
2. **Development**: Use `scripts/start_all.py` for full system
3. **Testing**: Use individual test files for component testing
4. **Documentation**: Update files in `docs/` directory
5. **Deployment**: Use production configuration in `.env`

## 🔧 Maintenance

### Regular Tasks
- Update dependencies in `requirements.txt` and `package.json`
- Validate data with `validate_dataset.py`
- Check server health with `check_servers.py`
- Update documentation in `docs/` directory

### Adding New Features
1. Add backend logic to appropriate Python files
2. Add frontend logic to appropriate JavaScript files
3. Update styles in CSS files
4. Add tests for new functionality
5. Update documentation

## 📈 Future Enhancements

### Planned Additions
- Mobile app development
- Multi-language support
- Advanced analytics
- Social features
- Offline capabilities

### Technical Improvements
- Performance optimization
- Security enhancements
- Scalability improvements
- Monitoring and logging

---

**This structure provides a clean, organized, and maintainable codebase for the Baganetic project.**
