---
title: CV Chatbot API
emoji: 🤖
colorFrom: blue
colorTo: green
sdk: docker
pinned: false
license: mit
app_port: 7860
---

# CV Chatbot Backend with LangChain Agents

Advanced AI chatbot backend using **LangChain agents**, **OpenAI API**, and **vector embeddings** to answer questions about Mathieu Delehaye's CV and professional background.

## 🚀 Features

- **LangChain Agents** for intelligent conversation flow
- **Vector Embeddings** with ChromaDB for semantic search
- **Conversation Memory** for context-aware responses
- **RAG (Retrieval Augmented Generation)** for accurate CV information
- **Session Management** for multiple simultaneous conversations
- **Structured Logging** for monitoring and debugging
- **FastAPI** with automatic API documentation
- **CORS Support** for Flutter web integration

## 📋 Prerequisites

- Python 3.9+ 
- OpenAI API key
- Git

## ⚡ Quick Setup

### 1. Create Python Virtual Environment
```bash
# Navigate to the chatbot backend directory
cd chatbot_backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Environment Configuration
Create a `.env` file in the project root:
```bash
# Copy the example configuration
cp config.py .env

# Edit .env file with your values:
OPENAI_API_KEY=your_openai_api_key_here
```

**Minimum required environment variables:**
```env
OPENAI_API_KEY=sk-your-openai-key-here
```

### 4. Run the Server
```bash
# Option 1: Direct Python
python main.py

# Option 2: Using uvicorn (recommended for development)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Option 3: Production
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

### 5. Test the API
```bash
# Run the test suite
python test_chatbot.py

# Or manually test endpoints:
curl http://localhost:8000/health
curl http://localhost:8000/sample-questions
```

## 🔧 API Endpoints

### Core Endpoints
- `POST /chat` - Main chatbot interaction
- `GET /sample-questions` - Get example questions
- `GET /health` - Health check
- `GET /` - API information

### Session Management
- `GET /active-sessions` - List active conversation sessions
- `POST /reset-session` - Reset a specific session

### Interactive API Documentation
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## 💬 Usage Examples

### Basic Chat Request
```json
POST /chat
{
  "message": "What is Mathieu's experience in cybersecurity?",
  "session_id": "optional_session_id"
}
```

### Response Format
```json
{
  "response": "Mathieu has extensive cybersecurity experience...",
  "session_id": "session_12345",
  "sources": ["Recent Experience - Verimatrix", "Technical Skills"],
  "conversation_id": "session_12345"
}
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter CV App                         │
│                   (Frontend Client)                        │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTP/JSON API calls
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Server                           │
│                 (chatbot_backend/)                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────────┐                 │
│  │   LangChain     │  │  Conversation    │                 │
│  │     Agents      │  │     Memory       │                 │
│  └─────────────────┘  └──────────────────┘                 │
│                                                             │
│  ┌─────────────────┐  ┌──────────────────┐                 │
│  │   ChromaDB      │  │    OpenAI API    │                 │
│  │ Vector Storage  │  │   (GPT-3.5/4)    │                 │
│  └─────────────────┘  └──────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## 🤖 LangChain Components

### 1. **Conversational Retrieval Chain**
- Combines chat history with document retrieval
- Uses vector similarity search for relevant CV sections
- Maintains conversation context across messages

### 2. **Vector Embeddings**
- OpenAI embeddings for semantic understanding
- ChromaDB for persistent vector storage
- Automatic chunking and indexing of CV content

### 3. **Memory Management**
- `ConversationBufferWindowMemory` for recent context
- Session-based conversation tracking
- Configurable memory window size

## 🔐 Security & Privacy

### Data Handling
- **No personal data collection** from users
- Anonymous conversation logging (optional)
- CV content is embedded locally
- OpenAI API calls include only necessary context

### API Security
- CORS configuration for allowed origins
- Input validation and sanitization
- Rate limiting (configurable)
- Environment variable management

## 🚀 Deployment Options

### Local Development
```bash
uvicorn main:app --reload
```

### Docker Deployment
```dockerfile
FROM python:3.11-slim
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Azure Container Apps
```bash
# Build and deploy to Azure
az containerapp create \
  --name cv-chatbot-api \
  --resource-group your-rg \
  --image your-image \
  --env-vars OPENAI_API_KEY=your-key
```

## 🔧 Configuration

### Environment Variables
See `config.py` for all available configuration options:

```python
# Core configuration
OPENAI_API_KEY=required
OPENAI_MODEL=gpt-3.5-turbo
ENVIRONMENT=development
LOG_LEVEL=INFO

# Vector database
CHROMA_PERSIST_DIR=./chroma_db
EMBEDDING_CHUNK_SIZE=500
RETRIEVAL_TOP_K=4

# Conversation settings
MAX_CONVERSATION_MEMORY=10
MAX_MESSAGE_LENGTH=1000
```

## 🧪 Testing

### Automated Tests
```bash
# Run all tests
python test_chatbot.py

# Test specific functionality
pytest tests/ -v
```

### Manual Testing
1. Start the server: `python main.py`
2. Open: http://localhost:8000/docs
3. Try the `/chat` endpoint with sample questions

## 📊 Monitoring & Logs

### Structured Logging
- JSON-formatted logs for production
- Request/response tracking
- Error monitoring and debugging
- Performance metrics

### Log Examples
```json
{
  "timestamp": "2024-12-19T10:30:00Z",
  "level": "info",
  "event": "Chat interaction",
  "session_id": "session_123",
  "question": "What is Mathieu's experience?",
  "response_length": 245,
  "sources": ["Recent Experience - Verimatrix"]
}
```

## 🔄 Integration with Flutter

### HTTP Client Setup (Flutter)
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatService {
  static const String baseUrl = 'http://localhost:8000';
  
  static Future<Map<String, dynamic>> sendMessage(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'message': message}),
    );
    return json.decode(response.body);
  }
}
```

## 🐛 Troubleshooting

### Common Issues

1. **OpenAI API Key Error**
   ```
   Error: OpenAI API key not found
   Solution: Set OPENAI_API_KEY in .env file
   ```

2. **Vector Database Issues**
   ```
   Error: ChromaDB initialization failed
   Solution: Delete ./chroma_db folder and restart
   ```

3. **Memory Issues**
   ```
   Error: Out of memory
   Solution: Reduce EMBEDDING_CHUNK_SIZE or MAX_CONVERSATION_MEMORY
   ```

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=DEBUG
python main.py
```

## 📝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is part of Mathieu Delehaye's CV application portfolio.

## 🤝 Support

For questions or issues:
- Email: mathieu.delehaye@gmail.com
- LinkedIn: linkedin.com/in/mathieudelehaye
- GitHub: github.com/mathieudelehaye
