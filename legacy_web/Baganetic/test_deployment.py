#!/usr/bin/env python3
"""
Baganetic Deployment Test Script
Tests the one-click deployment setup
"""

import os
import sys
import subprocess
import time
import requests
from pathlib import Path

def test_file_exists(file_path, description):
    """Test if a file exists"""
    if Path(file_path).exists():
        print(f"[OK] {description}: {file_path}")
        return True
    else:
        print(f"[FAIL] {description}: {file_path} - NOT FOUND")
        return False

def test_environment():
    """Test environment setup"""
    print("Testing Environment Setup...")
    print("=" * 50)
    
    # Test essential files
    files_to_test = [
        ("setup.bat", "Master installer script"),
        ("setup.py", "Python installer script"),
        ("START.bat", "Quick launch script"),
        ("uninstall.bat", "Uninstaller script"),
        ("INSTALL.txt", "Installation guide"),
        (".gitignore", "Git ignore file"),
        ("requirements-core.txt", "Core requirements"),
        ("app.py", "Main Flask application"),
        ("admin_backend.py", "Admin backend"),
        ("chatbot_backend.py", "Chatbot backend"),
        ("env.template", "Environment template"),
        ("assets/data/pagodas.js", "Pagoda data file")
    ]
    
    all_files_exist = True
    for file_path, description in files_to_test:
        if not test_file_exists(file_path, description):
            all_files_exist = False
    
    print("=" * 50)
    if all_files_exist:
        print("[OK] All essential files present")
    else:
        print("[FAIL] Some files missing")
    
    return all_files_exist

def test_python_imports():
    """Test if Python can import required modules"""
    print("\nTesting Python Imports...")
    print("=" * 50)
    
    required_modules = [
        "flask",
        "flask_cors", 
        "requests",
        "json",
        "os",
        "sys"
    ]
    
    all_imports_work = True
    for module in required_modules:
        try:
            __import__(module)
            print(f"[OK] {module}")
        except ImportError as e:
            print(f"[FAIL] {module}: {e}")
            all_imports_work = False
    
    print("=" * 50)
    if all_imports_work:
        print("[OK] All required Python modules available")
    else:
        print("[FAIL] Some Python modules missing")
    
    return all_imports_work

def test_environment_file():
    """Test if .env file exists and has required variables"""
    print("\nTesting Environment Configuration...")
    print("=" * 50)
    
    env_file = Path(".env")
    if not env_file.exists():
        print("[FAIL] .env file not found - run setup.bat first")
        return False
    
    # Read .env file
    with open(env_file, 'r') as f:
        content = f.read()
    
    required_vars = [
        "PORT",
        "JWT_SECRET", 
        "SESSION_SECRET",
        "FALLBACK_MODE"
    ]
    
    all_vars_present = True
    for var in required_vars:
        if f"{var}=" in content:
            print(f"[OK] {var}")
        else:
            print(f"[FAIL] {var} - NOT FOUND")
            all_vars_present = False
    
    print("=" * 50)
    if all_vars_present:
        print("[OK] Environment configuration complete")
    else:
        print("[FAIL] Some environment variables missing")
    
    return all_vars_present

def test_services_startup():
    """Test if services can start (basic test)"""
    print("\nTesting Service Startup...")
    print("=" * 50)
    
    # Test if we can import the main modules
    try:
        import app
        print("[OK] Main app module imports successfully")
    except Exception as e:
        print(f"[FAIL] Main app import failed: {e}")
        return False
    
    try:
        import admin_backend
        print("[OK] Admin backend module imports successfully")
    except Exception as e:
        print(f"[FAIL] Admin backend import failed: {e}")
        return False
    
    try:
        import chatbot_backend
        print("[OK] Chatbot backend module imports successfully")
    except Exception as e:
        print(f"[FAIL] Chatbot backend import failed: {e}")
        return False
    
    print("=" * 50)
    print("[OK] All service modules can be imported")
    return True

def test_fallback_mode():
    """Test fallback mode functionality"""
    print("\nTesting Fallback Mode...")
    print("=" * 50)
    
    # Set fallback mode
    os.environ["FALLBACK_MODE"] = "true"
    
    try:
        # Test app.py fallback
        import app
        pagodas = app.load_pagoda_data()
        if pagodas and len(pagodas) > 0:
            print(f"[OK] Fallback mode loads {len(pagodas)} pagodas")
        else:
            print("[FAIL] Fallback mode failed to load pagodas")
            return False
        
        # Test admin_backend.py fallback
        import admin_backend
        admin_pagodas = admin_backend.load_pagoda_data_from_db()
        if admin_pagodas and len(admin_pagodas) > 0:
            print(f"[OK] Admin fallback mode loads {len(admin_pagodas)} pagodas")
        else:
            print("[FAIL] Admin fallback mode failed to load pagodas")
            return False
        
        print("=" * 50)
        print("[OK] Fallback mode working correctly")
        return True
        
    except Exception as e:
        print(f"[FAIL] Fallback mode test failed: {e}")
        return False

def main():
    """Main test function"""
    print("BAGANETIC DEPLOYMENT TEST")
    print("=" * 60)
    print()
    
    tests = [
        ("Environment Setup", test_environment),
        ("Python Imports", test_python_imports),
        ("Environment Configuration", test_environment_file),
        ("Service Startup", test_services_startup),
        ("Fallback Mode", test_fallback_mode)
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\nRunning {test_name} Test...")
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"[FAIL] {test_name} test crashed: {e}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 60)
    print("TEST RESULTS SUMMARY")
    print("=" * 60)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results:
        status = "[PASS]" if result else "[FAIL]"
        print(f"{test_name:<25} {status}")
        if result:
            passed += 1
    
    print("=" * 60)
    print(f"Tests Passed: {passed}/{total}")
    
    if passed == total:
        print("ALL TESTS PASSED! Deployment is ready.")
        print("\nNext steps:")
        print("1. Run setup.bat to install dependencies")
        print("2. Run START.bat to launch the application")
        print("3. Open http://localhost:5000 in your browser")
    else:
        print("Some tests failed. Please check the issues above.")
        print("\nTroubleshooting:")
        print("1. Make sure you're in the Baganetic project directory")
        print("2. Run setup.bat to install dependencies")
        print("3. Check that all files are present")
    
    print("=" * 60)
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)