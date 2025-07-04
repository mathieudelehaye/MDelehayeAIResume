#!/usr/bin/env python3
"""
Test script for the CV Chatbot API
Run this after starting the FastAPI server to test functionality
"""

import asyncio
import json
import httpx
from typing import Dict, Any

# API Configuration
BASE_URL = "http://localhost:8000"
TIMEOUT = 30.0

async def test_health_check():
    """Test the health check endpoint"""
    print("🏥 Testing health check...")
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(f"{BASE_URL}/health", timeout=TIMEOUT)
            if response.status_code == 200:
                print(f"✅ Health check passed: {response.json()}")
                return True
            else:
                print(f"❌ Health check failed: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Health check error: {e}")
            return False

async def test_sample_questions():
    """Test the sample questions endpoint"""
    print("\n🔍 Testing sample questions...")
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(f"{BASE_URL}/sample-questions", timeout=TIMEOUT)
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Sample questions retrieved: {len(data['sample_questions'])} questions")
                for i, question in enumerate(data['sample_questions'][:3], 1):
                    print(f"   {i}. {question}")
                return data['sample_questions']
            else:
                print(f"❌ Sample questions failed: {response.status_code}")
                return []
        except Exception as e:
            print(f"❌ Sample questions error: {e}")
            return []

async def test_chat_interaction(question: str, session_id: str | None = None):
    """Test a chat interaction"""
    print(f"\n💬 Testing chat: '{question[:50]}...'")
    async with httpx.AsyncClient() as client:
        try:
            payload = {"message": question}
            if session_id:
                payload["session_id"] = session_id
            
            response = await client.post(
                f"{BASE_URL}/chat", 
                json=payload,
                timeout=TIMEOUT
            )
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Chat response received")
                print(f"   Response: {data['response'][:100]}...")
                print(f"   Session ID: {data['session_id']}")
                if data.get('sources'):
                    print(f"   Sources: {', '.join(data['sources'])}")
                return data
            else:
                print(f"❌ Chat failed: {response.status_code} - {response.text}")
                return None
        except Exception as e:
            print(f"❌ Chat error: {e}")
            return None

async def test_conversation_flow():
    """Test a conversation with multiple messages"""
    print("\n🗣️ Testing conversation flow...")
    session_id = "test_session_123"
    
    questions = [
        "What is Mathieu's background in cybersecurity?",
        "Tell me more about his experience at Verimatrix",
        "What programming languages does he know best?",
        "How is he transitioning to finance?"
    ]
    
    for i, question in enumerate(questions, 1):
        print(f"\n   Message {i}: {question}")
        response = await test_chat_interaction(question, session_id)
        if not response:
            print(f"❌ Conversation failed at message {i}")
            return False
        
        # Short delay between messages
        await asyncio.sleep(1)
    
    print("✅ Conversation flow completed successfully")
    return True

async def test_session_management():
    """Test session management endpoints"""
    print("\n🔧 Testing session management...")
    async with httpx.AsyncClient() as client:
        try:
            # Test active sessions
            response = await client.get(f"{BASE_URL}/active-sessions", timeout=TIMEOUT)
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Active sessions: {data['count']}")
                
                # Test session reset if there are active sessions
                if data['count'] > 0 and data['active_sessions']:
                    session_to_reset = data['active_sessions'][0]
                    reset_response = await client.post(
                        f"{BASE_URL}/reset-session",
                        params={"session_id": session_to_reset},
                        timeout=TIMEOUT
                    )
                    if reset_response.status_code == 200:
                        print(f"✅ Session reset successful")
                    else:
                        print(f"❌ Session reset failed: {reset_response.status_code}")
                
                return True
            else:
                print(f"❌ Session management failed: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Session management error: {e}")
            return False

async def run_all_tests():
    """Run all tests"""
    print("🚀 Starting CV Chatbot API Tests")
    print("=" * 50)
    
    # Test basic functionality
    health_ok = await test_health_check()
    if not health_ok:
        print("❌ Basic health check failed. Is the server running?")
        return
    
    # Test endpoints
    sample_questions = await test_sample_questions()
    
    # Test individual chat
    if sample_questions:
        await test_chat_interaction(sample_questions[0])
    else:
        await test_chat_interaction("What is Mathieu's experience in software engineering?")
    
    # Test conversation flow
    await test_conversation_flow()
    
    # Test session management
    await test_session_management()
    
    print("\n" + "=" * 50)
    print("🏁 Tests completed!")

if __name__ == "__main__":
    # Check if server is running
    print("Make sure the FastAPI server is running on http://localhost:8000")
    print("Start it with: python main.py")
    print("Or: uvicorn main:app --reload")
    print()
    
    try:
        asyncio.run(run_all_tests())
    except KeyboardInterrupt:
        print("\n⏹️ Tests interrupted by user")
    except Exception as e:
        print(f"\n❌ Test runner error: {e}") 