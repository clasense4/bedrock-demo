output "knowledge_base_id" {
  description = "The ID of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.resource_kb.id
}

output "knowledge_base_arn" {
  description = "The ARN of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.resource_kb.arn
}

output "knowledge_base_name" {
  description = "The name of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.resource_kb.name
}

output "opensearch_collection_endpoint" {
  description = "The endpoint of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.resource_kb.collection_endpoint
}

output "data_source_id" {
  description = "The ID of the web crawler data source"
  value       = aws_bedrockagent_data_source.web_crawler.id
}
