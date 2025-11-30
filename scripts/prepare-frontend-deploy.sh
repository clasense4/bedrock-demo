#!/bin/bash
set -e

REGION=${1:-us-east-1}

echo "Preparing frontend files for production deployment..."

# Create temporary deployment directory
rm -rf /tmp/frontend-deploy
mkdir -p /tmp/frontend-deploy

# Copy all frontend files to temp directory
cp -r src/frontend/* /tmp/frontend-deploy/

# Try to get API endpoint from Terraform backend outputs first
API_ENDPOINT=""

if [ -d "infra/backend" ] && [ -f "infra/backend/terraform.tfstate" ]; then
    echo "Reading API endpoint from Terraform backend state..."
    API_ENDPOINT=$(cd infra/backend && terraform output -raw api_gateway_endpoint 2>/dev/null || echo "")

    if [ -n "$API_ENDPOINT" ]; then
        echo "✓ Found API endpoint from Terraform: $API_ENDPOINT"
    fi
fi

# Fallback to legacy prod-backend-info.txt if Terraform output not available
if [ -z "$API_ENDPOINT" ] && [ -f scripts/prod-backend-info.txt ]; then
    echo "Falling back to prod-backend-info.txt..."
    API_ENDPOINT=$(grep "API Endpoint:" scripts/prod-backend-info.txt | cut -d: -f2- | tr -d ' ')

    if [ -n "$API_ENDPOINT" ]; then
        echo "✓ Found API endpoint from info file: $API_ENDPOINT"
    fi
fi

# Update script.js with production API endpoint
if [ -n "$API_ENDPOINT" ]; then
    # Replace the API_BASE_URL constant with the production endpoint
    # Use @ as delimiter to avoid conflicts with special characters
    sed -i.bak "s@(window\.API_GATEWAY_ENDPOINT || window\.location\.origin)@'${API_ENDPOINT}'@g" /tmp/frontend-deploy/script.js

    # Remove backup file
    rm -f /tmp/frontend-deploy/script.js.bak

    echo "✓ Updated script.js with production API endpoint"
else
    echo "⚠ Warning: API endpoint not found"
    echo "  Checked:"
    echo "    - infra/backend/terraform.tfstate"
    echo "  Frontend will use window.location.origin as fallback"
fi

echo "✓ Frontend files prepared in /tmp/frontend-deploy/"
