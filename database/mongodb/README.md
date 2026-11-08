# MongoDB do catálogo de serviços

O catálogo de serviços da Oficina Mecânica Dinoco usa MongoDB 8. O banco roda com uma réplica no Amazon EKS e usa um volume EBS gp3 criptografado de 5 GiB. O Service `mongodb-servico` é interno ao cluster. O StatefulSet mantém a identidade do Pod e seu vínculo com o volume. A política `Retain` mantém o volume quando o PVC é removido. Verifique volumes retidos ao desmontar o laboratório.

O ambiente começa vazio e recebe os serviços pela API do catálogo. A imagem inicializa o administrador e um usuário de aplicação com permissão `readWrite` apenas no banco `oficina_servicos_db`.

## Provisionamento

1. Configure os GitHub Actions Secrets `MONGODB_SERVICO_ADMIN_PASSWORD` e `MONGODB_SERVICO_APP_PASSWORD` neste repositório. Use senhas distintas.
2. Após o merge, aguarde o workflow **CI/CD - Infra Kubernetes** concluir o Terraform. Ele cria o repositório ECR `oficina-servico-dev-repo` e mantém o driver de volumes EBS do cluster.
3. Execute **Deploy MongoDB do Catálogo de Serviços** manualmente na branch `main`. O workflow cria os Secrets Kubernetes, aplica os manifestos e aguarda a prontidão do banco.

Confirmar o resultado no cluster.

```bash
kubectl get pod mongodb-servico-0 -n default
kubectl get pvc data-mongodb-servico-0 -n default
kubectl get service mongodb-servico -n default
aws ecr describe-repositories --repository-names oficina-servico-dev-repo --region us-east-1
```

O Pod deve estar `Ready`, o PVC deve estar `Bound` e o Service deve ser do tipo `ClusterIP`. A verificação de prontidão autentica com o usuário da aplicação e testa acesso ao banco do catálogo.

## Contrato para o deploy do catálogo

O Deployment da API, no mesmo namespace, deve ler `MONGODB_URI` da chave de mesmo nome no Secret `catalogo-servico-mongodb` via `secretKeyRef`. A URI aponta para `mongodb-servico:27017` e usa `oficina_servicos_db` como banco de autenticação. A senha é codificada no formato da URI durante o provisionamento. A chave HTTP da API será configurada no deploy da aplicação.

As credenciais inicializam um volume vazio. Os Secrets são imutáveis para evitar divergência entre o cluster e o banco já inicializado. Uma rotação exige alterar as credenciais no MongoDB e substituir os Secrets de forma coordenada. Preserve o PVC.
