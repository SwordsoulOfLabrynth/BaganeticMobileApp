# 🚀 Baganetic Deployment Guide

## Quick Reference for Developers

### One-Click Deployment Files

| File | Purpose | Usage |
|------|---------|-------|
| `setup.bat` | Master installer | Double-click to install everything |
| `setup.py` | Python installer logic | Called by setup.bat |
| `START.bat` | Quick launcher | Double-click to start app |
| `uninstall.bat` | Cleanup script | Double-click to remove everything |
| `INSTALL.txt` | User guide | Read this for installation help |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FALLBACK_MODE` | `false` | Enable fallback mode (no MongoDB) |
| `MONGODB_URI` | `mongodb://localhost:27017/baganetic_users` | MongoDB connection string |
| `JWT_SECRET` | Auto-generated | JWT token secret |
| `SESSION_SECRET` | Auto-generated | Session secret |
| `ADMIN_USERNAME` | `admin` | Admin login username |
| `ADMIN_PASSWORD` | `baganetic2025!` | Admin login password |

### Fallback Mode

When `FALLBACK_MODE=true`:
- Pagoda data loads from `assets/data/pagodas.js`
- No MongoDB connection required
- Limited functionality (read-only)
- Admin features disabled
- User authentication disabled

### Service Ports

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| Main App | 5000 | http://localhost:5000 | Primary application |
| Chatbot | 5001 | http://localhost:5001 | AI assistant API |
| Admin | 5002 | http://localhost:5002/admin | Admin dashboard |
| Node.js | 3000 | http://localhost:3000 | Frontend server (optional) |

### Testing Deployment

Run the test script to verify everything works:
```bash
python test_deployment.py
```

### Manual Setup (if needed)

1. **Install Python packages:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Install Node.js packages:**
   ```bash
   npm install
   ```

3. **Create environment file:**
   ```bash
   copy env.template .env
   # Edit .env with your settings
   ```

4. **Start services:**
   ```bash
   python scripts/start_all.py
   ```

### Troubleshooting

**Common Issues:**
- **Setup fails** → Run as administrator
- **MongoDB won't start** → Check if port 27017 is free
- **Python not found** → Install Python 3.8+ and add to PATH
- **Port conflicts** → Close other apps using ports 5000-5002

**Logs:**
- Check console output for error messages
- Look in `.installer/` directory for installation logs
- Check `logs/` directory for application logs

### File Structure

```
Baganetic/
├── setup.bat              # Master installer
├── setup.py               # Python installer
├── START.bat              # Quick launcher
├── uninstall.bat          # Cleanup script
├── INSTALL.txt            # User guide
├── DEPLOYMENT_GUIDE.md    # This file
├── test_deployment.py     # Test script
├── requirements-core.txt  # Essential packages
├── .gitignore            # Git ignore rules
├── .installer/           # Installer downloads (auto-created)
├── .env                  # Environment config (auto-created)
└── logs/                 # Application logs (auto-created)
```

### Customization

**To modify the installer:**
1. Edit `setup.py` for installation logic
2. Edit `setup.bat` for Windows-specific setup
3. Update `INSTALL.txt` for user instructions

**To add new dependencies:**
1. Add to `requirements.txt` for Python packages
2. Add to `package.json` for Node.js packages
3. Update `setup.py` if special handling needed

**To modify fallback behavior:**
1. Update `app.py` for main app fallback
2. Update `admin_backend.py` for admin fallback
3. Update `chatbot_backend.py` for chatbot fallback
