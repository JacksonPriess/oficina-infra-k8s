# RabbitMQ no EKS

O RabbitMQ transporta eventos de estoque e mensagens da Saga de pagamento entre os serviços da Oficina Dinoco. O broker é implantado pela infraestrutura. As aplicações declaram exchanges, filas e bindings conforme seus contratos.

| Fluxo | Exchange | Produtor → consumidor |
| --- | --- | --- |
| Cadastro de produto e inicialização de estoque | `oficina.produtos` | Catálogo de produtos → núcleo |
| Solicitação de cobrança ou estorno | `oficina.financeiro` | Núcleo → financeiro |
| Confirmação de cobrança, aprovação ou estorno | `oficina.financeiro` | Financeiro → núcleo |

O provedor simulado é acessado por HTTP pelo financeiro. As regras da Saga, o contrato das mensagens e o tratamento de compensação pertencem aos repositórios das aplicações. [Núcleo](https://github.com/JacksonPriess/oficina-dinoco) · [Financeiro](https://github.com/JacksonPriess/oficina-financeiro-api)

## Recursos

| Recurso | Configuração |
| --- | --- |
| StatefulSet `rabbitmq` | Uma réplica com a imagem `rabbitmq:4.1-management` |
| Service `rabbitmq` | Acesso interno nas portas `5672` para AMQP e `15672` para administração |
| Service `rabbitmq-headless` | Identidade de rede do Pod do StatefulSet |
| ConfigMap `rabbitmq-config` | Configuração de listeners, logs e alarmes de memória e disco |
| StorageClass `rabbitmq-gp3` | Volume Amazon EBS gp3 criptografado, provisionado pelo driver EBS CSI |
| PVC `data-rabbitmq-0` | Solicitação de volume de 5 GiB montado em `/var/lib/rabbitmq` |
| Secret `rabbitmq-secret` | Chaves `username`, `password` e `erlang-cookie` |

O volume mantém os dados do broker durante a recriação do Pod. A StorageClass usa `WaitForFirstConsumer` para provisionar o volume na zona do nó escolhido e `Retain` para preservar o volume quando a solicitação é removida. Uma réplica atende ao ambiente de laboratório e implica indisponibilidade durante a recuperação desse Pod.

## Implantação

O cluster EKS deve ter um nó disponível e o driver EBS CSI funcionando. O workflow [Deploy RabbitMQ](../../.github/workflows/rabbitmq.yml) valida os manifestos e executa [deploy-rabbitmq.sh](../../scripts/deploy-rabbitmq.sh).

Configure no GitHub Actions os Repository Secrets abaixo, além das credenciais AWS utilizadas pelo repositório.

| Secret no GitHub | Uso |
| --- | --- |
| `RABBITMQ_USERNAME` | Usuário inicial do broker |
| `RABBITMQ_PASSWORD` | Senha inicial do broker |
| `RABBITMQ_ERLANG_COOKIE` | Credencial de comunicação do nó Erlang |

O script verifica o driver de armazenamento, publica o Secret e aplica os manifestos. Em seguida aguarda o rollout, confirma que o PVC está `Bound` e executa diagnósticos do broker. Alterações no ConfigMap acionam a recriação do Pod por meio de uma anotação com o hash da configuração.

As credenciais iniciais são aplicadas quando o volume está vazio. O script rejeita valores que divergem do Secret existente. A rotação de credenciais deve coordenar a atualização do usuário no broker, do Secret e das aplicações consumidoras.

## Configuração das aplicações

No mesmo namespace, as aplicações usam `RABBITMQ_HOST=rabbitmq` e `RABBITMQ_PORT=5672`. O núcleo, o catálogo e o financeiro devem usar o mesmo broker e virtual host. Nos Deployments, as variáveis `RABBITMQ_USERNAME` e `RABBITMQ_PASSWORD` devem referenciar as chaves `username` e `password` de `rabbitmq-secret`. Nas aplicações Spring, o perfil `rabbit` habilita a integração.

## Operação e diagnóstico

Confirme que o Pod está pronto e que o volume foi associado.

```bash
kubectl -n default get statefulset,pods,svc,pvc -l app=rabbitmq
kubectl -n default exec rabbitmq-0 -- rabbitmq-diagnostics -q check_running
kubectl -n default exec rabbitmq-0 -- rabbitmq-diagnostics -q check_local_alarms
```

Use o encaminhamento de porta para acessar o painel em [localhost:15672](http://localhost:15672) com as credenciais do broker.

```bash
kubectl -n default port-forward svc/rabbitmq 15672:15672
```

Consulte as filas e seus consumidores com o comando abaixo.

```bash
kubectl -n default exec rabbitmq-0 -- rabbitmqctl list_queues name consumers messages_ready messages_unacknowledged
```

- **PVC pendente:** consulte os eventos do PVC e do Pod e verifique o estado do driver EBS CSI.
- **Fila sem consumidores:** verifique o perfil `rabbit`, as credenciais e os logs da aplicação que deveria consumir.
- **Mensagens em uma DLQ:** confira os logs do consumidor e o contrato da mensagem antes de decidir pelo reprocessamento. Uma DLQ é uma fila que recebe mensagens rejeitadas conforme a configuração de cada aplicação.
- **Fila vazia:** a mensagem pode já ter sido consumida. Confirme o efeito no estoque ou na Saga.

[Voltar ao README de infraestrutura](../../README.md)
