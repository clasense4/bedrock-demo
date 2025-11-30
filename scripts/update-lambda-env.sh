#!/bin/bash
set -e

LAMBDA_NAME=${1:-bedrock-chat-prod-lambda}
REGION=${2:-us-east-1}

echo "Updating Lambda environment variables..."

# Load environment variables from .env.prod if it exists
if [ -f .env.prod ]; then
    echo "Loading environment variables from .env.prod file..."
    set -a  # automatically export all variables
    source .env.prod
    set +a
    echo "✓ Loaded .env.prod file"
else
    echo "⚠ Warning: .env.prod file not found"
    echo "  Create .env.prod from .env.prod.example"
fi

# Get CloudFront URL if available
FRONTEND_URL=""
if [ -f scripts/prod-frontend-info.txt ]; then
    FRONTEND_URL=$(grep "CloudFront URL:" scripts/prod-frontend-info.txt | cut -d: -f2- | tr -d ' ')
fi

# Check if KNOWLEDGE_BASE_ID is set
if [ -z "$KNOWLEDGE_BASE_ID" ]; then
    echo ""
    echo "⚠ ERROR: KNOWLEDGE_BASE_ID is not set!"
    echo ""
    echo "Please set KNOWLEDGE_BASE_ID in one of these ways:"
    echo "  1. Add to .env file: KNOWLEDGE_BASE_ID=your-kb-id"
    echo "  2. Export in shell: export KNOWLEDGE_BASE_ID=your-kb-id"
    echo "  3. Pass as argument: KNOWLEDGE_BASE_ID=your-kb-id make prod-backend-deploy"
    echo ""
    exit 1
fi

# Update Lambda environment
aws lambda update-function-configuration \
    --function-name "$LAMBDA_NAME" \
    --environment "Variables={
        KNOWLEDGE_BASE_ID=$KNOWLEDGE_BASE_ID,
        BEDROCK_MODEL_ID=${BEDROCK_MODEL_ID:-nova-micro-v1:0},
        FRONTEND_URL=${FRONTEND_URL:-*},
        LOG_LEVEL=${LOG_LEVEL:-INFO}
    }" \
    --region "$REGION" \
    --output text > /dev/null

echo ""
echo "✓ Environment variables updated"
echo "  AWS_REGION: $REGION"
echo "  KNOWLEDGE_BASE_ID: $KNOWLEDGE_BASE_ID"
echo "  BEDROCK_MODEL_ID: ${BEDROCK_MODEL_ID:-nova-micro-v1:0}"
echo "  FRONTEND_URL: ${FRONTEND_URL:-*}"
echo "  LOG_LEVEL: ${LOG_LEVEL:-INFO}"
