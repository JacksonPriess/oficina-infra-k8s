terraform {
  backend "s3" {
    bucket = "oficina-state-priess951"
    key    = "infra/k8s/terraform.tfstate"
    region = "us-east-1"
  }
}