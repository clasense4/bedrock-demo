terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.23.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
    opensearch = {
      source  = "opensearch-project/opensearch"
      version = "= 2.2.0"
    }
  }

  required_version = "1.14.0"
}

provider "aws" {
  region = "us-east-1"
}

