# Oficina Dinoco - Infraestrutura Kubernetes

Repositório responsável pelo provisionamento da infraestrutura principal da aplicação **Oficina Dinoco** na AWS utilizando Terraform.

## Responsabilidades

Este repositório provisiona:

- VPC
- Subnets públicas
- Internet Gateway
- Route Tables
- Amazon EKS
- Node Group EC2
- Amazon ECR
- Backend Terraform em S3

O banco de dados PostgreSQL é provisionado separadamente no repositório `oficina-infra-db`.

## Tecnologias

- AWS
- Terraform
- Amazon EKS
- Amazon EC2
- Amazon ECR
- Amazon S3
- GitHub Actions

## Estrutura

```text
.
├── .github/
│   └── workflows/
│       └── terraform.yml
├── terraform/
│   ├── backend.tf
│   ├── ecr.tf
│   ├── eks.tf
│   ├── network.tf
│   ├── outputs.tf
│   └── providers.tf
├── .gitignore
└── README.md
```

## Pré-requisitos

Para execução local:

- Terraform instalado
- AWS CLI configurada
- Credenciais válidas do AWS Academy/Lab
- Profile AWS `pos` configurado localmente

Exemplo no PowerShell:

```powershell
$env:AWS_PROFILE="pos"
```

## Execução local

Acesse a pasta Terraform:

```bash
cd terraform
```

Inicialize o Terraform:

```bash
terraform init
```

Valide a configuração:

```bash
terraform validate
```

Visualize o plano:

```bash
terraform plan
```

Para provisionar manualmente:

```bash
terraform apply
```

> O deploy oficial da infraestrutura deve ocorrer através da pipeline de CI/CD.

## Terraform State

O estado remoto é armazenado no Amazon S3:

```text
Bucket: oficina-state-priess951
Key: infra/k8s/terraform.tfstate
Region: us-east-1
```

O bucket é criado automaticamente pela pipeline caso ainda não exista.

## CI/CD

A pipeline GitHub Actions está localizada em:

```text
.github/workflows/terraform.yml
```

### Pull Request para `main`

Executa:

```text
terraform fmt
terraform init
terraform validate
terraform plan
```

Nenhuma alteração de infraestrutura é realizada durante o Pull Request.

### Merge/Push na `main`

Executa as validações e:

```text
terraform apply -auto-approve
```

realizando automaticamente o deploy da infraestrutura na AWS.

## Outputs

Este projeto disponibiliza informações utilizadas por outros repositórios, incluindo:

- ID da VPC
- CIDR da VPC
- IDs das Subnets
- Nome do cluster EKS
- Endpoint do EKS
- URL do ECR

O repositório `oficina-infra-db` utiliza os dados de rede para provisionar o PostgreSQL na mesma VPC.

## Segurança

A branch `main` deve permanecer protegida, sem commits diretos e com uso obrigatório de Pull Requests.

Arquivos de state, credenciais e informações sensíveis não devem ser versionados no Git.