data "terraform_remote_state" "auth_lambda" {
  backend = "s3"

  config = {
    bucket = "oficina-state-priess951"
    key    = "infra/auth-lambda/terraform.tfstate"
    region = "us-east-1"
  }
}