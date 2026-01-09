# 🏛️ Baganetic - Bagan Pagodas Guide & Interactive Map

A comprehensive web application for exploring Bagan's ancient pagodas with detailed information, interactive maps, and user authentication.

## ✨ Features

### 🗺️ **Interactive Map & Navigation**
- Interactive map showing all pagoda locations
- Shortest route planning between pagodas using A* algorithm
- Detailed location information and directions

### 🏛️ **Comprehensive Pagoda Database**
- Detailed information about each pagoda
- Historical background and architectural details
- High-quality images and descriptions
- Search and filter functionality

### 🔐 **User Authentication System**
- Secure user registration and login
- JWT-based authentication
- User profiles and preferences
- Favorites and personal collections

### 🤖 **AI Chatbot Assistant**
- Intelligent conversational AI for pagoda exploration
- Natural language understanding and processing
- Route planning and recommendations
- Cultural and historical insights

### 🛠️ **Admin Dashboard**
- Complete admin interface for content management
- Pagoda CRUD operations (Create, Read, Update, Delete)
- System health monitoring and service management
- Admin activity logs and audit trail

### 📱 **Modern, Responsive Design**
- Mobile-first responsive design
- Beautiful animations and transitions
- Cross-browser compatibility
- Accessibility features

## 🚀 Quick Start

### Prerequisites
- **Python** (v3.8 or higher)
- **Node.js** (v14 or higher) - Optional
- **MongoDB** (v4.4 or higher) - Optional
- **Git** (for cloning)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Baganetic
   ```

2. **Quick Start (All Services)**
   ```bash
   # Windows
   start_all.bat
   
   # Linux/Mac
   python start_all.py
   ```

3. **Admin Dashboard Only**
   ```bash
   # Windows
   start_admin.bat
   
   # Linux/Mac
   python start_admin.py
   ```

## 🛠️ Admin Dashboard

The Baganetic Admin Dashboard provides comprehensive management capabilities for the entire system.

### Access
- **URL:** http://localhost:5002/admin
- **Default Login:** 
  - Username: `admin`
  - Password: `baganetic2025!`

### Features
- **Dashboard Overview:** System statistics, health monitoring, recent activity
- **Pagoda Management:** Full CRUD operations for pagoda data
- **System Monitoring:** Real-time service health and performance metrics
- **Admin Logs:** Complete audit trail of all admin actions
- **Service Management:** Start/stop/restart system services

## 🔧 Manual Installation

1. **Install dependencies**
   ```bash
   npm install
   pip install -r requirements.txt
   ```

2. **Set up environment variables**
   ```bash
   cp env.template .env
   # Edit .env with your configuration
   ```

3. **Start the application**
   ```bash
   npm start
   ```

## 📁 Project Structure

```
Baganetic/
├── docs/                    # Documentation
├── assets/
│   ├── css/                # Stylesheets
│   ├── js/                 # Frontend JavaScript
│   ├── images/             # Images and icons
│   └── data/               # Pagoda data files
├── scripts/                # Startup and utility scripts
├── server.js               # Main server file
├── app.py                  # Main Flask application
├── admin_backend.py        # Admin system
├── chatbot_backend.py      # AI chatbot
├── package.json            # Dependencies and scripts
└── requirements.txt        # Python dependencies
```

## 🎯 Usage

### For Users
1. **Browse Pagodas**: Explore the comprehensive pagoda database
2. **Interactive Map**: Use the map to find and navigate between pagodas
3. **Create Account**: Register to save favorites and access personalized features
4. **User Profile**: Manage your account and preferences

### For Developers
1. **API Endpoints**: RESTful API for pagoda and user data
2. **Authentication**: JWT-based user authentication system
3. **Database**: MongoDB with Mongoose schemas
4. **Frontend**: Vanilla JavaScript with modern CSS

## 🔌 API Endpoints

### Authentication
- `POST /signup` - User registration
- `POST /login` - User login
- `POST /logout` - User logout
- `POST /forgot-password` - Password reset request
- `POST /reset-password` - Password reset

### Pagodas
- `GET /api/pagodas` - Get all pagodas
- `GET /api/pagodas/:id` - Get specific pagoda
- `GET /api/pagodas/featured` - Get featured pagodas
- `GET /api/pagodas/search/:query` - Search pagodas

### AI Chatbot
- `POST /api/chatbot/chat` - Send message to chatbot
- `GET /api/chatbot/history/:user_id` - Get chat history
- `POST /api/chatbot/clear/:user_id` - Clear chat history

## 🛡️ Security Features

- **Password Hashing**: bcryptjs for secure password storage
- **JWT Authentication**: Secure token-based authentication
- **Rate Limiting**: Protection against brute force attacks
- **Input Validation**: Comprehensive form and data validation
- **CORS Protection**: Cross-origin request security

## 🧪 Testing

### Test Authentication System
1. Open `http://localhost:5000/test-auth.html`
2. Test login, signup, and logout functionality
3. Verify localStorage persistence
4. Check authentication state management

## 🚀 Deployment

### Local Development
```bash
npm run dev    # Development mode with auto-reload
npm start      # Production mode
```

### Production Deployment
1. Set `NODE_ENV=production` in environment
2. Configure production MongoDB connection
3. Set strong JWT and session secrets
4. Use PM2 or similar process manager
5. Configure reverse proxy (nginx/Apache)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

If you encounter any issues:
1. Check the console for error messages
2. Verify MongoDB is running
3. Check environment variable configuration
4. Review the authentication test page
5. Check browser console for JavaScript errors

## 🙏 Acknowledgments

- Bagan Archaeological Museum for historical information
- Myanmar Tourism for location data
- Open source community for libraries and tools

---

**Made with ❤️ for exploring the ancient wonders of Bagan**
