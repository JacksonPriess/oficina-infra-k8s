terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configuração do provedor de nuvem com o perfil "pos" e a região "us-east-1", trava de segurança
provider "aws" {
  region = "us-east-1"
  # profile = "pos"
}