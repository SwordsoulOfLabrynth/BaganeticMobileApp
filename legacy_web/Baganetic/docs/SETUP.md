# 🚀 Baganetic Setup Guide

This guide will walk you through setting up the Baganetic project from scratch on any machine.

## 📋 Prerequisites Checklist

Before you begin, ensure you have the following installed:

- [ ] **Python** (v3.8 or higher)
- [ ] **Node.js** (v14 or higher) - Optional
- [ ] **MongoDB** (v4.4 or higher) - Optional
- [ ] **Git** (for version control)
- [ ] **Text Editor** (VS Code, Sublime, etc.)

## 🔧 Step-by-Step Installation

### 1. Install Python

#### Windows:
1. Go to [python.org](https://python.org/)
2. Download the latest version
3. Run the installer and follow the prompts
4. Verify installation: `python --version`

#### macOS:
```bash
# Using Homebrew
brew install python

# Or download from python.org
```

#### Linux (Ubuntu/Debian):
```bash
sudo apt update
sudo apt install python3 python3-pip
```

### 2. Install Node.js (Optional)

#### Windows:
1. Go to [nodejs.org](https://nodejs.org/)
2. Download the LTS version
3. Run the installer and follow the prompts
4. Verify installation: `node --version` and `npm --version`

#### macOS:
```bash
# Using Homebrew
brew install node

# Or download from nodejs.org
```

#### Linux (Ubuntu/Debian):
```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 3. Install MongoDB (Optional)

#### Windows:
1. Go to [mongodb.com](https://mongodb.com/)
2. Download MongoDB Community Server
3. Run the installer
4. Add MongoDB to your PATH environment variable

#### macOS:
```bash
# Using Homebrew
brew tap mongodb/brew
brew install mongodb-community

# Start MongoDB
brew services start mongodb-community
```

#### Linux (Ubuntu/Debian):
```bash
# Import MongoDB public GPG key
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

# Create list file for MongoDB
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# Update package database
sudo apt-get update

# Install MongoDB
sudo apt-get install -y mongodb-org

# Start MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod
```

### 4. Clone/Download the Project

#### Option A: Using Git
```bash
git clone <repository-url>
cd Baganetic
```

#### Option B: Download ZIP
1. Download the project ZIP file
2. Extract to your desired location
3. Open terminal/command prompt in the project folder

### 5. Install Project Dependencies

```bash
# Navigate to project directory
cd Baganetic

# Install Python packages
pip install -r requirements.txt

# Install Node.js packages (if using Node.js)
npm install
```

### 6. Configure Environment Variables

1. **Create environment file:**
   ```bash
   # Windows
   copy env.template .env
   
   # macOS/Linux
   cp env.template .env
   ```

2. **Edit the `.env` file** with your configuration:
   ```env
   # Server Configuration
   PORT=5000
   NODE_ENV=development
   
   # Database Configuration
   MONGODB_URI=mongodb://localhost:27017/baganetic_users
   
   # Security (CHANGE THESE!)
   JWT_SECRET=your-super-secret-jwt-key-here-change-this
   SESSION_SECRET=your-session-secret-key-here-change-this
   
   # Admin Configuration
   ADMIN_USERNAME=admin
   ADMIN_PASSWORD=baganetic2025!
   
   # Optional: Email Configuration
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USER=your-email@gmail.com
   SMTP_PASS=your-app-password
   ```

### 7. Start the Application

#### Quick Start (Recommended)
```bash
# Windows
start_all.bat

# Linux/Mac
python start_all.py
```

#### Manual Start
```bash
# Start main Flask app
python app.py

# Start admin system (in another terminal)
python admin_backend.py

# Start chatbot (in another terminal)
python chatbot_backend.py

# Start Node.js server (if using)
node server.js
```

### 8. Test the Application

1. **Open your browser** and go to `http://localhost:5000`
2. **Test the admin dashboard** at `http://localhost:5002/admin`
3. **Test the chatbot** at `http://localhost:5001`
4. **Create a test account** to verify everything works

## 🔍 Troubleshooting

### Common Issues and Solutions

#### 1. "Port 5000 is already in use"
```bash
# Find what's using port 5000
# Windows
netstat -ano | findstr :5000

# macOS/Linux
lsof -i :5000

# Kill the process or change port in .env
PORT=3000
```

#### 2. "MongoDB connection failed"
```bash
# Check if MongoDB is running
# Windows
tasklist | findstr mongod

# macOS/Linux
ps aux | grep mongod

# Start MongoDB if not running
mongod
```

#### 3. "Module not found" errors
```bash
# Reinstall dependencies
pip install -r requirements.txt

# For Node.js
rm -rf node_modules package-lock.json
npm install
```

#### 4. "JWT_SECRET is not defined"
- Check your `.env` file exists
- Verify JWT_SECRET is set in `.env`
- Restart the server after changing `.env`

#### 5. "Cannot find module 'flask'"
```bash
# Install missing dependencies
pip install flask flask-cors requests
```

### Database Issues

#### Reset Database
```bash
# Connect to MongoDB
mongosh

# Switch to database
use baganetic_users

# Drop collections (WARNING: This deletes all data!)
db.users.drop()
db.sessions.drop()

# Exit
exit
```

#### Check Database Status
```bash
# Connect to MongoDB
mongosh

# Show databases
show dbs

# Show collections
use baganetic_users
show collections

# Check user count
db.users.countDocuments()
```

## 🧪 Testing Your Setup

### 1. Basic Functionality Test
- [ ] Homepage loads without errors
- [ ] Navigation menu works
- [ ] Admin dashboard accessible
- [ ] Forms submit without errors

### 2. Authentication Test
- [ ] Admin login works
- [ ] User registration works (if enabled)
- [ ] JWT token is stored in localStorage
- [ ] Logout works and clears data

### 3. Database Test
- [ ] MongoDB connection successful
- [ ] User data is stored in database
- [ ] Sessions are created
- [ ] Data persists after server restart

### 4. API Test
- [ ] Pagoda data loads
- [ ] Search functionality works
- [ ] Map displays correctly
- [ ] Routes calculate properly

## 🚀 Production Deployment

### Environment Variables for Production
```env
NODE_ENV=production
PORT=3000
MONGODB_URI=mongodb://your-production-db-url
JWT_SECRET=very-long-random-secret-key
SESSION_SECRET=another-very-long-random-key
ADMIN_USERNAME=your_secure_username
ADMIN_PASSWORD=your_very_secure_password
```

### Process Management
```bash
# Install PM2
npm install -g pm2

# Start application
pm2 start app.py --name "baganetic"
pm2 start admin_backend.py --name "baganetic-admin"

# Monitor
pm2 status
pm2 logs baganetic

# Restart
pm2 restart baganetic
```

## 📱 Mobile Testing

### Test on Mobile Devices
1. **Find your computer's IP address:**
   ```bash
   # Windows
   ipconfig
   
   # macOS/Linux
   ifconfig
   ```

2. **Access from mobile:**
   - Connect mobile to same WiFi network
   - Open browser and go to `http://YOUR_IP:5000`
   - Test responsive design and touch interactions

## 🔒 Security Checklist

- [ ] JWT_SECRET is strong and unique
- [ ] SESSION_SECRET is strong and unique
- [ ] ADMIN_PASSWORD is changed from default
- [ ] MongoDB is not exposed to public network
- [ ] Environment variables are not committed to Git
- [ ] HTTPS is enabled in production
- [ ] Rate limiting is working
- [ ] Input validation is active

## 📞 Getting Help

If you encounter issues:

1. **Check the console** for error messages
2. **Verify all prerequisites** are installed
3. **Check environment variables** are set correctly
4. **Ensure MongoDB is running** (if using)
5. **Check port availability**
6. **Review the documentation**

## 🎉 Success!

Once everything is working:
- ✅ Server runs on `http://localhost:5000`
- ✅ Admin dashboard accessible at `http://localhost:5002/admin`
- ✅ Chatbot available at `http://localhost:5001`
- ✅ Database stores data (if using MongoDB)
- ✅ All pages load without errors

**Congratulations! You now have a fully functional Baganetic application! 🎊**

---

**Need more help? Check the main README.md or create an issue in the repository.**
