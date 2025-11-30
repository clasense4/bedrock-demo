# Bedrock Chat Application

A minimal chat interface powered by AWS Bedrock Knowledge Base, built with FastAPI and vanilla JavaScript.

## Features

- Simple chat interface with conversation history
- AWS Bedrock Knowledge Base integration
- Optimistic UI for instant feedback
- Local storage for conversation persistence
- Docker support for local development
- AWS Lambda + API Gateway deployment for backend
- S3 + CloudFront deployment for frontend

## Quick Start

### Local Development

1. Copy environment variables:
```bash
cp .env.example .env
```

2. Configure your AWS credentials and Knowledge Base ID in `.env`

3. Start the application:
```bash
make up
```

4. Access the application:
   - Frontend: http://localhost:8080
   - Backend API: http://localhost:8000
   - API Docs: http://localhost:8000/docs

## Deployment

### Backend Deployment (Lambda + API Gateway)

See [LAMBDA_DEPLOYMENT.md](LAMBDA_DEPLOYMENT.md) for detailed instructions.

Quick commands:
```bash
# Create Lambda deployment package
make lambda-package

# Deploy using AWS CLI or Console
# See LAMBDA_DEPLOYMENT.md for full instructions
```

### Frontend Deployment (S3 + CloudFront)

See [FRONTEND_DEPLOYMENT.md](FRONTEND_DEPLOYMENT.md) for detailed instructions.

Quick commands:
```bash
# Create S3 bucket and configure for static hosting
make s3-create

# Deploy frontend files to S3
make s3-deploy

# Create CloudFront distribution
make cf-create

# Full deployment (after initial setup)
make deploy-frontend CLOUDFRONT_DIST_ID=YOUR_DIST_ID
```

## Available Commands

Run `make help` to see all available commands:

```bash
# Local development
make build          # Build Docker containers
make up             # Start the application
make down           # Stop the application
make logs           # View application logs
make clean          # Remove containers and volumes

# Backend deployment
make lambda-package # Create Lambda deployment package
make lambda-clean   # Remove Lambda build artifacts

# Frontend deployment
make s3-create      # Create S3 bucket for static hosting
make s3-deploy      # Deploy frontend to S3
make cf-create      # Create CloudFront distribution
make cf-invalidate  # Invalidate CloudFront cache
make deploy-frontend # Full frontend deployment
```

## Architecture

```
┌─────────────────┐
│   Web Browser   │
│  (Chat UI)      │
└────────┬────────┘
         │ HTTP POST /api/chat
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

## Technology Stack

**Frontend:**
- HTML5, CSS3, Vanilla JavaScript
- LocalStorage for persistence

**Backend:**
- Python 3.12+
- FastAPI
- Strands Agents (AWS Bedrock integration)
- Boto3

**Infrastructure:**
- Docker & Docker Compose (local)
- AWS Lambda + API Gateway (backend)
- S3 + CloudFront (frontend)


## Development

### Project Structure

```
.
├── src/
│   ├── backend/
│   │   ├── fastapi_app.py      # FastAPI application
│   │   ├── lambda_app.py       # Lambda handler
│   │   └── services/
│   │       └── chat_engine.py  # Bedrock integration
│   └── frontend/
│       ├── index.html          # Chat interface
│       └── script.js           # Frontend logic
├── docker-compose.yml          # Local development setup
├── Dockerfile                  # Backend container
├── Dockerfile.frontend         # Frontend container
├── Makefile                    # Build and deployment commands
└── requirements.txt            # Python dependencies
```

## License

MIT

## Support

For issues or questions, please refer to the documentation or create an issue in the repository.
