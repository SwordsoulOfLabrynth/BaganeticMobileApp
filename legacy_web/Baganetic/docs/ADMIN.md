# 🏛️ Baganetic Admin Dashboard

A comprehensive admin interface for managing the Baganetic tour guide application. This admin system provides full control over pagodas, system monitoring, and content management.

## 🚀 Quick Start

### Windows Users
```bash
# Double-click the batch file
start_admin.bat
```

### Linux/Mac Users
```bash
# Make the script executable and run
chmod +x start_admin.py
python start_admin.py
```

### Manual Start
```bash
# Install dependencies
pip install flask requests

# Start the admin backend
python admin_backend.py
```

## 🌐 Access the Admin Dashboard

Once started, open your browser and navigate to:
```
http://localhost:5002/admin
```

### Default Login Credentials
- **Username:** `admin`
- **Password:** `baganetic2025!`

⚠️ **Important:** Change these credentials in production by setting environment variables:
```bash
export ADMIN_USERNAME=your_username
export ADMIN_PASSWORD=your_secure_password
```

## 📊 Features

### 1. Dashboard Overview
- **System Statistics:** Total pagodas, featured pagodas, temples, locations
- **System Health:** Real-time monitoring of main app, chatbot, and database
- **Recent Activity:** Latest admin actions and system events
- **Quick Actions:** Refresh data, restart services

### 2. Pagoda Management
- **View All Pagodas:** Complete list with filtering and search
- **Add New Pagodas:** Create pagodas with full details
- **Edit Existing Pagodas:** Update information, images, descriptions
- **Delete Pagodas:** Remove pagodas with confirmation
- **Featured Management:** Mark pagodas as featured for homepage display

### 3. System Monitoring
- **Service Status:** Check health of main app, chatbot, database
- **Response Times:** Monitor API performance
- **Error Tracking:** View system errors and issues
- **Service Restart:** Restart services when needed

### 4. Admin Logs
- **Activity Tracking:** All admin actions are logged
- **Audit Trail:** Track who did what and when
- **Error Logs:** System errors and warnings
- **Search & Filter:** Find specific actions or time periods

## 🛠️ Technical Details

### Architecture
```
Admin Frontend (HTML/CSS/JS) → Admin Backend (Flask) → Main App (Flask) → Database
```

### Ports Used
- **Admin Backend:** `5002`
- **Main App:** `5000` (required)
- **Chatbot:** `5001` (optional)

### File Structure
```
├── admin_backend.py          # Main admin backend server
├── templates/
│   └── admin.html           # Admin dashboard HTML
├── assets/
│   ├── css/
│   │   └── admin.css        # Admin-specific styles
│   └── js/
│       └── admin.js         # Admin dashboard JavaScript
├── scripts/
│   ├── start_admin.py       # Startup script
│   └── start_admin.bat      # Windows batch file
└── docs/
    └── ADMIN.md             # This file
```

## 🔧 Configuration

### Environment Variables
Create a `.env` file in the project root:
```env
# Admin Configuration
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your_secure_password
FLASK_ENV=development

# Optional: MongoDB connection
MONGODB_URI=mongodb://localhost:27017/baganetic
```

### Security Settings
The admin system includes several security features:
- **Session Management:** 1-hour session timeout
- **Brute Force Protection:** 5 failed attempts = 15-minute lockout
- **CSRF Protection:** Built-in Flask security
- **Input Validation:** All inputs are validated and sanitized

## 📝 API Endpoints

### Authentication
- `POST /admin/login` - Admin login
- `POST /admin/logout` - Admin logout
- `GET /admin/status` - Check authentication status

### Dashboard
- `GET /admin/dashboard/stats` - Get dashboard statistics
- `GET /admin/dashboard/logs` - Get recent admin logs

### Pagoda Management
- `GET /admin/pagodas` - Get all pagodas
- `GET /admin/pagodas/<id>` - Get specific pagoda
- `POST /admin/pagodas` - Create new pagoda
- `PUT /admin/pagodas/<id>` - Update pagoda
- `DELETE /admin/pagodas/<id>` - Delete pagoda

### System Management
- `GET /admin/system/health` - Get detailed system health
- `POST /admin/system/restart/<service>` - Restart service

## 🎨 Customization

### Styling
The admin interface uses a custom CSS framework with:
- **Color Scheme:** Professional blue and gray palette
- **Responsive Design:** Works on desktop, tablet, and mobile
- **Modern UI:** Clean, intuitive interface with smooth animations
- **Accessibility:** WCAG compliant design

### Adding New Features
1. **Backend:** Add new endpoints in `admin_backend.py`
2. **Frontend:** Add new sections in `admin.html`
3. **JavaScript:** Add functionality in `admin.js`
4. **Styling:** Add styles in `admin.css`

## 🔍 Troubleshooting

### Common Issues

#### Admin Server Won't Start
```bash
# Check if port 5002 is available
netstat -an | findstr :5002

# Kill process using the port
taskkill /PID <process_id> /F
```

#### Can't Connect to Main App
```bash
# Check if main app is running
curl http://localhost:5000/api/health

# Start main app if needed
python app.py
```

#### Login Issues
- Verify credentials in `.env` file
- Check browser console for errors
- Clear browser cache and cookies
- Check admin backend logs

#### Pagoda Data Not Loading
- Verify `assets/data/pagodas.js` exists
- Check file permissions
- Verify JSON syntax in pagoda data
- Check browser network tab for API errors

### Debug Mode
Enable debug mode by setting:
```env
FLASK_ENV=development
FLASK_DEBUG=1
```

### Logs
Admin actions are logged in memory and can be viewed in the admin interface. For persistent logging, modify `admin_backend.py` to use a proper logging system.

## 🚀 Deployment

### Production Setup
1. **Change Default Credentials:**
   ```env
   ADMIN_USERNAME=your_secure_username
   ADMIN_PASSWORD=your_very_secure_password
   ```

2. **Use Production WSGI Server:**
   ```bash
   pip install gunicorn
   gunicorn -w 4 -b 0.0.0.0:5002 admin_backend:app
   ```

3. **Set Up Reverse Proxy:**
   ```nginx
   location /admin {
       proxy_pass http://localhost:5002;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
   }
   ```

4. **Enable HTTPS:**
   - Use SSL certificates
   - Redirect HTTP to HTTPS
   - Set secure session cookies

### Docker Deployment
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 5002

CMD ["python", "admin_backend.py"]
```

## 📚 Development

### Adding New Admin Features
1. **Backend API:**
   ```python
   @app.route('/admin/new-feature', methods=['GET', 'POST'])
   @require_admin_auth
   def new_feature():
       # Implementation
   ```

2. **Frontend Integration:**
   ```javascript
   async loadNewFeature() {
       const response = await fetch(`${this.apiBase}/new-feature`);
       // Handle response
   }
   ```

3. **UI Components:**
   ```html
   <div id="newFeatureSection" class="hidden">
       <!-- New feature UI -->
   </div>
   ```

### Testing
```bash
# Test admin endpoints
curl -X POST http://localhost:5002/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"baganetic2025!"}'
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This admin system is part of the Baganetic project and follows the same license terms.

## 🆘 Support

For issues and questions:
1. Check this documentation
2. Review the troubleshooting section
3. Check the main Baganetic documentation
4. Create an issue in the project repository

---

**Made with ❤️ for Baganetic Admin Management**
