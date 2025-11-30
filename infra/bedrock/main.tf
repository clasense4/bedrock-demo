#######################################
# locals / providers / datasources
#######################################

locals {
  kb_name                 = "resourceKB"
  kb_oss_collection_name  = "bedrock-resource-kb"
  bedrock_model_arn       = "arn:${data.aws_partition.this.partition}:bedrock:${data.aws_region.this.region}::foundation-model/amazon.titan-embed-text-v2:0"
}

data "aws_caller_identity" "this" {}
data "aws_partition" "this" {}
data "aws_region" "this" {}

# opensearch provider uses the collection endpoint below (set after collection created)
provider "opensearch" {
  alias       = "oss"
  url         = aws_opensearchserverless_collection.resource_kb.collection_endpoint
  healthcheck = false
}

#######################################
# OSS security + access policies + collection
#######################################

resource "aws_opensearchserverless_security_policy" "resource_kb_encryption" {
  name = local.kb_oss_collection_name
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource = ["collection/${local.kb_oss_collection_name}"]
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "resource_kb_network" {
  name = local.kb_oss_collection_name
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.kb_oss_collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${local.kb_oss_collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "resource_kb" {
  name = local.kb_oss_collection_name
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${local.kb_oss_collection_name}/*"]
          Permission   = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:UpdateIndex",
            "aoss:WriteDocument"
          ]
        },
        {
          ResourceType = "collection"
          Resource   = ["collection/${local.kb_oss_collection_name}"]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DescribeCollectionItems",
            "aoss:UpdateCollectionItems"
          ]
        }
      ],
      Principal = [
        aws_iam_role.bedrock_kb_resource_kb.arn,
        data.aws_caller_identity.this.arn
      ]
    }
  ])
}

resource "aws_opensearchserverless_collection" "resource_kb" {
  name = local.kb_oss_collection_name
  type = "VECTORSEARCH"
  depends_on = [
    aws_opensearchserverless_access_policy.resource_kb,
    aws_opensearchserverless_security_policy.resource_kb_encryption,
    aws_opensearchserverless_security_policy.resource_kb_network
  ]
}

#######################################
# create index in OSS via opensearch provider
# note: name must match bedrock vector_index_name later
#######################################

resource "opensearch_index" "resource_kb" {
  provider = opensearch.oss
  name                           = "bedrock-knowledge-base-default-index"
  number_of_shards               = "2"
  number_of_replicas             = "0"
  index_knn                      = true
  index_knn_algo_param_ef_search = "512"
  mappings                       = <<-EOF
    {
      "properties": {
        "bedrock-knowledge-base-default-vector": {
          "type": "knn_vector",
          "dimension": ${var.vector_dimension},
          "method": {
            "name": "hnsw",
            "engine": "faiss",
            "parameters": {
              "m": 16,
              "ef_construction": 512
            },
            "space_type": "l2"
          }
        },
        "AMAZON_BEDROCK_METADATA": {
          "type": "text",
          "index": "false"
        },
        "AMAZON_BEDROCK_TEXT_CHUNK": {
          "type": "text",
          "index": "true"
        }
      }
    }
  EOF
  force_destroy  = true
  depends_on     = [aws_opensearchserverless_collection.resource_kb]
}

# small wait to ensure role/policy propagation (20s)
resource "time_sleep" "wait_for_oss_propagation" {
  depends_on      = [opensearch_index.resource_kb]
  create_duration = "20s"
}

#######################################
# bedrock IAM roles (minimal, from example)
#######################################

resource "aws_iam_role" "bedrock_kb_resource_kb" {
  name = "AmazonBedrockExecutionRoleForKnowledgeBase_${local.kb_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "bedrock.amazonaws.com" }
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.this.account_id }
          ArnLike = { "aws:SourceArn" = "arn:${data.aws_partition.this.partition}:bedrock:${data.aws_region.this.region}:${data.aws_caller_identity.this.account_id}:knowledge-base/*" }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_kb_resource_kb_model" {
  name = "AmazonBedrockFoundationModelPolicyForKnowledgeBase_${local.kb_name}"
  role = aws_iam_role.bedrock_kb_resource_kb.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "bedrock:InvokeModel"
        Effect   = "Allow"
        Resource = local.bedrock_model_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_kb_resource_kb_oss" {
  name = "AmazonBedrockOSSPolicyForKnowledgeBase_${local.kb_name}"
  role = aws_iam_role.bedrock_kb_resource_kb.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "aoss:APIAccessAll"
        Effect   = "Allow"
        Resource = aws_opensearchserverless_collection.resource_kb.arn
      }
    ]
  })
}

#######################################
# Bedrock Knowledge Base (depends on index created)
#######################################

resource "aws_bedrockagent_knowledge_base" "resource_kb" {
  name     = "${var.app}-kb"
  role_arn = aws_iam_role.bedrock_kb_resource_kb.arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.this.region}::foundation-model/amazon.titan-embed-text-v2:0"
    }
    type = "VECTOR"
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.resource_kb.arn
      vector_index_name = opensearch_index.resource_kb.name
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.bedrock_kb_resource_kb_model,
    opensearch_index.resource_kb,
    time_sleep.wait_for_oss_propagation
  ]
}

#######################################
# Bedrock Data Source - WEB crawler
#######################################

resource "aws_bedrockagent_data_source" "web_crawler" {
  name              = "${var.app}-web-crawler"
  knowledge_base_id = aws_bedrockagent_knowledge_base.resource_kb.id

  data_source_configuration {
    type = "WEB"
    web_configuration {
      crawler_configuration {
        crawler_limits {
          rate_limit = var.max_rate_limit
        }
      }
      source_configuration {
        url_configuration {
          dynamic "seed_urls" {
            for_each = var.crawler_urls
            content {
              url = seed_urls.value
            }
          }
        }
      }
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }

  depends_on = [
    aws_bedrockagent_knowledge_base.resource_kb
  ]
}

#######################################
# variables
#######################################

variable "kb_oss_collection_name" {
  type = string
  default = "bedrock-resource-kb"
}

variable "kb_name" {
  type = string
  default = "resourceKB"
}

variable "vector_dimension" {
  type = number
  default = 1024
}

variable "chunking_strategy" {
  type = string
  default = "FIXED_SIZE"
}

variable "fixed_size_max_tokens" {
  type = number
  default = 512
}

variable "fixed_size_overlap_percentage" {
  type = number
  default = 20
}
