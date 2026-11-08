#!/usr/bin/env bash
set -euo pipefail

K8S_NAMESPACE="${K8S_NAMESPACE:-default}"

kubectl get namespace "$K8S_NAMESPACE" >/dev/null
kubectl get csidriver ebs.csi.aws.com >/dev/null
kubectl rollout status deployment/ebs-csi-controller -n kube-system --timeout=300s

# A imagem cria os usuarios somente na primeira inicializacao do volume.
# Secrets imutaveis impedem sobrescrever credenciais de um banco ja inicializado.
python3 - <<'PY' | kubectl apply --server-side -n "$K8S_NAMESPACE" -f -
from base64 import b64encode
import json
import os
from urllib.parse import quote

admin = os.environ.get("MONGODB_SERVICO_ADMIN_PASSWORD", "")
app = os.environ.get("MONGODB_SERVICO_APP_PASSWORD", "")
if not admin.strip() or not app.strip() or admin == app:
    raise SystemExit("Configure senhas distintas e nao vazias para o MongoDB.")

def secret(name, values):
    return {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": name},
        "type": "Opaque",
        "immutable": True,
        "data": {key: b64encode(value.encode()).decode() for key, value in values.items()},
    }

uri = (f"mongodb://catalogo_servico_app:{quote(app, safe='')}@mongodb-servico:27017/"
       "oficina_servicos_db?authSource=oficina_servicos_db")
print(json.dumps({"apiVersion": "v1", "kind": "List", "items": [
    secret("mongodb-servico-admin", {"password": admin}),
    secret("catalogo-servico-mongodb", {"password": app, "MONGODB_URI": uri}),
]}))
PY

kubectl apply -f database/mongodb/storageclass.yaml
kubectl apply -n "$K8S_NAMESPACE" -f database/mongodb/configmap.yaml \
  -f database/mongodb/service.yaml -f database/mongodb/statefulset.yaml
kubectl rollout status statefulset/mongodb-servico -n "$K8S_NAMESPACE" --timeout=600s
kubectl get pod mongodb-servico-0 -n "$K8S_NAMESPACE"
kubectl get pvc data-mongodb-servico-0 -n "$K8S_NAMESPACE"
kubectl get service mongodb-servico -n "$K8S_NAMESPACE"
