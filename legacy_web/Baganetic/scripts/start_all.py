#!/usr/bin/env python3
"""
Baganetic Complete System Startup Script
Starts all services including the admin system and chatbot
"""

import os
import sys
import subprocess
import time
import threading
import requests
from pathlib import Path
import signal

class BaganeticSystem:
    def __init__(self):
        self.processes = {}
        self.running = True
        
    def check_dependencies(self):
        """Check if all required dependencies are installed"""
        print("🔍 Checking dependencies...")
        
        # Check for fallback mode
        fallback_mode = os.getenv("FALLBACK_MODE", "false").lower() == "true"
        if fallback_mode:
            print("⚠️  Running in fallback mode - limited functionality")
        
        required_packages = [
            'flask', 'requests', 'flask_cors'
        ]
        
        missing_packages = []
        for package in required_packages:
            try:
                __import__(package.replace('-', '_'))
                print(f"✅ {package}")
            except ImportError:
                missing_packages.append(package)
                print(f"❌ {package}")
        
        if missing_packages:
            print(f"\n📦 Installing missing packages: {', '.join(missing_packages)}")
            try:
                subprocess.check_call([sys.executable, '-m', 'pip', 'install'] + missing_packages)
                print("✅ Dependencies installed successfully")
            except subprocess.CalledProcessError:
                print("❌ Failed to install dependencies")
                return False
        
        return True
    
    def start_service(self, name, command, port, delay=2):
        """Start a service in a separate process"""
        try:
            print(f"🚀 Starting {name}...")
            
            if isinstance(command, str):
                process = subprocess.Popen(command, shell=True)
            else:
                process = subprocess.Popen(command)
            
            self.processes[name] = {
                'process': process,
                'port': port,
                'command': command
            }
            
            # Wait for service to start
            time.sleep(delay)
            
            # Check if service is running
            if self.check_service_health(port):
                print(f"✅ {name} started successfully on port {port}")
                return True
            else:
                print(f"⚠️  {name} started but health check failed")
                return False
                
        except Exception as e:
            print(f"❌ Failed to start {name}: {e}")
            return False
    
    def check_service_health(self, port, timeout=5):
        """Check if a service is healthy"""
        try:
            if port == 5000:
                response = requests.get(f'http://localhost:{port}/api/health', timeout=timeout)
            elif port == 5001:
                response = requests.get(f'http://localhost:{port}/api/chatbot/health', timeout=timeout)
            elif port == 5002:
                response = requests.get(f'http://localhost:{port}/admin/status', timeout=timeout)
            else:
                return True  # Skip health check for unknown ports
            
            return response.status_code == 200
        except:
            return False
    
    def start_main_app(self):
        """Start the main Baganetic Flask app"""
        return self.start_service(
            "Main App",
            [sys.executable, "app.py"],
            5000,
            delay=3
        )
    
    def start_chatbot(self):
        """Start the chatbot service (agentic backend)"""
        if not Path("chatbot_backend.py").exists():
            print("⚠️  Agentic chatbot backend not found, skipping...")
            return True
        
        return self.start_service(
            "Chatbot",
            [sys.executable, "chatbot_backend.py"],
            5001,
            delay=2
        )
    
    def start_admin(self):
        """Start the admin system"""
        return self.start_service(
            "Admin System",
            [sys.executable, "admin_backend.py"],
            5002,
            delay=2
        )
    
    def start_node_server(self):
        """Start the Node.js server if available"""
        if not Path("server.js").exists():
            print("⚠️  Node.js server not found, skipping...")
            return True
        
        if not Path("package.json").exists():
            print("⚠️  package.json not found, skipping Node.js server...")
            return True
        
        return self.start_service(
            "Node.js Server",
            ["node", "server.js"],
            3000,
            delay=3
        )
    
    def display_status(self):
        """Display system status"""
        print("\n" + "="*60)
        print("🏛️  BAGANETIC SYSTEM STATUS")
        print("="*60)
        
        # Check fallback mode
        fallback_mode = os.getenv("FALLBACK_MODE", "false").lower() == "true"
        if fallback_mode:
            print("⚠️  FALLBACK MODE - Limited functionality")
            print("   MongoDB features disabled, using JSON data files")
            print("="*60)
        
        services = [
            ("Main App", 5000, "http://localhost:5000"),
            ("Chatbot", 5001, "http://localhost:5001"),
            ("Admin System", 5002, "http://localhost:5002/admin"),
            ("Node.js Server", 3000, "http://localhost:3000")
        ]
        
        for name, port, url in services:
            if name in self.processes:
                status = "🟢 RUNNING" if self.check_service_health(port) else "🟡 STARTING"
                print(f"{name:<15} {status:<10} {url}")
            else:
                print(f"{name:<15} 🔴 STOPPED   {url}")
        
        print("="*60)
        print("🔐 Admin Login Credentials:")
        print("   Username: admin")
        print("   Password: baganetic2025!")
        print("="*60)
        print("📊 Available Services:")
        print("   • Main App: Baganetic tour guide application")
        if not fallback_mode:
            print("   • Admin System: Full admin dashboard")
            print("   • Chatbot: AI assistant with full features")
        else:
            print("   • Admin System: Limited (read-only mode)")
            print("   • Chatbot: Basic functionality only")
        print("   • Node.js Server: Frontend server (if available)")
        print("="*60)
        print("Press Ctrl+C to stop all services")
        print("="*60)
    
    def stop_all_services(self):
        """Stop all running services"""
        print("\n🛑 Stopping all services...")
        
        for name, service_info in self.processes.items():
            try:
                process = service_info['process']
                if process.poll() is None:  # Process is still running
                    print(f"🛑 Stopping {name}...")
                    process.terminate()
                    
                    # Wait for graceful shutdown
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        print(f"⚠️  Force killing {name}...")
                        process.kill()
                        process.wait()
                    
                    print(f"✅ {name} stopped")
            except Exception as e:
                print(f"❌ Error stopping {name}: {e}")
        
        self.processes.clear()
        print("✅ All services stopped")
    
    def monitor_services(self):
        """Monitor services and restart if needed"""
        while self.running:
            time.sleep(10)  # Check every 10 seconds
            
            for name, service_info in list(self.processes.items()):
                process = service_info['process']
                port = service_info['port']
                
                # Check if process is still running
                if process.poll() is not None:
                    print(f"⚠️  {name} has stopped unexpectedly")
                    del self.processes[name]
                    
                    # Attempt to restart
                    if name == "Main App":
                        self.start_main_app()
                    elif name == "Chatbot":
                        self.start_chatbot()
                    elif name == "Admin System":
                        self.start_admin()
                    elif name == "Node.js Server":
                        self.start_node_server()
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        print(f"\n🛑 Received signal {signum}, shutting down...")
        self.running = False
        self.stop_all_services()
        sys.exit(0)
    
    def create_env_file(self):
        """Create environment file if it doesn't exist"""
        env_file = Path('.env')
        if not env_file.exists():
            print("📝 Creating .env file...")
            with open('.env', 'w') as f:
                f.write("# Baganetic Configuration\n")
                f.write("ADMIN_USERNAME=admin\n")
                f.write("ADMIN_PASSWORD=baganetic2025!\n")
                f.write("FLASK_ENV=development\n")
                f.write("FLASK_DEBUG=1\n")
            print("✅ Created .env file with default settings")
    
    def run(self):
        """Main run method"""
        print("🏛️  BAGANETIC COMPLETE SYSTEM STARTUP")
        print("="*50)
        
        # Set up signal handlers
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
        
        # Check dependencies
        if not self.check_dependencies():
            print("❌ Dependency check failed")
            return False
        
        # Create environment file
        self.create_env_file()
        
        # Start services
        print("\n🚀 Starting services...")
        
        services_started = 0
        total_services = 4
        
        # Start main app first (required)
        if self.start_main_app():
            services_started += 1
        
        # Start other services
        if self.start_chatbot():
            services_started += 1
        
        if self.start_admin():
            services_started += 1
        
        if self.start_node_server():
            services_started += 1
        
        # Display status
        self.display_status()
        
        if services_started == 0:
            print("❌ No services started successfully")
            return False
        
        # Start monitoring thread
        monitor_thread = threading.Thread(target=self.monitor_services, daemon=True)
        monitor_thread.start()
        
        # Keep main thread alive
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            self.signal_handler(signal.SIGINT, None)
        
        return True

def main():
    """Main function"""
    system = BaganeticSystem()
    success = system.run()
    
    if not success:
        print("❌ System startup failed")
        sys.exit(1)
    
    print("👋 System shutdown complete")

if __name__ == '__main__':
    main()
