#!/usr/bin/env python3
"""
Test Tasks API Endpoint
Fetches tasks from the backend and displays them
"""

import requests
import json
from typing import Optional, Dict, Any

def test_api(backend_url: str, username: str, password: str) -> None:
    """Test the backend API endpoint"""
    
    print("=" * 60)
    print("TEST TASKS API ENDPOINT")
    print("=" * 60)
    print()
    
    # Step 1: Test backend health
    print("Step 1: Testing backend connection...")
    try:
        health_response = requests.get(f"{backend_url}/api/health", timeout=5)
        print(f"✓ Backend is running at {backend_url}")
        print()
    except Exception as e:
        print(f"✗ Backend is not responding: {e}")
        return
    
    # Step 2: Login
    print("Step 2: Logging in...")
    login_url = f"{backend_url}/api/login"
    login_data = {
        "username": username,
        "password": password
    }
    
    try:
        login_response = requests.post(
            login_url,
            json=login_data,
            timeout=10
        )
        login_response.raise_for_status()
        login_json = login_response.json()
        
        if "token" not in login_json:
            print(f"✗ No token in response: {login_response.text}")
            return
        
        token = login_json["token"]
        print(f"✓ Login successful")
        print(f"  Token preview: {token[:30]}...")
        print()
    except Exception as e:
        print(f"✗ Login failed: {e}")
        return
    
    # Step 3: Fetch tasks
    print("Step 3: Fetching tasks from endpoint...")
    print(f"  URL: {backend_url}/api/technician/tasks")
    print()
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    try:
        tasks_response = requests.get(
            f"{backend_url}/api/technician/tasks",
            headers=headers,
            timeout=15
        )
        tasks_response.raise_for_status()
        tasks_json = tasks_response.json()
        
        print("=" * 60)
        print("API RESPONSE:")
        print("=" * 60)
        print(json.dumps(tasks_json, indent=2))
        print("=" * 60)
        print()
        
        # Analyze
        if "data" in tasks_json:
            tasks = tasks_json["data"]
            if isinstance(tasks, list):
                print(f"✓ TASKS FOUND: {len(tasks)}")
                print()
                
                if len(tasks) > 0:
                    print("Task Details (first 5):")
                    for i, task in enumerate(tasks[:5], 1):
                        print()
                        print(f"Task {i}:")
                        print(f"  ID: {task.get('id', 'N/A')}")
                        print(f"  Title: {task.get('title', 'N/A')}")
                        print(f"  Description: {task.get('description', 'N/A')}")
                        print(f"  Status: {task.get('status', 'N/A')}")
                        print(f"  Priority: {task.get('priority', 'N/A')}")
                        print(f"  Location: {task.get('location', 'N/A')}")
                        print(f"  Customer: {task.get('clientName', 'N/A')}")
                        print(f"  Phone: {task.get('clientPhone', 'N/A')}")
                        print(f"  Created: {task.get('assignedDate', 'N/A')}")
                    print()
                else:
                    print("⚠ No tasks returned (empty list)")
                    print()
            else:
                print(f"⚠ Data is not a list: {type(tasks)}")
                print()
        else:
            print("⚠ No 'data' field in response")
            print()
    
    except requests.exceptions.HTTPError as e:
        print(f"✗ HTTP Error: {e.response.status_code}")
        print(f"  Response: {e.response.text}")
    except Exception as e:
        print(f"✗ Error fetching tasks: {e}")
    
    print("=" * 60)
    print("TEST COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    # Configuration
    BACKEND_URL = "http://10.91.220.92:5000"
    USERNAME = "Balbino"
    PASSWORD = "password"
    
    test_api(BACKEND_URL, USERNAME, PASSWORD)
