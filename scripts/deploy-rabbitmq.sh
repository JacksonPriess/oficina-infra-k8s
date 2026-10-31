#!/usr/bin/env bash
set -euo pipefail

# Executar na raiz do repositorio, depois de configurar kubeconfig.
K8S_NAMESPACE="${K8S_NAMESPACE:-default}"
export K8S_NAMESPACE

: "${RABBITMQ_USERNAME:?Configure RABBITMQ_USERNAME}"
: "${RABBITMQ_PASSWORD:?Configure RABBITMQ_PASSWORD}"
: "${RABBITMQ_ERLANG_COOKIE:?Configure RABBITMQ_ERLANG_COOKIE}"

kubectl get namespace "$K8S_NAMESPACE" >/dev/null
kubectl get csidriver ebs.csi.aws.com >/dev/null
kubectl rollout status deployment/ebs-csi-controller -n kube-system --timeout=300s

# O usuario/senha padrao so inicializa um volume vazio. Uma alteracao de Secret
# nao altera automaticamente as credenciais persistidas dentro do RabbitMQ.
python3 - <<'PY'
import base64
import json
import os
import subprocess

command = ["kubectl", "get", "secret", "rabbitmq-secret", "-n",
           os.environ["K8S_NAMESPACE"], "--ignore-not-found", "-o", "json"]
raw = subprocess.check_output(command, text=True)
if raw.strip():
    data = json.loads(raw)["data"]
    for key, variable in [("username", "RABBITMQ_USERNAME"),
                          ("password", "RABBITMQ_PASSWORD"),
                          ("erlang-cookie", "RABBITMQ_ERLANG_COOKIE")]:
        previous = base64.b64decode(data.get(key, "")).decode()
        if previous != os.environ[variable]:
            raise SystemExit("Secret RabbitMQ diverge das credenciais fornecidas. "
                             "Execute uma rotacao coordenada; nao apague o PVC.")
PY

kubectl create secret generic rabbitmq-secret \
  -n "$K8S_NAMESPACE" \
  --from-literal=username="$RABBITMQ_USERNAME" \
  --from-literal=password="$RABBITMQ_PASSWORD" \
  --from-literal=erlang-cookie="$RABBITMQ_ERLANG_COOKIE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f messaging/rabbitmq/storageclass.yaml
kubectl apply -n "$K8S_NAMESPACE" -f messaging/rabbitmq/configmap.yaml
kubectl apply -n "$K8S_NAMESPACE" -f messaging/rabbitmq/service.yaml
kubectl apply -n "$K8S_NAMESPACE" -f messaging/rabbitmq/statefulset.yaml

# ConfigMap montado por subPath requer novo Pod para aplicar configuracao.
CONFIG_SHA=$(sha256sum messaging/rabbitmq/configmap.yaml | cut -d ' ' -f1)
kubectl patch statefulset rabbitmq -n "$K8S_NAMESPACE" --type=merge \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"oficina.dinoco/config-sha\":\"$CONFIG_SHA\"}}}}}"

kubectl rollout status statefulset/rabbitmq -n "$K8S_NAMESPACE" --timeout=600s
PVC_PHASE=$(kubectl get pvc data-rabbitmq-0 -n "$K8S_NAMESPACE" -o jsonpath='{.status.phase}')
if [ "$PVC_PHASE" != "Bound" ]; then
  echo "PVC do RabbitMQ nao esta Bound. Verifique os eventos do PVC."
  exit 1
fi
kubectl exec -n "$K8S_NAMESPACE" rabbitmq-0 -- rabbitmq-diagnostics -q check_running
kubectl exec -n "$K8S_NAMESPACE" rabbitmq-0 -- rabbitmq-diagnostics -q check_local_alarms
kubectl get pods,svc,pvc -n "$K8S_NAMESPACE" -l app=rabbitmq
