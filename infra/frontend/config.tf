terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.23.0"
    }
  }

  required_version = "1.14.0"
}

provider "aws" {
  region = var.region
}

# CloudFront requires ACM certificates in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
