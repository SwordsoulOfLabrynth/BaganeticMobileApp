#!/usr/bin/env python3
"""
Baganetic One-Click Setup Script
Automatically installs all dependencies and configures the application
"""

import os
import sys
import subprocess
import json
import shutil
import urllib.request
import zipfile
import tempfile
import platform
import secrets
import time
from pathlib import Path
from typing import List, Dict, Any, Optional

class BaganeticInstaller:
    def __init__(self):
        self.project_root = Path.cwd()
        self.installer_dir = self.project_root / ".installer"
        self.installer_dir.mkdir(exist_ok=True)
        self.fallback_mode = False
        self.mongodb_installed = False
        
    def log(self, message: str, level: str = "INFO"):
        """Log messages with timestamps"""
        timestamp = time.strftime("%H:%M:%S")
        icons = {"INFO": "[INFO]", "SUCCESS": "[OK]", "WARNING": "[WARN]", "ERROR": "[FAIL]"}
        print(f"[{timestamp}] {icons.get(level, '[INFO]')} {message}")
    
    def run_command(self, command: List[str], check: bool = True, shell: bool = False) -> subprocess.CompletedProcess:
        """Run a command and return the result"""
        try:
            if shell and isinstance(command, list):
                command = " ".join(command)
            return subprocess.run(command, check=check, shell=shell, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            self.log(f"Command failed: {' '.join(command) if isinstance(command, list) else command}", "ERROR")
            self.log(f"Error: {e.stderr}", "ERROR")
            raise
    
    def check_python_version(self) -> bool:
        """Check if Python version is compatible"""
        version = sys.version_info
        if version.major < 3 or (version.major == 3 and version.minor < 8):
            self.log(f"Python {version.major}.{version.minor} is not supported. Need Python 3.8+", "ERROR")
            return False
        self.log(f"Python {version.major}.{version.minor}.{version.micro} is compatible", "SUCCESS")
        return True
    
    def check_node_js(self) -> bool:
        """Check if Node.js is installed"""
        try:
            result = self.run_command(["node", "--version"], check=False)
            if result.returncode == 0:
                version = result.stdout.strip()
                self.log(f"Node.js {version} found", "SUCCESS")
                return True
        except FileNotFoundError:
            pass
        
        self.log("Node.js not found, will install it", "WARNING")
        return False
    
    def install_node_js(self) -> bool:
        """Download and install Node.js for Windows"""
        try:
            self.log("Downloading Node.js installer...")
            
            # Get latest LTS version info
            with urllib.request.urlopen("https://nodejs.org/dist/index.json") as response:
                versions = json.loads(response.read().decode())
                lts_version = next(v for v in versions if v.get("lts"))
                version = lts_version["version"]
            
            # Download installer
            installer_url = f"https://nodejs.org/dist/{version}/node-{version}-x64.msi"
            installer_path = self.installer_dir / f"node-{version}-x64.msi"
            
            self.log(f"Downloading Node.js {version}...")
            urllib.request.urlretrieve(installer_url, installer_path)
            
            # Install silently
            self.log("Installing Node.js (this may take a few minutes)...")
            result = self.run_command([
                "msiexec", "/i", str(installer_path), 
                "/quiet", "/norestart", "/L*v", str(self.installer_dir / "nodejs_install.log")
            ], check=False)
            
            if result.returncode == 0:
                self.log("Node.js installed successfully", "SUCCESS")
                # Update PATH for current session
                os.environ["PATH"] = os.environ["PATH"] + ";C:\\Program Files\\nodejs"
                return True
            else:
                self.log("Node.js installation failed", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"Failed to install Node.js: {e}", "ERROR")
            return False
    
    def check_mongodb(self) -> bool:
        """Check if MongoDB is installed and running"""
        try:
            # Check if mongod is available
            result = self.run_command(["mongod", "--version"], check=False)
            if result.returncode == 0:
                self.log("MongoDB found", "SUCCESS")
                self.mongodb_installed = True
                
                # Try to start MongoDB
                return self.start_mongodb()
        except FileNotFoundError:
            pass
        
        self.log("MongoDB not found, will install it", "WARNING")
        return False
    
    def install_mongodb(self) -> bool:
        """Download and install MongoDB Community Server"""
        try:
            self.log("Downloading MongoDB Community Server...")
            
            # MongoDB download URL for Windows
            mongodb_url = "https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-7.0.4-signed.msi"
            installer_path = self.installer_dir / "mongodb-installer.msi"
            
            urllib.request.urlretrieve(mongodb_url, installer_path)
            
            # Install MongoDB
            self.log("Installing MongoDB (this may take a few minutes)...")
            result = self.run_command([
                "msiexec", "/i", str(installer_path),
                "/quiet", "/norestart", "/L*v", str(self.installer_dir / "mongodb_install.log")
            ], check=False)
            
            if result.returncode == 0:
                self.log("MongoDB installed successfully", "SUCCESS")
                self.mongodb_installed = True
                
                # Create data directory
                data_dir = Path("C:/data/db")
                data_dir.mkdir(parents=True, exist_ok=True)
                
                return self.start_mongodb()
            else:
                self.log("MongoDB installation failed", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"Failed to install MongoDB: {e}", "ERROR")
            return False
    
    def start_mongodb(self) -> bool:
        """Start MongoDB service"""
        try:
            # Try to start as Windows service
            result = self.run_command(["net", "start", "MongoDB"], check=False)
            if result.returncode == 0:
                self.log("MongoDB service started", "SUCCESS")
                return True
            
            # If service doesn't exist, try to start manually
            self.log("Starting MongoDB manually...")
            mongod_path = Path("C:/Program Files/MongoDB/Server/7.0/bin/mongod.exe")
            if mongod_path.exists():
                # Start in background
                subprocess.Popen([str(mongod_path), "--dbpath", "C:/data/db"], 
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                time.sleep(3)  # Give it time to start
                self.log("MongoDB started manually", "SUCCESS")
                return True
            
            return False
            
        except Exception as e:
            self.log(f"Failed to start MongoDB: {e}", "ERROR")
            return False
    
    def install_python_packages(self) -> bool:
        """Install Python packages in phases"""
        try:
            self.log("Installing Python packages...")
            
            # Phase 1: Core requirements (essential)
            self.log("Phase 1: Installing core packages...")
            core_requirements = [
                "flask>=2.0.0",
                "flask-cors>=3.0.0", 
                "requests>=2.25.0",
                "PyJWT>=2.0.0",
                "pymongo>=4.6.0",
                "python-dotenv>=0.19.0"
            ]
            
            for package in core_requirements:
                try:
                    self.log(f"Installing {package}...")
                    self.run_command([sys.executable, "-m", "pip", "install", package])
                except Exception as e:
                    self.log(f"Failed to install {package}: {e}", "WARNING")
            
            # Phase 2: Chatbot essentials (required for full functionality)
            self.log("Phase 2: Installing chatbot essentials...")
            chatbot_essentials = [
                "nltk>=3.8.0",
                "scikit-learn>=1.3.0",
                "numpy>=1.24.0",
                "pandas>=2.1.0",
                "fuzzywuzzy>=0.18.0",
                "python-Levenshtein>=0.21.0"
            ]
            
            for package in chatbot_essentials:
                try:
                    self.log(f"Installing {package}...")
                    self.run_command([sys.executable, "-m", "pip", "install", package])
                except Exception as e:
                    self.log(f"Failed to install {package}: {e}", "WARNING")
            
            # Phase 3: Optional packages (install if possible)
            self.log("Phase 3: Installing optional packages...")
            optional_packages = [
                "spacy>=3.7.0"
            ]
            
            for package in optional_packages:
                try:
                    self.log(f"Installing {package} (optional)...")
                    self.run_command([sys.executable, "-m", "pip", "install", package])
                except Exception as e:
                    self.log(f"Optional package {package} failed: {e}", "WARNING")
                    self.log("Continuing without this package...", "WARNING")
            
            # Phase 4: Install from requirements.txt if it exists (covers any missing packages)
            if Path("requirements.txt").exists():
                self.log("Phase 4: Installing from requirements.txt...")
                try:
                    self.run_command([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
                except Exception as e:
                    self.log(f"Some packages from requirements.txt failed: {e}", "WARNING")
            
            self.log("Python packages installation completed", "SUCCESS")
            return True
            
        except Exception as e:
            self.log(f"Failed to install Python packages: {e}", "ERROR")
            return False
    
    def install_node_packages(self) -> bool:
        """Install Node.js packages"""
        try:
            if not Path("package.json").exists():
                self.log("No package.json found, skipping Node.js packages", "WARNING")
                return True
            
            self.log("Installing Node.js packages...")
            self.run_command(["npm", "install"], shell=True)
            self.log("Node.js packages installed successfully", "SUCCESS")
            return True
            
        except Exception as e:
            self.log(f"Failed to install Node.js packages: {e}", "ERROR")
            return False
    
    def create_env_file(self) -> bool:
        """Create .env file with secure defaults"""
        try:
            env_path = self.project_root / ".env"
            if env_path.exists():
                self.log(".env file already exists, backing up...")
                shutil.copy(env_path, env_path.with_suffix(".env.backup"))
            
            # Generate secure secrets
            jwt_secret = secrets.token_urlsafe(64)
            session_secret = secrets.token_urlsafe(64)
            
            # Determine MongoDB URI
            if self.mongodb_installed:
                mongodb_uri = "mongodb://localhost:27017/baganetic_users"
            else:
                mongodb_uri = "mongodb://localhost:27017/baganetic_users"
                self.fallback_mode = True
            
            env_content = f"""# Baganetic Configuration - Generated by installer
# Server Configuration
PORT=5000
NODE_ENV=development
FLASK_ENV=development
FLASK_DEBUG=1

# Database Configuration
MONGODB_URI={mongodb_uri}
FALLBACK_MODE={'true' if self.fallback_mode else 'false'}

# Security Configuration
JWT_SECRET={jwt_secret}
SESSION_SECRET={session_secret}
JWT_EXPIRES_IN=86400
SESSION_MAX_AGE=86400000

# Admin Configuration
ADMIN_USERNAME=admin
ADMIN_PASSWORD=baganetic2025!
ADMIN_SESSION_SECRET={session_secret}

# CORS Configuration
CORS_ORIGIN=http://localhost:5000,http://localhost:3000,http://localhost:5002

# Logging
LOG_LEVEL=info
ENABLE_REQUEST_LOGGING=true
DEBUG=true
SHOW_ERROR_DETAILS=true

# Rate Limiting
RATE_LIMIT_MAX=100
RATE_LIMIT_WINDOW_MS=900000
"""
            
            with open(env_path, 'w') as f:
                f.write(env_content)
            
            self.log(".env file created successfully", "SUCCESS")
            return True
            
        except Exception as e:
            self.log(f"Failed to create .env file: {e}", "ERROR")
            return False
    
    def setup_directories(self) -> bool:
        """Create necessary directories"""
        try:
            directories = [
                "uploads",
                "uploads/avatars", 
                "uploads/pagodas",
                "logs",
                "temp"
            ]
            
            for directory in directories:
                Path(directory).mkdir(parents=True, exist_ok=True)
            
            self.log("Directories created successfully", "SUCCESS")
            return True
            
        except Exception as e:
            self.log(f"Failed to create directories: {e}", "ERROR")
            return False
    
    def seed_database(self) -> bool:
        """Seed the database with initial data"""
        try:
            if not self.mongodb_installed:
                self.log("MongoDB not available, skipping database seeding", "WARNING")
                return True
            
            # Import here to avoid issues if pymongo not installed
            try:
                from pymongo import MongoClient
                import json
                
                # Connect to MongoDB
                client = MongoClient("mongodb://localhost:27017/")
                db = client["baganetic_users"]
                
                # Create collections
                users_collection = db["users"]
                pagodas_collection = db["pagodas"]
                
                # Create admin user
                admin_user = {
                    "username": "admin",
                    "email": "admin@baganetic.com",
                    "password": "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4J/9KJ8K2O",  # baganetic2025!
                    "role": "admin",
                    "created_at": "2024-01-01T00:00:00Z",
                    "verified": True
                }
                
                # Check if admin user exists
                if not users_collection.find_one({"username": "admin"}):
                    users_collection.insert_one(admin_user)
                    self.log("Admin user created", "SUCCESS")
                
                # Load pagoda data from JS file
                pagoda_js_path = self.project_root / "assets" / "data" / "pagodas.js"
                if pagoda_js_path.exists():
                    with open(pagoda_js_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Extract JSON data from JS file
                    start = content.find('[')
                    end = content.rfind(']') + 1
                    if start != -1 and end != -1:
                        json_data = content[start:end]
                        pagodas = json.loads(json_data)
                        
                        # Insert pagodas if collection is empty
                        if pagodas_collection.count_documents({}) == 0:
                            for pagoda in pagodas:
                                pagoda["_id"] = pagoda.get("id")
                                del pagoda["id"]  # Remove id field as MongoDB uses _id
                            
                            pagodas_collection.insert_many(pagodas)
                            self.log(f"Seeded {len(pagodas)} pagodas", "SUCCESS")
                
                client.close()
                return True
                
            except ImportError:
                self.log("pymongo not available, skipping database seeding", "WARNING")
                return True
                
        except Exception as e:
            self.log(f"Failed to seed database: {e}", "ERROR")
            return False
    
    def download_nltk_data(self) -> bool:
        """Download required NLTK data for chatbot"""
        try:
            self.log("Downloading NLTK data for chatbot...")
            
            # Check if nltk is available
            try:
                import nltk
            except ImportError:
                self.log("NLTK not available, skipping data download", "WARNING")
                return True
            
            # Required NLTK data for chatbot functionality
            nltk_data = [
                'punkt',                    # Sentence tokenization
                'stopwords',                # Stop words for text processing
                'wordnet',                  # WordNet lemmatizer
                'averaged_perceptron_tagger', # POS tagging
                'maxent_ne_chunker',       # Named entity chunking
                'words'                     # Word corpus
            ]
            
            downloaded = 0
            failed = 0
            
            for data in nltk_data:
                try:
                    self.log(f"Downloading NLTK data: {data}...")
                    nltk.download(data, quiet=True)
                    downloaded += 1
                except Exception as e:
                    self.log(f"Failed to download {data}: {e}", "WARNING")
                    failed += 1
            
            if downloaded > 0:
                self.log(f"NLTK data download completed: {downloaded} packages downloaded", "SUCCESS")
            if failed > 0:
                self.log(f"Warning: {failed} NLTK packages failed to download", "WARNING")
            
            return True
            
        except Exception as e:
            self.log(f"Failed to download NLTK data: {e}", "WARNING")
            return True  # Not critical for basic functionality
    
    def create_launch_scripts(self) -> bool:
        """Create convenient launch scripts"""
        try:
            # Create START.bat
            start_bat_content = """@echo off
echo 🏛️ Starting Baganetic...
echo.

REM Check if setup was completed
if not exist ".env" (
    echo ❌ Setup not completed. Please run setup.bat first.
    pause
    exit /b 1
)

REM Start the application
python scripts/start_all.py

REM Open browser
timeout /t 3 /nobreak >nul
start http://localhost:5000

pause
"""
            
            with open("START.bat", 'w') as f:
                f.write(start_bat_content)
            
            self.log("Launch scripts created", "SUCCESS")
            return True
            
        except Exception as e:
            self.log(f"Failed to create launch scripts: {e}", "ERROR")
            return False
    
    def run(self) -> bool:
        """Main installation process"""
        self.log("Starting Baganetic installation...")
        
        # Check Python version
        if not self.check_python_version():
            return False
        
        # Check and install Node.js
        if not self.check_node_js():
            if not self.install_node_js():
                self.log("Node.js installation failed, continuing without it", "WARNING")
        
        # Check and install MongoDB
        if not self.check_mongodb():
            if not self.install_mongodb():
                self.log("MongoDB installation failed, will use fallback mode", "WARNING")
                self.fallback_mode = True
        
        # Install Python packages
        if not self.install_python_packages():
            return False
        
        # Install Node.js packages
        if not self.install_node_packages():
            self.log("Node.js package installation failed, continuing...", "WARNING")
        
        # Create environment file
        if not self.create_env_file():
            return False
        
        # Setup directories
        if not self.setup_directories():
            return False
        
        # Seed database
        if not self.seed_database():
            self.log("Database seeding failed, continuing...", "WARNING")
        
        # Download NLTK data
        self.download_nltk_data()
        
        # Create launch scripts
        if not self.create_launch_scripts():
            return False
        
        # Final status
        self.log("=" * 50, "SUCCESS")
        self.log("Installation completed successfully!", "SUCCESS")
        
        if self.fallback_mode:
            self.log("Running in FALLBACK MODE (limited features)", "WARNING")
            self.log("MongoDB features disabled. Install MongoDB for full functionality.", "WARNING")
        else:
            self.log("Full functionality enabled with MongoDB", "SUCCESS")
        
        self.log("=" * 50, "SUCCESS")
        return True

def main():
    """Main entry point"""
    installer = BaganeticInstaller()
    success = installer.run()
    
    if not success:
        installer.log("Installation failed!", "ERROR")
        sys.exit(1)
    
    installer.log("Ready to launch! Run START.bat to begin.", "SUCCESS")

if __name__ == "__main__":
    main()
