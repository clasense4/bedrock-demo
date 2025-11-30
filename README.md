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

### Production Deployment

1. **Connect to AWS via CLI**

   Option A - Configure default profile:
   ```bash
   aws configure
   ```

   Option B - Use named profile:
   ```bash
   aws configure --profile your-profile-name
   export AWS_PROFILE=your-profile-name
   ```

2. **Test AWS connection and prepare environment**
   ```bash
   make prod-preparation
   ```

3. **Deploy Bedrock Knowledge Base stack**
   ```bash
   cd infra/bedrock
   terraform init
   terraform apply --auto-approve
   ```

   Wait approximately 5 minutes for the stack to complete.

4. **Sync the Knowledge Base data source**

   Open AWS Console and manually sync the data source:
   https://us-east-1.console.aws.amazon.com/bedrock/home?region=us-east-1#/knowledge-bases

   Wait a few minutes for the sync to complete.

   Optional: Test the knowledge base in the AWS Console dashboard.

5. **Deploy Backend stack**
   ```bash
   cd ../backend
   terraform init
   terraform apply --auto-approve
   ```

   Test the API with curl (use the API Gateway URL from terraform output):
   ```bash
   curl -X POST "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/api/chat" \
     -H "Content-Type: application/json" \
     -d '{"message": "what do you know about axrail?"}'
   ```

6. **Deploy Frontend stack**
   ```bash
   cd ../frontend
   terraform init
   terraform apply --auto-approve
   ```

   Wait approximately 5 minutes for CloudFront to be ready, then deploy the frontend files:
   ```bash
   cd ../..
   make prod-frontend-deploy
   ```

   Open the CloudFront domain URL from the terraform output.

7. **Destroy infrastructure (when needed)**

   Run `terraform destroy --auto-approve` in each directory (frontend, backend, bedrock).

   **Important:** Make sure to delete all S3 objects and versions before destroying.

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
- Terraform (AWS infrastructure)
- Bedrock Knowledge Base
