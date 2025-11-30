variable "stack_name" {
  description = "Name of the stack (used for resource naming)"
  type        = string
  default     = "bedrock-chat-prod"
}

variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend hosting"
  type        = string
  default     = ""
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100: US/EU, PriceClass_200: US/EU/Asia, PriceClass_All: All)"
  type        = string
  default     = "PriceClass_200"
}

variable "enable_cloudfront" {
  description = "Enable CloudFront distribution (set to false for faster deployment, use S3 website directly)"
  type        = bool
  default     = true
}

variable "api_gateway_endpoint" {
  description = "API Gateway endpoint URL from backend (optional, can be set after backend deployment)"
  type        = string
  default     = ""
}
