# Backend Infrastructure Variables

variable "stack_name" {
  description = "Name of the stack (used for resource naming)"
  type        = string
  default     = "bedrock-chat-prod"
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "knowledge_base_id" {
  description = "AWS Bedrock Knowledge Base ID (leave empty to auto-detect from Bedrock Terraform state)"
  type        = string
  default     = ""
}

variable "bedrock_model_id" {
  description = "AWS Bedrock Model ID"
  type        = string
  default     = "amazon.nova-micro-v1:0"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"
}

variable "frontend_url" {
  description = "Frontend URL for CORS configuration"
  type        = string
  default     = "*"
}

variable "lambda_package_path" {
  description = "Path to Lambda deployment package"
  type        = string
  default     = "../../lambda-package.zip"
}
