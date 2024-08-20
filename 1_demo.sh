#!/usr/bin/env bash
set -eo pipefail

echo "Deploying workload"

humanitec_app=$(terraform -chdir=setup/terraform output -raw humanitec_app)

humctl score deploy --app "$humanitec_app" --env 5min-local -f ./score.yaml --wait

workload_host=$(humctl get active-resources --app "$humanitec_app" --env 5min-local -o yaml | yq '.[] | select(.metadata.type == "route") | .status.resource.host')

echo "Waiting for workload to be available"

# manually change the host here as the workload host resolves to localhost, which is not reachable from the container
if curl -I --retry 30 --retry-delay 3 --retry-all-errors --fail \
  --connect-to "$workload_host:30080:5min-idp-control-plane:30080" \
  "http://$workload_host:30080"; then
  echo "Workload available at: http://$workload_host:30080"
else
  echo "Workload not available"
  kubectl get pods --all-namespaces
  kubectl -n "$humanitec_app-development" logs deployment/hello-world
  exit 1
fi
