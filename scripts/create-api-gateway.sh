#!/bin/bash
set -e

API_NAME=${1:-bedrock-chat-prod-api}
LAMBDA_NAME=${2:-bedrock-chat-prod-lambda}
REGION=${3:-us-east-1}

echo "Creating API Gateway: $API_NAME"

# Check if API already exists
EXISTING_API_ID=$(aws apigatewayv2 get-apis --region "$REGION" --query "Items[?Name=='$API_NAME'].ApiId" --output text)

if [ -n "$EXISTING_API_ID" ]; then
    echo "✓ API Gateway $API_NAME already exists (ID: $EXISTING_API_ID)"
    API_ID=$EXISTING_API_ID
else
    # Create HTTP API with CORS configuration
    API_ID=$(aws apigatewayv2 create-api \
        --name "$API_NAME" \
        --protocol-type HTTP \
        --cors-configuration '{
            "AllowOrigins": ["*"],
            "AllowMethods": ["GET", "POST", "OPTIONS"],
            "AllowHeaders": ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token"],
            "MaxAge": 300,
            "AllowCredentials": false
        }' \
        --region "$REGION" \
        --query 'ApiId' \
        --output text)

    echo "✓ API created with ID: $API_ID"
fi

# Update CORS configuration if API already exists
echo "Updating CORS configuration..."
aws apigatewayv2 update-api \
    --api-id "$API_ID" \
    --cors-configuration '{
        "AllowOrigins": ["*"],
        "AllowMethods": ["GET", "POST", "OPTIONS"],
        "AllowHeaders": ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token"],
        "MaxAge": 300,
        "AllowCredentials": false
    }' \
    --region "$REGION" \
    --output text > /dev/null

echo "✓ CORS configuration updated"

# Get Lambda ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${LAMBDA_NAME}"

# Create integration
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$LAMBDA_ARN" \
    --payload-format-version 2.0 \
    --region "$REGION" \
    --query 'IntegrationId' \
    --output text)

echo "✓ Integration created: $INTEGRATION_ID"

# Create routes
# POST /api/chat
aws apigatewayv2 create-route \
    --api-id "$API_ID" \
    --route-key "POST /api/chat" \
    --target "integrations/$INTEGRATION_ID" \
    --region "$REGION" \
    --output text > /dev/null

echo "✓ Route created: POST /api/chat"

# GET /health
aws apigatewayv2 create-route \
    --api-id "$API_ID" \
    --route-key "GET /health" \
    --target "integrations/$INTEGRATION_ID" \
    --region "$REGION" \
    --output text > /dev/null

echo "✓ Route created: GET /health"

# Create default stage
STAGE_NAME='$default'
aws apigatewayv2 create-stage \
    --api-id "$API_ID" \
    --stage-name "$STAGE_NAME" \
    --auto-deploy \
    --region "$REGION" \
    --output text > /dev/null 2>&1 || echo "✓ Stage already exists"

# Get API endpoint
API_ENDPOINT=$(aws apigatewayv2 get-api --api-id "$API_ID" --region "$REGION" --query 'ApiEndpoint' --output text)

echo ""
echo "=== API Gateway Setup Complete ==="
echo "API ID: $API_ID"
echo "API Endpoint: $API_ENDPOINT"
echo ""
echo "Test endpoints:"
echo "  Health: $API_ENDPOINT/health"
echo "  Chat:   $API_ENDPOINT/api/chat"
echo ""

# Save info to file
mkdir -p scripts
cat > scripts/prod-backend-info.txt <<EOF
API Gateway Information
=======================
API ID: $API_ID
API Name: $API_NAME
API Endpoint: $API_ENDPOINT
Lambda Function: $LAMBDA_NAME
Region: $REGION

Endpoints:
  Health Check: $API_ENDPOINT/health
  Chat API: $API_ENDPOINT/api/chat

Created: $(date)
EOF

echo "✓ Info saved to scripts/prod-backend-info.txt"
