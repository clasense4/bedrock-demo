#!/bin/bash
set -e

BUCKET_NAME=${1:-bedrock-chat-prod-frontend}
REGION=${2:-us-east-1}

echo "Creating S3 bucket: $BUCKET_NAME"

# Check if bucket exists
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo "✓ Bucket $BUCKET_NAME already exists"
else
    # Create bucket
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo "✓ Bucket created"
fi

# Disable block public access for static website hosting
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
    --region "$REGION"

echo "✓ Public access enabled for static website"

# Configure static website hosting
aws s3api put-bucket-website \
    --bucket "$BUCKET_NAME" \
    --website-configuration \
        "IndexDocument={Suffix=index.html},ErrorDocument={Key=index.html}" \
    --region "$REGION"

echo "✓ Static website hosting enabled"

# Create bucket policy for public read access
cat > /tmp/s3-public-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy file:///tmp/s3-public-policy.json \
    --region "$REGION"

echo "✓ Public read policy applied"

# Enable versioning (optional but recommended)
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$REGION"

echo "✓ Versioning enabled"

# Get website endpoint
if [ "$REGION" = "us-east-1" ]; then
    WEBSITE_ENDPOINT="${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"
else
    WEBSITE_ENDPOINT="${BUCKET_NAME}.s3-website.${REGION}.amazonaws.com"
fi

echo ""
echo "✓ S3 bucket setup complete: $BUCKET_NAME"
echo "✓ Website endpoint: http://$WEBSITE_ENDPOINT"
