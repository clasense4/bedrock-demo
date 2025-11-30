# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source to read Bedrock knowledge base ID from Bedrock Terraform state
data "terraform_remote_state" "bedrock" {
  backend = "local"

  config = {
    path = "${path.module}/../bedrock/terraform.tfstate"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.stack_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.stack_name}-lambda-role"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for Bedrock access
resource "aws_iam_policy" "bedrock_policy" {
  name        = "${var.stack_name}-bedrock-policy"
  description = "Policy for Lambda to access AWS Bedrock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.stack_name}-bedrock-policy"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Attach Bedrock policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_bedrock" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.bedrock_policy.arn
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.stack_name}-lambda"
  retention_in_days = 7

  tags = {
    Name        = "${var.stack_name}-lambda-logs"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Lambda Function
resource "aws_lambda_function" "api" {
  filename         = var.lambda_package_path
  function_name    = "${var.stack_name}-lambda"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_app.handler"
  source_code_hash = filebase64sha256(var.lambda_package_path)
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.knowledge_base_id != "" ? var.knowledge_base_id : try(data.terraform_remote_state.bedrock.outputs.knowledge_base_id, "")
      BEDROCK_MODEL_ID  = var.bedrock_model_id
      LOG_LEVEL         = var.log_level
      FRONTEND_URL      = var.frontend_url
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_bedrock,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name        = "${var.stack_name}-lambda"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.stack_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = [
      "Content-Type",
      "X-Amz-Date",
      "Authorization",
      "X-Api-Key",
      "X-Amz-Security-Token"
    ]
    max_age = 300
  }

  tags = {
    Name        = "${var.stack_name}-api"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# API Gateway Integration with Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api.invoke_arn

  payload_format_version = "2.0"
}

# API Gateway Route: POST /api/chat
resource "aws_apigatewayv2_route" "chat" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /api/chat"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Route: GET /health
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name        = "${var.stack_name}-api-stage"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.stack_name}-api"
  retention_in_days = 7

  tags = {
    Name        = "${var.stack_name}-api-logs"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
