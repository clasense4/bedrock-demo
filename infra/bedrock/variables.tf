variable "environment" {
  type        = string
  description = "Environment Name"
  default     = "prod"
}

variable "stack" {
  type        = string
  description = "Stack Name"
  default     = "bedrock"
}

variable "app" {
  type        = string
  description = "Application Name"
  default     = "bedrock-demo"
}

variable "crawler_urls" {
  type        = list(string)
  description = "List of URLs to crawl"
  default = [
    "https://www.axrail.ai/",
    "https://www.axrail.ai/about-us",
    "https://www.axrail.ai/digital-workforce",
    "https://www.axrail.ai/cloud-migration",
    "https://www.axrail.ai/data-analytics",
    "https://www.axrail.ai/digital-platform",
    "https://www.axrail.ai/ql-maxincome-case-study",
    "https://www.axrail.ai/sepang-circuit-international",
    "https://www.axrail.ai/pelangi-case-study"
  ]
}

variable "crawler_scope" {
  type        = string
  description = "Crawler scope (HOST or SUBDOMAINS)"
  default     = "HOST"
}

variable "max_rate_limit" {
  type        = number
  description = "Maximum crawl rate per host per minute"
  default     = 300
}
