.PHONY: help build up down logs clean install test lambda-package lambda-clean
.PHONY: prod-preparation prod-backend-build prod-backend-deploy prod-backend-update-env
.PHONY: prod-frontend-deploy

# Production Configuration
PROD_STACK_NAME ?= bedrock-chat-prod
PROD_LAMBDA_NAME ?= $(PROD_STACK_NAME)-lambda
PROD_API_NAME ?= $(PROD_STACK_NAME)-api
PROD_S3_BUCKET ?= $(PROD_STACK_NAME)-frontend
PROD_REGION ?= us-east-1

help:
	@echo "Available commands:"
	@echo "  make build          - Build Docker containers"
	@echo "  make up             - Start the application"
	@echo "  make down           - Stop the application"
	@echo "  make logs           - View application logs"
	@echo "  make clean          - Remove containers and volumes"
	@echo "  make install        - Install Python dependencies locally"
	@echo ""
	@echo "Production deployment commands:"
	@echo "  make prod-preparation       - Check AWS credentials and environment"
	@echo "  make prod-backend-build     - Build Lambda deployment package"
	@echo "  make prod-backend-deploy    - Deploy Lambda code only"
	@echo "  make prod-backend-update-env - Update Lambda environment variables"
	@echo "  make prod-frontend-deploy   - Deploy frontend to S3 & invalidate cache"
	@echo ""
	@echo "Terraform backend (replaces prod-backend-bootstrap):"
	@echo "  cd infra/backend && terraform init   - Initialize Terraform"
	@echo "  cd infra/backend && terraform plan   - Preview changes"
	@echo "  cd infra/backend && terraform apply  - Deploy infrastructure"
	@echo ""
	@echo "Terraform frontend (replaces prod-frontend-bootstrap):"
	@echo "  cd infra/frontend && terraform init   - Initialize Terraform"
	@echo "  cd infra/frontend && terraform plan   - Preview changes"
	@echo "  cd infra/frontend && terraform apply  - Deploy infrastructure"
	@echo ""

build:
	docker-compose build

up:
	docker-compose up -d
	@echo "Application started!"
	@echo "Frontend: http://localhost:8080"
	@echo "Backend: http://localhost:8000"
	@echo "API Docs: http://localhost:8000/docs"

down:
	docker-compose down

logs:
	docker-compose logs -f

clean:
	docker-compose down -v
	docker system prune -f

install:
	pip install -r requirements.txt

# Production Deployment Commands

prod-preparation:
	@echo "=== Production Environment Check ==="
	@echo ""
	@echo "Checking AWS CLI installation..."
	@which aws > /dev/null || (echo "Error: AWS CLI not installed" && exit 1)
	@echo "✓ AWS CLI installed: $$(aws --version)"
	@echo ""
	@echo "Checking AWS credentials..."
	@aws sts get-caller-identity > /dev/null || (echo "Error: AWS credentials not configured" && exit 1)
	@echo "✓ AWS Account: $$(aws sts get-caller-identity --query Account --output text)"
	@echo "✓ AWS User/Role: $$(aws sts get-caller-identity --query Arn --output text)"
	@echo ""
	@echo "Checking AWS region..."
	@echo "✓ Region: $(PROD_REGION)"
	@echo ""
	@echo "Checking production environment file..."
	@if [ ! -f .env.prod ]; then \
		echo "⚠ Warning: .env.prod not found"; \
		echo "  Create it from .env.prod.example"; \
	else \
		echo "✓ .env.prod file exists"; \
		. .env.prod && echo "✓ KNOWLEDGE_BASE_ID: $$KNOWLEDGE_BASE_ID"; \
	fi
	@echo ""
	@echo "Testing AWS connectivity..."
	@aws lambda list-functions --region $(PROD_REGION) --max-items 1 > /dev/null || (echo "Error: Cannot connect to AWS Lambda service" && exit 1)
	@aws s3 ls > /dev/null || (echo "Error: Cannot connect to AWS S3 service" && exit 1)
	@echo "✓ AWS connectivity OK"
	@echo ""
	@echo "=== All checks passed! Ready for production deployment ==="

prod-backend-build:
	@echo "=== Building Lambda Package ==="
	@rm -rf lambda-package lambda-package.zip
	@mkdir -p lambda-package
	@echo "Installing dependencies..."
	@pip install -r requirements-lambda.txt -t lambda-package/ --upgrade --quiet
	@echo "Copying application code..."
	@cp -r src lambda-package/
	@cp src/backend/lambda_app.py lambda-package/
	@echo "Creating deployment zip..."
	@cd lambda-package && zip -r ../lambda-package.zip . -q
	@echo "✓ Lambda package created: lambda-package.zip"
	@echo "✓ Package size: $$(du -h lambda-package.zip | cut -f1)"

# Note: prod-backend-bootstrap has been replaced by Terraform
# Use: cd infra/backend && terraform apply

prod-backend-deploy:
	@echo "=== Deploying Lambda Package ==="
	@if [ ! -f lambda-package.zip ]; then \
		echo "Error: lambda-package.zip not found. Run 'make prod-backend-build' first"; \
		exit 1; \
	fi
	@echo "Updating Lambda function code..."
	@aws lambda update-function-code \
		--function-name $(PROD_LAMBDA_NAME) \
		--zip-file fileb://lambda-package.zip \
		--region $(PROD_REGION) \
		--output json > /tmp/lambda-update.json
	@echo "✓ Lambda code updated"
	@echo ""
	@echo "Waiting for Lambda to be ready..."
	@aws lambda wait function-updated --function-name $(PROD_LAMBDA_NAME) --region $(PROD_REGION)
	@echo "✓ Lambda deployment complete!"
	@echo ""
	@echo "Function ARN: $$(cat /tmp/lambda-update.json | grep -o '"FunctionArn": "[^"]*' | cut -d'"' -f4)"

prod-backend-update-env:
	@echo "=== Updating Lambda Environment Variables ==="
	@bash scripts/update-lambda-env.sh $(PROD_LAMBDA_NAME) $(PROD_REGION)
	@echo ""
	@echo "Waiting for Lambda to be ready..."
	@aws lambda wait function-updated --function-name $(PROD_LAMBDA_NAME) --region $(PROD_REGION)
	@echo "✓ Environment variables updated!"

prod-frontend-deploy:
	@echo "=== Deploying Frontend ==="
	@if [ ! -d "src/frontend" ]; then \
		echo "Error: src/frontend directory not found"; \
		exit 1; \
	fi
	@echo "Preparing frontend files for production..."
	@bash scripts/prepare-frontend-deploy.sh $(PROD_REGION)
	@echo ""
	@echo "Syncing files to S3..."
	@aws s3 sync /tmp/frontend-deploy/ s3://$(PROD_S3_BUCKET)/ \
		--delete \
		--cache-control "public, max-age=3600" \
		--exclude "*.md" \
		--region $(PROD_REGION)
	@echo "✓ Files synced to S3"
	@echo ""
	@echo "Invalidating CloudFront cache..."
	@if [ -d "infra/frontend" ]; then \
		DIST_ID=$$(cd infra/frontend && terraform output -raw cloudfront_distribution_id 2>/dev/null); \
		if [ -n "$$DIST_ID" ] && [ "$$DIST_ID" != "" ]; then \
			echo "Distribution ID: $$DIST_ID"; \
			aws cloudfront create-invalidation \
				--distribution-id $$DIST_ID \
				--paths "/*" \
				--output json > /tmp/cf-invalidation.json; \
			echo "✓ Cache invalidation initiated"; \
			echo "Invalidation ID: $$(cat /tmp/cf-invalidation.json | grep -o '"Id": "[^"]*' | head -1 | cut -d'"' -f4)"; \
		else \
			echo "⚠ Warning: CloudFront distribution ID not found in Terraform outputs"; \
			echo "  Run 'cd infra/frontend && terraform apply' first"; \
		fi \
	else \
		echo "⚠ Warning: infra/frontend directory not found. Skipping cache invalidation."; \
	fi
	@echo ""
	@rm -rf /tmp/frontend-deploy
	@echo "✓ Cleaned up temporary files"
	@echo ""
	@echo "=== Frontend deployment complete! ==="

