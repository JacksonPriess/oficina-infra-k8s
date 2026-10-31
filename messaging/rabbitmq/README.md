# RabbitMQ persistente no EKS — Oficina Dinoco

## Escopo

Uma instancia RabbitMQ no mesmo EKS das aplicacoes. 
StatefulSet de uma replica, Service ClusterIP, PVC EBS gp3 criptografado de 5 GiB, configuracao e probes.

Nao e um cluster RabbitMQ com alta disponibilidade. 
Nao escale replicas para 3:

isso exigiria configuracao de descoberta/formacao de cluster e outro planejamento.

O ambiente desta entrega sera criado do zero. 

O projeto de infraestrutura continua dono de VPC/EKS/ECR/storage/mensageria; 

os repositorios das APIs continuam donos dos seus Deployments, Services, HPA e respectivos segredos.

## Arquivos

| Arquivo | Papel |
|---|---|
| terraform/storage.tf | Launch Template dos nodes e add-on gerenciado EBS CSI |
| terraform/variables.tf | Versao opcional do add-on e role IRSA existente opcional |
| terraform/eks.tf | Associa o Launch Template ao node group |
| terraform/outputs.tf | Expoe a versao instalada do driver |
| messaging/rabbitmq/storageclass.yaml | Volume gp3, criptografia, criacao por demanda e retencao |
| messaging/rabbitmq/service.yaml | Service das aplicacoes e Service headless do StatefulSet |
| messaging/rabbitmq/configmap.yaml | Configuracao operacional do broker |
| messaging/rabbitmq/statefulset.yaml | Broker, probes e volumeClaimTemplates |
| scripts/deploy-rabbitmq.sh | Preflight, Secret, aplicacao e verificacao do rollout |
| .github/workflows/rabbitmq.yml | Validacao em PR; deploy manual/main ou apos Terraform |

O PVC e gerado pelo volumeClaimTemplates: data-rabbitmq-0. Nao ha um segundo
manifesto pvc.yaml para evitar criar um volume que nao e utilizado pelo Pod.

## Dependencia de permissoes no LAB

O EBS CSI precisa criar, consultar, marcar, anexar e remover volumes EBS.
No modo padrao desta entrega utiliza a role dos nodes, atualmente LabRole.
O Launch Template exige IMDSv2 e hop limit 2 para permitir acesso do controller
as credenciais do instance profile. Isso NAO acrescenta permissoes a LabRole.

As permissoes efetivas da sua conta nao foram inspecionadas. Se a LabRole nao
autorizar as operacoes necessarias, o PVC falhara com UnauthorizedOperation ou
AccessDenied. O nome LabRole, sozinho, nao prova essas permissoes. Sem permissao
de criar/anexar volumes, nao existe ajuste apenas no YAML que resolva.

Fora do LAB, prefira uma identidade dedicada do driver (IRSA ou Pod Identity),
com privilegios limitados. O modo de instance profile torna as credenciais da
role dos nodes acessiveis a Pods que alcancem IMDS. Nao foi criada nem alterada
nenhuma policy ou role IAM nesta entrega.

ebs_csi_service_account_role_arn aceita uma role IRSA EXISTENTE e preparada
(OIDC, trust e policy corretos). Nao preencha com a LabRole apenas pelo nome:
uma role EC2 nao e automaticamente uma role IRSA. Pod Identity e outra opcao,
mas sua configuracao nao foi incluida neste incremento.

addon_version null seleciona o padrao compativel que a AWS oferece para o EKS.
O output ebs_csi_addon_version permite consultar e depois fixar a versao validada.
Nao fixamos uma versao de add-on sem conhecer a versao EKS efetivamente criada.

ATENCAO: associar Launch Template pode substituir um node group que ja existe
sem template. Esta entrega assume infraestrutura nova. Se houver recursos
antigos, revise o terraform plan antes de aplicar; nao aplicar automaticamente
um plano de substituicao ao ambiente com dados. Um add-on ja instalado fora
deste Terraform deve ser reconciliado/importado, nao instalado novamente.

## 1. Incorporar os arquivos e validar Terraform

Na pasta terraform, usando as credenciais do LAB:

```powershell
terraform fmt
terraform init
terraform validate
terraform plan
```

O state bucket precisa existir conforme o bootstrap atual. Para ambiente vazio,
o plano inclui VPC, EKS, nodes com Launch Template, os ECRs e o add-on EBS CSI.
Revise o plano e siga o workflow existente de infraestrutura para aplicar.

A pipeline atual aplica somente em push/merge na main. A nova pipeline de
RabbitMQ pode executar manualmente; depois de merge na main tambem e acionada
apos sucesso de um push no workflow "CI/CD - Infra Kubernetes". Validacoes de
PR nao implantam recursos. Alteracoes so em messaging tambem disparam deploy
em push na main, desde que o cluster/driver ja estejam prontos.

## 2. Criar GitHub Repository Secrets em oficina-infra-k8s

Os tres Secrets AWS ja utilizados permanecem. Acrescente:

| Secret | Valor |
|---|---|
| RABBITMQ_USERNAME | Usuario administrativo do broker, por exemplo oficina |
| RABBITMQ_PASSWORD | Senha aleatoria propria do ambiente AWS |
| RABBITMQ_ERLANG_COOKIE | Segredo aleatorio estavel, alfanumerico, por exemplo 32 bytes em hexadecimal |

Mantenha os mesmos valores ao reexecutar a pipeline. Nao grave as senhas nos
manifestos nem no Git. As APIs devem receber usuario/senha correspondentes,
mas nao precisam do cookie Erlang. Futuramente e possivel separar usuarios de
publicacao e consumo por permissoes no vhost.

Exemplo para gerar CADA segredo em PowerShell (execute separadamente para
senha e cookie e guarde cada resultado no Secret correspondente):

```powershell
$bytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
([System.BitConverter]::ToString($bytes)).Replace("-", "").ToLowerInvariant()
```

## 3. Implantar pelo workflow

Em Actions, execute Deploy RabbitMQ depois da infraestrutura. O workflow cria
rabbitmq-secret no namespace default e aplica os manifests com kubectl.
O namespace default preserva o contexto atual dos Deployments das APIs.
Nao sao criados LoadBalancers nem abertura de portas publicas do broker.

O workflow faz verificacao de sintaxe Bash/YAML, nao uma validacao completa de
schema Kubernetes em PR. A API Kubernetes valida os objetos durante o apply.
O script exige o CSI driver e aguarda rollout, PVC Bound e broker sem alarmes.

Se o deploy de mensageria disparar antes do novo cluster/CSI terminar, ele pode
falhar no preflight. O workflow_run apos sucesso da infraestrutura executa de
novo; tambem e possivel reexecutar manualmente depois de conferir o driver.

## 4. Conferir

```powershell
aws eks update-kubeconfig --region us-east-1 --name oficina-api-dev-cluster
kubectl get csidriver ebs.csi.aws.com
kubectl get pods -n kube-system -l app=ebs-csi-controller
kubectl get storageclass rabbitmq-gp3
kubectl get statefulset rabbitmq -n default
kubectl get pod rabbitmq-0 -n default
kubectl get pvc data-rabbitmq-0 -n default
kubectl get service rabbitmq -n default
kubectl exec -n default rabbitmq-0 -- rabbitmq-diagnostics -q check_running
```

Esperado: Pod 1/1 Ready; PVC Bound; Service ClusterIP.
WaitForFirstConsumer pode manter o PVC Pending ate o primeiro Pod consumidor
ser agendado; nao e erro por si so. A zona do volume sera escolhida junto do
agendamento do Pod. Depois de criado, EBS e zonal: o Pod precisa de node nessa
zona. O node group atual abrange duas zonas, mas nao garante node ativo em
ambas. Se o unico node for substituido em outra zona, pode ser necessario
repor capacidade na zona do volume. Nao apague o PVC para resolver isso.

Para acesso administrativo, em um terminal separado:

```powershell
kubectl port-forward -n default service/rabbitmq 15672:15672
```

Abra http://localhost:15672 e use as credenciais configuradas no workflow.

## 5. Configuracao das APIs (proxima etapa de deploy das aplicacoes)

Dentro do mesmo namespace:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: oficina-api-config
data:
  SPRING_PROFILES_ACTIVE: "aws,rabbit"
  RABBITMQ_HOST: "rabbitmq"
  RABBITMQ_PORT: "5672"
  # Preservar as demais configuracoes de banco, API e observabilidade.
```

Usar a mesma conexao no ConfigMap do Catalogo, com nome proprio.
RABBITMQ_USERNAME/PASSWORD entram nos Secrets de cada aplicacao.
Profile aws e proposto para evitar o seed dev; deve ser preparado na etapa
das aplicacoes. O profile rabbit existente e o que carrega AMQP.
Em outro namespace: rabbitmq.default.svc.cluster.local.

Este pacote NAO modifica os repositorios das APIs. Nao conecta automaticamente
as aplicacoes ao broker novo. E nao transfere mensagens do Docker local para
a AWS; a AWS inicia com volume vazio. Exchanges/filas/DLQ sao declarados pelas
aplicacoes quando se conectarem, conforme seus beans ProdutoRabbitConfig.

## Persistencia e recuperacao

- Mensagens precisam ser persistentes e filas duraveis (o Java ja foi escrito
  com essas propriedades). Outbox/inbox continuam necessarias.
- O Pod monta /var/lib/rabbitmq no EBS; nome do node rabbit@rabbitmq-0 fica estavel.
- Reiniciar o Pod reaproveita o PVC. Nao e necessario recriar credenciais.
- Deletar apenas o StatefulSet preserva seus PVCs pelo comportamento padrao.
- ReclaimPolicy Retain preserva o volume mesmo se o PVC for excluido. A
  recuperacao/revinculacao entao e administrativa; nao e automatica.
- Destruir/resetar a conta LAB pode remover os recursos AWS independentemente
  dessa politica Kubernetes. Nao e uma estrategia de backup externo.
- Nao excluir a role, cluster ou VPC antes de remover/reconciliar volumes e
  anexos. EBS retido pode continuar consumindo creditos apos remover o broker.
- Usuario/senha padrao so inicializam o banco do RabbitMQ em volume vazio.
  Alterar Secret nao troca a senha gravada no broker. O script recusa alteracoes
  divergentes para evitar desconectar APIs ou invalidar o cookie. Rotacao deve
  ser coordenada com rabbitmqctl/API administrativa e consumidores.
- Atualizacoes de config geram rollout pelo hash aplicado no Pod template.
  Mantivemos rabbitmq:4.1-management para alinhar ao Compose ja utilizado;
  essa tag e mutavel. Fixe patch/digest validado antes de exigir reproducao binaria.
- Nao incluimos TLS de AMQP neste incremento. Porta5672 permanece apenas no
  cluster. TLS e restricoes finas de rede sao uma evolucao distinta; ClusterIP
  por si so nao restringe quais Pods internos conseguem conectar.

## Diagnostico de falhas

```powershell
kubectl describe pvc data-rabbitmq-0 -n default
kubectl describe pod rabbitmq-0 -n default
kubectl logs rabbitmq-0 -n default --tail=100
kubectl logs -n kube-system deployment/ebs-csi-controller -c ebs-plugin --tail=100
kubectl get events -n default --sort-by=.lastTimestamp
```

- UnauthorizedOperation/AccessDenied: permissoes EBS/KMS/role no LAB.
- Credenciais ausentes no driver: conferir role dos nodes, IMDS e add-on.
- Pending por memoria/CPU: medir capacidade; o broker reserva512Mi, limitado1Gi.
  Duas JVMs com New Relic, broker, CSI e nri-bundle podem exceder um t3.medium.
  Esta entrega nao aumenta nodes automaticamente nem instala Cluster Autoscaler.
- Pending por zona: conferir zona do EBS e nodes disponiveis.
- ImagePullBackOff: conferir saida de rede para baixar a imagem Docker Hub.

## Limites da verificacao desta entrega

Foram verificados localmente sintaxe YAML, sintaxe Bash, relacionamentos
estaticos de Services/labels/Secret/volume e cenarios do script com kubectl
simulado. Isso nao prova validade do schema na versao real do cluster, IAM,
montagem EBS, pull da imagem, saude do RabbitMQ nem persistencia em execucao.
Terraform, kubectl, Helm e Docker nao estao disponiveis neste ambiente.
Nenhuma alteracao foi aplicada na AWS ou enviada ao GitHub.

## Referencias

- https://www.rabbitmq.com/docs/install-kubernetes-diy
- https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
- https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md
- https://kubernetes.io/docs/concepts/storage/storage-classes/
