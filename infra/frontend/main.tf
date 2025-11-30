# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source to read backend API Gateway endpoint from backend Terraform state
data "terraform_remote_state" "backend" {
  backend = "local"

  config = {
    path = "${path.module}/../backend/terraform.tfstate"
  }
}

# Local variables
locals {
  bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.stack_name}-frontend"
  api_endpoint = var.api_gateway_endpoint != "" ? var.api_gateway_endpoint : try(data.terraform_remote_state.backend.outputs.api_gateway_endpoint, "")
}

# S3 Bucket for static website hosting
resource "aws_s3_bucket" "frontend" {
  bucket = local.bucket_name

  tags = {
    Name        = local.bucket_name
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# S3 Bucket Public Access Block Configuration
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket Policy for Public Read Access
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# CloudFront Origin Access Identity (for future use with private S3)
resource "aws_cloudfront_origin_access_identity" "frontend" {
  count   = var.enable_cloudfront ? 1 : 0
  comment = "OAI for ${local.bucket_name}"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  count               = var.enable_cloudfront ? 1 : 0
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  comment             = "CloudFront distribution for ${local.bucket_name}"

  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend.website_endpoint
    origin_id   = "S3-Website-${local.bucket_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Website-${local.bucket_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 300
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.stack_name}-cloudfront"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
