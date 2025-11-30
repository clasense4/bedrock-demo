// DOM Elements
const messageInput = document.getElementById('message-input');
const sendButton = document.getElementById('send-button');
const messageLog = document.getElementById('message-log');
const thinkingIndicator = document.getElementById('thinking-indicator');

// Configure API base URL for local vs production
// In production, this will be replaced by the deployment script with the actual API Gateway endpoint
const API_BASE_URL = window.location.hostname === 'localhost'
    ? 'http://localhost:8000'
    : (window.API_GATEWAY_ENDPOINT || window.location.origin);

// LocalStorage key for chat history
const CHAT_HISTORY_KEY = 'chat_history';

// Event Listeners
sendButton.addEventListener('click', sendMessage);
messageInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        sendMessage();
    }
});

// Prevent empty message submission by monitoring input
messageInput.addEventListener('input', () => {
    const isEmpty = messageInput.value.trim() === '';
    sendButton.disabled = isEmpty;
});

// Initialize button state
sendButton.disabled = true;

/**
 * Handles message submission
 */
async function sendMessage() {
    const message = messageInput.value.trim();

    // Prevent empty message submission
    if (!message) {
        return;
    }

    // Clear input field after sending
    clearInput();

    // Display user message immediately (optimistic UI)
    displayUserMessage(message);

    // Show thinking indicator
    showThinking();

    try {
        // Create fetch request with 30-second timeout
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 30000);

        const response = await fetch(`${API_BASE_URL}/api/chat`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ message }),
            signal: controller.signal
        });

        clearTimeout(timeoutId);

        // Handle API error responses (4xx, 5xx)
        if (!response.ok) {
            // Try to parse error details from response
            let errorDetail = 'Oops — the server had a hiccup. Try again!';
            try {
                const errorData = await response.json();
                if (errorData.detail) {
                    console.error('API error:', errorData.detail);
                }
            } catch (parseError) {
                // If we can't parse the error response, use default message
                console.error('Failed to parse error response:', parseError);
            }
            throw new Error(errorDetail);
        }

        const data = await response.json();

        // Display agent response
        displayAgentMessage(data.reply);

    } catch (error) {
        // Handle all error types with consistent error message
        // - Timeout errors (AbortError)
        // - Network errors (fetch failures)
        // - API errors (HTTP error responses)

        if (error.name === 'AbortError') {
            // Timeout error
            console.error('Request timeout after 30 seconds');
        } else if (error instanceof TypeError && error.message.includes('fetch')) {
            // Network error (connection failed, DNS lookup failed, etc.)
            console.error('Network error:', error);
        } else {
            // API error or other errors
            console.error('Error:', error);
        }

        // Display consistent error message for all error types
        displayError('Oops — the server had a hiccup. Try again!');
    } finally {
        // Remove thinking indicator
        hideThinking();
    }
}

/**
 * Displays user message in the message log
 * @param {string} text - The user's message text
 * @param {boolean} skipSave - If true, skip saving to LocalStorage (for loading history)
 */
function displayUserMessage(text, skipSave = false) {
    const messageElement = document.createElement('div');
    messageElement.className = 'message user';
    messageElement.textContent = text;
    messageLog.appendChild(messageElement);

    // Scroll to bottom
    messageLog.scrollTop = messageLog.scrollHeight;

    // Save to LocalStorage after each message
    if (!skipSave) {
        saveToLocalStorage('user', text);
    }
}

/**
 * Displays agent message in the message log
 * @param {string} text - The agent's reply text
 * @param {boolean} skipSave - If true, skip saving to LocalStorage (for loading history)
 */
function displayAgentMessage(text, skipSave = false) {
    const messageElement = document.createElement('div');
    messageElement.className = 'message agent';
    messageElement.textContent = text;
    messageLog.appendChild(messageElement);

    // Scroll to bottom
    messageLog.scrollTop = messageLog.scrollHeight;

    // Save to LocalStorage after each message
    if (!skipSave) {
        saveToLocalStorage('agent', text);
    }
}

/**
 * Displays error message in the message log
 * @param {string} message - The error message to display
 */
function displayError(message) {
    const errorElement = document.createElement('div');
    errorElement.className = 'error-message';
    errorElement.textContent = message;
    messageLog.appendChild(errorElement);

    // Scroll to bottom
    messageLog.scrollTop = messageLog.scrollHeight;
}

/**
 * Shows the thinking indicator
 */
function showThinking() {
    thinkingIndicator.classList.add('visible');
}

/**
 * Hides the thinking indicator
 */
function hideThinking() {
    thinkingIndicator.classList.remove('visible');
}

/**
 * Clears the input field and resets button state
 */
function clearInput() {
    messageInput.value = '';
    sendButton.disabled = true;
    messageInput.focus();
}

/**
 * Saves conversation history to LocalStorage
 * @param {string} role - The message role ('user' or 'agent')
 * @param {string} text - The message text
 */
function saveToLocalStorage(role, text) {
    // Retrieve existing history
    let history = [];
    try {
        const stored = localStorage.getItem(CHAT_HISTORY_KEY);
        if (stored) {
            history = JSON.parse(stored);
        }
    } catch (error) {
        console.error('Error reading from LocalStorage:', error);
        history = [];
    }

    // Create new message object
    const message = {
        id: Date.now().toString(),
        role: role,
        text: text,
        timestamp: Date.now()
    };

    // Append to history
    history.push(message);

    // Save back to LocalStorage
    try {
        localStorage.setItem(CHAT_HISTORY_KEY, JSON.stringify(history));
    } catch (error) {
        console.error('Error saving to LocalStorage:', error);
    }
}

/**
 * Loads conversation history from LocalStorage
 * Displays all previous messages in chronological order
 */
function loadFromLocalStorage() {
    try {
        const stored = localStorage.getItem(CHAT_HISTORY_KEY);
        if (!stored) {
            return;
        }

        const history = JSON.parse(stored);

        // Display each message in chronological order
        history.forEach(message => {
            if (message.role === 'user') {
                displayUserMessage(message.text, true);
            } else if (message.role === 'agent') {
                displayAgentMessage(message.text, true);
            }
        });
    } catch (error) {
        console.error('Error loading from LocalStorage:', error);
    }
}

// Initialize: Load conversation history on page load
loadFromLocalStorage();
