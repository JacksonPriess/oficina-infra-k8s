output "api_gateway_id" {
  description = "ID do API Gateway"
  value       = aws_apigatewayv2_api.oficina.id
}

output "api_gateway_url" {
  description = "URL pública do API Gateway"
  value       = aws_apigatewayv2_api.oficina.api_endpoint
}