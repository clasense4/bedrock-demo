import os
import logging
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, validator

from src.backend.services.chat_engine import ChatEngine

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(title="Bedrock Chat API", version="0.1.0")

# Initialize ChatEngine (will be created on first request to handle startup)
chat_engine: ChatEngine = None

# Get frontend URL from environment
FRONTEND_URL = os.getenv("FRONTEND_URL", "*")

# Configure CORS
# In production, FRONTEND_URL should be set to the CloudFront domain
# For development, we allow localhost
if FRONTEND_URL == "*":
    # Allow all origins (useful for development or when using API Gateway CORS)
    origins = ["*"]
else:
    # Allow specific origins
    origins = [
        FRONTEND_URL,
        "http://localhost:8080",  # Local development
        "http://127.0.0.1:8080",  # Alternative localhost
    ]

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=False if FRONTEND_URL == "*" else True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Pydantic models for request/response
class ChatRequest(BaseModel):
    """Request model for chat endpoint"""
    message: str

    @validator('message')
    def message_not_empty(cls, v):
        """Validate that message is not empty"""
        if not v or not v.strip():
            raise ValueError('Message cannot be empty')
        return v.strip()


class ChatResponse(BaseModel):
    """Response model for chat endpoint"""
    reply: str


@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return {"status": "healthy"}


def get_chat_engine() -> ChatEngine:
    """
    Get or create ChatEngine instance (lazy initialization)

    Returns:
        ChatEngine instance

    Raises:
        HTTPException: If ChatEngine initialization fails
    """
    global chat_engine
    if chat_engine is None:
        try:
            logger.info("Initializing ChatEngine...")
            chat_engine = ChatEngine()
            logger.info("ChatEngine initialized successfully")
        except ValueError as e:
            logger.error(f"ChatEngine initialization failed: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Configuration error: {str(e)}"
            )
        except Exception as e:
            logger.error(f"Unexpected error initializing ChatEngine: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail="Failed to initialize chat service"
            )
    return chat_engine


@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Chat endpoint that accepts user messages and returns agent responses

    Args:
        request: ChatRequest containing the user's message

    Returns:
        ChatResponse containing the agent's reply

    Raises:
        HTTPException: 400 for validation errors, 500 if agent fails
    """
    try:
        # Get ChatEngine instance
        engine = get_chat_engine()

        # Process message through Strands Agent
        logger.info(f"Processing chat request: {request.message[:50]}...")
        reply = engine.process_message(request.message)

        return ChatResponse(reply=reply)

    except ValueError as e:
        # Handle validation errors (400 Bad Request)
        logger.warning(f"Validation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

    except HTTPException:
        # Re-raise HTTP exceptions (from get_chat_engine)
        raise

    except Exception as e:
        # Handle agent errors and unexpected errors (500 Internal Server Error)
        logger.error(f"Error processing chat request: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Failed to generate response"
        )
