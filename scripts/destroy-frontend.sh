#!/bin/bash
set -e

BUCKET_NAME=${1:-bedrock-chat-prod-frontend}
REGION=${2:-us-east-1}

echo "=== Starting Frontend Resource Destruction ==="
echo ""

# Get CloudFront distribution ID from info file
DIST_ID=""

if [ -f scripts/prod-frontend-info.txt ]; then
    DIST_ID=$(grep "Distribution ID:" scripts/prod-frontend-info.txt | cut -d: -f2 | tr -d ' ')
fi

# Delete CloudFront distribution
if [ -n "$DIST_ID" ]; then
    echo "1. Disabling CloudFront distribution..."

    # Get current distribution config
    aws cloudfront get-distribution-config \
        --id "$DIST_ID" \
        --output json > /tmp/cf-config.json 2>/dev/null || {
        echo "⚠ CloudFront distribution not found: $DIST_ID"
        DIST_ID=""
    }

    if [ -n "$DIST_ID" ]; then
        ETAG=$(cat /tmp/cf-config.json | grep -o '"ETag": "[^"]*' | cut -d'"' -f4)

        # Check if already disabled
        ENABLED=$(cat /tmp/cf-config.json | grep -o '"Enabled": [^,]*' | cut -d: -f2 | tr -d ' ')

        if [ "$ENABLED" = "true" ]; then
            # Modify config to disable
            cat /tmp/cf-config.json | \
                jq '.DistributionConfig.Enabled = false | .DistributionConfig' > /tmp/cf-config-disabled.json

            # Update distribution to disable it
            aws cloudfront update-distribution \
                --id "$DIST_ID" \
                --distribution-config file:///tmp/cf-config-disabled.json \
                --if-match "$ETAG" \
                --output json > /tmp/cf-update.json

            echo "✓ CloudFront distribution disabled"
            echo "  Waiting for distribution to be deployed (this may take 10-15 minutes)..."

            # Wait for distribution to be deployed
            aws cloudfront wait distribution-deployed --id "$DIST_ID" 2>/dev/null || {
                echo "  ⚠ Timeout waiting for distribution. You may need to delete it manually later."
                echo "  Command: aws cloudfront delete-distribution --id $DIST_ID --if-match <etag>"
                DIST_ID=""
            }
        else
            echo "✓ CloudFront distribution already disabled"
        fi

        if [ -n "$DIST_ID" ]; then
            # Get new ETag after update
            ETAG=$(aws cloudfront get-distribution --id "$DIST_ID" --query 'ETag' --output text)

            # Delete the distribution
            echo "  Deleting CloudFront distribution..."
            aws cloudfront delete-distribution \
                --id "$DIST_ID" \
                --if-match "$ETAG"

            echo "✓ CloudFront distribution deleted: $DIST_ID"
        fi
    fi
else
    echo "1. ⚠ CloudFront distribution ID not found, skipping..."
fi

# Delete S3 bucket
echo ""
echo "2. Deleting S3 bucket and all contents..."

if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    # Delete all objects and versions
    echo "  Removing all objects from bucket..."
    aws s3 rm "s3://$BUCKET_NAME" --recursive --region "$REGION"

    # Delete all object versions if versioning is enabled
    aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --output json \
        --region "$REGION" 2>/dev/null | \
        jq -r '.Versions[]?, .DeleteMarkers[]? | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
        xargs -I {} aws s3api delete-object --bucket "$BUCKET_NAME" --region "$REGION" {} 2>/dev/null || true

    # Delete the bucket
    aws s3api delete-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION"

    echo "✓ S3 bucket deleted: $BUCKET_NAME"
else
    echo "⚠ S3 bucket not found: $BUCKET_NAME"
fi

# Clean up local files
echo ""
echo "3. Cleaning up local files..."

if [ -f scripts/prod-frontend-info.txt ]; then
    rm scripts/prod-frontend-info.txt
    echo "✓ Removed scripts/prod-frontend-info.txt"
fi

# Clean up temp files
rm -f /tmp/cf-*.json /tmp/s3-*.json 2>/dev/null || true

echo ""
echo "=== Frontend Destruction Complete ==="
echo ""
echo "All frontend resources have been deleted:"
echo "  ✓ CloudFront distribution"
echo "  ✓ S3 bucket and contents"
echo "  ✓ Local info files"
echo ""
echo "Note: CloudFront DNS records may take up to 24 hours to fully propagate."
echo ""
