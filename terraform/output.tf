output "api_gateway_rest_api_id" {
  description = "The ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_main_resource_id" {
  description = "The ID of the API Gateway main resource"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}