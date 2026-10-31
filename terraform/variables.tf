variable "ebs_csi_addon_version" {
  description = "Versao do add-on EBS CSI; null seleciona o padrao compativel da AWS"
  type        = string
  default     = null
}

variable "ebs_csi_service_account_role_arn" {
  description = "Role IRSA existente para EBS CSI; null utiliza a role dos nodes no LAB"
  type        = string
  default     = null
}
