# Criação do Gateway
resource "aws_apigatewayv2_api" "oficina" {
  name          = "oficina-api-gateway"
  protocol_type = "HTTP"

  tags = {
    Name = "oficina-api-gateway"
  }
}

# Integração com a Lambda
resource "aws_apigatewayv2_integration" "auth_lambda" {
  api_id = aws_apigatewayv2_api.oficina.id

  integration_type       = "AWS_PROXY"
  integration_uri        = data.terraform_remote_state.auth_lambda.outputs.lambda_invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Configuracao da rota, Gateway sabe quem chamar
resource "aws_apigatewayv2_route" "auth_cliente" {
  api_id = aws_apigatewayv2_api.oficina.id

  route_key = "POST /auth/cliente"

  target = "integrations/${aws_apigatewayv2_integration.auth_lambda.id}"
}


resource "aws_lambda_permission" "allow_api_gateway_auth" {
  statement_id = "AllowApiGatewayInvokeAuth"

  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.auth_lambda.outputs.lambda_function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.oficina.execution_arn}/*/*"
}

# API Gateway repassa requisição e resposta entre cliente e backend - Spring Boot / EKS
resource "aws_apigatewayv2_integration" "spring_api" {
  api_id = aws_apigatewayv2_api.oficina.id

  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"

  integration_uri = "${var.backend_url}/{proxy}"
}

# Cria a rota proxy
resource "aws_apigatewayv2_route" "spring_api" {
  api_id = aws_apigatewayv2_api.oficina.id

  route_key = "ANY /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.spring_api.id}"
}

# Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.oficina.id

  name        = "$default"
  auto_deploy = true
}