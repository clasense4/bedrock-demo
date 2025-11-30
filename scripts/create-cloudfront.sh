#!/bin/bash
set -euo pipefail

BUCKET_NAME=${1:-bedrock-chat-prod-frontend}
REGION=${2:-us-east-1}

echo "Creating CloudFront distribution for bucket: $BUCKET_NAME"

CALLER_REF="bedrock-chat-$(date +%s)"

# Determine S3 website endpoint
if [ "$REGION" = "us-east-1" ]; then
    S3_WEBSITE_ENDPOINT="${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"
else
    S3_WEBSITE_ENDPOINT="${BUCKET_NAME}.s3-website.${REGION}.amazonaws.com"
fi

echo "Using S3 website endpoint: $S3_WEBSITE_ENDPOINT"

# --- Create CloudFront Distribution Config ---
echo "Creating CloudFront config file..."

cat > /tmp/cf-distribution-config.json <<EOF
{
  "CallerReference": "$CALLER_REF",
  "Comment": "CloudFront distribution for $BUCKET_NAME",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-Website-$BUCKET_NAME",
        "DomainName": "$S3_WEBSITE_ENDPOINT",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only"
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-Website-$BUCKET_NAME",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": { "Forward": "none" }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  },
  "PriceClass": "PriceClass_100"
}
EOF

echo "Creating CloudFront distribution… (takes ~10 minutes)"

CF_OUTPUT=$(aws cloudfront create-distribution \
    --distribution-config file:///tmp/cf-distribution-config.json \
    --output json)

DIST_ID=$(echo "$CF_OUTPUT" | jq -r '.Distribution.Id')
DOMAIN_NAME=$(echo "$CF_OUTPUT" | jq -r '.Distribution.DomainName')

echo ""
echo "=== CloudFront Distribution Created ==="
echo "Distribution ID: $DIST_ID"
echo "CloudFront URL: https://$DOMAIN_NAME"
echo "S3 Website URL: http://$S3_WEBSITE_ENDPOINT"
echo ""
echo "⏳ Distribution is deploying…"
echo ""

mkdir -p scripts
cat > scripts/prod-frontend-info.txt <<EOF
CloudFront Distribution Information
====================================
Distribution ID: $DIST_ID
CloudFront URL: https://$DOMAIN_NAME
S3 Website URL: http://$S3_WEBSITE_ENDPOINT
S3 Bucket: $BUCKET_NAME
Region: $REGION

Status: Deploying (check:
  aws cloudfront get-distribution --id $DIST_ID --query 'Distribution.Status'
)

Created: $(date)
EOF

echo "✓ Info saved to scripts/prod-frontend-info.txt"
