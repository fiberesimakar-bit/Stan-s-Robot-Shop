#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OBS="$ROOT/K8s/observability"
EXPECTED_CONTEXT="kind-robot-shop"
PROMETHEUS_CHART_VERSION="69.8.2"

if ! command -v helm >/dev/null 2>&1 || ! command -v kubectl >/dev/null 2>&1 || ! command -v kind >/dev/null 2>&1; then
  printf '%s\n' "helm, kubectl, and kind must be installed." >&2
  exit 1
fi

context="$(kubectl config current-context)"
if [[ "$context" != "$EXPECTED_CONTEXT" ]]; then
  printf 'Refusing install: current context is %s, expected %s.\n' "$context" "$EXPECTED_CONTEXT" >&2
  exit 1
fi

if ! kind get clusters | grep -Fxq robot-shop; then
  printf '%s\n' "Refusing install: Kind does not list the robot-shop cluster. Resolve the Docker/Kind inventory mismatch first." >&2
  exit 1
fi

if [[ "${ALLOW_CLUSTER_CHANGES:-}" != "YES" ]]; then
  printf '%s\n' "This script installs cluster resources. Review K8s/observability/README.md and rerun with ALLOW_CLUSTER_CHANGES=YES only after explicit approval." >&2
  exit 1
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update prometheus-community
helm upgrade --install robot-observability prometheus-community/kube-prometheus-stack \
  --version "$PROMETHEUS_CHART_VERSION" \
  --namespace monitoring \
  --create-namespace \
  --values "$OBS/prometheus/values.yaml" \
  --wait \
  --timeout 10m

kubectl apply -f "$OBS/prometheus/blackbox.yaml"
kubectl apply -f "$OBS/prometheus/robot-shop-rules.yaml"
kubectl create configmap robot-shop-dashboard \
  --namespace monitoring \
  --from-file=robot-shop-capstone-2.json="$OBS/prometheus/robot-shop-dashboard.json" \
  --dry-run=client \
  --output=yaml \
  --labels=grafana_dashboard=1 | kubectl apply -f -

kubectl apply -f "$OBS/logging/loki.yaml"
kubectl apply -f "$OBS/logging/fluent-bit.yaml"
kubectl apply -f "$OBS/tracing/jaeger.yaml"

if kubectl get secret robot-shop-slack --namespace monitoring >/dev/null 2>&1; then
  kubectl apply -f "$OBS/prometheus/alertmanager-config.yaml"
else
  printf '%s\n' "Slack route not installed: create the robot-shop-slack Secret as documented, then apply alertmanager-config.yaml." >&2
fi

kubectl rollout status deployment/blackbox-exporter --namespace monitoring --timeout=5m
kubectl rollout status deployment/loki --namespace observability --timeout=5m
kubectl rollout status daemonset/fluent-bit --namespace monitoring --timeout=5m
kubectl rollout status deployment/jaeger --namespace observability --timeout=5m

printf '%s\n' "Observability resources installed. Follow the verification commands in K8s/observability/README.md; installation alone is not acceptance evidence."
