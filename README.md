# ☁️ Oficina Dinoco - Infraestrutura Kubernetes e API Gateway

Repositório responsável pela infraestrutura AWS utilizada pela aplicação **Oficina Dinoco**, contemplando a infraestrutura base do Kubernetes/EKS e a camada de entrada da solução através do **AWS API Gateway**.

Este repositório faz parte da Fase 3 do projeto de pós-graduação em Arquitetura de Software e foi separado da aplicação principal para permitir ciclos independentes de provisionamento, deploy e evolução da infraestrutura.

---

## 🎯 Objetivos do repositório

Este repositório é responsável por provisionar e manter:

- VPC da solução;
- Subnets utilizadas pelos recursos AWS;
- Internet Gateway e rotas de rede;
- Cluster Amazon EKS;
- Node Group EC2;
- Amazon ECR;
- Metrics Server utilizado pelo Kubernetes HPA;
- AWS API Gateway HTTP API;
- Integração do API Gateway com a Lambda de autenticação;
- Integração do API Gateway com a aplicação Spring Boot executada no EKS;
- Estados Terraform independentes para infraestrutura Kubernetes e API Gateway.

---

# 🏗️ Arquitetura

A arquitetura atual possui o **API Gateway como ponto de entrada principal da solução**.

```text
                         Internet
                            |
                            v
                    ┌────────────────┐
                    │  API Gateway   │
                    └───────┬────────┘
                            |
              +-------------+-------------+
              |                           |
              v                           v
      POST /auth/cliente             Demais rotas
              |                           |
              v                           v
       Auth Lambda                 Load Balancer
              |                           |
              |                           v
              |                          EKS
              |                           |
              |                           v
              |                     Spring Boot
              |
              v
       Autenticação CPF
```

O API Gateway decide o destino de acordo com a rota:

```text
POST /auth/cliente
        ↓
AWS Lambda

ANY /{proxy+}
        ↓
Load Balancer
        ↓
Spring Boot / EKS
```

Dessa forma, a Lambda de autenticação é executada somente quando necessária.

---

# 📦 Separação dos repositórios

A solução foi dividida em repositórios independentes.

### `oficina-infra-k8s`

Responsável por:

- VPC;
- Subnets;
- Internet Gateway;
- EKS;
- Node Groups EC2;
- ECR;
- Metrics Server;
- API Gateway;
- integrações de entrada da aplicação.

### `oficina-infra-db`

Responsável por:

- RDS PostgreSQL;
- DB Subnet Group;
- Security Group do banco;
- credenciais do banco gerenciadas pelo AWS Secrets Manager.

### `oficina-auth-lambda`

Responsável por:

- AWS Lambda para autenticação de clientes;
- validação de CPF;
- consulta do cliente no PostgreSQL;
- verificação de existência/status;
- geração de JWT;
- Secret utilizado na assinatura dos tokens;
- VPC Endpoint para acesso privado ao Secrets Manager.

### `oficina-dinoco`

Responsável por:

- aplicação Java/Spring Boot;
- regras de negócio;
- autenticação dos funcionários;
- Dockerfile;
- migrations Flyway;
- manifestos Kubernetes;
- build e publicação da imagem;
- deploy da aplicação no EKS.

---

# 📁 Estrutura do repositório

```text
oficina-infra-k8s/
├── .github/
│   └── workflows/
│       ├── terraform.yml
│       └── api-gateway.yml
│
├── terraform/
│   ├── backend.tf
│   ├── ecr.tf
│   ├── eks.tf
│   ├── network.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── .terraform.lock.hcl
│
├── terraform-api-gateway/
│   ├── backend.tf
│   ├── providers.tf
│   ├── remote-states.tf
│   ├── variables.tf
│   ├── api-gateway.tf
│   └── outputs.tf
│
├── .gitignore
└── README.md
```

A infraestrutura foi dividida em dois estados Terraform para evitar acoplamento desnecessário entre o ciclo de vida do EKS e o API Gateway.

---

# 🌐 Infraestrutura Kubernetes

A pasta:

```text
terraform/
```

contém a infraestrutura base da solução.

Principais recursos:

```text
VPC
├── Subnet pública A
├── Subnet pública B
├── Internet Gateway
└── Route Table

EKS
├── Control Plane
└── Node Group EC2

ECR
└── Repositório Docker da aplicação
```

O Node Group do EKS utiliza instâncias EC2 para executar os Pods da aplicação.

---

# 📊 Metrics Server e HPA

A aplicação utiliza Kubernetes Horizontal Pod Autoscaler (HPA).

O Metrics Server fornece ao Kubernetes métricas de utilização de CPU e memória necessárias para o funcionamento do HPA.

A instalação é realizada através da pipeline de infraestrutura:

```bash
kubectl apply -f \
https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Após instalado, é possível verificar as métricas através de:

```bash
kubectl top nodes
kubectl top pods
```

Exemplo de configuração do HPA utilizada pela aplicação:

```text
mínimo: 1 réplica
máximo: 3 réplicas
CPU alvo: 70%
```

---

# 🚪 API Gateway

O API Gateway possui um Terraform próprio dentro do mesmo repositório:

```text
terraform-api-gateway/
```

O state é armazenado separadamente:

```text
infra/api-gateway/terraform.tfstate
```

Isso evita uma dependência circular entre:

```text
EKS
Lambda
API Gateway
```

O Gateway pode ser criado, alterado ou destruído sem alterar diretamente o state principal do EKS.

---

## Roteamento do API Gateway

O API Gateway utiliza uma **HTTP API**.

### Autenticação do cliente

```text
POST /auth/cliente
        ↓
AWS Lambda
```

A integração utiliza:

```text
AWS_PROXY
Payload version 2.0
```

A Lambda recebe o evento HTTP do API Gateway, valida o CPF do cliente e devolve um JWT.

---

### Aplicação Spring Boot

As demais requisições são encaminhadas através de uma rota proxy:

```text
ANY /{proxy+}
```

Fluxo:

```text
API Gateway
     ↓
HTTP_PROXY
     ↓
Load Balancer Kubernetes
     ↓
Service
     ↓
Pod Spring Boot
```

Exemplo:

```text
POST /api/auth/login
```

é encaminhado para:

```text
LoadBalancer
    ↓
/api/auth/login
```

O Gateway preserva o fluxo já existente da aplicação, incluindo headers como:

```http
Authorization: Bearer <JWT>
```

---

# 🔐 Dois fluxos de autenticação

A solução mantém dois mecanismos distintos.

### Funcionários

Funcionários continuam utilizando a autenticação da aplicação principal:

```text
Funcionário
   ↓
e-mail + senha
   ↓
API Gateway
   ↓
Spring Boot
   ↓
JWT funcionário
```

### Clientes

Clientes utilizam o fluxo serverless:

```text
Cliente
   ↓
CPF
   ↓
API Gateway
   ↓
Auth Lambda
   ↓
PostgreSQL
   ↓
JWT CLIENTE
```

Esses dois modelos coexistem sem necessidade de alterar o fluxo já existente dos funcionários.

---

# 🔄 Remote State

O Terraform utiliza estados remotos armazenados no Amazon S3.

Exemplos:

```text
infra/k8s/terraform.tfstate
infra/db/terraform.tfstate
infra/auth-lambda/terraform.tfstate
infra/api-gateway/terraform.tfstate
```

O Terraform do API Gateway lê outputs do state da Lambda para obter informações como:

```text
lambda_function_name
lambda_function_arn
lambda_invoke_arn
```

Isso permite integrar os recursos sem recriá-los ou duplicar responsabilidade entre repositórios.

---

# 📤 Outputs da infraestrutura Kubernetes

Entre os principais outputs do Terraform estão:

```text
vpc_id
vpc_cidr_block
public_subnet_a_id
public_subnet_b_id
eks_cluster_name
eks_cluster_endpoint
ecr_repository_url
```

Esses outputs podem ser consumidos por outros states Terraform.

---

# 📤 Outputs do API Gateway

O Terraform específico do Gateway disponibiliza:

```text
api_gateway_id
api_gateway_url
```

Exemplo:

```bash
terraform output api_gateway_url
```

Retorno esperado:

```text
https://xxxxxxxx.execute-api.us-east-1.amazonaws.com
```

Essa URL passa a ser a entrada principal para consumo das APIs.

---

# 🚀 CI/CD

Este repositório possui pipelines independentes para os dois conjuntos de infraestrutura.

## Pipeline `terraform.yml`

Responsável pela infraestrutura:

```text
VPC
EKS
EC2 Node Group
ECR
Metrics Server
```

Fluxo simplificado:

```text
Checkout
   ↓
AWS Credentials
   ↓
Terraform Setup
   ↓
terraform fmt
   ↓
terraform init
   ↓
terraform validate
   ↓
terraform plan
   ↓
terraform apply
   ↓
configura kubectl
   ↓
instala Metrics Server
```

Em Pull Requests são executadas validações e `terraform plan`.

O `terraform apply` é executado após merge/push na `main`.

---

## Pipeline `api-gateway.yml`

Responsável exclusivamente pelo API Gateway.

Fluxo:

```text
Checkout
   ↓
AWS Credentials
   ↓
Terraform Setup
   ↓
terraform fmt
   ↓
terraform init
   ↓
terraform validate
   ↓
configura kubectl
   ↓
descobre Load Balancer atual
   ↓
terraform plan
   ↓
terraform apply
```

O hostname do Load Balancer não fica fixo no Terraform.

A pipeline obtém dinamicamente o endereço:

```bash
kubectl get svc oficina-api-service \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

e o fornece ao Terraform como:

```text
backend_url
```

Isso é importante porque o endereço do Load Balancer pode mudar após recriação do AWS LAB.

---

# 🧪 Execução manual - infraestrutura EKS

Configure o profile utilizado pelo AWS LAB:

```powershell
$env:AWS_PROFILE="pos"
```

Entre no Terraform principal:

```bash
cd terraform
```

Execute:

```bash
terraform fmt
terraform fmt -check
terraform init
terraform validate
terraform plan
terraform apply
```

---

# 🧪 Execução manual - API Gateway

Antes de aplicar o Gateway, a aplicação precisa estar executando no EKS e possuir um `Service` do tipo `LoadBalancer`.

Obtenha o hostname:

```powershell
$LB_HOST = kubectl get svc oficina-api-service `
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

$BACKEND_URL = "http://$LB_HOST"
```

Entre no Terraform:

```bash
cd terraform-api-gateway
```

Execute:

```powershell
terraform fmt
terraform init
terraform validate

terraform plan `
  -var="backend_url=$BACKEND_URL"

terraform apply `
  -var="backend_url=$BACKEND_URL"
```

---

# 🧭 Ordem de provisionamento do AWS LAB

Após um Reset do ambiente AWS Academy, a ordem recomendada é:

```text
1. oficina-infra-k8s
      ↓
   VPC + EKS + ECR

2. oficina-infra-db
      ↓
   PostgreSQL RDS

3. oficina-auth-lambda
      ↓
   Lambda + Secrets + integração VPC

4. oficina-dinoco
      ↓
   Docker + ECR + Deployment + Service

5. oficina-infra-k8s
   workflow API Gateway
      ↓
   Gateway + integrações
```

O API Gateway é aplicado por último porque depende de:

```text
Lambda existente
+
Load Balancer da aplicação existente
```

---

# 🔎 Comandos úteis Kubernetes

Atualizar o kubeconfig:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name oficina-api-dev-cluster
```

Listar Nodes:

```bash
kubectl get nodes
```

Listar Pods:

```bash
kubectl get pods
```

Listar Services:

```bash
kubectl get svc
```

Ver Deployment:

```bash
kubectl get deployment
```

Ver HPA:

```bash
kubectl get hpa
```

Ver métricas:

```bash
kubectl top nodes
kubectl top pods
```

---

# 🗑️ Destruição do ambiente

Antes de destruir o EKS, remova recursos Kubernetes que criam infraestrutura externa na AWS.

Principalmente o Service `LoadBalancer`:

```bash
kubectl delete service oficina-api-service
```

Confirme:

```bash
kubectl get svc -A
kubectl get ingress -A
```

Somente depois execute o destroy da infraestrutura.

Em ambientes de laboratório AWS Academy, também pode ser utilizado o mecanismo de **Reset do LAB** para limpar todos os recursos temporários do ambiente.

> Em ambientes reais, o ciclo de vida da infraestrutura deve preferencialmente continuar sendo controlado por Infrastructure as Code.

---

# 🔒 Segurança

Nenhuma credencial AWS deve ser versionada no Git.

Os workflows utilizam GitHub Repository Secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
```

Credenciais do banco e chave JWT são armazenadas no AWS Secrets Manager.

Arquivos Terraform locais também não devem ser versionados:

```text
.terraform/
*.tfstate
*.tfstate.*
```

O arquivo:

```text
.terraform.lock.hcl
```

deve ser versionado para manter as versões dos providers reproduzíveis.

---

# 📌 Estado atual

Atualmente a infraestrutura já suporta:

```text
✅ VPC
✅ Subnets
✅ Internet Gateway
✅ Amazon EKS
✅ EC2 Node Group
✅ Amazon ECR
✅ Kubernetes Metrics Server
✅ HPA
✅ Load Balancer da aplicação
✅ AWS API Gateway
✅ Roteamento API Gateway → Auth Lambda
✅ Roteamento API Gateway → Spring Boot/EKS
✅ Terraform Remote State
✅ CI/CD separado para infraestrutura e Gateway
```

Próximas evoluções previstas incluem o fortalecimento da autorização das rotas destinadas aos clientes e integração de observabilidade/monitoramento com New Relic.
