#!/bin/bash
set -e

STACK_NAME=${1:-bedrock-chat-prod}
ROLE_NAME="${STACK_NAME}-lambda-role"

echo "Creating IAM role: $ROLE_NAME"

# Check if role already exists
if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
    echo "✓ Role $ROLE_NAME already exists"
    exit 0
fi

# Create trust policy
cat > /tmp/lambda-trust-policy.json <<\EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
    --description "Lambda execution role for $STACK_NAME"

echo "✓ Role created"

# Attach basic Lambda execution policy
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

echo "✓ Attached AWSLambdaBasicExecutionRole"

# Create and attach Bedrock policy
cat > /tmp/bedrock-policy.json <<\EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:Retrieve",
        "bedrock:RetrieveAndGenerate"
      ],
      "Resource": "*"
    }
  ]
}
EOF

POLICY_NAME="${STACK_NAME}-bedrock-policy"

# Check if policy exists
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
    POLICY_ARN=$(aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document file:///tmp/bedrock-policy.json \
        --query 'Policy.Arn' \
        --output text)
    echo "✓ Created Bedrock policy"
else
    echo "✓ Bedrock policy already exists"
fi

aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN"

echo "✓ Attached Bedrock policy"

# Wait for role to be available
echo "Waiting for role to propagate..."
sleep 10

echo "✓ IAM role setup complete: $ROLE_NAME"
