#!/usr/bin/env bash
set -eo pipefail

mkdir -p /state/kube

# 1. Create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi

# 2. Create Kind cluster
if [ ! -f /state/kube/config.yaml ]; then
  kind create cluster -n 5min-idp --kubeconfig /state/kube/config.yaml --config ./setup/kind/cluster.yaml
fi

# connect current container to the kind network
container_name="5min-idp"
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${container_name}")" = 'null' ]; then
  docker network connect "kind" "${container_name}"
fi

# used by humanitec-agent / inside docker to reach the cluster
kubeconfig_docker=/state/kube/config-internal.yaml
kind export kubeconfig --internal  -n 5min-idp --kubeconfig "$kubeconfig_docker"

### Export needed env-vars for terraform
export TF_VAR_humanitec_org=$HUMANITEC_ORG
# Aim for service user if present, otherwise use current user token (max 24h validity)
if [ -n "$HUMANITEC_SERVICE_USER" ]; then
  export TF_VAR_humanitec_token=$HUMANITEC_SERVICE_USER
else
  export TF_VAR_humanitec_token=$(yq -r '.token' ~/.humctl)
fi
# Variables for TLS in Terraform
export TF_VAR_tls_ca_cert=$TLS_CA_CERT
export TF_VAR_tls_cert_string=$TLS_CERT_STRING
export TF_VAR_tls_key_string=$TLS_KEY_STRING
# Kubeconfig for Terraform
export TF_VAR_kubeconfig=$kubeconfig_docker

terraform -chdir=setup/terraform init -upgrade
terraform -chdir=setup/terraform apply -auto-approve

# Create Gitea Runner for Actions CI
RUNNER_TOKEN=""
while [[ -z $RUNNER_TOKEN ]]; do
  response=$(curl -k -s -X 'GET' 'https://5min-idp-control-plane/api/v1/admin/runners/registration-token' -H 'accept: application/json' -H 'authorization: Basic NW1pbmFkbWluOjVtaW5hZG1pbg==')
  if [[ $response == *"token"* ]]; then
    RUNNER_TOKEN=$(echo $response | jq -r '.token')
  fi
  sleep 1
done

# Start Gitea Runner
docker volume create gitea_runner_data
docker create \
    --name gitea_runner \
    -v gitea_runner_data:/data \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e CONFIG_FILE=/config.yaml \
    -e GITEA_INSTANCE_URL=https://5min-idp-control-plane \
    -e GITEA_RUNNER_REGISTRATION_TOKEN=$RUNNER_TOKEN \
    -e GITEA_RUNNER_NAME=local \
    -e GITEA_RUNNER_LABELS=local \
    --network kind \
    gitea/act_runner:latest
sed 's|###ca-certficates.crt###|'"$TLS_CA_CERT"'|' setup/gitea/config.yaml > setup/gitea/config.done.yaml
docker cp setup/gitea/config.done.yaml gitea_runner:/config.yaml
docker start gitea_runner

# Create Gitea org and Backstage clone with configuration
curl -k -X 'POST' \
  'https://5min-idp-control-plane/api/v1/orgs' \
  -H 'accept: application/json' \
  -H 'authorization: Basic NW1pbmFkbWluOjVtaW5hZG1pbg==' \
  -H 'Content-Type: application/json' \
  -d '{
  "repo_admin_change_team_access": true,
  "username": "5minorg",
  "visibility": "public"
}'
curl -k -X 'POST' \
  'https://5min-idp-control-plane/api/v1/repos/migrate' \
  -H 'accept: application/json' \
  -H 'authorization: Basic NW1pbmFkbWluOjVtaW5hZG1pbg==' \
  -H 'Content-Type: application/json' \
  -d '{
  "clone_addr": "https://github.com/humanitec-architecture/backstage.git",
  "mirror": false,
  "private": false,
  "repo_name": "backstage",
  "repo_owner": "5minorg"
}'
curl -k -X 'POST' \
  'https://5min-idp-control-plane/api/v1/orgs/5minorg/actions/variables/CLOUD_PROVIDER' \
  -H 'accept: application/json' \
  -H 'authorization: Basic NW1pbmFkbWluOjVtaW5hZG1pbg==' \
  -H 'Content-Type: application/json' \
  -d '{
  "value": "5min"
}'
curl -k -X 'POST' \
  'https://5min-idp-control-plane/api/v1/orgs/5minorg/actions/variables/HUMANITEC_ORG_ID' \
  -H 'accept: application/json' \
  -H 'authorization: Basic NW1pbmFkbWluOjVtaW5hZG1pbg==' \
  -H 'Content-Type: application/json' \
  -d '{
  "value": "'$HUMANITEC_ORG'"
}'
humanitec_app_backstage=$(terraform -chdir=setup/terraform output -raw humanitec_app_backstage)
curl -k -X 'POST' \
  'https://5min-idp-control-plane/api/v1/orgs/5minorg/actions/variables/HUMANITEC_APP_ID' \
  -H 'accept: application/json' \
  -H 'authorization: Basic NW1pbmFkbWluOjVtaW5hZG1pbg==' \
  -H 'Content-Type: application/json' \
  -d '{
  "value": "'$humanitec_app_backstage'"
}'
### TODO -> Use from env if present instead of extracting
curl -k -X 'PUT' \
  'https://5min-idp-control-plane/api/v1/orgs/5minorg/actions/secrets/HUMANITEC_TOKEN' \
  -H 'accept: application/json' \
  -H 'authorization: Basic NW1pbmFkbWluOjVtaW5hZG1pbg==' \
  -H 'Content-Type: application/json' \
  -d '{
  "data": "'$TF_VAR_humanitec_token'"
}'

# 3. Add the registry config to the nodes
#
# This is necessary because localhost resolves to loopback addresses that are
# network-namespace local.
# In other words: localhost in the container is not localhost on the host.
#
# We want a consistent name that works from both ends, so we tell containerd to
# alias localhost:${reg_port} to the registry container when pulling images
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes -n 5min-idp); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

# 4. Connect the registry to the cluster network if not already connected
# This allows kind to bootstrap the network but ensures they're on the same network
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# 5. Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo ""
echo ">>>> Everything prepared, ready to deploy application."
