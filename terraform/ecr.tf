# Cria o repositório privado no Elastic Container Registry (ECR)
resource "aws_ecr_repository" "oficina_api_repo" {
  name                 = "${local.prefix}-repo"
  image_tag_mutability = "MUTABLE"

  # Configuração para deletar o repositório facilmente quando destruirmos o ambiente
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true # Opcional, mas bacana: escaneia a imagem em busca de vulnerabilidades
  }

  tags = {
    Name = "${local.prefix}-ecr"
  }
}

# Repositorio exclusivo do microservico de Catalogo de Produtos.
resource "aws_ecr_repository" "oficina_produto_repo" {
  name                 = "oficina-produto-dev-repo"
  image_tag_mutability = "MUTABLE"

  # Mantem o comportamento de destruicao adotado para o ambiente de laboratorio.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "oficina-produto-dev-ecr"
  }
}
