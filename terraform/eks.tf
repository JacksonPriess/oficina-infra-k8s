# 1. Obtém os dados da conta AWS atual para montar a permissão dinamicamente
data "aws_caller_identity" "current" {}

locals {
  # Monta o caminho exato da LabRole fornecida pelo laboratório
  lab_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}

# 2. Cluster EKS - Control Plane - gerido pela AWS
resource "aws_eks_cluster" "eks_cluster" {
  name     = "${local.prefix}-cluster"
  role_arn = local.lab_role_arn

  vpc_config {
    subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  }
}

# 3. Node Group (Os servidores EC2 que vão rodar o seu Java e os testes)
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${local.prefix}-nodes"
  node_role_arn   = local.lab_role_arn
  subnet_ids      = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  # Configuração de escala económica para laboratório
  scaling_config {
    desired_size = 1 # Começamos com 1 servidor apenas
    max_size     = 2 # Se a carga aumentar, o Kubernetes pode pedir até 2
    min_size     = 1 # Nunca fica com menos de 1
  }

  # t3.medium é o standard recomendado para aguentar os recursos de sistema do Kubernetes e aplicações Spring Boot
  instance_types = ["t3.medium"]

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]

  tags = {
    Name = "${local.prefix}-node-group"
  }
}