# Frontend Infrastructure Outputs

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.frontend.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.frontend.arn
}

output "s3_website_endpoint" {
  description = "S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "s3_website_url" {
  description = "S3 website URL"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.frontend[0].id : "CloudFront disabled"
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.frontend[0].domain_name : "CloudFront disabled"
}

output "cloudfront_url" {
  description = "CloudFront URL"
  value       = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.frontend[0].domain_name}" : "CloudFront disabled - use S3 website URL"
}

output "cloudfront_status" {
  description = "Status of the CloudFront distribution"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.frontend[0].status : "Disabled"
}

output "cloudfront_enabled" {
  description = "Whether CloudFront is enabled"
  value       = var.enable_cloudfront
}

output "api_gateway_endpoint" {
  description = "API Gateway endpoint being used by frontend"
  value       = local.api_endpoint
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "stack_name" {
  description = "Stack name"
  value       = var.stack_name
}
