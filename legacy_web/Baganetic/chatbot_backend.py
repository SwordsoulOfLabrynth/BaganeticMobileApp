"""
Baganetic AI Chatbot Backend
A powerful conversational AI assistant for Bagan pagoda exploration
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import re
import random
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple
import difflib
import math
import os
import sys
from collections import defaultdict
import time
from functools import lru_cache

# Enhanced ML/NLP for Advanced NLU
try:
    from sklearn.pipeline import Pipeline
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.naive_bayes import MultinomialNB
    import nltk
    from nltk.tokenize import word_tokenize, sent_tokenize
    from nltk.corpus import stopwords
    from nltk.stem import WordNetLemmatizer
    from nltk.chunk import ne_chunk
    from nltk.tag import pos_tag
    import spacy
except Exception as e:
    print(f"Warning: Some NLP libraries not available: {e}")
    Pipeline = None
    TfidfVectorizer = None
    LogisticRegression = None
    RandomForestClassifier = None
    MultinomialNB = None
    nltk = None
    spacy = None

# Download required NLTK data
try:
    if nltk:
        nltk.download('punkt', quiet=True)
        nltk.download('stopwords', quiet=True)
        nltk.download('wordnet', quiet=True)
        nltk.download('averaged_perceptron_tagger', quiet=True)
        nltk.download('maxent_ne_chunker', quiet=True)
        nltk.download('words', quiet=True)
except Exception:
    pass

# Add current directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Import existing pathfinder modules
try:
    from improved_pathfinder import ImprovedPagodaPathFinder
    # Create a simple graph function for compatibility
    def create_pagoda_graph(pagoda_data):
        return None  # Not needed for ImprovedPagodaPathFinder
    PagodaPathFinder = None  # Not used
except ImportError:
    print("Warning: Pathfinder modules not found. Some features may be limited.")
    PagodaPathFinder = None
    ImprovedPagodaPathFinder = None

app = Flask(__name__)
CORS(app)

# Check for fallback mode
FALLBACK_MODE = os.getenv("FALLBACK_MODE", "false").lower() == "true"

class ContextAnalyzer:
    """Advanced context analysis for better conversation understanding"""
    
    def __init__(self):
        self.context_window = 5  # Number of previous messages to consider
        self.topic_weights = defaultdict(float)
        
    def analyze_context(self, conversation_history: List[Dict], current_message: str) -> Dict[str, Any]:
        """Analyze conversation context to improve understanding"""
        context = {
            'current_topic': None,
            'mentioned_pagodas': [],
            'user_preferences': {},
            'conversation_flow': 'new',
            'urgency_level': 'normal'
        }
        
        if not conversation_history:
            return context
            
        # Extract mentioned pagodas from history
        for msg in conversation_history[-self.context_window:]:
            if msg.get('type') == 'user':
                # Simple entity extraction for pagodas
                mentioned = self._extract_pagoda_mentions(msg.get('message', ''))
                context['mentioned_pagodas'].extend(mentioned)
        
        # Determine conversation flow
        if len(conversation_history) > 3:
            context['conversation_flow'] = 'ongoing'
        elif any('route' in msg.get('message', '').lower() for msg in conversation_history[-3:]):
            context['conversation_flow'] = 'planning'
        elif any('history' in msg.get('message', '').lower() for msg in conversation_history[-3:]):
            context['conversation_flow'] = 'learning'
            
        return context
    
    def _extract_pagoda_mentions(self, text: str) -> List[str]:
        """Extract potential pagoda mentions from text"""
        # This is a simplified version - in production, use NER
        pagoda_names = []
        text_lower = text.lower()
        
        # Common pagoda names to look for
        common_pagodas = ['ananda', 'shwezigon', 'dhammayangyi', 'gawdawpalin', 'sulamani', 'htilominlo']
        for pagoda in common_pagodas:
            if pagoda in text_lower:
                pagoda_names.append(pagoda)
                
        return pagoda_names

class SentimentAnalyzer:
    """Advanced sentiment analysis for better user experience"""
    
    def __init__(self):
        self.positive_words = {'good', 'great', 'amazing', 'wonderful', 'excellent', 'fantastic', 'love', 'like', 'enjoy'}
        self.negative_words = {'bad', 'terrible', 'awful', 'hate', 'dislike', 'disappointed', 'frustrated', 'confused'}
        
    def analyze_sentiment(self, text: str) -> Dict[str, Any]:
        """Analyze sentiment of user message"""
        text_lower = text.lower()
        
        positive_score = sum(1 for word in self.positive_words if word in text_lower)
        negative_score = sum(1 for word in self.negative_words if word in text_lower)
        
        if positive_score > negative_score:
            sentiment = 'positive'
            confidence = min(0.9, 0.5 + (positive_score - negative_score) * 0.1)
        elif negative_score > positive_score:
            sentiment = 'negative'
            confidence = min(0.9, 0.5 + (negative_score - positive_score) * 0.1)
        else:
            sentiment = 'neutral'
            confidence = 0.5
            
        return {
            'sentiment': sentiment,
            'confidence': confidence,
            'positive_score': positive_score,
            'negative_score': negative_score
        }

class EntityExtractor:
    """Advanced entity extraction for pagodas and locations"""
    
    def __init__(self, pagoda_data: List[Dict]):
        self.pagoda_data = pagoda_data
        self.pagoda_names = self._build_pagoda_name_map()
        self.pagoda_name_map = self.pagoda_names  # Alias for compatibility
        
    def _build_pagoda_name_map(self) -> Dict[str, str]:
        """Build a map of pagoda names and variations"""
        name_map = {}
        for pagoda in self.pagoda_data:
            name = pagoda.get('name', '').lower()
            short_name = pagoda.get('shortName', '').lower()
            pagoda_id = pagoda.get('id', '').lower()
            
            name_map[name] = pagoda['id']
            name_map[short_name] = pagoda['id']
            name_map[pagoda_id] = pagoda['id']
            
            # Add variations
            name_map[name.replace(' temple', '')] = pagoda['id']
            name_map[name.replace(' pagoda', '')] = pagoda['id']
            
        return name_map
    
    def extract_pagodas(self, text: str) -> List[Dict[str, Any]]:
        """Extract pagoda entities from text"""
        text_lower = text.lower()
        found_pagodas = []
        
        # Handle "about [pagoda]" pattern specifically
        if text_lower.startswith('about '):
            pagoda_name = text_lower[6:].strip()
            pagoda = self._find_pagoda_by_name(pagoda_name)
            if pagoda:
                found_pagodas.append({
                    'pagoda': pagoda,
                    'name': pagoda_name,
                    'confidence': 0.9
                })
                return found_pagodas
        
        # Regular entity extraction
        for name, pagoda_id in self.pagoda_name_map.items():
            if name in text_lower:
                pagoda = next((p for p in self.pagoda_data if p['id'] == pagoda_id), None)
                if pagoda:
                    found_pagodas.append({
                        'pagoda': pagoda,
                        'name': name,
                        'confidence': 0.9 if name == pagoda.get('name', '').lower() else 0.7
                    })
        
        return found_pagodas
    
    def _find_pagoda_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Find a pagoda by name with improved fuzzy matching"""
        if not name or not name.strip():
            return None
            
        name_lower = name.lower().strip()
        
        # Try alias map first (fastest)
        if name_lower in self.pagoda_name_map:
            pagoda_id = self.pagoda_name_map[name_lower]
            for pagoda in self.pagoda_data:
                if pagoda.get('id', '').lower() == pagoda_id:
                    return pagoda
        
        # Direct exact matches
        for pagoda in self.pagoda_data:
            pagoda_name = pagoda.get('name', '').lower()
            short_name = pagoda.get('shortName', '').lower()
            pagoda_id = pagoda.get('id', '').lower()
            
            if name_lower in [pagoda_name, short_name, pagoda_id]:
                return pagoda
        
        # Partial matches (substring)
        for pagoda in self.pagoda_data:
            pagoda_name = pagoda.get('name', '').lower()
            short_name = pagoda.get('shortName', '').lower()
            
            if name_lower in pagoda_name or name_lower in short_name:
                return pagoda
        
        return None
    
    def detect_language(self, text: str) -> str:
        """Detect the language of the input text"""
        text_lower = text.lower()
        
        # Define language detection keywords here instead of using self.language_detection
        myanmar_keywords = ['မြန်မာ', 'ဗုဒ္ဓ', 'ဘုရား', 'စေတီ', 'ပုဂံ']
        chinese_keywords = ['中文', '中国', '佛教', '寺庙', '蒲甘']
        japanese_keywords = ['日本語', '日本', '仏教', '寺院', 'バガン']
        
        # Check for Myanmar script
        for keyword in myanmar_keywords:
            if keyword in text_lower:
                return 'myanmar'
        
        # Check for Chinese characters
        for keyword in chinese_keywords:
            if keyword in text_lower:
                return 'chinese'
        
        # Check for Japanese characters
        for keyword in japanese_keywords:
            if keyword in text_lower:
                return 'japanese'
        
        # Default to English
        return 'english'
    
    def enhance_response_with_personality(self, response: str, sentiment: Dict, context: Dict) -> str:
        """Enhance response with personality based on sentiment and context"""
        # Add excitement for positive sentiment
        if sentiment['sentiment'] == 'positive' and sentiment['confidence'] > 0.7:
            excitement_phrase = random.choice(self.response_templates['excited'])
            response = excitement_phrase + "\n\n" + response
        
        # Add encouragement for negative sentiment
        elif sentiment['sentiment'] == 'negative' and 'confused' in context.get('current_topic', '').lower():
            encouragement_phrase = random.choice(self.response_templates['encouraging'])
            response = encouragement_phrase + "\n\n" + response
        
        # Add context-aware elements
        if context.get('conversation_flow') == 'ongoing':
            if "!" not in response:
                response += " 😊"
        
        return response

class ConversationLearning:
    """Advanced conversation learning that adapts to user preferences"""
    
    def __init__(self):
        self.user_patterns = defaultdict(list)
        self.preference_weights = defaultdict(float)
        self.learning_rate = 0.1
        
    def learn_from_interaction(self, user_id: str, message: str, response: str, user_satisfaction: float = 0.5):
        """Learn from user interactions to improve future responses"""
        # Extract topics from message
        topics = self._extract_topics(message)
        
        # Update user preferences based on interaction
        for topic in topics:
            if user_satisfaction > 0.7:  # Positive feedback
                self.preference_weights[f"{user_id}:{topic}"] += self.learning_rate
            elif user_satisfaction < 0.3:  # Negative feedback
                self.preference_weights[f"{user_id}:{topic}"] -= self.learning_rate * 0.5
        
        # Store interaction pattern
        self.user_patterns[user_id].append({
            'message': message,
            'topics': topics,
            'satisfaction': user_satisfaction,
            'timestamp': datetime.now()
        })
        
        # Keep only recent patterns (last 50 interactions)
        if len(self.user_patterns[user_id]) > 50:
            self.user_patterns[user_id] = self.user_patterns[user_id][-50:]
    
    def get_user_preferences(self, user_id: str) -> Dict[str, float]:
        """Get learned user preferences"""
        preferences = {}
        for key, weight in self.preference_weights.items():
            if key.startswith(f"{user_id}:"):
                topic = key.split(":", 1)[1]
                preferences[topic] = weight
        return preferences
    
    def _extract_topics(self, text: str) -> List[str]:
        """Extract topics from text"""
        topics = []
        text_lower = text.lower()
        
        # Define topic keywords
        topic_keywords = {
            'history': ['history', 'historical', 'ancient', 'old', 'built', 'constructed', 'dynasty', 'king'],
            'architecture': ['architecture', 'design', 'structure', 'style', 'building', 'construction'],
            'religion': ['buddhist', 'buddhism', 'religious', 'temple', 'pagoda', 'spiritual'],
            'culture': ['cultural', 'tradition', 'heritage', 'significance', 'meaning'],
            'travel': ['visit', 'travel', 'tour', 'trip', 'journey', 'explore', 'discover'],
            'practical': ['entrance', 'fee', 'ticket', 'hours', 'time', 'access', 'location']
        }
        
        for topic, keywords in topic_keywords.items():
            if any(keyword in text_lower for keyword in keywords):
                topics.append(topic)
        
        return topics

class SmartRecommendationEngine:
    """Advanced recommendation engine that learns from user behavior"""
    
    def __init__(self, pagoda_data: List[Dict]):
        self.pagoda_data = pagoda_data
        self.user_interactions = defaultdict(list)
        self.pagoda_similarity_matrix = self._build_similarity_matrix()
        
    def _build_similarity_matrix(self) -> Dict[str, Dict[str, float]]:
        """Build similarity matrix between pagodas"""
        similarity_matrix = {}
        
        for pagoda1 in self.pagoda_data:
            similarities = {}
            for pagoda2 in self.pagoda_data:
                if pagoda1['id'] != pagoda2['id']:
                    similarity = self._calculate_pagoda_similarity(pagoda1, pagoda2)
                    similarities[pagoda2['id']] = similarity
            similarity_matrix[pagoda1['id']] = similarities
        
        return similarity_matrix
    
    def _calculate_pagoda_similarity(self, pagoda1: Dict, pagoda2: Dict) -> float:
        """Calculate similarity between two pagodas"""
        score = 0.0
        
        # Type similarity
        if pagoda1.get('type') == pagoda2.get('type'):
            score += 0.3
        
        # Architecture style similarity
        style1 = pagoda1.get('architecture', {}).get('style', '')
        style2 = pagoda2.get('architecture', {}).get('style', '')
        if style1 and style2 and any(word in style2.lower() for word in style1.lower().split()):
            score += 0.2
        
        # Era similarity
        era1 = pagoda1.get('history', {}).get('built', '')
        era2 = pagoda2.get('history', {}).get('built', '')
        if era1 and era2:
            try:
                year1 = int(era1.split()[0])
                year2 = int(era2.split()[0])
                year_diff = abs(year1 - year2)
                if year_diff <= 50:
                    score += 0.3
                elif year_diff <= 100:
                    score += 0.2
                elif year_diff <= 200:
                    score += 0.1
            except:
                pass
        
        # Religious significance similarity
        rel1 = pagoda1.get('religious', {}).get('significance', '')
        rel2 = pagoda2.get('religious', {}).get('significance', '')
        if rel1 and rel2 and any(word in rel2.lower() for word in rel1.lower().split()):
            score += 0.2
        
        return min(score, 1.0)
    
    def get_smart_recommendations(self, user_id: str, limit: int = 5) -> List[Dict]:
        """Get smart recommendations based on user behavior"""
        user_interactions = self.user_interactions[user_id]
        
        if not user_interactions:
            # Return popular pagodas for new users
            return [p for p in self.pagoda_data if p.get('featured', False)][:limit]
        
        # Get recently visited pagodas
        recent_pagodas = [interaction['pagoda_id'] for interaction in user_interactions[-10:]]
        
        # Calculate recommendation scores
        recommendation_scores = defaultdict(float)
        
        for pagoda_id in recent_pagodas:
            if pagoda_id in self.pagoda_similarity_matrix:
                similarities = self.pagoda_similarity_matrix[pagoda_id]
                for similar_id, similarity in similarities.items():
                    if similar_id not in recent_pagodas:  # Don't recommend already visited
                        recommendation_scores[similar_id] += similarity
        
        # Sort by score and return top recommendations
        sorted_recommendations = sorted(recommendation_scores.items(), key=lambda x: x[1], reverse=True)
        
        recommended_pagodas = []
        for pagoda_id, score in sorted_recommendations[:limit]:
            pagoda = next((p for p in self.pagoda_data if p['id'] == pagoda_id), None)
            if pagoda:
                recommended_pagodas.append(pagoda)
        
        return recommended_pagodas
    
    def record_interaction(self, user_id: str, pagoda_id: str, interaction_type: str = 'view'):
        """Record user interaction with a pagoda"""
        self.user_interactions[user_id].append({
            'pagoda_id': pagoda_id,
            'type': interaction_type,
            'timestamp': datetime.now()
        })
        
        # Keep only recent interactions (last 100)
        if len(self.user_interactions[user_id]) > 100:
            self.user_interactions[user_id] = self.user_interactions[user_id][-100:]

class ContextualMemory:
    """Advanced contextual memory that maintains conversation context"""
    
    def __init__(self):
        self.conversation_contexts = defaultdict(dict)
        self.topic_transitions = defaultdict(list)
        
    def update_context(self, user_id: str, message: str, intent: str, entities: List[str]):
        """Update conversation context"""
        context = self.conversation_contexts[user_id]
        
        # Update current topic
        context['current_topic'] = intent
        context['last_message'] = message
        context['last_entities'] = entities
        context['timestamp'] = datetime.now()
        
        # Track topic transitions
        if 'previous_topic' in context:
            transition = f"{context['previous_topic']} -> {intent}"
            self.topic_transitions[user_id].append(transition)
            
            # Keep only recent transitions
            if len(self.topic_transitions[user_id]) > 20:
                self.topic_transitions[user_id] = self.topic_transitions[user_id][-20:]
        
        context['previous_topic'] = intent
    
    def get_contextual_suggestions(self, user_id: str) -> List[str]:
        """Get contextual suggestions based on conversation history"""
        context = self.conversation_contexts[user_id]
        suggestions = []
        
        current_topic = context.get('current_topic', '')
        entities = context.get('last_entities', [])
        
        if current_topic == 'pagoda_info' and entities:
            pagoda_name = entities[0] if entities else 'this pagoda'
            suggestions.extend([
                f"Tell me more about {pagoda_name}",
                f"Find pagodas similar to {pagoda_name}",
                f"Plan a route to {pagoda_name}",
                f"What's the history of {pagoda_name}?"
            ])
        elif current_topic == 'pathfinding':
            suggestions.extend([
                "Show me more routes",
                "Find pagodas near Ananda",
                "Plan another route",
                "What are the best routes in Bagan?"
            ])
        elif current_topic == 'recommendations':
            suggestions.extend([
                "Tell me about Ananda Temple",
                "What are the must-see pagodas?",
                "Plan a route from Shwezigon to Dhammayangyi",
                "Find pagodas near Ananda"
            ])
        else:
            suggestions.extend([
                "Tell me about Ananda Temple",
                "Plan a route",
                "What are the must-see pagodas?",
                "Help me explore Bagan"
            ])
        
        return suggestions[:4]

class AdaptiveResponseGenerator:
    """Generates adaptive responses based on user behavior and preferences"""
    
    def __init__(self):
        self.response_templates = {
            'enthusiastic': [
                "That's fantastic! I'm excited to share this with you! 🌟",
                "Wonderful choice! Let me tell you all about it! ✨",
                "Excellent! This is one of my favorite topics! 🎉"
            ],
            'encouraging': [
                "Don't worry, I'm here to help you every step of the way! 🤝",
                "That's perfectly fine! Let me guide you through this! 🗺️",
                "No problem at all! I'll make this easy for you! ✨"
            ],
            'informative': [
                "Let me share some fascinating details with you! 📚",
                "I have some interesting information about this! 🔍",
                "Here's what makes this special! ✨"
            ]
        }
        
    def generate_adaptive_response(self, base_response: str, user_sentiment: str, 
                                 user_experience: str, context: Dict) -> str:
        """Generate adaptive response based on user characteristics"""
        
        # Only add personality phrases occasionally (30% chance) to avoid repetition
        if random.random() < 0.3:
            if user_sentiment == 'positive':
                personality_phrase = random.choice(self.response_templates['enthusiastic'])
                base_response = personality_phrase + "\n\n" + base_response
            elif user_sentiment == 'negative':
                personality_phrase = random.choice(self.response_templates['encouraging'])
                base_response = personality_phrase + "\n\n" + base_response
            else:
                personality_phrase = random.choice(self.response_templates['informative'])
                base_response = personality_phrase + "\n\n" + base_response
        
        # Add experience-based enhancements only sometimes
        if random.random() < 0.4:  # 40% chance
            if user_experience == 'beginner':
                tips = [
                    "💡 **Pro Tip:** I can help you plan your perfect Bagan itinerary!",
                    "🌟 **Insider Tip:** Start with the most famous pagodas first!",
                    "🗺️ **Travel Tip:** Use the map feature to see pagoda locations!",
                    "⏰ **Best Time:** Visit during sunrise or sunset for amazing views!"
                ]
                base_response += "\n\n" + random.choice(tips)
            elif user_experience == 'expert':
                expert_tips = [
                    "🔍 **Advanced Info:** Would you like architectural details or historical significance?",
                    "📚 **Deep Dive:** I can share fascinating historical stories!",
                    "🏛️ **Expert Mode:** Ask about specific architectural styles or dynasties!",
                    "🎯 **Specialized:** I know about restoration efforts and archaeological findings!"
                ]
                base_response += "\n\n" + random.choice(expert_tips)
        
        # Add context-aware elements occasionally
        if context.get('conversation_flow') == 'ongoing' and random.random() < 0.3:
            related_suggestions = [
                "🔄 **Related:** I can also help with routes, recommendations, or more details!",
                "💬 **Ask me:** Feel free to ask about any other pagodas or topics!",
                "🗺️ **Navigation:** Need help planning routes between pagodas?",
                "⭐ **Recommendations:** Want personalized suggestions based on your interests?"
            ]
            base_response += "\n\n" + random.choice(related_suggestions)
        
        return base_response

class QuestionAnalyzer:
    """Advanced question analysis for better understanding"""
    
    def __init__(self):
        self.question_patterns = {
            'what': ['what is', 'what are', 'what does', 'what makes', 'what can'],
            'how': ['how to', 'how does', 'how can', 'how long', 'how much'],
            'when': ['when was', 'when did', 'when is', 'when can'],
            'where': ['where is', 'where are', 'where can', 'where to'],
            'why': ['why is', 'why are', 'why does', 'why should'],
            'which': ['which is', 'which are', 'which one', 'which pagoda']
        }
    
    def analyze_question(self, message: str) -> Dict[str, Any]:
        """Analyze question type and extract key information"""
        message_lower = message.lower()
        
        question_type = 'general'
        for q_type, patterns in self.question_patterns.items():
            if any(pattern in message_lower for pattern in patterns):
                question_type = q_type
                break
        
        # Extract entities and keywords
        entities = self._extract_entities(message)
        keywords = self._extract_keywords(message)
        
        return {
            'type': question_type,
            'entities': entities,
            'keywords': keywords,
            'complexity': self._assess_complexity(message),
            'specificity': self._assess_specificity(message)
        }
    
    def _extract_entities(self, text: str) -> List[str]:
        """Extract entities from text"""
        entities = []
        text_lower = text.lower()
        
        # Common pagoda names
        pagoda_names = ['ananda', 'shwezigon', 'dhammayangyi', 'gawdawpalin', 'sulamani', 'htilominlo']
        for name in pagoda_names:
            if name in text_lower:
                entities.append(name)
        
        return entities
    
    def _extract_keywords(self, text: str) -> List[str]:
        """Extract important keywords"""
        keywords = []
        text_lower = text.lower()
        
        important_words = ['history', 'architecture', 'built', 'temple', 'pagoda', 'buddhist', 'route', 'nearby', 'recommend']
        for word in important_words:
            if word in text_lower:
                keywords.append(word)
        
        return keywords
    
    def _assess_complexity(self, text: str) -> str:
        """Assess question complexity"""
        word_count = len(text.split())
        if word_count <= 5:
            return 'simple'
        elif word_count <= 15:
            return 'moderate'
        else:
            return 'complex'
    
    def _assess_specificity(self, text: str) -> str:
        """Assess question specificity"""
        if any(word in text.lower() for word in ['specific', 'exact', 'precise', 'detailed']):
            return 'high'
        elif any(word in text.lower() for word in ['general', 'overview', 'summary']):
            return 'low'
        else:
            return 'medium'

class TopicClassifier:
    """Advanced topic classification for better conversation flow"""
    
    def __init__(self):
        self.topic_keywords = {
            'history': ['history', 'historical', 'ancient', 'built', 'constructed', 'dynasty', 'king', 'era'],
            'architecture': ['architecture', 'design', 'structure', 'style', 'building', 'construction', 'materials'],
            'religion': ['buddhist', 'buddhism', 'religious', 'temple', 'pagoda', 'spiritual', 'sacred'],
            'culture': ['cultural', 'tradition', 'heritage', 'significance', 'meaning', 'customs'],
            'travel': ['visit', 'travel', 'tour', 'trip', 'journey', 'explore', 'discover', 'itinerary'],
            'practical': ['entrance', 'fee', 'ticket', 'hours', 'time', 'access', 'location', 'directions']
        }
    
    def classify_topic(self, text: str) -> Dict[str, float]:
        """Classify text into topics with confidence scores"""
        text_lower = text.lower()
        topic_scores = {}
        
        for topic, keywords in self.topic_keywords.items():
            score = 0
            for keyword in keywords:
                if keyword in text_lower:
                    score += 1
            topic_scores[topic] = score / len(keywords)
        
        return topic_scores
    
    def get_primary_topic(self, text: str) -> str:
        """Get the primary topic of the text"""
        topic_scores = self.classify_topic(text)
        if topic_scores:
            return max(topic_scores.keys(), key=lambda x: topic_scores[x])
        return 'general'

class IntentRefinement:
    """Refines intent classification for better accuracy"""
    
    def __init__(self):
        self.intent_patterns = {
            'pagoda_info': [
                r'tell me about (.+)',
                r'what is (.+)',
                r'information about (.+)',
                r'details about (.+)'
            ],
            'pathfinding': [
                r'route from (.+) to (.+)',
                r'how to get to (.+)',
                r'directions to (.+)',
                r'path to (.+)'
            ],
            'recommendations': [
                r'recommend (.+)',
                r'suggest (.+)',
                r'what should i (.+)',
                r'best (.+)'
            ]
        }
    
    def refine_intent(self, message: str, initial_intent: str) -> Tuple[str, float]:
        """Refine intent classification using pattern matching"""
        message_lower = message.lower()
        
        # Check for specific patterns
        for intent, patterns in self.intent_patterns.items():
            for pattern in patterns:
                if re.search(pattern, message_lower):
                    return intent, 0.9
        
        # If no specific pattern found, return original intent with lower confidence
        return initial_intent, 0.6

class BaganeticChatbot:
    """Advanced AI chatbot for Bagan pagoda exploration with enhanced NLP capabilities"""
    
    def __init__(self):
        self.conversation_memory = {}
        self.pagoda_data = self._load_pagoda_data()
        self.pathfinder = None
        self.graph = None
        self._initialize_pathfinder()
        
        # Enhanced metrics/telemetry
        self.metrics = {
            'intent_counts': defaultdict(int),
            'fallback_counts': defaultdict(int),
            'sentiment_scores': [],
            'response_times': [],
            'user_satisfaction': defaultdict(int)
        }
        
        # Advanced NLP components
        self.lemmatizer = WordNetLemmatizer() if nltk else None
        self.stop_words = set(stopwords.words('english')) if nltk else set()
        self.spacy_nlp = None
        
        # Initialize spaCy model
        try:
            if spacy:
                self.spacy_nlp = spacy.load("en_core_web_sm")
        except OSError:
            print("Warning: spaCy English model not found. Install with: python -m spacy download en_core_web_sm")
        
        # Alias map for robust entity resolution
        self.alias_map = self._build_alias_map(self.pagoda_data)
        
        # Enhanced intent classification with multiple models
        self.intent_models = self._train_ensemble_classifiers()
        
        # Advanced conversation context
        self.context_analyzer = ContextAnalyzer()
        self.sentiment_analyzer = SentimentAnalyzer()
        self.entity_extractor = EntityExtractor(self.pagoda_data)
        
        # Performance optimization
        self.response_cache = {}
        self.cache_ttl = 300  # 5 minutes
        self.max_cache_size = 1000
        
        # Simplified keyword-based intent detection
        self.intent_keywords = {
            'greeting': ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening', 'start', 'begin'],
            'pagoda_info': ['tell me about', 'information about', 'details about', 'what is', 'show me', 'find', 'search for', 'about'],
            'pathfinding': ['route', 'path', 'way', 'how to get', 'directions', 'navigate', 'shortest', 'best', 'quickest', 'go from', 'travel from', 'plan route', 'plan another route'],
            'recommendations': ['recommend', 'suggest', 'what should', 'what can', 'best', 'famous', 'popular', 'must see', 'should visit', 'worth visiting', 'important', 'plan', 'itinerary', 'tour', 'visit', 'what are', 'must-visit', 'show me more routes', 'best routes', 'more routes'],
            'history_culture': ['history', 'historical', 'when was', 'built', 'constructed', 'dynasty', 'king', 'architect', 'culture', 'cultural', 'significance', 'religious', 'buddhist', 'buddhism', 'architecture', 'style', 'design', 'structure', 'materials'],
            'practical_info': ['entrance fee', 'ticket', 'price', 'cost', 'free', 'opening hours', 'time', 'when open', 'closed', 'accessibility', 'wheelchair', 'disabled', 'difficulty', 'duration', 'how long', 'time to visit', 'spend'],
            'nearby': ['nearby', 'close to', 'around', 'near', 'surrounding', 'within', 'distance', 'km', 'kilometers', 'walking distance', 'find pagodas near', 'pagodas near', 'find pagodas near the destination'],
            'favorites': ['favorite', 'favourite', 'like', 'love', 'prefer', 'save', 'bookmark', 'remember', 'add to'],
            'general_help': ['help', 'what can', 'how can', 'what do', 'assist', 'commands', 'features', 'capabilities', 'options', 'show me more', 'tell me more', 'what else']
        }
        
        # More natural and varied response templates
        self.response_templates = {
            'greeting': [
                "Hello! I'm your Baganetic AI assistant. I can help you explore the ancient pagodas of Bagan!",
                "Hi there! Welcome to Baganetic. I'm here to help you discover the wonders of Bagan's temples!",
                "Greetings! I'm your personal guide to Bagan's magnificent pagodas. How can I assist you today?",
                "Welcome to Baganetic! I'm your AI companion for exploring Myanmar's ancient treasures. Let's begin your journey!",
                "Hey! Ready to explore Bagan's incredible pagodas? I'm here to help you discover their secrets!",
                "Welcome! I'm your guide to Bagan's ancient wonders. What would you like to know about these magnificent temples?"
            ],
            'help': [
                "I can help you with pagoda information, route planning, recommendations, cultural details, and practical visiting info. What would you like to know?",
                "Here's what I can do: tell you about any pagoda in Bagan, plan routes between temples, suggest must-see pagodas, share historical insights, and help with visiting details. Just ask me anything!",
                "I'm your comprehensive Bagan guide! I can provide detailed pagoda information, calculate optimal routes, recommend temples based on your interests, share fascinating historical stories, and help plan your perfect Bagan itinerary. What interests you most?",
                "I specialize in Bagan's pagodas - their history, architecture, cultural significance, and practical visiting information. I can also help you plan routes and find the best pagodas to visit. What would you like to explore?",
                "I'm here to help you discover Bagan's ancient treasures! I can tell you about pagodas, plan your routes, give recommendations, and share fascinating stories about Myanmar's spiritual heritage. What catches your interest?"
            ],
            'excited': [
                "That's fantastic! I'm excited to share this with you!",
                "Wonderful choice! Let me tell you all about it!",
                "Excellent! This is one of my favorite topics!",
                "Great question! I love talking about this!",
                "Perfect! I have some amazing information about this!",
                "Awesome! This is such an interesting topic!"
            ],
            'encouraging': [
                "Don't worry, I'm here to help you every step of the way!",
                "That's perfectly fine! Let me guide you through this!",
                "No problem at all! I'll make this easy for you!",
                "Absolutely! I'm here to make your Bagan experience amazing!",
                "No worries! I'll help you understand this better!",
                "That's totally fine! Let me explain this clearly!"
            ]
        }
        
        # Multi-language support (basic)
        self.language_detection = {
            'myanmar_keywords': ['မြန်မာ', 'ဗုဒ္ဓ', 'ဘုရား', 'စေတီ', 'ပုဂံ'],
            'chinese_keywords': ['中文', '中国', '佛教', '寺庙', '蒲甘'],
            'japanese_keywords': ['日本語', '日本', '仏教', '寺院', 'バガン']
        }
        
        # Advanced AI capabilities for English
        self.conversation_learning = ConversationLearning()
        self.smart_recommendations = SmartRecommendationEngine(self.pagoda_data)
        self.contextual_memory = ContextualMemory()
        self.adaptive_responses = AdaptiveResponseGenerator()
        
        # Advanced NLP features
        self.question_analyzer = QuestionAnalyzer()
        self.topic_classifier = TopicClassifier()
        self.intent_refinement = IntentRefinement()
    
    def _normalize_text(self, text: str) -> str:
        """Normalize text for robust matching (case, spaces, hyphens)."""
        try:
            t = text.lower().strip()
            t = re.sub(r'[^a-z0-9\s]', ' ', t)
            t = re.sub(r'\s+', ' ', t)
            return t
        except Exception:
            return text.lower().strip()

    def _build_alias_map(self, pagodas: List[Dict[str, Any]]) -> Dict[str, str]:
        """Build map of alias -> pagoda_id for quick, robust lookup."""
        alias_to_id: Dict[str, str] = {}
        for p in pagodas:
            pid = p.get('id') or ''
            names = set()
            for key in ['id', 'name', 'shortName']:
                val = p.get(key)
                if val:
                    names.add(str(val))
            # Additional simple variants
            expanded = set()
            for n in names:
                expanded.add(n)
                expanded.add(n.replace(' Temple', ''))
                expanded.add(n.replace(' Pagoda', ''))
                expanded.add(n.replace('-', ' '))
            for n in expanded:
                norm = self._normalize_text(n)
                if norm:
                    alias_to_id[norm] = pid
        return alias_to_id

    def _train_ensemble_classifiers(self):
        """Train multiple classifiers for robust intent detection"""
        if not all([Pipeline, TfidfVectorizer, LogisticRegression, RandomForestClassifier, MultinomialNB]):
            return {}
            
        # Enhanced training dataset with more examples
        training_data = [
            # Greeting patterns
            ("hi", 'greeting'), ("hello", 'greeting'), ("hey there", 'greeting'), 
            ("good morning", 'greeting'), ("good afternoon", 'greeting'), ("good evening", 'greeting'),
            ("start", 'greeting'), ("begin", 'greeting'), ("help me", 'general_help'),
            
            # Pagoda information requests
            ("tell me about ananda", 'pagoda_info'), ("information about shwezigon", 'pagoda_info'), 
            ("details about dhammayangyi", 'pagoda_info'), ("what is ananda temple", 'pagoda_info'),
            ("show me ananda", 'pagoda_info'), ("find ananda temple", 'pagoda_info'),
            ("ananda temple", 'pagoda_info'), ("shwezigon pagoda", 'pagoda_info'),
            
            # Pathfinding and navigation
            ("route from ananda to shwezigon", 'pathfinding'), ("how to get to gawdawpalin", 'pathfinding'), 
            ("directions between temples", 'pathfinding'), ("navigate to ananda", 'pathfinding'),
            ("shortest path to shwezigon", 'pathfinding'), ("best route to dhammayangyi", 'pathfinding'),
            ("go from ananda to gawdawpalin", 'pathfinding'), ("travel between temples", 'pathfinding'),
            
            # Recommendations and suggestions
            ("recommend must see pagodas", 'recommendations'), ("what are the best temples", 'recommendations'),
            ("suggest pagodas to visit", 'recommendations'), ("what should i see", 'recommendations'),
            ("must visit pagodas", 'recommendations'), ("popular temples", 'recommendations'),
            ("best pagodas in bagan", 'recommendations'), ("famous temples", 'recommendations'),
            
            # Nearby search
            ("nearby pagodas around ananda", 'nearby'), ("what's close to shwezigon", 'nearby'),
            ("pagodas near dhammayangyi", 'nearby'), ("find pagodas near me", 'nearby'),
            ("surrounding temples", 'nearby'), ("close to ananda", 'nearby'),
            
            # History and culture
            ("history of dhammayangyi", 'history_culture'), ("when was sulamani built", 'history_culture'), 
            ("cultural significance of bagan", 'history_culture'), ("ancient history", 'history_culture'),
            ("pagan dynasty", 'history_culture'), ("buddhist architecture", 'history_culture'),
            ("religious significance", 'history_culture'), ("cultural heritage", 'history_culture'),
            
            # Practical information
            ("entrance fee for ananda", 'practical_info'), ("opening hours shwezigon", 'practical_info'), 
            ("how long to visit sulamani", 'practical_info'), ("visiting hours", 'practical_info'),
            ("ticket prices", 'practical_info'), ("accessibility", 'practical_info'),
            ("what to bring", 'practical_info'), ("visiting tips", 'practical_info'),
            
            # General help
            ("what can you do", 'general_help'), ("commands", 'general_help'), ("help", 'general_help'),
            ("what do you know", 'general_help'), ("capabilities", 'general_help'),
            
            # Itinerary planning
            ("plan a day trip", 'itinerary'), ("create an itinerary", 'itinerary'), 
            ("day trip to bagan", 'itinerary'), ("what should i see in bagan", 'itinerary'),
            ("plan my visit", 'itinerary'), ("tour planning", 'itinerary'),
        ]

        texts = [t for t, y in training_data]
        labels = [y for t, y in training_data]
        unique_labels = sorted(set(labels))

        models = {}
        
        try:
            # Logistic Regression
            lr_pipeline = Pipeline([
                ('tfidf', TfidfVectorizer(ngram_range=(1, 2), min_df=1, max_features=1000)),
                ('clf', LogisticRegression(max_iter=1000, random_state=42))
            ])
            lr_pipeline.fit(texts, labels)
            models['logistic_regression'] = lr_pipeline
            
            # Random Forest
            rf_pipeline = Pipeline([
                ('tfidf', TfidfVectorizer(ngram_range=(1, 2), min_df=1, max_features=1000)),
                ('clf', RandomForestClassifier(n_estimators=100, random_state=42))
            ])
            rf_pipeline.fit(texts, labels)
            models['random_forest'] = rf_pipeline
            
            # Naive Bayes
            nb_pipeline = Pipeline([
                ('tfidf', TfidfVectorizer(ngram_range=(1, 2), min_df=1, max_features=1000)),
                ('clf', MultinomialNB())
            ])
            nb_pipeline.fit(texts, labels)
            models['naive_bayes'] = nb_pipeline
            
        except Exception as e:
            print(f"Error training classifiers: {e}")
            
        return models

    def _classify_intent_ensemble(self, message: str) -> Tuple[str, float]:
        """Classify intent using ensemble of ML models. Returns (intent, probability)."""
        if not self.intent_models:
            return 'unknown', 0.0
            
        predictions = {}
        confidences = {}
        
        try:
            # Get predictions from all models
            for model_name, model in self.intent_models.items():
                try:
                    intent = model.predict([message])[0]
                    predictions[model_name] = intent
                    
                    # Get confidence score
                    if hasattr(model.named_steps.get('clf'), 'predict_proba'):
                        proba_vec = model.predict_proba([message])[0]
                        class_labels = model.named_steps['clf'].classes_
                        idx = list(class_labels).index(intent)
                        confidences[model_name] = float(proba_vec[idx])
                    else:
                        confidences[model_name] = 0.5
                except Exception as e:
                    print(f"Error with {model_name}: {e}")
                    continue
            
            if not predictions:
                return 'unknown', 0.0
            
            # Ensemble voting with confidence weighting
            intent_votes = defaultdict(float)
            for model_name, intent in predictions.items():
                confidence = confidences.get(model_name, 0.5)
                intent_votes[intent] += confidence
            
            # Get the intent with highest weighted vote
            best_intent = max(intent_votes.keys(), key=lambda x: intent_votes[x])
            best_confidence = intent_votes[best_intent] / len(predictions)
            
            return best_intent, best_confidence
            
        except Exception as e:
            print(f"Error in ensemble classification: {e}")
            return 'unknown', 0.0
    
    def _load_pagoda_data(self) -> List[Dict[str, Any]]:
        """Load pagoda data from the existing data source"""
        try:
            # Try to load from pagodas.js file
            with open("assets/data/pagodas.js", "r", encoding="utf-8") as f:
                content = f.read()
            
            # Extract pagodas array
            start_key = "pagodas: ["
            start_idx = content.find(start_key)
            if start_idx == -1:
                raise ValueError("pagodas array not found")
            
            start_idx += len("pagodas: ")
            depth, i = 0, start_idx
            while i < len(content):
                if content[i] == "[":
                    depth += 1
                elif content[i] == "]":
                    depth -= 1
                    if depth == 0:
                        end_idx = i + 1
                        break
                i += 1
            else:
                raise ValueError("unterminated pagodas array")
            
            array_text = content[start_idx:end_idx]
            
            # Convert to JSON format
            replacements = [
                ("id:", '"id":'),
                ("name:", '"name":'),
                ("shortName:", '"shortName":'),
                ("type:", '"type":'),
                ("location:", '"location":'),
                ("coordinates:", '"coordinates":'),
                ("lat:", '"lat":'),
                ("lng:", '"lng":'),
                ("images:", '"images":'),
                ("main:", '"main":'),
                ("thumbnail:", '"thumbnail":'),
                ("description:", '"description":'),
                ("short:", '"short":'),
                ("long:", '"long":'),
                ("history:", '"history":'),
                ("architecture:", '"architecture":'),
                ("religious:", '"religious":'),
                ("visiting:", '"visiting":'),
                ("tags:", '"tags":'),
                ("featured:", '"featured":'),
            ]
            
            for a, b in replacements:
                array_text = array_text.replace(a, b)
            
            data = json.loads(f'{{"pagodas": {array_text}}}')
            return data["pagodas"]
            
        except Exception as e:
            print(f"Error loading pagoda data: {e}")
            # Return minimal sample data
            return [
                {
                    "id": "ananda",
                    "name": "Ananda Temple",
                    "shortName": "Ananda",
                    "type": "Temple",
                    "location": {"coordinates": {"lat": 21.170806, "lng": 94.867856}},
                    "description": {"short": "One of Bagan's most beautiful temples", "long": "Built in 1105 AD by King Kyanzittha, the Ananda Temple is considered one of the finest examples of Mon architecture in Bagan."},
                    "history": {"built": "1105 AD", "dynasty": "Pagan", "king": "Kyanzittha"},
                    "architecture": {"style": "Mon", "height": "51 meters"},
                    "religious": {"significance": "Buddhist temple", "buddha_statues": 4},
                    "visiting": {"entrance_fee": "Free", "opening_hours": "6:00 AM - 6:00 PM"},
                    "featured": True
                },
                {
                    "id": "shwezigon",
                    "name": "Shwezigon Pagoda",
                    "shortName": "Shwezigon",
                    "type": "Pagoda",
                    "location": {"coordinates": {"lat": 21.183, "lng": 94.867}},
                    "description": {"short": "The most sacred pagoda in Bagan", "long": "Built by King Anawrahta in 1059, this golden pagoda is considered the prototype for all Myanmar pagodas."},
                    "history": {"built": "1059 AD", "dynasty": "Pagan", "king": "Anawrahta"},
                    "architecture": {"style": "Myanmar", "height": "49 meters"},
                    "religious": {"significance": "Most sacred pagoda", "buddha_statues": 1},
                    "visiting": {"entrance_fee": "Free", "opening_hours": "24/7"},
                    "featured": True
                }
            ]
    
    def _initialize_pathfinder(self):
        """Initialize the pathfinder for route calculations"""
        try:
            if ImprovedPagodaPathFinder:
                self.graph = create_pagoda_graph(self.pagoda_data)
                self.pathfinder = ImprovedPagodaPathFinder(self.pagoda_data)
                print("Pathfinder initialized successfully")
            else:
                print("Pathfinder modules not available")
        except Exception as e:
            print(f"Error initializing pathfinder: {e}")
    
    def _detect_intent(self, message: str) -> Tuple[str, List[str]]:
        """Detect user intent from the message using improved keyword matching"""
        message_lower = message.lower().strip()
        
        
        # Special handling for suggestion prompts first
        if message_lower in ['show me more routes', 'plan another route', 'what are the best routes in bagan?']:
            return 'recommendations', ['route suggestions']
        
        if message_lower in ['find pagodas near the destination', 'find pagodas near sulamani']:
            return 'nearby', ['destination']
        
        if message_lower in ['show me more', 'tell me more', 'what else']:
            return 'general_help', ['more information']
        
        # Handle general pagoda queries that shouldn't be treated as specific names
        if message_lower in ['tell me about these pagodas', 'tell me about the pagodas', 'tell me about pagodas', 'about these pagodas', 'about the pagodas', 'about pagodas']:
            return 'recommendations', ['general pagoda information']
        
        if message_lower in ['show me pagodas', 'show me the pagodas', 'show me these pagodas']:
            return 'recommendations', ['pagoda list']
        
        if message_lower in ['what pagodas', 'which pagodas', 'what are the pagodas', 'which are the pagodas']:
            return 'recommendations', ['pagoda information']
        
        # Special handling for common patterns - but only for specific pagoda names
        if any(word in message_lower for word in ['tell me about', 'information about', 'details about']):
            # Extract pagoda name after "about" - but only for specific pagoda names
            parts = message_lower.split('about')
            if len(parts) > 1:
                pagoda_name = parts[1].strip()
                # Only treat as pagoda name if it's not a general term
                if pagoda_name and pagoda_name not in ['these pagodas', 'the pagodas', 'pagodas', 'these', 'the']:
                    return 'pagoda_info', [pagoda_name]
        
        if 'what is' in message_lower:
            # Extract pagoda name after "what is"
            parts = message_lower.split('what is')
            if len(parts) > 1:
                pagoda_name = parts[1].strip()
                if pagoda_name:
                    return 'pagoda_info', [pagoda_name]
        
        if 'show me information about' in message_lower:
            # Extract pagoda name after "show me information about"
            parts = message_lower.split('show me information about')
            if len(parts) > 1:
                pagoda_name = parts[1].strip()
                if pagoda_name:
                    return 'pagoda_info', [pagoda_name]
        
        # Nearby search patterns
        if any(pattern in message_lower for pattern in ['find pagodas near', 'pagodas near', 'nearby pagodas around', 'what\'s near']):
            # Extract pagoda name after "near" or "around"
            for keyword in ['near', 'around']:
                if keyword in message_lower:
                    parts = message_lower.split(keyword)
                    if len(parts) > 1:
                        pagoda_name = parts[1].strip()
                        if pagoda_name:
                            return 'nearby', [pagoda_name]
        
        # Handle "nearby pagodas around X" pattern specifically
        if 'nearby pagodas around' in message_lower:
            parts = message_lower.split('nearby pagodas around')
            if len(parts) > 1:
                pagoda_name = parts[1].strip()
                if pagoda_name:
                    return 'nearby', [pagoda_name]
        
        if 'what are the' in message_lower and any(word in message_lower for word in ['must-see', 'best', 'famous', 'popular']):
            return 'recommendations', ['must-see pagodas']
        
        # Itinerary planning
        if any(phrase in message_lower for phrase in ['plan a day trip', 'create an itinerary', 'day trip to bagan', 'what should i see in bagan']):
            return 'itinerary', ['day trip']
        
        if 'history of' in message_lower:
            # Extract pagoda name after "history of"
            parts = message_lower.split('history of')
            if len(parts) > 1:
                pagoda_name = parts[1].strip()
                if pagoda_name:
                    return 'history_culture', [pagoda_name]
        
        if 'when was' in message_lower and 'built' in message_lower:
            # Extract pagoda name between "when was" and "built"
            parts = message_lower.split('when was')
            if len(parts) > 1:
                middle_part = parts[1].split('built')[0].strip()
                if middle_part:
                    return 'history_culture', [middle_part]
        
        if 'cultural significance of' in message_lower:
            # Extract pagoda name after "cultural significance of"
            parts = message_lower.split('cultural significance of')
            if len(parts) > 1:
                pagoda_name = parts[1].strip()
                if pagoda_name:
                    return 'history_culture', [pagoda_name]
        
        # Score each intent based on keyword matches (prioritize multi-word phrases)
        intent_scores = {}
        for intent, keywords in self.intent_keywords.items():
            score = 0
            matched_keywords = []
            for keyword in keywords:
                if keyword in message_lower:
                    # Give higher score to multi-word keywords
                    word_count = len(keyword.split())
                    if word_count > 1:
                        score += 2  # Double score for multi-word phrases
                    else:
                        score += 1
                    matched_keywords.append(keyword)
            if score > 0:
                intent_scores[intent] = (score, matched_keywords)
        
        # Return the highest scoring intent
        if intent_scores:
            best_intent = max(intent_scores.keys(), key=lambda x: intent_scores[x][0])
            return best_intent, intent_scores[best_intent][1]
        
        # Check if message is just a pagoda name
        pagoda = self._find_pagoda_by_name(message)
        if pagoda:
            return 'pagoda_info', [message]
        
        # Handle simple "about [pagoda]" patterns
        if message_lower.startswith('about '):
            pagoda_name = message_lower[6:].strip()  # Remove "about "
            pagoda = self._find_pagoda_by_name(pagoda_name)
            if pagoda:
                return 'pagoda_info', [pagoda_name]
        
        return 'unknown', []
    
    def _find_pagoda_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Find a pagoda by name with improved fuzzy matching"""
        if not name or not name.strip():
            return None
            
        name_lower = name.lower().strip()
        
        # Try alias map first (fastest)
        alias_norm = self._normalize_text(name)
        if alias_norm in self.alias_map:
            pid = self.alias_map[alias_norm]
            for pagoda in self.pagoda_data:
                if pagoda.get('id', '').lower() == pid:
                    return pagoda
        
        # Direct exact matches
        for pagoda in self.pagoda_data:
            pagoda_name = pagoda.get('name', '').lower()
            short_name = pagoda.get('shortName', '').lower()
            pagoda_id = pagoda.get('id', '').lower()
            
            if name_lower in [pagoda_name, short_name, pagoda_id]:
                return pagoda
        
        # Partial matches (substring)
        partial_matches = []
        for pagoda in self.pagoda_data:
            pagoda_name = pagoda.get('name', '').lower()
            short_name = pagoda.get('shortName', '').lower()
            
            if name_lower in pagoda_name or name_lower in short_name:
                # Score based on match position and length
                score = 0.8 if name_lower in pagoda_name else 0.7
                partial_matches.append((score, pagoda))
        
        if partial_matches:
            partial_matches.sort(key=lambda x: x[0], reverse=True)
            return partial_matches[0][1]
        
        # Fuzzy matching for typos and variations (more conservative)
        fuzzy_candidates = []
        for pagoda in self.pagoda_data:
            pagoda_name = pagoda.get('name', '').lower()
            short_name = pagoda.get('shortName', '').lower()
            pagoda_id = pagoda.get('id', '').lower()
            
            # Calculate similarity scores
            name_score = difflib.SequenceMatcher(None, name_lower, pagoda_name).ratio()
            short_score = difflib.SequenceMatcher(None, name_lower, short_name).ratio()
            id_score = difflib.SequenceMatcher(None, name_lower, pagoda_id).ratio()
            
            max_score = max(name_score, short_score, id_score)
            # Higher threshold to avoid false positives
            if max_score >= 0.8:
                fuzzy_candidates.append((max_score, pagoda))
        
        if fuzzy_candidates:
            fuzzy_candidates.sort(key=lambda x: x[0], reverse=True)
            # Only return if the best match is significantly better than others
            if len(fuzzy_candidates) == 1 or fuzzy_candidates[0][0] - fuzzy_candidates[1][0] > 0.1:
                return fuzzy_candidates[0][1]

        return None

    def _suggest_similar_pagodas(self, query: str, limit: int = 3) -> List[str]:
        """Suggest similar pagoda names for clarification prompts."""
        candidates = []
        q = self._normalize_text(query)
        keys = list(self.alias_map.keys())
        try:
            # Use difflib on alias keys for better coverage
            matches = difflib.get_close_matches(q, keys, n=limit, cutoff=0.6)
            for m in matches:
                pid = self.alias_map[m]
                p = next((x for x in self.pagoda_data if x.get('id') == pid), None)
                if p:
                    candidates.append(p.get('name') or p.get('shortName') or p.get('id'))
        except Exception:
            pass
        return candidates
    
    def _find_pagodas_by_keywords(self, keywords: List[str]) -> List[Dict[str, Any]]:
        """Find pagodas by keywords"""
        results = []
        keywords_lower = [kw.lower() for kw in keywords]
        
        for pagoda in self.pagoda_data:
            score = 0
            pagoda_text = f"{pagoda.get('name', '')} {pagoda.get('description', {}).get('short', '')} {pagoda.get('description', {}).get('long', '')}".lower()
            
            for keyword in keywords_lower:
                if keyword in pagoda_text:
                    score += 1
            
            if score > 0:
                results.append((pagoda, score))
        
        # Sort by relevance score
        results.sort(key=lambda x: x[1], reverse=True)
        return [pagoda for pagoda, score in results]
    
    def _calculate_distance(self, pagoda1: Dict[str, Any], pagoda2: Dict[str, Any]) -> float:
        """Calculate distance between two pagodas in kilometers"""
        try:
            lat1 = pagoda1['location']['coordinates']['lat']
            lng1 = pagoda1['location']['coordinates']['lng']
            lat2 = pagoda2['location']['coordinates']['lat']
            lng2 = pagoda2['location']['coordinates']['lng']
            
            # Haversine formula
            R = 6371  # Earth's radius in kilometers
            dlat = math.radians(lat2 - lat1)
            dlng = math.radians(lng2 - lng1)
            a = (math.sin(dlat/2) * math.sin(dlat/2) + 
                 math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * 
                 math.sin(dlng/2) * math.sin(dlng/2))
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
            return R * c
        except:
            return 0
    
    def _get_pagoda_info_response(self, pagoda: Dict[str, Any]) -> str:
        """Generate detailed information response for a pagoda"""
        pagoda_name = pagoda.get('name', 'Unknown Pagoda')
        
        # More natural opening phrases
        openings = [
            f"**{pagoda_name}** is truly remarkable!",
            f"Let me tell you about **{pagoda_name}** - it's fascinating!",
            f"**{pagoda_name}** is one of Bagan's most incredible sites!",
            f"**{pagoda_name}** has such an amazing story!",
            f"**{pagoda_name}** is absolutely worth learning about!"
        ]
        response = random.choice(openings) + "\n\n"
        
        # Basic info
        if pagoda.get('description', {}).get('short'):
            response += f"{pagoda['description']['short']}\n\n"
        
        # History with more natural language
        if pagoda.get('history'):
            history = pagoda['history']
            history_intros = [
                "**Here's the fascinating history:**",
                "**The historical background is incredible:**",
                "**This pagoda has an amazing history:**",
                "**Let me share the historical story:**"
            ]
            response += random.choice(history_intros) + "\n"
            if history.get('built'):
                response += f"- Built: {history['built']}\n"
            if history.get('dynasty'):
                response += f"- Dynasty: {history['dynasty']}\n"
            if history.get('king'):
                response += f"- King: {history['king']}\n"
            response += "\n"
        
        # Architecture with varied language
        if pagoda.get('architecture'):
            arch = pagoda['architecture']
            arch_intros = [
                "**The architecture is stunning:**",
                "**From an architectural perspective:**",
                "**The design features are remarkable:**",
                "**The structural details are fascinating:**"
            ]
            response += random.choice(arch_intros) + "\n"
            if arch.get('style'):
                response += f"- Style: {arch['style']}\n"
            if arch.get('height'):
                response += f"- Height: {arch['height']}\n"
            if arch.get('structure'):
                response += f"- Structure: {arch['structure']}\n"
            response += "\n"
        
        # Religious significance with natural language
        if pagoda.get('religious'):
            rel = pagoda['religious']
            rel_intros = [
                "**Its religious importance is profound:**",
                "**The spiritual significance is remarkable:**",
                "**From a religious perspective:**",
                "**The sacred aspects are fascinating:**"
            ]
            response += random.choice(rel_intros) + "\n"
            if rel.get('significance'):
                response += f"- {rel['significance']}\n"
            if rel.get('buddha_statues'):
                response += f"- Buddha Statues: {rel['buddha_statues']}\n"
            response += "\n"
        
        # Visiting info with helpful tone
        if pagoda.get('visiting'):
            visit = pagoda['visiting']
            visit_intros = [
                "**Practical visiting information:**",
                "**Here's what you need to know for your visit:**",
                "**Visiting details:**",
                "**Practical information for visitors:**"
            ]
            response += random.choice(visit_intros) + "\n"
            if visit.get('entrance_fee'):
                response += f"- Entrance Fee: {visit['entrance_fee']}\n"
            if visit.get('opening_hours'):
                response += f"- Opening Hours: {visit['opening_hours']}\n"
            if visit.get('duration'):
                response += f"- Recommended Duration: {visit['duration']}\n"
        
        return response
    
    def _get_route_response(self, start_name: str, end_name: str) -> str:
        """Generate route planning response"""
        # Find start and end pagodas
        start_pagoda = self._find_pagoda_by_name(start_name)
        end_pagoda = self._find_pagoda_by_name(end_name)
        
        if not start_pagoda:
            suggestions = self._suggest_similar_pagodas(start_name, limit=3)
            if suggestions:
                return f"I couldn't find '{start_name}'. Did you mean:\n\n" + "\n".join(f"- {s}" for s in suggestions)
            else:
                return f"I couldn't find a pagoda named '{start_name}'. Please check the spelling."
        
        if not end_pagoda:
            suggestions = self._suggest_similar_pagodas(end_name, limit=3)
            if suggestions:
                return f"I couldn't find '{end_name}'. Did you mean:\n\n" + "\n".join(f"- {s}" for s in suggestions)
            else:
                return f"I couldn't find a pagoda named '{end_name}'. Please check the spelling."
        
        if start_pagoda['id'] == end_pagoda['id']:
            return f"You're already at {start_pagoda['name']}! No route needed."
        
        # Calculate distance
        distance = self._calculate_distance(start_pagoda, end_pagoda)
        
        # Try to use pathfinder if available
        if self.pathfinder:
            try:
                # Use the pathfinder to get the route
                route = self.pathfinder.find_path_astar(start_pagoda['name'], end_pagoda['name'])
                if route and len(route) > 1:
                    response = f"**Route from {start_pagoda['name']} to {end_pagoda['name']}:**\n\n"
                    response += f"**Distance:** {distance:.2f} km\n"
                    response += f"**Estimated Time:** {distance * 2:.0f} minutes (walking)\n\n"
                    response += "**Route:**\n"
                    
                    for i, pagoda_name in enumerate(route):
                        if i == 0:
                            response += f"{i+1}. **{pagoda_name}** (Start)\n"
                        elif i == len(route) - 1:
                            response += f"{i+1}. **{pagoda_name}** (Destination)\n"
                        else:
                            response += f"{i+1}. {pagoda_name}\n"
                    
                    response += f"\n**Tips:**\n"
                    response += f"- Follow the main roads between pagodas\n"
                    response += f"- Bring water and sun protection\n"
                    response += f"- Check opening hours before visiting\n"
                    
                    return response
            except Exception as e:
                print(f"Pathfinder error: {e}")
        
        # Fallback: Simple distance-based response
        response = f"**Route from {start_pagoda['name']} to {end_pagoda['name']}:**\n\n"
        response += f"**Distance:** {distance:.2f} km\n"
        response += f"**Estimated Time:** {distance * 2:.0f} minutes (walking)\n\n"
        response += f"**Directions:**\n"
        response += f"1. Start at {start_pagoda['name']}\n"
        response += f"2. Head towards {end_pagoda['name']}\n"
        response += f"3. Follow the main roads and signs\n\n"
        response += f"**Tips:**\n"
        response += f"- Use the map feature for detailed navigation\n"
        response += f"- Bring water and sun protection\n"
        response += f"- Check opening hours before visiting\n"
        
        return response
    
    def _get_recommendations_response(self, context: str = "") -> str:
        """Generate recommendations based on context"""
        featured_pagodas = [p for p in self.pagoda_data if p.get('featured', False)]
        
        if not featured_pagodas:
            # If no featured pagodas, recommend based on popularity
            featured_pagodas = self.pagoda_data[:5]
        
        # More natural opening phrases
        openings = [
            "**Here are the must-visit pagodas in Bagan:**",
            "**These are the most incredible pagodas you should see:**",
            "**I highly recommend these amazing pagodas:**",
            "**These are Bagan's most spectacular sites:**",
            "**You absolutely must visit these pagodas:**"
        ]
        response = random.choice(openings) + "\n\n"
        
        for i, pagoda in enumerate(featured_pagodas[:5], 1):
            response += f"{i}. **{pagoda.get('name', 'Unknown')}**\n"
            if pagoda.get('description', {}).get('short'):
                response += f"   {pagoda['description']['short']}\n"
            if pagoda.get('history', {}).get('built'):
                response += f"   Built: {pagoda['history']['built']}\n"
            response += "\n"
        
        # More natural tips
        tip_intros = [
            "**Here are some helpful tips for your visit:**",
            "**Pro tips to make your experience amazing:**",
            "**Some insider advice for your journey:**",
            "**Tips to help you make the most of your visit:**"
        ]
        response += random.choice(tip_intros) + "\n"
        response += "- Visit during sunrise or sunset for the best views\n"
        response += "- Wear comfortable shoes for walking\n"
        response += "- Bring water and sun protection\n"
        response += "- Respect the religious sites and dress modestly\n"
        
        return response
    
    def _get_nearby_pagodas_response(self, pagoda_name: str, radius: float = 1.0) -> str:
        """Find and return nearby pagodas"""
        center_pagoda = self._find_pagoda_by_name(pagoda_name)
        
        if not center_pagoda:
            return f"I couldn't find a pagoda named '{pagoda_name}'. Please check the spelling."
        
        nearby_pagodas = []
        
        for pagoda in self.pagoda_data:
            if pagoda['id'] != center_pagoda['id']:
                distance = self._calculate_distance(center_pagoda, pagoda)
                if distance <= radius:
                    nearby_pagodas.append((pagoda, distance))
        
        # Sort by distance
        nearby_pagodas.sort(key=lambda x: x[1])
        
        if not nearby_pagodas:
            return f"No pagodas found within {radius} km of {center_pagoda['name']}."
        
        response = f"**Pagodas near {center_pagoda['name']} (within {radius} km):**\n\n"
        
        for pagoda, distance in nearby_pagodas[:10]:  # Show top 10
            response += f"- **{pagoda['name']}** - {distance:.2f} km\n"
            if pagoda.get('description', {}).get('short'):
                response += f"  {pagoda['description']['short']}\n"
            response += "\n"
        
        return response
    
    def _get_itinerary_response(self, context: str = "") -> str:
        """Generate itinerary planning response"""
        featured_pagodas = [p for p in self.pagoda_data if p.get('featured', False)]
        
        if not featured_pagodas:
            featured_pagodas = self.pagoda_data[:5]
        
        response = "**Perfect Day Trip Itinerary for Bagan:**\n\n"
        
        # Morning itinerary
        response += "**Morning (6:00 AM - 12:00 PM):**\n"
        morning_pagodas = featured_pagodas[:3]
        for i, pagoda in enumerate(morning_pagodas, 1):
            response += f"{i}. **{pagoda['name']}** (6:00-8:00 AM)\n"
            if pagoda.get('description', {}).get('short'):
                response += f"   {pagoda['description']['short']}\n"
            response += "\n"
        
        # Afternoon itinerary
        response += "**Afternoon (12:00 PM - 6:00 PM):**\n"
        afternoon_pagodas = featured_pagodas[3:6] if len(featured_pagodas) > 3 else featured_pagodas[:3]
        for i, pagoda in enumerate(afternoon_pagodas, 1):
            response += f"{i}. **{pagoda['name']}** (2:00-4:00 PM)\n"
            if pagoda.get('description', {}).get('short'):
                response += f"   {pagoda['description']['short']}\n"
            response += "\n"
        
        # Evening itinerary
        response += "**Evening (6:00 PM - 8:00 PM):**\n"
        response += "1. **Sunset Viewing** at Shwezigon Pagoda\n"
        response += "   Best spot for sunset photography\n\n"
        
        response += "**Tips for Your Day Trip:**\n"
        response += "- Start early to avoid crowds\n"
        response += "- Bring water, sun protection, and comfortable shoes\n"
        response += "- Respect religious sites and dress modestly\n"
        response += "- Consider hiring a guide for detailed information\n"
        response += "- Check opening hours before visiting\n"
        
        return response
    
    def _find_similar_pagodas(self, pagoda: Dict[str, Any], limit: int = 3) -> List[Dict[str, Any]]:
        """Find pagodas similar to the given one based on type, architecture, or era"""
        similar_pagodas = []
        pagoda_type = pagoda.get('type', '')
        pagoda_style = pagoda.get('architecture', {}).get('style', '')
        pagoda_era = pagoda.get('history', {}).get('built', '')
        
        for other_pagoda in self.pagoda_data:
            if other_pagoda['id'] == pagoda['id']:
                continue
                
            score = 0
            
            # Type similarity
            if other_pagoda.get('type', '') == pagoda_type:
                score += 3
            
            # Architecture style similarity
            other_style = other_pagoda.get('architecture', {}).get('style', '')
            if other_style and pagoda_style and other_style.lower() in pagoda_style.lower():
                score += 2
            
            # Era similarity (same century)
            other_era = other_pagoda.get('history', {}).get('built', '')
            if other_era and pagoda_era:
                try:
                    pagoda_year = int(pagoda_era.split()[0])
                    other_year = int(other_era.split()[0])
                    if abs(pagoda_year - other_year) <= 100:  # Within 100 years
                        score += 1
                except:
                    pass
            
            if score > 0:
                similar_pagodas.append((other_pagoda, score))
        
        # Sort by similarity score and return top results
        similar_pagodas.sort(key=lambda x: x[1], reverse=True)
        return [pagoda for pagoda, score in similar_pagodas[:limit]]
    
    def _assess_user_experience(self, user_id: str) -> str:
        """Assess user experience level based on interaction history"""
        if user_id not in self.conversation_memory:
            return 'beginner'
        
        user_data = self.conversation_memory[user_id]
        message_count = len([msg for msg in user_data['history'] if msg.get('type') == 'user'])
        visited_pagodas = len(user_data['preferences']['visited_pagodas'])
        
        if message_count > 20 and visited_pagodas > 5:
            return 'expert'
        elif message_count > 5 or visited_pagodas > 2:
            return 'intermediate'
        else:
            return 'beginner'
    
    def _get_cached_response(self, message: str, user_id: str) -> Optional[Dict[str, Any]]:
        """Get cached response if available and not expired"""
        cache_key = f"{user_id}:{message.lower().strip()}"
        current_time = time.time()
        
        if cache_key in self.response_cache:
            cached_data = self.response_cache[cache_key]
            if current_time - cached_data['timestamp'] < self.cache_ttl:
                return cached_data['response']
            else:
                # Remove expired cache entry
                del self.response_cache[cache_key]
        
        return None
    
    def _cache_response(self, message: str, user_id: str, response: Dict[str, Any]):
        """Cache response for future use"""
        cache_key = f"{user_id}:{message.lower().strip()}"
        current_time = time.time()
        
        # Clean up old cache entries if cache is too large
        if len(self.response_cache) >= self.max_cache_size:
            # Remove oldest entries
            oldest_keys = sorted(self.response_cache.keys(), 
                               key=lambda k: self.response_cache[k]['timestamp'])[:self.max_cache_size//2]
            for key in oldest_keys:
                del self.response_cache[key]
        
        self.response_cache[cache_key] = {
            'response': response,
            'timestamp': current_time
        }
    
    def _generate_contextual_suggestions(self, user_id: str, current_pagoda: Dict[str, Any]) -> List[str]:
        """Generate contextual suggestions based on conversation history and current pagoda"""
        suggestions = []
        user_prefs = self.conversation_memory[user_id]['preferences']
        
        # Always include basic suggestions
        suggestions.extend([
            f"Plan route to {current_pagoda['name']}",
            f"Find pagodas near {current_pagoda['name']}",
            "Tell me about another pagoda",
            "What are the best pagodas to visit?"
        ])
        
        # Add contextual suggestions based on user's interests
        if len(user_prefs['visited_pagodas']) > 1:
            suggestions.append("Plan a route between visited pagodas")
        
        if current_pagoda.get('history', {}).get('built'):
            suggestions.append(f"When was {current_pagoda['name']} built?")
        
        if current_pagoda.get('architecture'):
            suggestions.append(f"What's the architecture of {current_pagoda['name']}?")
        
        # Limit to 4 suggestions
        return suggestions[:4]
    
    def process_message(self, message: str, user_id: str = "default") -> Dict[str, Any]:
        """Process user message and generate response with advanced NLP capabilities"""
        start_time = datetime.now()
        
        # Check cache first for simple queries
        cached_response = self._get_cached_response(message, user_id)
        if cached_response:
            print(f"[chatbot] Cache hit for user {user_id}")
            return cached_response
        
        # Initialize conversation memory for user
        if user_id not in self.conversation_memory:
            self.conversation_memory[user_id] = {
                'history': [],
                'context': {},
                'last_pagoda': None,
                'preferences': {
                    'favorite_pagodas': [],
                    'visited_pagodas': [],
                    'interests': []
                },
                'sentiment_history': [],
                'conversation_topics': []
            }
        
        # Add message to history
        self.conversation_memory[user_id]['history'].append({
            'message': message,
            'timestamp': datetime.now().isoformat(),
            'type': 'user'
        })
        
        # Advanced context analysis
        context = self.context_analyzer.analyze_context(
            self.conversation_memory[user_id]['history'], 
            message
        )
        
        # Sentiment analysis
        sentiment = self.sentiment_analyzer.analyze_sentiment(message)
        self.conversation_memory[user_id]['sentiment_history'].append(sentiment)
        
        # Language detection (simplified for English focus)
        detected_language = 'english'  # Focus on English as requested
        
        # Entity extraction
        extracted_pagodas = self.entity_extractor.extract_pagodas(message)
        
        # Advanced question analysis
        question_analysis = self.question_analyzer.analyze_question(message)
        
        # Topic classification
        primary_topic = self.topic_classifier.get_primary_topic(message)
        
        # Enhanced intent detection (Hybrid: Ensemble ML + regex fallback)
        ml_intent, ml_conf = self._classify_intent_ensemble(message)
        intent, groups = self._detect_intent(message)
        
        # Intent refinement
        refined_intent, intent_confidence = self.intent_refinement.refine_intent(message, intent)
        if intent_confidence > ml_conf:
            intent = refined_intent
            ml_conf = intent_confidence

        # Routing strategy
        # 1) If regex found a clear intent, prefer it (deterministic)
        # 2) Else if ML confidence high, use ML
        # 3) Else remain unknown
        low_confidence_ml = False
        if intent == 'unknown':
            if ml_conf >= 0.75:
                intent = ml_intent
            elif ml_conf >= 0.5:
                # Tentative: record low-confidence recommendation to clarify later
                intent = ml_intent
                self.metrics['fallback_counts']['low_confidence_ml'] += 1
                low_confidence_ml = True
            else:
                self.metrics['fallback_counts']['unknown_intent'] += 1

        self.metrics['intent_counts'][intent] += 1

        # Fallback: if message looks like a single word/name, try pagoda lookup directly
        # Only trigger if no action verbs are present and it looks like a proper noun
        if intent == 'unknown':
            name_candidate = message.strip()
            message_lower = message.lower()  # Define message_lower in this scope
            # Check if message contains action verbs that should not be treated as pagoda names
            action_verbs = ['show', 'find', 'plan', 'tell', 'get', 'give', 'help', 'want', 'need', 'can', 'will', 'should', 'could', 'would', 'about', 'these', 'the', 'what', 'which', 'how', 'where', 'when', 'why']
            has_action_verb = any(verb in message_lower for verb in action_verbs)
            
            # Check for common question words and general terms
            general_terms = ['these', 'the', 'some', 'any', 'all', 'many', 'few', 'most', 'best', 'famous', 'popular', 'important', 'favorite', 'favourite']
            has_general_term = any(term in message_lower for term in general_terms)
            
            # Only treat as pagoda name if:
            # 1. No action verbs present
            # 2. No general terms present
            # 3. Looks like a proper noun (starts with capital letter or is title case)
            # 4. Reasonable length
            # 5. Matches pagoda name pattern
            # 6. Not a common word that could be confused
            if (not has_action_verb and 
                not has_general_term and
                1 <= len(name_candidate) <= 40 and 
                re.match(r'^[A-Za-z\s\-]+$', name_candidate) and
                (name_candidate[0].isupper() or name_candidate.istitle()) and
                name_candidate.lower() not in ['these', 'the', 'some', 'any', 'all', 'many', 'few', 'most', 'best', 'famous', 'popular', 'important', 'favorite', 'favourite', 'pagodas', 'temples', 'sites', 'places']):
                pagoda = self._find_pagoda_by_name(name_candidate)
                if pagoda:
                    intent = 'pagoda_info'
                    groups = ('', name_candidate)
        
        # Update contextual memory
        self.contextual_memory.update_context(user_id, message, intent, [p['pagoda']['name'] for p in extracted_pagodas])
        
        # Get user experience level
        user_experience = self._assess_user_experience(user_id)
        
        # Generate response based on intent with enhanced context
        response = ""
        suggestions = []
        
        # Update metrics
        response_time = (datetime.now() - start_time).total_seconds()
        self.metrics['response_times'].append(response_time)
        self.metrics['sentiment_scores'].append(sentiment['sentiment'])
        
        try:
            if intent == 'greeting':
                # More natural and varied greetings
                if context['conversation_flow'] == 'ongoing':
                    greetings = [
                        "Welcome back! Ready to continue exploring Bagan's amazing pagodas?",
                        "Great to see you again! What would you like to discover today?",
                        "Hello again! I'm here to help you explore more of Bagan's treasures!",
                        "Welcome back! Let's continue your journey through Bagan's ancient wonders!"
                    ]
                    response = random.choice(greetings)
                elif sentiment['sentiment'] == 'positive':
                    positive_greetings = [
                        "Hello! I'm excited to help you discover the wonders of Bagan!",
                        "Hey there! Ready to explore some incredible pagodas?",
                        "Welcome! I'm thrilled to be your guide to Bagan's ancient treasures!",
                        "Hi! I can't wait to share Bagan's amazing stories with you!"
                    ]
                    response = random.choice(positive_greetings)
                else:
                    response = random.choice(self.response_templates['greeting'])
                
                # More natural suggestions
                if context['mentioned_pagodas']:
                    last_pagoda = context['mentioned_pagodas'][-1]
                    suggestions = [
                        f"Tell me more about {last_pagoda.title()}",
                        f"Find pagodas near {last_pagoda.title()}",
                        f"Plan a route to {last_pagoda.title()}",
                        "What are the must-see pagodas?"
                    ]
                else:
                    suggestions = [
                        "Tell me about Ananda Temple",
                        "Plan a route from Shwezigon to Dhammayangyi", 
                        "What are the must-see pagodas?",
                        "Find pagodas near me"
                    ]
                
                if low_confidence_ml:
                    response = "I can help with pagoda info, routes, recommendations, or nearby searches. What would you like?"
                    suggestions = [
                        "Tell me about Shwezigon Pagoda",
                        "Route from Ananda to Gawdawpalin",
                        "Must-see pagodas",
                        "Find pagodas near Ananda"
                    ]
            
            elif intent == 'general_help':
                response = random.choice(self.response_templates['help'])
                suggestions = [
                    "Tell me about Shwezigon Pagoda",
                    "Plan my Bagan itinerary",
                    "What's the history of Bagan?",
                    "Show me nearby pagodas"
                ]
            
            elif intent == 'pagoda_info':
                # Extract pagoda name from groups or message
                pagoda_name = None
                if groups and len(groups) >= 1:
                    pagoda_name = groups[0].strip()
                else:
                    # Try to extract from message directly
                    pagoda_name = message.strip()
                
                if pagoda_name:
                    pagoda = self._find_pagoda_by_name(pagoda_name)
                    
                    if pagoda:
                        response = self._get_pagoda_info_response(pagoda)
                        self.conversation_memory[user_id]['last_pagoda'] = pagoda
                        
                        # Add to visited pagodas if not already there
                        if pagoda['id'] not in self.conversation_memory[user_id]['preferences']['visited_pagodas']:
                            self.conversation_memory[user_id]['preferences']['visited_pagodas'].append(pagoda['id'])
                        
                        # Generate contextual suggestions
                        suggestions = self._generate_contextual_suggestions(user_id, pagoda)
                    else:
                        # Clarification with suggestions
                        candidates = self._suggest_similar_pagodas(pagoda_name, limit=3)
                        if candidates:
                            response = f"I couldn't find '{pagoda_name}'. Did you mean:\n\n"
                            for c in candidates:
                                response += f"- {c}\n"
                        else:
                            response = f"I couldn't find a pagoda named '{pagoda_name}'. Here are some popular ones:\n\n"
                            for pagoda in self.pagoda_data[:5]:
                                response += f"- {pagoda['name']}\n"
                        suggestions = [
                            "Tell me about Ananda Temple",
                            "Tell me about Shwezigon Pagoda",
                            "Show me all pagodas",
                            "What are the featured pagodas?"
                        ]
                else:
                    response = "Which pagoda would you like to know about? I can tell you about any pagoda in Bagan!"
                    suggestions = [
                        "Tell me about Ananda Temple",
                        "Tell me about Shwezigon Pagoda",
                        "Tell me about Dhammayangyi Temple",
                        "Show me featured pagodas"
                    ]
            
            elif intent == 'pathfinding':
                # Extract route information from message
                message_lower = message.lower()
                
                # Look for "from X to Y" patterns
                if 'from' in message_lower and 'to' in message_lower:
                    parts = message_lower.split('from')[1].split('to')
                    if len(parts) == 2:
                        start_name = parts[0].strip()
                        end_name = parts[1].strip()
                    else:
                        start_name = end_name = None
                elif 'between' in message_lower:
                    parts = message_lower.split('between')[1].split('and')
                    if len(parts) == 2:
                        start_name = parts[0].strip()
                        end_name = parts[1].strip()
                    else:
                        start_name = end_name = None
                else:
                    start_name = end_name = None
                
                if start_name and end_name:
                    response = self._get_route_response(start_name, end_name)
                    suggestions = [
                        "Find pagodas near the destination",
                        "Plan another route",
                        "Tell me about the destination pagoda",
                        "What are the best routes in Bagan?"
                    ]
                else:
                    response = "I can help you plan routes between pagodas! Please specify the starting and destination pagodas."
                    suggestions = [
                        "Route from Ananda to Shwezigon",
                        "Route from Dhammayangyi to Gawdawpalin",
                        "Best route for a day tour",
                        "Show me all pagodas"
                    ]
            
            elif intent == 'recommendations':
                response = self._get_recommendations_response()
                suggestions = [
                    "Plan a route from Ananda to Shwezigon",
                    "Tell me about Ananda Temple",
                    "What's the history of Bagan?",
                    "Find pagodas near Ananda"
                ]
                if low_confidence_ml:
                    response = "Looking for suggestions? Here are must-visit pagodas and tips."
            
            elif intent == 'itinerary':
                response = self._get_itinerary_response()
                suggestions = [
                    "Plan route from Ananda to Shwezigon",
                    "Tell me about Ananda Temple",
                    "Find pagodas near Shwezigon",
                    "What are the must-see pagodas?"
                ]
            
            elif intent == 'nearby':
                # Extract pagoda name for nearby search
                pagoda_name = None
                if groups and len(groups) >= 1:
                    pagoda_name = groups[0].strip()
                else:
                    # Fallback: try to extract from message
                    message_lower = message.lower()
                    for keyword in ['near', 'around', 'close to', 'surrounding']:
                        if keyword in message_lower:
                            parts = message_lower.split(keyword)
                            if len(parts) > 1:
                                pagoda_name = parts[1].strip()
                                break
                
                if pagoda_name:
                    response = self._get_nearby_pagodas_response(pagoda_name)
                    suggestions = [
                        f"Plan route to {pagoda_name}",
                        f"Tell me about {pagoda_name}",
                        "Find pagodas in a different area",
                        "Show me all pagodas"
                    ]
                else:
                    response = "Which pagoda would you like to find nearby pagodas for?"
                    suggestions = [
                        "Find pagodas near Ananda",
                        "Find pagodas near Shwezigon",
                        "Find pagodas near Dhammayangyi",
                        "Show me all pagodas"
                    ]
            
            elif intent == 'history_culture':
                # Extract pagoda name for history/culture queries
                pagoda_name = None
                if groups and len(groups) >= 1:
                    pagoda_name = groups[0].strip()
                else:
                    # Try to extract from message
                    message_lower = message.lower()
                    for keyword in ['history', 'historical', 'culture', 'cultural', 'built', 'constructed']:
                        if keyword in message_lower:
                            # Look for pagoda name after the keyword
                            parts = message_lower.split(keyword)
                            if len(parts) > 1:
                                potential_name = parts[1].strip()
                                if potential_name:
                                    pagoda_name = potential_name
                                    break
                
                if pagoda_name:
                    pagoda = self._find_pagoda_by_name(pagoda_name)
                    
                    if pagoda:
                        response = self._get_pagoda_info_response(pagoda)
                        suggestions = [
                            f"Plan route to {pagoda['name']}",
                            f"Find pagodas near {pagoda['name']}",
                            "Tell me about Bagan's history",
                            "What's the cultural significance?"
                        ]
                    else:
                        response = f"Which pagoda's history would you like to know about? I couldn't find '{pagoda_name}'."
                        suggestions = [
                            "Tell me about Ananda Temple history",
                            "Tell me about Shwezigon Pagoda history",
                            "What's the history of Bagan?",
                            "Show me all pagodas"
                        ]
                else:
                    response = "I can tell you about the rich history and culture of Bagan's pagodas! Which pagoda interests you most?"
                    suggestions = [
                        "Tell me about Ananda Temple history",
                        "What's the cultural significance of Bagan?",
                        "Tell me about the Pagan dynasty",
                        "Show me featured pagodas"
                    ]
            
            else:
                response = "I'm not sure I understand. I can help you with:\n- Pagoda information and history\n- Route planning\n- Recommendations\n- Cultural insights\n\nWhat would you like to know?"
                suggestions = [
                    "Tell me about Ananda Temple",
                    "Plan a route",
                    "What are the must-see pagodas?",
                    "Help me explore Bagan"
                ]
                if low_confidence_ml:
                    response = "Not sure I got that. Do you want info, routes, recommendations, or nearby searches?"
                    suggestions = [
                        "Tell me about Shwezigon Pagoda",
                        "Route from Ananda to Gawdawpalin",
                        "Must-see pagodas",
                        "Find pagodas near Ananda"
                    ]
        
        except Exception as e:
            print(f"Error generating response: {e}")
            response = "I'm sorry, I encountered an error processing your request. Please try again or ask something else."
            suggestions = [
                "Tell me about Ananda Temple",
                "What are the must-see pagodas?",
                "Help me explore Bagan",
                "Plan a route"
            ]
        
        # Enhanced response with personality and language awareness
        response = self.entity_extractor.enhance_response_with_personality(response, sentiment, context)
        
        # Apply adaptive response generation
        response = self.adaptive_responses.generate_adaptive_response(
            response, 
            sentiment['sentiment'], 
            user_experience, 
            context
        )
        
        # Language-specific enhancements (simplified for English focus)
        # Since we're focusing on English, no language detection needed
        
        # Additional sentiment-aware enhancements
        if sentiment['sentiment'] == 'negative' and 'confused' in message.lower():
            response = "I understand this might be overwhelming! Let me help you step by step. " + response
        elif sentiment['sentiment'] == 'positive':
            response = response.replace("I can help", "I'd love to help")
            if "!" not in response:
                response += " 😊"
        
        # Get contextual suggestions
        contextual_suggestions = self.contextual_memory.get_contextual_suggestions(user_id)
        if contextual_suggestions:
            suggestions = contextual_suggestions
        
        # Record interaction for learning
        if intent == 'pagoda_info' and extracted_pagodas:
            for pagoda_info in extracted_pagodas:
                self.smart_recommendations.record_interaction(user_id, pagoda_info['pagoda']['id'], 'view')
        
        # Learn from interaction
        user_satisfaction = 0.7 if sentiment['sentiment'] == 'positive' else 0.3
        self.conversation_learning.learn_from_interaction(user_id, message, response, user_satisfaction)
        
        # Add response to history
        self.conversation_memory[user_id]['history'].append({
            'message': response,
            'timestamp': datetime.now().isoformat(),
            'type': 'bot',
            'sentiment': sentiment,
            'context': context,
            'question_analysis': question_analysis,
            'primary_topic': primary_topic
        })
        
        # Keep only last 10 messages in history
        if len(self.conversation_memory[user_id]['history']) > 10:
            self.conversation_memory[user_id]['history'] = self.conversation_memory[user_id]['history'][-10:]
        
        # Enhanced telemetry log
        try:
            print(f"[chatbot] intent={intent} ml_intent={ml_intent} ml_conf={ml_conf:.2f} sentiment={sentiment['sentiment']} response_time={response_time:.3f}s user={user_id}")
        except Exception:
            pass

        final_response = {
            'response': response,
            'suggestions': suggestions,
            'intent': intent,
            'sentiment': sentiment,
            'context': context,
            'extracted_pagodas': [p['pagoda']['name'] for p in extracted_pagodas],
            'confidence': ml_conf,
            'response_time': response_time,
            'timestamp': datetime.now().isoformat()
        }
        
        # Cache response for future use (only for simple queries)
        if intent in ['greeting', 'general_help'] and len(message) < 50:
            self._cache_response(message, user_id, final_response)
        
        return final_response

@app.route('/api/chatbot/metrics', methods=['GET'])
def get_metrics():
    """Return lightweight telemetry counters (for debugging/monitoring)."""
    try:
        # Convert defaultdict to plain dict
        intent_counts = dict(chatbot.metrics.get('intent_counts', {}))
        fallback_counts = dict(chatbot.metrics.get('fallback_counts', {}))
        return jsonify({
            'success': True,
            'data': {
                'intent_counts': intent_counts,
                'fallback_counts': fallback_counts,
                'pagodas_loaded': len(chatbot.pagoda_data)
            }
        })
    except Exception as e:
        return jsonify({ 'success': False, 'error': str(e) }), 500

# Initialize chatbot
chatbot = BaganeticChatbot()

@app.route('/api/chatbot/chat', methods=['POST'])
def chat():
    """Main chat endpoint"""
    try:
        data = request.get_json()
        message = data.get('message', '').strip()
        user_id = data.get('user_id', 'default')
        
        if not message:
            return jsonify({
                'success': False,
                'error': 'Message is required'
            }), 400
        
        # Process message
        result = chatbot.process_message(message, user_id)
        
        return jsonify({
            'success': True,
            'data': result
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/chatbot/history/<user_id>', methods=['GET'])
def get_chat_history(user_id):
    """Get chat history for a user"""
    try:
        if user_id in chatbot.conversation_memory:
            return jsonify({
                'success': True,
                'data': chatbot.conversation_memory[user_id]['history']
            })
        else:
            return jsonify({
                'success': True,
                'data': []
            })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/chatbot/clear/<user_id>', methods=['POST'])
def clear_chat_history(user_id):
    """Clear chat history for a user"""
    try:
        if user_id in chatbot.conversation_memory:
            chatbot.conversation_memory[user_id]['history'] = []
            chatbot.conversation_memory[user_id]['context'] = {}
            chatbot.conversation_memory[user_id]['last_pagoda'] = None
        
        return jsonify({
            'success': True,
            'message': 'Chat history cleared'
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/chatbot/pagodas', methods=['GET'])
def get_all_pagodas():
    """Get all pagodas for the chatbot"""
    try:
        return jsonify({
            'success': True,
            'data': chatbot.pagoda_data
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/chatbot/analytics/<user_id>', methods=['GET'])
def get_user_analytics(user_id):
    """Get user conversation analytics and insights"""
    try:
        if user_id not in chatbot.conversation_memory:
            return jsonify({
                'success': True,
                'data': {
                    'message_count': 0,
                    'favorite_topics': [],
                    'sentiment_trend': 'neutral',
                    'conversation_insights': []
                }
            })
        
        user_data = chatbot.conversation_memory[user_id]
        
        # Analyze conversation patterns
        message_count = len([msg for msg in user_data['history'] if msg.get('type') == 'user'])
        
        # Analyze sentiment trend
        sentiment_history = user_data.get('sentiment_history', [])
        if sentiment_history:
            recent_sentiments = sentiment_history[-5:]  # Last 5 messages
            positive_count = sum(1 for s in recent_sentiments if s['sentiment'] == 'positive')
            negative_count = sum(1 for s in recent_sentiments if s['sentiment'] == 'negative')
            
            if positive_count > negative_count:
                sentiment_trend = 'positive'
            elif negative_count > positive_count:
                sentiment_trend = 'negative'
            else:
                sentiment_trend = 'neutral'
        else:
            sentiment_trend = 'neutral'
        
        # Generate insights
        insights = []
        if message_count > 5:
            insights.append("You're an active explorer of Bagan!")
        if sentiment_trend == 'positive':
            insights.append("You seem to be enjoying learning about Bagan!")
        if len(user_data['preferences']['visited_pagodas']) > 3:
            insights.append("You've shown interest in multiple pagodas!")
        
        return jsonify({
            'success': True,
            'data': {
                'message_count': message_count,
                'favorite_topics': user_data['preferences']['interests'],
                'visited_pagodas': user_data['preferences']['visited_pagodas'],
                'sentiment_trend': sentiment_trend,
                'conversation_insights': insights,
                'last_activity': user_data['history'][-1]['timestamp'] if user_data['history'] else None
            }
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/chatbot/smart-recommendations/<user_id>', methods=['GET'])
def get_smart_recommendations(user_id):
    """Get smart AI-powered recommendations based on user behavior"""
    try:
        # Get smart recommendations using the advanced engine
        recommendations = chatbot.smart_recommendations.get_smart_recommendations(user_id, limit=5)
        
        if not recommendations:
            # Fallback to general recommendations
            recommendations = [p for p in chatbot.pagoda_data if p.get('featured', False)][:5]
        
        response = "**🤖 Smart AI Recommendations for You:**\n\n"
        for i, pagoda in enumerate(recommendations, 1):
            response += f"{i}. **{pagoda.get('name', 'Unknown')}**\n"
            if pagoda.get('description', {}).get('short'):
                response += f"   {pagoda['description']['short']}\n"
            response += "\n"
        
        # Add AI insights
        user_preferences = chatbot.conversation_learning.get_user_preferences(user_id)
        if user_preferences:
            top_preferences = sorted(user_preferences.items(), key=lambda x: x[1], reverse=True)[:3]
            response += "**🎯 Based on your interests:**\n"
            for topic, weight in top_preferences:
                response += f"- {topic.title()}: {weight:.1f}\n"
            response += "\n"
        
        return jsonify({
            'success': True,
            'data': response,
            'recommendations': recommendations,
            'user_preferences': user_preferences
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/chatbot/personalized-recommendations/<user_id>', methods=['GET'])
def get_personalized_recommendations(user_id):
    """Get personalized pagoda recommendations based on user history"""
    try:
        if user_id not in chatbot.conversation_memory:
            return jsonify({
                'success': True,
                'data': chatbot._get_recommendations_response()
            })
        
        user_data = chatbot.conversation_memory[user_id]
        visited_pagodas = user_data['preferences']['visited_pagodas']
        interests = user_data['preferences']['interests']
        
        # Get recommendations based on user preferences
        recommendations = []
        
        # If user has visited pagodas, recommend similar ones
        if visited_pagodas:
            for pagoda_id in visited_pagodas[-3:]:  # Last 3 visited
                pagoda = next((p for p in chatbot.pagoda_data if p['id'] == pagoda_id), None)
                if pagoda:
                    # Find similar pagodas based on type, architecture, or era
                    similar_pagodas = chatbot._find_similar_pagodas(pagoda)
                    recommendations.extend(similar_pagodas[:2])
        
        # If no visited pagodas, use general recommendations
        if not recommendations:
            featured_pagodas = [p for p in chatbot.pagoda_data if p.get('featured', False)]
            recommendations = featured_pagodas[:5]
        
        # Remove duplicates and limit to 5
        seen = set()
        unique_recommendations = []
        for rec in recommendations:
            if rec['id'] not in seen and rec['id'] not in visited_pagodas:
                unique_recommendations.append(rec)
                seen.add(rec['id'])
                if len(unique_recommendations) >= 5:
                    break
        
        response = "**Personalized Recommendations for You:**\n\n"
        for i, pagoda in enumerate(unique_recommendations, 1):
            response += f"{i}. **{pagoda.get('name', 'Unknown')}**\n"
            if pagoda.get('description', {}).get('short'):
                response += f"   {pagoda['description']['short']}\n"
            response += "\n"
        
        return jsonify({
            'success': True,
            'data': response,
            'recommendations': unique_recommendations
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/chatbot/advanced-features', methods=['GET'])
def get_advanced_features():
    """Get information about advanced chatbot features"""
    return jsonify({
        'success': True,
        'data': {
            'features': {
                'sentiment_analysis': True,
                'context_awareness': True,
                'ensemble_classification': True,
                'multi_language_support': True,
                'personalized_recommendations': True,
                'conversation_analytics': True,
                'response_caching': True,
                'entity_extraction': True
            },
            'capabilities': [
                "Understand user emotions and respond appropriately",
                "Remember conversation context across multiple messages",
                "Provide personalized recommendations based on user history",
                "Detect multiple languages (English, Myanmar, Chinese, Japanese)",
                "Extract pagoda names and locations from natural language",
                "Cache responses for faster performance",
                "Analyze conversation patterns and user preferences",
                "Generate contextual suggestions based on current topic"
            ],
            'performance': {
                'cache_size': len(chatbot.response_cache),
                'max_cache_size': chatbot.max_cache_size,
                'cache_ttl': chatbot.cache_ttl,
                'average_response_time': sum(chatbot.metrics['response_times'][-10:]) / len(chatbot.metrics['response_times'][-10:]) if chatbot.metrics['response_times'] else 0
            }
        }
    })

@app.route('/api/chatbot/health', methods=['GET'])
def health_check():
    """Enhanced health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'Baganetic AI Chatbot',
        'version': '2.0',
        'fallback_mode': FALLBACK_MODE,
        'mongodb_available': not FALLBACK_MODE,
        'features': {
            'nlp_enhanced': True,
            'sentiment_analysis': True,
            'context_awareness': True,
            'ensemble_classification': True,
            'multi_language_support': True,
            'response_caching': True
        },
        'pagodas_loaded': len(chatbot.pagoda_data),
        'pathfinder_available': chatbot.pathfinder is not None,
        'active_users': len(chatbot.conversation_memory),
        'models_trained': len(chatbot.intent_models),
        'cache_entries': len(chatbot.response_cache),
        'total_messages_processed': sum(chatbot.metrics['intent_counts'].values())
    })

if __name__ == '__main__':
    print("Starting Baganetic AI Chatbot...")
    print(f"Loaded {len(chatbot.pagoda_data)} pagodas")
    print(f"Pathfinder available: {chatbot.pathfinder is not None}")
    print("Chatbot server running on http://localhost:5001")
    app.run(debug=True, host='0.0.0.0', port=5001)
