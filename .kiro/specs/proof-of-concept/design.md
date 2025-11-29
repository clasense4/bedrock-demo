# Design Document

## Overview

This proof-of-concept implements a minimal chat interface that connects users to an AWS Bedrock-powered agent through a FastAPI backend. The architecture follows a simple client-server pattern with a vanilla JavaScript frontend and a Python FastAPI backend that integrates with AWS Bedrock Knowledge Base via the Strands Agent framework.

The system is designed for rapid development and deployment with two target environments:
- **Local Development**: Docker + Docker Compose
- **Production**: CloudFront + S3 (frontend) and API Gateway + Lambda (backend)

## Architecture

### High-Level Architecture

```
┌─────────────────┐
│   Web Browser   │
│  (Chat UI)      │
└────────┬────────┘
         │ HTTP POST /api/chat
         │ { "message": "..." }
         ▼
┌─────────────────┐
│  FastAPI        │
│  Backend        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Strands Agent   │
│ (AWS Bedrock)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ AWS Bedrock     │
│ Knowledge Base  │
└─────────────────┘
```

### Technology Stack

**Frontend:**
- HTML5 for structure
- Vanilla JavaScript (ES6+) for interactivity
- CSS3 for styling
- LocalStorage API for message persistence

**Backend:**
- Python 3.12+
- FastAPI for REST API
- Strands Agents (v1.18.0) for Bedrock integration
- Boto3 for AWS SDK
- Uvicorn as ASGI server

**Infrastructure:**
- Docker & Docker Compose for local development
- AWS Bedrock for AI agent
- AWS Lambda for serverless backend (production)
- API Gateway for HTTP routing (production)
- S3 + CloudFront for static hosting (production)

### Deployment Environments

**Local Development:**
- Frontend: HTTP server on port 8080
- Backend: Docker container on port 8000
- AWS credentials via environment variables

**Production:**
- Frontend: S3 bucket served via CloudFront
- Backend: Lambda function behind API Gateway
- AWS credentials via IAM roles

## Components and Interfaces

### Frontend Components

#### 1. Chat Interface (index.html)
**Purpose:** Provides the user interface for the chat application

**Structure:**
- Header section displaying Knowledge Base data source URL
- Message log container for conversation history
- Input section with text field and send button
- Thinking indicator for loading states

**Key Elements:**
```html
- #chat-header: Displays "Knowledge Base: https://axrail.ai"
- #message-log: Container for all messages
- #message-input: Text input field
- #send-button: Submit button
- #thinking-indicator: Loading state indicator
```

#### 2. Chat Controller (script.js)
**Purpose:** Manages chat logic, API communication, and UI updates

**Key Functions:**
- `sendMessage()`: Handles message submission
- `displayUserMessage(text)`: Adds user message to UI
- `displayAgentMessage(text)`: Adds agent response to UI
- `displayError(message)`: Shows error messages
- `showThinking()`: Displays loading indicator
- `hideThinking()`: Removes loading indicator
- `saveToLocalStorage()`: Persists conversation
- `loadFromLocalStorage()`: Restores conversation
- `clearInput()`: Resets input field

**API Communication:**
```javascript
POST /api/chat
Content-Type: application/json

Request:
{
  "message": "List Axrail services"
}

Response:
{
  "reply": "Here are the Axrail services..."
}

Error Response:
{
  "detail": "Error message"
}
```

### Backend Components

#### 1. FastAPI Application (fastapi_app.py)
**Purpose:** Main application entry point and HTTP endpoint handler

**Endpoints:**
- `POST /api/chat`: Receives user messages and returns agent responses

**Responsibilities:**
- CORS configuration for cross-origin requests
- Request validation using Pydantic models
- Error handling and HTTP status codes
- Integration with ChatEngine service

**Request/Response Models:**
```python
class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    reply: str
```

#### 2. Chat Engine Service (services/chat_engine.py)
**Purpose:** Encapsulates Strands Agent integration and conversation management

**Key Class: ChatEngine**

**Methods:**
- `__init__(knowledge_base_id, region)`: Initialize with AWS configuration
- `process_message(message: str) -> str`: Send message to agent and return response
- `_create_agent()`: Configure Strands Agent with Bedrock settings
- `_handle_agent_error(error)`: Process agent errors

**Configuration:**
- AWS Region: us-east-1
- Model: AWS Titan (to avoid Cohere costs)
- Knowledge Base ID: Configured via environment variable

#### 3. Lambda Handler (lambda_app.py)
**Purpose:** AWS Lambda entry point for production deployment

**Responsibilities:**
- Adapt Lambda event format to FastAPI request format
- Initialize FastAPI app with Lambda-specific configuration
- Handle Lambda context and logging

### Data Flow

#### Successful Message Flow
1. User types message and clicks Send
2. Frontend displays message immediately (optimistic UI)
3. Frontend shows "Thinking..." indicator
4. Frontend sends POST request to `/api/chat`
5. FastAPI validates request
6. ChatEngine forwards message to Strands Agent
7. Strands Agent queries AWS Bedrock Knowledge Base
8. Agent generates response based on Data Source
9. ChatEngine returns response text
10. FastAPI returns JSON response
11. Frontend displays agent reply
12. Frontend hides "Thinking..." indicator
13. Frontend saves conversation to LocalStorage

#### Error Flow
1. User sends message
2. Frontend displays message and shows "Thinking..."
3. API request fails (timeout, network error, or server error)
4. Frontend catches error
5. Frontend displays: "Oops — the server had a hiccup. Try again!"
6. Frontend hides "Thinking..." indicator
7. User message remains in log
8. User can retry without page reload

## Data Models

### Frontend Data Structures

#### Message Object
```javascript
{
  id: string,           // Unique identifier (timestamp-based)
  role: "user" | "agent", // Message sender
  text: string,         // Message content
  timestamp: number     // Unix timestamp
}
```

#### LocalStorage Schema
```javascript
{
  "chat_history": [
    {
      id: "1234567890",
      role: "user",
      text: "List Axrail services",
      timestamp: 1234567890
    },
    {
      id: "1234567891",
      role: "agent",
      text: "Here are the Axrail services...",
      timestamp: 1234567891
    }
  ]
}
```

### Backend Data Models

#### ChatRequest (Pydantic)
```python
class ChatRequest(BaseModel):
    message: str
    
    @validator('message')
    def message_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError('Message cannot be empty')
        return v.strip()
```

#### ChatResponse (Pydantic)
```python
class ChatResponse(BaseModel):
    reply: str
```

#### Agent Configuration
```python
{
    "knowledge_base_id": str,  # AWS Bedrock KB ID
    "region": "us-east-1",     # AWS region
    "model_id": str,           # AWS Titan model ID
    "max_tokens": int,         # Response length limit
    "temperature": float       # Response randomness (0.0-1.0)
}
```

## Error Handling

### Frontend Error Handling

**Network Errors:**
- Timeout after 30 seconds
- Connection failures
- Display: "Oops — the server had a hiccup. Try again!"

**Validation Errors:**
- Empty message submission prevented at UI level
- No error message shown (button disabled)

**Error Recovery:**
- User message preserved in chat log
- Input field remains functional
- No page reload required

### Backend Error Handling

**Request Validation Errors (400):**
```python
{
  "detail": "Message cannot be empty"
}
```

**Agent Errors (500):**
```python
{
  "detail": "Failed to generate response"
}
```

**AWS Service Errors (500):**
- Bedrock API failures
- Knowledge Base unavailable
- Authentication errors

**Error Logging:**
- All errors logged with context
- AWS CloudWatch integration (production)
- Console logging (development)

## Configuration Management

### Environment Variables

**Backend Configuration:**
```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=<key>
AWS_SECRET_ACCESS_KEY=<secret>
KNOWLEDGE_BASE_ID=<bedrock-kb-id>

# Application Configuration
FRONTEND_URL=http://localhost:8080
API_PORT=8000

# Model Configuration
BEDROCK_MODEL_ID=amazon.titan-text-express-v1
```

**Frontend Configuration:**
```javascript
// config.js or inline
const API_BASE_URL = window.location.hostname === 'localhost' 
  ? 'http://localhost:8000'
  : 'https://api.yourdomain.com';
```

### Docker Configuration

**docker-compose.yml structure:**
- Backend service (FastAPI)
- Frontend service (nginx or Python HTTP server)
- Environment variable injection
- Volume mounts for development
- Port mappings (8000, 8080)

## Testing Strategy

### Frontend Testing

**Manual Testing Focus:**
- UI responsiveness and layout
- Message submission flow
- Optimistic UI behavior
- Error message display
- LocalStorage persistence
- Cross-browser compatibility (Chrome, Firefox, Safari)

**Test Scenarios:**
1. Send message with valid input
2. Attempt to send empty message
3. Receive successful response
4. Handle timeout error
5. Handle network error
6. Refresh page and verify history restored
7. Send multiple messages in sequence

### Backend Testing

**Unit Tests:**
- ChatEngine message processing
- Request validation
- Response formatting
- Error handling

**Integration Tests:**
- FastAPI endpoint behavior
- Strands Agent integration
- AWS Bedrock connectivity (mocked for CI/CD)

**Test Framework:**
- pytest for unit and integration tests
- httpx for API testing
- moto for AWS mocking

**Key Test Cases:**
```python
def test_chat_endpoint_success()
def test_chat_endpoint_empty_message()
def test_chat_endpoint_agent_error()
def test_chat_engine_process_message()
def test_chat_engine_bedrock_integration()
```

### End-to-End Testing

**Manual E2E Scenarios:**
1. Start application locally
2. Open browser to localhost:8080
3. Verify UI loads within 2 seconds
4. Send test message
5. Verify response appears
6. Verify conversation persists after refresh

**Production Smoke Tests:**
1. Deploy to staging environment
2. Test CloudFront URL loads
3. Test API Gateway endpoint responds
4. Verify Lambda logs in CloudWatch
5. Test error scenarios

## Performance Considerations

### Frontend Performance
- Minimal JavaScript bundle (no frameworks)
- CSS loaded inline or as single file
- LocalStorage operations throttled
- Message rendering optimized for large histories

### Backend Performance
- FastAPI async handlers for concurrent requests
- Connection pooling for AWS SDK
- Response streaming for long agent replies (future enhancement)
- Lambda cold start optimization (minimal dependencies)

### Expected Metrics
- Page load: < 2 seconds
- Message display: < 100ms (optimistic UI)
- API response: 2-10 seconds (depends on Bedrock)
- Timeout threshold: 30 seconds

## Security Considerations

### Frontend Security
- Input sanitization before display (XSS prevention)
- HTTPS only in production
- No sensitive data in LocalStorage
- CORS restrictions enforced by backend

### Backend Security
- CORS whitelist for allowed origins
- Request size limits
- Rate limiting (future enhancement)
- AWS IAM roles for Lambda (no hardcoded credentials)
- Input validation via Pydantic

### AWS Security
- IAM role with minimal permissions
- Knowledge Base access restricted
- VPC configuration for Lambda (optional)
- CloudWatch logging enabled

## Deployment Strategy

### Local Development Deployment
```bash
# Build and start services
docker-compose up --build

# Access points
Frontend: http://localhost:8080
Backend: http://localhost:8000
API Docs: http://localhost:8000/docs
```

### Production Deployment

**Frontend Deployment:**
1. Build static files
2. Upload to S3 bucket
3. Invalidate CloudFront cache
4. Verify CloudFront distribution

**Backend Deployment:**
1. Package Lambda function with dependencies
2. Deploy via AWS SAM or Serverless Framework
3. Configure API Gateway integration
4. Set environment variables
5. Test Lambda function
6. Update API Gateway stage

**Deployment Checklist:**
- [ ] Environment variables configured
- [ ] AWS credentials validated
- [ ] Knowledge Base ID verified
- [ ] CORS origins updated
- [ ] CloudFront distribution configured
- [ ] API Gateway endpoint tested
- [ ] Lambda function logs verified

## Future Enhancements

**Phase 2 Considerations:**
- User authentication (AWS Cognito)
- Conversation history in database
- Multi-user support
- Streaming responses (SSE)
- Message editing and deletion
- Export conversation feature
- Mobile-responsive design improvements
- Rate limiting and abuse prevention
- Analytics and usage tracking
- A/B testing framework

## Dependencies and Prerequisites

### AWS Prerequisites
- AWS Account with Bedrock access
- Knowledge Base created and synced
- Web Crawler configured for https://axrail.ai
- IAM user/role with appropriate permissions

### Development Prerequisites
- Python 3.12+
- Docker and Docker Compose
- AWS CLI configured
- Git for version control

### Required AWS Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:RetrieveAndGenerate"
      ],
      "Resource": "*"
    }
  ]
}
```
