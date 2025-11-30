# Backend Infrastructure Outputs

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.api.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.api.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda_role.arn
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.http_api.id
}

output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_apigatewayv2_api.http_api.execution_arn
}

output "health_endpoint" {
  description = "Health check endpoint"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/health"
}

output "chat_endpoint" {
  description = "Chat API endpoint"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/api/chat"
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "stack_name" {
  description = "Stack name"
  value       = var.stack_name
}

output "knowledge_base_id" {
  description = "Knowledge Base ID being used by Lambda"
  value       = var.knowledge_base_id != "" ? var.knowledge_base_id : try(data.terraform_remote_state.bedrock.outputs.knowledge_base_id, "not-configured")
}
