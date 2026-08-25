output "vpc_id" {
  description = "ID da VPC principal"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR da VPC principal"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_a_id" {
  description = "ID da subnet publica na zona us-east-1a"
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "ID da subnet publica na zona us-east-1b"
  value       = aws_subnet.public_b.id
}

output "eks_cluster_name" {
  description = "Nome do Cluster EKS"
  value       = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR da aplicacao"
  value       = aws_ecr_repository.oficina_api_repo.repository_url
}