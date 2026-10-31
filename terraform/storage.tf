# LAB: permite que o driver EBS CSI obtenha as credenciais da role dos nodes
# pelo IMDSv2. A LabRole ainda precisa autorizar as operacoes EC2/EBS.
# Fora do LAB, prefira uma identidade dedicada ao driver (IRSA/Pod Identity).
resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${local.prefix}-nodes-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "${local.prefix}-nodes"
  }
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "aws-ebs-csi-driver"

  # null deixa a AWS escolher sua versao padrao compativel com o cluster.
  # Depois de validar no LAB, a versao pode ser fixada nesta variavel.
  addon_version = var.ebs_csi_addon_version

  # Sem ARN, o modo LAB utiliza as credenciais da role dos nodes.
  # Um ARN informado aqui precisa ser de uma role IRSA ja configurada.
  service_account_role_arn = var.ebs_csi_service_account_role_arn

  depends_on = [aws_eks_node_group.eks_nodes]

  tags = {
    Name = "${local.prefix}-ebs-csi"
  }
}
