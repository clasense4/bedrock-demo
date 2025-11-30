#!/bin/bash
set -e

LAMBDA_NAME=${1:-bedrock-chat-prod-lambda}
API_NAME=${2:-bedrock-chat-prod-api}
STACK_NAME=${3:-bedrock-chat-prod}
REGION=${4:-us-east-1}

ROLE_NAME="${STACK_NAME}-lambda-role"
POLICY_NAME="${STACK_NAME}-bedrock-policy"

echo "=== Starting Backend Resource Destruction ==="
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Delete API Gateway
echo "1. Deleting API Gateway..."
if [ -f scripts/prod-backend-info.txt ]; then
    API_ID=$(grep "API ID:" scripts/prod-backend-info.txt | cut -d: -f2 | tr -d ' ')
    if [ -n "$API_ID" ]; then
        aws apigatewayv2 delete-api --api-id "$API_ID" --region "$REGION" 2>/dev/null || true
        echo "✓ API Gateway deleted: $API_ID"
    else
        echo "⚠ API ID not found in info file"
    fi
else
    # Try to find API by name
    API_ID=$(aws apigatewayv2 get-apis --region "$REGION" --query "Items[?Name=='$API_NAME'].ApiId" --output text)
    if [ -n "$API_ID" ]; then
        aws apigatewayv2 delete-api --api-id "$API_ID" --region "$REGION"
        echo "✓ API Gateway deleted: $API_ID"
    else
        echo "⚠ API Gateway not found: $API_NAME"
    fi
fi

# Delete Lambda function
echo ""
echo "2. Deleting Lambda function..."
if aws lambda get-function --function-name "$LAMBDA_NAME" --region "$REGION" 2>/dev/null; then
    aws lambda delete-function --function-name "$LAMBDA_NAME" --region "$REGION"
    echo "✓ Lambda function deleted: $LAMBDA_NAME"
else
    echo "⚠ Lambda function not found: $LAMBDA_NAME"
fi

# Delete CloudWatch log group
echo ""
echo "3. Deleting CloudWatch logs..."
LOG_GROUP="/aws/lambda/$LAMBDA_NAME"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$REGION" 2>/dev/null | grep -q "$LOG_GROUP"; then
    aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$REGION"
    echo "✓ CloudWatch log group deleted: $LOG_GROUP"
else
    echo "⚠ CloudWatch log group not found: $LOG_GROUP"
fi

# Detach and delete IAM policies
echo ""
echo "4. Deleting IAM role and policies..."

# Check if role exists
if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
    # Detach AWS managed policy
    aws iam detach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
        2>/dev/null || echo "  ⚠ AWSLambdaBasicExecutionRole not attached"

    # Detach custom Bedrock policy
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    if aws iam get-policy --policy-arn "$POLICY_ARN" 2>/dev/null; then
        aws iam detach-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-arn "$POLICY_ARN" \
            2>/dev/null || echo "  ⚠ Bedrock policy not attached"

        # Delete the custom policy
        aws iam delete-policy --policy-arn "$POLICY_ARN"
        echo "✓ IAM policy deleted: $POLICY_NAME"
    else
        echo "  ⚠ Bedrock policy not found: $POLICY_NAME"
    fi

    # Delete the role
    aws iam delete-role --role-name "$ROLE_NAME"
    echo "✓ IAM role deleted: $ROLE_NAME"
else
    echo "⚠ IAM role not found: $ROLE_NAME"
fi

# Clean up local files
echo ""
echo "5. Cleaning up local files..."
if [ -f scripts/prod-backend-info.txt ]; then
    rm scripts/prod-backend-info.txt
    echo "✓ Removed scripts/prod-backend-info.txt"
fi

if [ -f lambda-package.zip ]; then
    rm lambda-package.zip
    echo "✓ Removed lambda-package.zip"
fi

if [ -d lambda-package ]; then
    rm -rf lambda-package
    echo "✓ Removed lambda-package directory"
fi

# Clean up temp files
rm -f /tmp/lambda-*.json /tmp/bedrock-policy.json /tmp/lambda-trust-policy.json 2>/dev/null || true

echo ""
echo "=== Backend Destruction Complete ==="
echo ""
echo "All backend resources have been deleted:"
echo "  ✓ API Gateway"
echo "  ✓ Lambda function"
echo "  ✓ CloudWatch logs"
echo "  ✓ IAM role and policies"
echo "  ✓ Local build artifacts"
echo ""
