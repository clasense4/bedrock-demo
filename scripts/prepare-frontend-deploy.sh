#!/bin/bash
set -e

REGION=${1:-us-east-1}

echo "Preparing frontend files for production deployment..."

# Create temporary deployment directory
rm -rf /tmp/frontend-deploy
mkdir -p /tmp/frontend-deploy

# Copy all frontend files to temp directory
cp -r src/frontend/* /tmp/frontend-deploy/

# Get API endpoint from backend info file
if [ -f scripts/prod-backend-info.txt ]; then
    API_ENDPOINT=$(grep "API Endpoint:" scripts/prod-backend-info.txt | cut -d: -f2- | tr -d ' ')

    if [ -n "$API_ENDPOINT" ]; then
        echo "✓ Found API endpoint: $API_ENDPOINT"

        # Update script.js with production API endpoint
        # Replace the API_BASE_URL constant with the production endpoint
        sed -i.bak "s|const API_BASE_URL = window.location.hostname === 'localhost'|// Production API endpoint\nconst API_BASE_URL = window.location.hostname === 'localhost'|g" /tmp/frontend-deploy/script.js
        sed -i.bak "s|    ? 'http://localhost:8000'|    ? 'http://localhost:8000'|g" /tmp/frontend-deploy/script.js
        sed -i.bak "s|    : window.location.origin;|    : '${API_ENDPOINT}';|g" /tmp/frontend-deploy/script.js

        # Remove backup file
        rm -f /tmp/frontend-deploy/script.js.bak

        echo "✓ Updated script.js with production API endpoint"
    else
        echo "⚠ Warning: API endpoint not found in prod-backend-info.txt"
        echo "  Frontend will use window.location.origin as fallback"
    fi
else
    echo "⚠ Warning: prod-backend-info.txt not found"
    echo "  Run 'make prod-backend-bootstrap' first to create backend infrastructure"
    echo "  Frontend will use window.location.origin as fallback"
fi

echo "✓ Frontend files prepared in /tmp/frontend-deploy/"
