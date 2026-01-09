#!/usr/bin/env python3
"""
Baganetic Admin System Startup Script
Starts the admin backend server
"""

import os
import sys
import subprocess
import time
import requests
from pathlib import Path

def check_dependencies():
    """Check if required dependencies are installed"""
    try:
        import flask
        import requests
        print("✅ Required dependencies are installed")
        return True
    except ImportError as e:
        print(f"❌ Missing dependency: {e}")
        print("Please install required packages:")
        print("pip install flask requests")
        return False

def check_main_app():
    """Check if main Baganetic app is running"""
    try:
        response = requests.get('http://localhost:5000/api/health', timeout=3)
        if response.status_code == 200:
            print("✅ Main Baganetic app is running on port 5000")
            return True
        else:
            print("⚠️  Main Baganetic app responded with status:", response.status_code)
            return False
    except requests.exceptions.ConnectionError:
        print("❌ Main Baganetic app is not running on port 5000")
        print("Please start the main app first: python app.py")
        return False
    except Exception as e:
        print(f"⚠️  Could not check main app status: {e}")
        return False

def check_chatbot():
    """Check if chatbot is running"""
    try:
        response = requests.get('http://localhost:5001/api/chatbot/health', timeout=3)
        if response.status_code == 200:
            print("✅ Chatbot is running on port 5001")
            return True
        else:
            print("⚠️  Chatbot responded with status:", response.status_code)
            return False
    except requests.exceptions.ConnectionError:
        print("⚠️  Chatbot is not running on port 5001 (optional)")
        return False
    except Exception as e:
        print(f"⚠️  Could not check chatbot status: {e}")
        return False

def create_env_file():
    """Create environment file if it doesn't exist"""
    env_file = Path('.env')
    if not env_file.exists():
        print("📝 Creating .env file with default admin credentials...")
        with open('.env', 'w') as f:
            f.write("# Baganetic Admin Configuration\n")
            f.write("ADMIN_USERNAME=admin\n")
            f.write("ADMIN_PASSWORD=baganetic2025!\n")
            f.write("FLASK_ENV=development\n")
        print("✅ Created .env file")
        print("🔐 Default admin credentials:")
        print("   Username: admin")
        print("   Password: baganetic2025!")
        print("   ⚠️  Please change these credentials in production!")
    else:
        print("✅ .env file already exists")

def start_admin_server():
    """Start the admin backend server"""
    print("\n🚀 Starting Baganetic Admin Backend...")
    print("=" * 50)
    
    try:
        # Import and run the admin backend
        from admin_backend import app
        print("✅ Admin backend imported successfully")
        print("🌐 Admin interface will be available at: http://localhost:5002/admin")
        print("🔐 Default login credentials:")
        print("   Username: admin")
        print("   Password: baganetic2025!")
        print("\n📊 Admin Dashboard Features:")
        print("   • Dashboard with system statistics")
        print("   • Pagoda management (CRUD operations)")
        print("   • System health monitoring")
        print("   • Admin activity logs")
        print("   • Service restart capabilities")
        print("\n" + "=" * 50)
        print("Press Ctrl+C to stop the admin server")
        print("=" * 50)
        
        app.run(debug=True, host='0.0.0.0', port=5002)
        
    except KeyboardInterrupt:
        print("\n\n👋 Admin server stopped by user")
    except Exception as e:
        print(f"\n❌ Failed to start admin server: {e}")
        sys.exit(1)

def main():
    """Main startup function"""
    print("🏛️  Baganetic Admin System Startup")
    print("=" * 40)
    
    # Check dependencies
    if not check_dependencies():
        sys.exit(1)
    
    # Create environment file
    create_env_file()
    
    # Check if main app is running
    main_app_running = check_main_app()
    
    # Check if chatbot is running
    chatbot_running = check_chatbot()
    
    print("\n📋 System Status:")
    print(f"   Main App: {'✅ Running' if main_app_running else '❌ Not Running'}")
    print(f"   Chatbot:  {'✅ Running' if chatbot_running else '⚠️  Not Running (Optional)'}")
    
    if not main_app_running:
        print("\n⚠️  Warning: Main Baganetic app is not running.")
        print("   Some features may not work properly.")
        print("   Please start the main app first: python app.py")
        
        response = input("\nDo you want to continue anyway? (y/N): ")
        if response.lower() != 'y':
            print("👋 Exiting...")
            sys.exit(0)
    
    # Start admin server
    start_admin_server()

if __name__ == '__main__':
    main()
