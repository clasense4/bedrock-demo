#!/bin/bash
set -e

LAMBDA_NAME=${1:-bedrock-chat-prod-lambda}
STACK_NAME=${2:-bedrock-chat-prod}
REGION=${3:-us-east-1}
ROLE_NAME="${STACK_NAME}-lambda-role"

echo "Creating Lambda function: $LAMBDA_NAME"

# Get role ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Check if Lambda already exists
if aws lambda get-function --function-name "$LAMBDA_NAME" --region "$REGION" 2>/dev/null; then
    echo "✓ Lambda function $LAMBDA_NAME already exists"
    exit 0
fi

# Check if package exists
if [ ! -f lambda-package.zip ]; then
    echo "Error: lambda-package.zip not found. Run 'make prod-backend-build' first"
    exit 1
fi

# Create Lambda function
aws lambda create-function \
    --function-name "$LAMBDA_NAME" \
    --runtime python3.12 \
    --role "$ROLE_ARN" \
    --handler lambda_app.handler \
    --zip-file fileb://lambda-package.zip \
    --timeout 30 \
    --memory-size 512 \
    --region "$REGION" \
    --environment "Variables={
        KNOWLEDGE_BASE_ID=${KNOWLEDGE_BASE_ID:-},
        BEDROCK_MODEL_ID=${BEDROCK_MODEL_ID:-nova-micro-v1:0},
        LOG_LEVEL=INFO
    }" \
    --output json > /tmp/lambda-create.json

echo "✓ Lambda function created"

# Add resource-based policy to allow API Gateway to invoke
aws lambda add-permission \
    --function-name "$LAMBDA_NAME" \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --region "$REGION" \
    --output text > /dev/null 2>&1 || echo "✓ Permission already exists"

FUNCTION_ARN=$(cat /tmp/lambda-create.json | grep -o '"FunctionArn": "[^"]*' | cut -d'"' -f4)
echo "✓ Lambda ARN: $FUNCTION_ARN"
