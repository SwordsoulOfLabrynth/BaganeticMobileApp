/**
 * Baganetic Floating Chatbot Widget
 * A floating chatbot that can be integrated into any page
 */

class FloatingChatbotWidget {
    constructor(options = {}) {
        this.options = {
            position: 'bottom-right', // 'bottom-right', 'bottom-left', 'top-right', 'top-left'
            theme: 'gradient', // 'gradient', 'solid'
            primaryColor: '#667eea',
            secondaryColor: '#764ba2',
            accentColor: '#aa7739',
            apiUrl: 'http://localhost:5000/api/chatbot', // Flask proxy → agent_server on 5001
            ...options
        };
        
        this.userId = this.generateUserId();
        this.isOpen = false;
        this.isInitialized = false;
        
        this.init();
    }

    generateUserId() {
        // Prefer a stable ID derived from the authenticated user if available
        try {
            const getStable = () => {
                const auth = window.authManager;
                const username = (auth && auth.currentUser && (auth.currentUser.username || auth.currentUser.email)) ||
                    localStorage.getItem('username') || localStorage.getItem('userEmail');
                if (!username) return null;
                return 'uid_' + this.hashString(String(username));
            };

            const stable = getStable();
            if (stable) return stable;
        } catch (e) {}

        // Fallback to a persistent anonymous ID
        let userId = localStorage.getItem('baganetic_chatbot_user_id');
        if (!userId) {
            userId = 'user_' + Math.random().toString(36).substr(2, 9);
            localStorage.setItem('baganetic_chatbot_user_id', userId);
        }
        return userId;
    }

    hashString(str) {
        // Simple non-cryptographic hash for stable IDs
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            const chr = str.charCodeAt(i);
            hash = ((hash << 5) - hash) + chr;
            hash |= 0; // Convert to 32bit integer
        }
        return Math.abs(hash).toString(36);
    }

    getStorageKey(base) {
        return `${base}_${this.userId}`;
    }

    init() {
        if (this.isInitialized) return;
        
        // Refresh userId on each init in case login state changed
        this.userId = this.generateUserId();
        this.createWidget();
        this.attachEventListeners();
        this.loadMessagesFromLocal(); // Load from localStorage first
        this.loadChatHistory(); // Then try to load from server
        this.loadChatState();
        this.isInitialized = true;
    }

    createWidget() {
        // Create the floating button
        this.createFloatingButton();
        
        // Create the popup
        this.createPopup();
        
        // Create mobile overlay
        this.createOverlay();
        
        // Add to DOM
        document.body.appendChild(this.floatingButton);
        document.body.appendChild(this.popup);
        document.body.appendChild(this.overlay);
    }

    createFloatingButton() {
        this.floatingButton = document.createElement('div');
        this.floatingButton.className = 'baganetic-chatbot-widget';
        this.floatingButton.innerHTML = `
            <button class="baganetic-chatbot-toggle" id="baganeticChatbotToggle">
                <i class="ri-robot-2-line" id="baganeticChatbotIcon"></i>
                <div class="baganetic-chatbot-badge" id="baganeticChatbotBadge" style="display: none;">1</div>
            </button>
        `;
        
        // Add styles
        this.addStyles();
    }

    createPopup() {
        this.popup = document.createElement('div');
        this.popup.className = 'baganetic-chatbot-popup';
        this.popup.id = 'baganeticChatbotPopup';
        this.popup.innerHTML = `
            <div class="baganetic-chatbot-header">
                <div class="baganetic-chatbot-avatar">
                    <i class="ri-robot-2-line"></i>
                </div>
                <div class="baganetic-chatbot-info">
                    <h3>Baganetic AI</h3>
                    <p>Your Bagan Guide</p>
                </div>
                <div class="baganetic-chatbot-status">
                    <div class="baganetic-status-indicator"></div>
                    <span>Online</span>
                </div>
                <button class="baganetic-chatbot-expand" id="baganeticChatbotExpand" title="Expand">
                    <i class="ri-arrow-up-down-line"></i>
                </button>
                <button class="baganetic-chatbot-clear" id="baganeticChatbotClear" title="Clear chat">
                    <i class="ri-delete-bin-6-line"></i>
                </button>
            </div>
            <div class="baganetic-chatbot-messages" id="baganeticChatbotMessages">
                <div class="baganetic-welcome-message">
                    <h3>🏛️ Welcome!</h3>
                    <p>I'm your AI assistant for exploring Bagan's pagodas. Ask me anything!</p>
                    <div class="baganetic-quick-actions">
                        <div class="baganetic-quick-action" data-message="Tell me about Ananda Temple">
                            <i class="ri-temple-line"></i>
                            <h4>Pagoda Info</h4>
                            <p>Learn about temples</p>
                        </div>
                        <div class="baganetic-quick-action" data-message="Plan a route from Shwezigon to Dhammayangyi">
                            <i class="ri-route-line"></i>
                            <h4>Route Planning</h4>
                            <p>Find best paths</p>
                        </div>
                        <div class="baganetic-quick-action" data-message="What are the must-see pagodas?">
                            <i class="ri-star-line"></i>
                            <h4>Recommendations</h4>
                            <p>Must-see sites</p>
                        </div>
                        <div class="baganetic-quick-action" data-message="Find pagodas near Ananda">
                            <i class="ri-map-pin-line"></i>
                            <h4>Nearby Search</h4>
                            <p>Find nearby</p>
                        </div>
                    </div>
                </div>
            </div>
            <div class="baganetic-chatbot-input">
                <div class="baganetic-input-container">
                    <input type="text" id="baganeticMessageInput" placeholder="Ask about Bagan's pagodas..." autocomplete="off">
                    <div class="baganetic-typing-indicator" id="baganeticTypingIndicator">
                        <span>AI is typing</span>
                        <div class="baganetic-typing-dots">
                            <div class="baganetic-typing-dot"></div>
                            <div class="baganetic-typing-dot"></div>
                            <div class="baganetic-typing-dot"></div>
                        </div>
                    </div>
                </div>
                <button class="baganetic-send-button" id="baganeticSendButton">
                    <i class="ri-send-plane-line"></i>
                </button>
            </div>
        `;
    }

    createOverlay() {
        this.overlay = document.createElement('div');
        this.overlay.className = 'baganetic-chatbot-overlay';
        this.overlay.id = 'baganeticChatbotOverlay';
    }

    addStyles() {
        // CSS is now loaded statically in HTML, so we don't need to load it dynamically
        // This method is kept for compatibility but does nothing
        console.log('Chatbot CSS should be loaded statically in HTML');
    }

    attachEventListeners() {
        // Toggle button
        this.toggleButton = document.getElementById('baganeticChatbotToggle');
        this.toggleButton.addEventListener('click', () => this.toggleChatbot());
        
        // Overlay click to close
        this.overlay.addEventListener('click', () => this.closeChatbot());
        
        // Input events
        this.messageInput = document.getElementById('baganeticMessageInput');
        this.sendButton = document.getElementById('baganeticSendButton');
        
        this.messageInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.sendMessage();
            }
        });

        this.messageInput.addEventListener('input', () => {
            this.sendButton.disabled = this.messageInput.value.trim() === '';
        });

        this.sendButton.addEventListener('click', () => this.sendMessage());

        // Quick actions
        document.querySelectorAll('.baganetic-quick-action').forEach(action => {
            action.addEventListener('click', () => {
                const message = action.getAttribute('data-message');
                this.sendMessage(message);
            });
        });

        // Clear history
        const clearBtn = document.getElementById('baganeticChatbotClear');
        if (clearBtn) {
            clearBtn.addEventListener('click', () => this.clearHistory());
        }

        // Expand toggle
        const expandBtn = document.getElementById('baganeticChatbotExpand');
        if (expandBtn) {
            expandBtn.addEventListener('click', () => this.toggleExpand());
        }

        // Close on escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen) {
                this.closeChatbot();
            }
        });
    }

    toggleExpand() {
        // Toggle expanded class and persist per-user state
        this.popup.classList.toggle('expanded');
        try {
            const key = this.getStorageKey('baganetic_chatbot_ui');
            const ui = JSON.parse(localStorage.getItem(key) || '{}');
            ui.expanded = this.popup.classList.contains('expanded');
            localStorage.setItem(key, JSON.stringify(ui));
        } catch (e) {}
    }

    async clearHistory() {
        // Custom confirmation modal inside the chatbot
        const popup = this.popup;
        const overlay = document.createElement('div');
        overlay.className = 'baganetic-confirm-overlay';
        overlay.innerHTML = `
            <div class="baganetic-confirm-box">
                <div class="baganetic-confirm-header">Clear chat</div>
                <div class="baganetic-confirm-body">This will remove the conversation for this user. Continue?</div>
                <div class="baganetic-confirm-actions">
                    <button class="baganetic-btn secondary" id="baganeticCancelClear">Cancel</button>
                    <button class="baganetic-btn primary" id="baganeticConfirmClear">Clear</button>
                </div>
            </div>`;
        popup.appendChild(overlay);

        const cleanup = () => overlay.remove();

        return new Promise((resolve) => {
            overlay.querySelector('#baganeticCancelClear').onclick = () => {
                cleanup();
                resolve(false);
            };
            overlay.querySelector('#baganeticConfirmClear').onclick = async () => {
                // Clear local messages
                try { localStorage.removeItem(this.getStorageKey('baganetic_chatbot_messages')); } catch (e) {}
                // Clear server history (best-effort)
                try { await fetch(`${this.options.apiUrl}/clear/${this.userId}`, { method: 'POST' }); } catch (e) {}

                // Reset UI
                const messagesContainer = document.getElementById('baganeticChatbotMessages');
                if (messagesContainer) {
                    messagesContainer.innerHTML = this.getWelcomeTemplate();
                    // Rebind quick actions
                    document.querySelectorAll('.baganetic-quick-action').forEach(action => {
                        action.addEventListener('click', () => {
                            const message = action.getAttribute('data-message');
                            this.sendMessage(message);
                        });
                    });
                }
                cleanup();
                resolve(true);
            };
        });
    }

    getWelcomeTemplate() {
        return `
            <div class="baganetic-welcome-message">
                <h3>🏛️ Welcome!</h3>
                <p>I'm your AI assistant for exploring Bagan's pagodas. Ask me anything!</p>
                <div class="baganetic-quick-actions">
                    <div class="baganetic-quick-action" data-message="Tell me about Ananda Temple">
                        <i class="ri-temple-line"></i>
                        <h4>Pagoda Info</h4>
                        <p>Learn about temples</p>
                    </div>
                    <div class="baganetic-quick-action" data-message="Plan a route from Shwezigon to Dhammayangyi">
                        <i class="ri-route-line"></i>
                        <h4>Route Planning</h4>
                        <p>Find best paths</p>
                    </div>
                    <div class="baganetic-quick-action" data-message="What are the must-see pagodas?">
                        <i class="ri-star-line"></i>
                        <h4>Recommendations</h4>
                        <p>Must-see sites</p>
                    </div>
                    <div class="baganetic-quick-action" data-message="Find pagodas near Ananda">
                        <i class="ri-map-pin-line"></i>
                        <h4>Nearby Search</h4>
                        <p>Find nearby</p>
                    </div>
                </div>
            </div>`;
    }

    toggleChatbot() {
        if (this.isOpen) {
            this.closeChatbot();
        } else {
            this.openChatbot();
        }
    }

    openChatbot() {
        this.isOpen = true;
        this.popup.classList.add('active');
        this.overlay.classList.add('active');
        this.toggleButton.classList.add('active');
        this.toggleButton.querySelector('i').className = 'ri-close-line';
        this.toggleButton.querySelector('.baganetic-chatbot-badge').style.display = 'none';
        this.messageInput.focus();
        
        // Save state
        this.saveChatState();
        
        // Scroll to bottom
        setTimeout(() => this.scrollToBottom(), 100);
    }

    closeChatbot() {
        this.isOpen = false;
        this.popup.classList.remove('active');
        this.overlay.classList.remove('active');
        this.toggleButton.classList.remove('active');
        this.toggleButton.querySelector('i').className = 'ri-robot-2-line';
        
        // Save state
        this.saveChatState();
    }

    async sendMessage(message = null) {
        const messageText = message || this.messageInput.value.trim();
        
        if (!messageText) return;

        // Clear input
        this.messageInput.value = '';
        this.sendButton.disabled = true;

        // Add user message
        this.addMessage(messageText, 'user');

        // Show typing indicator
        this.showTypingIndicator();

        try {
            const response = await fetch(`${this.options.apiUrl}/chat`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    message: messageText,
                    user_id: this.userId
                })
            });

            const data = await response.json();

            if (data.success) {
                this.hideTypingIndicator();
                // Render text
                this.addMessage(data.data.response, 'bot', data.data.suggestions);
                // Handle actions from agent
                try {
                    if (data.data.actions && Array.isArray(data.data.actions)) {
                        this.consumeActions(data.data.actions);
                    }
                } catch (e) { console.warn('Failed to consume actions', e); }
            } else {
                this.hideTypingIndicator();
                this.addErrorMessage(data.error || 'Something went wrong. Please try again.');
            }
        } catch (error) {
            this.hideTypingIndicator();
            this.addErrorMessage('Unable to connect to the chatbot. Please check if the server is running.');
            console.error('Chatbot error:', error);
        }
    }

    consumeActions(actions) {
        // Handle structured actions from the agent
        actions.forEach(action => {
            if (!action || !action.type) return;
            if (action.type === 'focus') {
                const payload = action.payload || {};
                // Emit a DOM event that map page can listen to
                const event = new CustomEvent('baganetic:map:focus', { detail: payload });
                window.dispatchEvent(event);
            } else if (action.type === 'show_pagoda') {
                const payload = action.payload || {};
                const event = new CustomEvent('baganetic:pagoda:show', { detail: payload });
                window.dispatchEvent(event);
            } else if (action.type === 'route_summary') {
                const payload = action.payload || {};
                const event = new CustomEvent('baganetic:route:show', { detail: payload });
                window.dispatchEvent(event);
            }
        });
    }

    addMessage(message, sender, suggestions = []) {
        const messagesContainer = document.getElementById('baganeticChatbotMessages');
        const messageDiv = document.createElement('div');
        messageDiv.className = `baganetic-message ${sender}`;

        const avatar = document.createElement('div');
        avatar.className = 'baganetic-message-avatar';
        avatar.innerHTML = sender === 'user' ? '<i class="ri-user-line"></i>' : '<i class="ri-robot-2-line"></i>';

        const content = document.createElement('div');
        content.className = 'baganetic-message-content';

        // Format message with markdown-like syntax
        const formattedMessage = this.formatMessage(message);
        content.innerHTML = formattedMessage;

        // Add suggestions if provided
        if (suggestions && suggestions.length > 0) {
            const suggestionsDiv = document.createElement('div');
            suggestionsDiv.className = 'baganetic-suggestions';
            
            suggestions.forEach(suggestion => {
                const suggestionButton = document.createElement('div');
                suggestionButton.className = 'baganetic-suggestion';
                suggestionButton.textContent = suggestion;
                suggestionButton.onclick = () => this.sendMessage(suggestion);
                suggestionsDiv.appendChild(suggestionButton);
            });
            
            content.appendChild(suggestionsDiv);
        }

        messageDiv.appendChild(avatar);
        messageDiv.appendChild(content);

        // Remove welcome message if it exists
        const welcomeMessage = messagesContainer.querySelector('.baganetic-welcome-message');
        if (welcomeMessage) {
            welcomeMessage.remove();
        }

        messagesContainer.appendChild(messageDiv);
        
        // Save message to localStorage for persistence
        this.saveMessageToLocal(message, sender);
        
        this.scrollToBottom();
    }

    formatMessage(message) {
        // Convert markdown-like syntax to HTML
        let formatted = message
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            .replace(/\*(.*?)\*/g, '<em>$1</em>')
            .replace(/\n/g, '<br>')
            .replace(/• /g, '&bull; ');

        // Convert numbered lists
        formatted = formatted.replace(/(\d+)\. /g, '<strong>$1.</strong> ');

        return formatted;
    }

    addErrorMessage(error) {
        const messagesContainer = document.getElementById('baganeticChatbotMessages');
        const errorDiv = document.createElement('div');
        errorDiv.className = 'baganetic-error-message';
        errorDiv.textContent = error;
        messagesContainer.appendChild(errorDiv);
        this.scrollToBottom();
    }

    showTypingIndicator() {
        const typingIndicator = document.getElementById('baganeticTypingIndicator');
        typingIndicator.style.display = 'flex';
        this.scrollToBottom();
    }

    hideTypingIndicator() {
        const typingIndicator = document.getElementById('baganeticTypingIndicator');
        typingIndicator.style.display = 'none';
    }

    scrollToBottom() {
        const messagesContainer = document.getElementById('baganeticChatbotMessages');
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }

    async loadChatHistory() {
        try {
            const response = await fetch(`${this.options.apiUrl}/history/${this.userId}`);
            const data = await response.json();

            if (data.success && data.data.length > 0) {
                const messagesContainer = document.getElementById('baganeticChatbotMessages');
                // Clear welcome message
                const welcomeMessage = messagesContainer.querySelector('.baganetic-welcome-message');
                if (welcomeMessage) {
                    welcomeMessage.remove();
                }

                // Load chat history
                data.data.forEach(msg => {
                    if (msg.type === 'user') {
                        this.addMessage(msg.message, 'user');
                    } else if (msg.type === 'bot') {
                        this.addMessage(msg.message, 'bot');
                    }
                });
            }
        } catch (error) {
            console.error('Error loading chat history:', error);
        }
    }

    showNotification() {
        if (!this.isOpen) {
            const badge = document.getElementById('baganeticChatbotBadge');
            badge.style.display = 'flex';
        }
    }

    saveChatState() {
        // Save current chat state to localStorage (per-user)
        const chatState = {
            isOpen: this.isOpen,
            lastMessage: this.getLastMessage(),
            timestamp: Date.now()
        };
        localStorage.setItem(this.getStorageKey('baganetic_chatbot_state'), JSON.stringify(chatState));
    }

    loadChatState() {
        // Load chat state from localStorage (per-user)
        try {
            const savedState = localStorage.getItem(this.getStorageKey('baganetic_chatbot_state'));
            // Backward-compatibility: migrate legacy key if present and per-user missing
            if (!savedState) {
                const legacy = localStorage.getItem('baganetic_chatbot_state');
                if (legacy) {
                    localStorage.setItem(this.getStorageKey('baganetic_chatbot_state'), legacy);
                }
            }
            if (savedState) {
                const chatState = JSON.parse(savedState);
                // Restore open state if it was open recently (within 5 minutes)
                if (chatState.isOpen && (Date.now() - chatState.timestamp) < 5 * 60 * 1000) {
                    setTimeout(() => this.openChatbot(), 100);
                }
            }
        } catch (error) {
            console.error('Error loading chat state:', error);
        }
        // Restore expanded UI preference
        try {
            const key = this.getStorageKey('baganetic_chatbot_ui');
            const ui = JSON.parse(localStorage.getItem(key) || '{}');
            if (ui.expanded) {
                this.popup.classList.add('expanded');
            }
        } catch (e) {}
    }

    getLastMessage() {
        const messagesContainer = document.getElementById('baganeticChatbotMessages');
        if (messagesContainer) {
            const lastMessage = messagesContainer.querySelector('.baganetic-message:last-child');
            if (lastMessage) {
                const content = lastMessage.querySelector('.baganetic-message-content');
                return content ? content.textContent.trim() : '';
            }
        }
        return '';
    }

    saveMessageToLocal(message, sender) {
        // Save message to localStorage for persistence (per-user)
        const key = this.getStorageKey('baganetic_chatbot_messages');
        const messages = JSON.parse(localStorage.getItem(key) || '[]');
        messages.push({
            message: message,
            sender: sender,
            timestamp: Date.now()
        });
        
        // Keep only last 50 messages
        if (messages.length > 50) {
            messages.splice(0, messages.length - 50);
        }
        
        localStorage.setItem(key, JSON.stringify(messages));
    }

    loadMessagesFromLocal() {
        // Load messages from localStorage (per-user)
        try {
            const key = this.getStorageKey('baganetic_chatbot_messages');
            let messages = JSON.parse(localStorage.getItem(key) || '[]');
            // Backward-compatibility: if no per-user messages, try legacy and migrate
            if (messages.length === 0) {
                const legacy = JSON.parse(localStorage.getItem('baganetic_chatbot_messages') || '[]');
                if (legacy.length > 0) {
                    messages = legacy;
                    localStorage.setItem(key, JSON.stringify(messages));
                }
            }
            const messagesContainer = document.getElementById('baganeticChatbotMessages');
            
            if (messages.length > 0 && messagesContainer) {
                // Clear welcome message
                const welcomeMessage = messagesContainer.querySelector('.baganetic-welcome-message');
                if (welcomeMessage) {
                    welcomeMessage.remove();
                }

                // Add messages from localStorage
                messages.forEach(msg => {
                    this.addMessage(msg.message, msg.sender);
                });
            }
        } catch (error) {
            console.error('Error loading messages from localStorage:', error);
        }
    }

    destroy() {
        if (this.floatingButton) this.floatingButton.remove();
        if (this.popup) this.popup.remove();
        if (this.overlay) this.overlay.remove();
        // Don't remove CSS since it's now loaded statically in HTML
        this.isInitialized = false;
    }
}

// Function to initialize chatbot
function initializeChatbot() {
    // Prevent multiple initializations
    if (window.__chatbotInitializing) {
        console.log('Chatbot initialization already in progress, skipping');
        return;
    }
    
    window.__chatbotInitializing = true;
    
    // Check if user is authenticated by looking at localStorage token
    const token = localStorage.getItem('authToken');
    const isAuthenticated = !!token;
    
    // Also check auth manager if available
    const authManagerAuthenticated = window.authManager && window.authManager.isAuthenticated;
    
    // Additional check for userLoggedIn flag
    const userLoggedIn = localStorage.getItem('userLoggedIn') === 'true';
    
    console.log('Initializing chatbot:', {
        hasToken: isAuthenticated,
        authManagerAuthenticated: authManagerAuthenticated,
        userLoggedIn: userLoggedIn,
        existingChatbot: !!window.baganeticChatbot,
        existingWidget: !!document.querySelector('.baganetic-chatbot-widget')
    });
    
    // Show chatbot if any authentication method indicates user is logged in
    if (isAuthenticated || authManagerAuthenticated || userLoggedIn) {
        // Check if chatbot already exists (from previous page)
        if (window.baganeticChatbot) {
            // Reinitialize DOM elements for new page
            console.log('Reinitializing existing chatbot');
            window.baganeticChatbot.init();
        } else if (!document.querySelector('.baganetic-chatbot-widget')) {
            // Create new instance if none exists
            console.log('Creating new chatbot instance');
            window.baganeticChatbot = new FloatingChatbotWidget();
        }
    } else {
        // Remove chatbot if user is not logged in
        if (window.baganeticChatbot) {
            console.log('Removing chatbot - user not authenticated');
            window.baganeticChatbot.destroy();
            window.baganeticChatbot = null;
        }
    }
    
    // Reset the flag after a delay
    setTimeout(() => {
        window.__chatbotInitializing = false;
    }, 1000);
}

// Initialize chatbot immediately if DOM is already ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeChatbot);
    } else {
    // DOM is already ready, initialize immediately
    // New agent is now default
    initializeChatbot();
}

// Auto-initialize when DOM is ready (fallback)
document.addEventListener('DOMContentLoaded', () => {
    // Wait for other scripts to finish loading
    setTimeout(() => {
        initializeChatbot();
    }, 1000); // Reduced delay for faster appearance
    
    // Fallback: if auth manager doesn't load within 3 seconds, check token and show chatbot if authenticated
    setTimeout(() => {
        const token = localStorage.getItem('authToken');
        const userLoggedIn = localStorage.getItem('userLoggedIn') === 'true';
        if ((token || userLoggedIn) && !window.baganeticChatbot) {
            console.log('Auth manager not loaded, but user appears authenticated - showing chatbot as fallback');
            window.baganeticChatbot = new FloatingChatbotWidget();
        }
    }, 3000);
    
    // Listen for authentication state changes
    if (window.authManager) {
        // Override the original methods to trigger chatbot updates
        const originalLogin = window.authManager.handleSuccessfulLogin;
        const originalLogout = window.authManager.logout;
        
        if (originalLogin) {
            window.authManager.handleSuccessfulLogin = function(userData, token) {
                originalLogin.call(this, userData, token);
                // Show chatbot after successful login
                setTimeout(initializeChatbot, 100);
            };
        }
        
        if (originalLogout) {
            window.authManager.logout = function() {
                originalLogout.call(this);
                // Hide chatbot after logout
                setTimeout(initializeChatbot, 100);
            };
        }
    }
});

// Additional fallback on window load
window.addEventListener('load', () => {
    const token = localStorage.getItem('authToken');
    const userLoggedIn = localStorage.getItem('userLoggedIn') === 'true';
    if ((token || userLoggedIn) && !window.baganeticChatbot) {
        console.log('Window loaded, user appears authenticated - initializing chatbot');
        window.baganeticChatbot = new FloatingChatbotWidget();
    }
});

// Export for manual initialization
window.FloatingChatbotWidget = FloatingChatbotWidget;
