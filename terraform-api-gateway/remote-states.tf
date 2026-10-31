data "terraform_remote_state" "auth_lambda" {
  backend = "s3"

  config = {
    bucket = "oficina-state-priess952"
    key    = "infra/auth-lambda/terraform.tfstate"
    region = "us-east-1"
  }
}