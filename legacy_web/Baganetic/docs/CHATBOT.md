# 🤖 Baganetic AI Chatbot

A powerful conversational AI assistant for exploring the ancient pagodas of Bagan, Myanmar. This chatbot provides intelligent assistance with pagoda information, route planning, recommendations, and cultural insights.

## ✨ Features

### 🧠 **Intelligent Conversation**
- Natural language understanding for pagoda queries
- Context-aware responses and conversation memory
- Smart intent detection and response generation
- Multi-turn conversation support

### 🏛️ **Comprehensive Pagoda Knowledge**
- Detailed information about all Bagan pagodas
- Historical background and architectural details
- Religious significance and cultural context
- Practical visiting information (fees, hours, accessibility)

### 🗺️ **Advanced Route Planning**
- Integration with existing A* pathfinding algorithms
- Optimal route calculations between pagodas
- Distance and time estimates
- Nearby pagoda suggestions along routes

### 💡 **Smart Recommendations**
- Personalized pagoda suggestions
- Must-see temple recommendations
- Cultural and historical highlights
- Practical visiting tips

### 🎯 **Interactive Features**
- Quick action buttons for common queries
- Suggestion chips for easy follow-up questions
- Real-time typing indicators
- Chat history persistence

## 🚀 Quick Start

### Prerequisites
- Python 3.8 or higher
- Flask and Flask-CORS
- Access to Baganetic pagoda data

### Installation

1. **Install dependencies**
   ```bash
   pip install -r chatbot_requirements.txt
   ```

2. **Start the chatbot server**
   
   **Option A: Using Python script**
   ```bash
   python start_chatbot.py
   ```
   
   **Option B: Using batch file (Windows)**
   ```cmd
   start_chatbot.bat
   ```
   
   **Option C: Direct Flask run**
   ```bash
   python chatbot_backend.py
   ```

3. **Open the chat interface**
   - The chatbot will be available at `http://localhost:5001`
   - Access via floating widget on all pages

## 🎯 Usage Examples

### Basic Queries
```
"Tell me about Ananda Temple"
"What is the history of Shwezigon Pagoda?"
"Show me information about Dhammayangyi Temple"
```

### Route Planning
```
"Plan a route from Ananda to Shwezigon"
"How do I get from Dhammayangyi to Gawdawpalin?"
"Find the shortest path between Bupaya and Sulamani"
```

### Recommendations
```
"What are the must-see pagodas?"
"Recommend some famous temples"
"What should I visit in Bagan?"
```

### Nearby Search
```
"Find pagodas near Ananda"
"What's close to Shwezigon?"
"Show me temples around Dhammayangyi"
```

### Cultural Questions
```
"What's the cultural significance of Bagan?"
"Tell me about the Pagan dynasty"
"What architectural styles are in Bagan?"
```

## 🔧 API Endpoints

### Chat Endpoints
- `POST /api/chatbot/chat` - Send a message to the chatbot
- `GET /api/chatbot/history/<user_id>` - Get chat history
- `POST /api/chatbot/clear/<user_id>` - Clear chat history

### Data Endpoints
- `GET /api/chatbot/pagodas` - Get all pagoda data
- `GET /api/chatbot/health` - Health check

### Example API Usage
```javascript
// Send a message
const response = await fetch('http://localhost:5001/api/chatbot/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        message: "Tell me about Ananda Temple",
        user_id: "user123"
    })
});

const data = await response.json();
console.log(data.data.response);
```

## 🏗️ Architecture

### Backend Components
- **Flask Server** - Main web server and API
- **BaganeticChatbot Class** - Core chatbot logic
- **Intent Detection** - Natural language understanding
- **Pathfinder Integration** - Route planning capabilities
- **Conversation Memory** - Context and history management

### Frontend Components
- **HTML Interface** - Modern, responsive chat UI
- **JavaScript Client** - Real-time communication
- **Quick Actions** - Predefined query buttons
- **Suggestion System** - Interactive follow-up prompts

### Data Flow
```
User Input → Intent Detection → Response Generation → Pathfinder Integration → Formatted Response
```

## 🎨 Customization

### Adding New Intents
```python
# In chatbot_backend.py, add to intent_patterns
'intent_name': [
    r'\b(pattern1|pattern2)\b',
    r'\b(another pattern)\s+([^?]+)'
]
```

### Custom Response Templates
```python
# Add to response_templates
'custom_intent': [
    "Custom response 1",
    "Custom response 2"
]
```

### Styling the Frontend
- Modify the CSS in the chatbot interface
- Update colors, fonts, and layout
- Add custom animations and effects

## 🔍 Advanced Features

### Conversation Memory
- Maintains context across multiple messages
- Remembers user preferences and last pagoda
- Intelligent follow-up suggestions

### Smart Intent Detection
- Pattern-based natural language understanding
- Contextual intent recognition
- Fallback handling for unclear queries

### Integration with Existing Systems
- Seamless integration with Baganetic pathfinder
- Access to comprehensive pagoda database
- Real-time route calculations

## 🛠️ Development

### Running in Development Mode
```bash
# Enable debug mode
export FLASK_DEBUG=1
python chatbot_backend.py
```

### Testing
```bash
# Run tests (if available)
pytest tests/
```

### Adding New Features
1. Extend the `BaganeticChatbot` class
2. Add new intent patterns
3. Update response templates
4. Test with various user inputs

## 🚨 Troubleshooting

### Common Issues

**Chatbot not responding**
- Check if the server is running on port 5001
- Verify Flask dependencies are installed
- Check browser console for errors

**Route planning not working**
- Ensure pathfinder modules are available
- Check pagoda data file exists
- Verify pathfinder initialization

**Styling issues**
- Check CSS syntax in chatbot interface
- Verify font and icon CDN links
- Test responsive design on different screen sizes

### Debug Mode
```bash
# Enable detailed logging
export FLASK_DEBUG=1
python chatbot_backend.py
```

## 📱 Mobile Support

The chatbot interface is fully responsive and works on:
- Desktop computers
- Tablets
- Mobile phones
- Various screen sizes

## 🔒 Security Considerations

- Input validation and sanitization
- Rate limiting for API endpoints
- CORS configuration for cross-origin requests
- Error handling and logging

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This chatbot is part of the Baganetic project and follows the same license terms.

## 🙏 Acknowledgments

- Bagan Archaeological Museum for historical data
- Myanmar Tourism for location information
- Open source community for libraries and tools
- Baganetic development team

---

**Made with ❤️ for exploring the ancient wonders of Bagan**

For support or questions, please contact the Baganetic development team.
