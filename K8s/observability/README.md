# Capstone 2 Observability

This directory contains **local, reproducible configuration**, not evidence of a successful cluster deployment. The install script deliberately refuses to proceed unless the current Kubernetes context is `kind-robot-shop`, Kind itself lists the `robot-shop` cluster, and `ALLOW_CLUSTER_CHANGES=YES` is set. Do not use it until the Docker/Kind inventory discrepancy is resolved and a cluster rollout is approved.

## Components and versions

| Component | Configuration | Version |
| --- | --- | --- |
| kube-prometheus-stack | `prometheus/values.yaml` | Helm chart `69.8.2` |
| Blackbox Exporter | `prometheus/blackbox.yaml` | `v0.25.0` |
| Loki | `logging/loki.yaml` | `3.4.2` |
| Fluent Bit | `logging/fluent-bit.yaml` | `3.2.10` |
| Jaeger all-in-one | `tracing/jaeger.yaml` | `1.65.0` |

Versions are pinned to make the setup repeatable. Recheck upstream compatibility before changing these pins. The manifests are intended for a single-node local learning cluster, not production. Loki and Jaeger use ephemeral storage; their data is lost if their Pods are replaced.

## Prerequisites and installation order

1. Resolve the Kind/Docker inventory inconsistency. Confirm `kubectl config current-context` is `kind-robot-shop`, `kind get clusters` lists `robot-shop`, and `kubectl get nodes` shows the expected Ready node. Do not create or recreate a cluster as a troubleshooting shortcut.
2. Confirm the Robot Shop deployment and its data-safety plan. MySQL is currently crash-looping without a PVC; do not replace its Pod or claim the application is healthy.
3. Install Helm, kubectl, Kind, Python 3 with PyYAML, and access to the pinned container images/chart repository.
4. Run local-only checks:

   ```sh
   bash K8s/observability/scripts/validate.sh
   ```

   Expected: Helm lint succeeds (the upstream chart may warn that a chart icon is recommended), the dashboard/config assertions pass, and the script exits zero. This does not contact or mutate Kubernetes.
5. Review the rendered templates and the resource requests against the available Kind node capacity. The kube-prometheus-stack can be resource-intensive on a single-node cluster. Do not change workload limits to make it fit without measuring capacity and approval.
6. After explicit approval only, install observability:

   ```sh
   ALLOW_CLUSTER_CHANGES=YES bash K8s/observability/scripts/install-observability.sh
   ```

   The script installs kube-prometheus-stack, Blackbox Exporter, Loki, Fluent Bit, Jaeger, the dashboard, and Prometheus rules. It does not change Robot Shop application workloads. It exits without changes when `kind get clusters` does not list `robot-shop`.
7. Configure Slack separately (see below) and provide the instructor's original OpenTelemetry Collector configuration before completing the trace requirement.

## What is measured

- The Blackbox Exporter probes `GET http://web.default.svc.cluster.local:8080/` every 30 seconds, with a five-second timeout. The SLI is successful probes divided by scheduled probes over a rolling 30-day window; non-2xx responses and timeouts are failures.
- A 99.0% SLO allows a 1.0% error budget: 7.2 hours (7 hours, 12 minutes) in a 30-day window. No maintenance exclusions are currently specified.
- Synthetic request rate, error ratio, and probe latency are shown separately from application-wide HTTP metrics. Local source instrumentation now adds route-labelled request counters, status codes, and duration histograms to cart and payment. The changed images must be rebuilt and made available to Kind before those panels return application data. Other services remain uninstrumented.
- Kubernetes panels use kube-state-metrics and cAdvisor metrics. They will show no data if the stack cannot scrape these sources.

### Rebuild the instrumented service images

These build commands create local Docker images only; they do not change Kubernetes. Run them after reviewing the source changes and when Docker has sufficient disk/build capacity:

```sh
docker build --tag robotshop/rs-cart:latest ./cart
docker build --tag robotshop/rs-payment:latest ./payment
```

After the Docker/Kind inventory is reconciled and the owner approves cluster changes, load the images into the intended Kind cluster:

```sh
kind load docker-image robotshop/rs-cart:latest robotshop/rs-payment:latest --name robot-shop
```

The chart's existing global image tag remains `latest`. Making the new image contents active requires an approved Pod-template rollout. Do not apply a full chart upgrade until the MySQL ephemeral-data risk has been addressed; that chart contains the checksum change that will intentionally replace its Pod.

## Grafana dashboard

The dashboard source is [robot-shop-dashboard.json](./prometheus/robot-shop-dashboard.json). The installer creates a ConfigMap from that file with `grafana_dashboard=1`; Grafana's dashboard sidecar provisions it. Verify in Grafana that the dashboard is present, every intended panel has data, and empty panels are understood rather than reported as success.

Useful PromQL checks:

```promql
avg_over_time(probe_success{job="robot-shop-web-probe"}[30d])
1 - avg_over_time(probe_success{job="robot-shop-web-probe"}[5m])
quantile_over_time(0.95, probe_duration_seconds{job="robot-shop-web-probe"}[1h])
kube_deployment_status_replicas_available{namespace="default"}
increase(kube_pod_container_status_restarts_total{namespace="default"}[1h])
```

## Fluent Bit and Loki

Fluent Bit reads container logs from `/var/log/containers`, enriches records with Kubernetes pod labels, normalizes severity into `level`, and sends JSON records to the internal Loki Service. Grafana's Loki datasource is provisioned by the pinned kube-prometheus-stack values file and points to `http://loki.observability.svc.cluster.local:3100`. The intended low-cardinality labels are `service`, `level`, `namespace`, and `job`; Pod IDs stay in the log body/metadata to avoid high-cardinality labels. Service comes from the Robot Shop Pod's `service` label. Unknown severity is explicitly labeled `unknown`.

Example LogQL queries in Grafana Explore:

```logql
{service="payment"}
{service="payment", level="error"}
{namespace="default", level=~"warning|error|critical"}
{service="unknown"}
```

Check that logs are actually returned and their labels are present before claiming this requirement is complete. Loki uses an `emptyDir` with a 2 GiB cap and seven-day retention for this local exercise; it is not durable storage.

## Slack alerting

The Prometheus rules are in `prometheus/robot-shop-rules.yaml`; the Alertmanager route template is in `prometheus/alertmanager-config.yaml`. Replace the GitHub owner/repository/branch placeholders in each alert's `runbook_url` with the real published location of the runbook. Do not leave the placeholders in a submission claiming an active runbook link.

Create a protected local file containing only the Slack incoming webhook URL, restrict its permissions, and create the Kubernetes Secret without putting the URL in Git:

```sh
umask 077
secret_file="$(mktemp)"
trap 'rm -f "$secret_file"' EXIT
chmod 600 "$secret_file"
read -rsp 'Slack webhook URL: ' SLACK_WEBHOOK
printf '%s' "$SLACK_WEBHOOK" > "$secret_file"
unset SLACK_WEBHOOK
kubectl create secret generic robot-shop-slack \
  --namespace monitoring \
  --from-file=slack_api_url="$secret_file"
kubectl apply -f K8s/observability/prometheus/alertmanager-config.yaml
```

Only do this after cluster approval. Never paste the URL in a terminal transcript or evidence. Verify the AlertmanagerConfig is accepted, the alert reaches firing state in Prometheus/Alertmanager, and the expected Slack channel receives the notification. The installer skips the Slack route if the Secret is absent.

## Tracing and instructor-provided configuration

`tracing/jaeger.yaml` provides Jaeger UI and OTLP receiver endpoints (`jaeger.observability.svc.cluster.local:4317` gRPC and `:4318` HTTP). The assignment requires use of the **instructor-provided OpenTelemetry Collector configuration**. That file was not found in the repository/workspace. No substitute Collector configuration is included. Robot Shop source also contains Instana instrumentation, not a verified OpenTelemetry SDK/exporter pipeline.

Obtain the original Collector file and any required endpoint/credentials from the instructor. Preserve its contents and provenance, validate it, deploy it only after approval, then generate a representative storefront request and verify the trace and service/span details in Jaeger. Do not claim tracing works from Jaeger being Ready alone.

## Validation and troubleshooting

Run the local validator before any deployment:

```sh
bash K8s/observability/scripts/validate.sh
```

After an approved install, check:

```sh
kubectl get pods -n monitoring
kubectl get pods -n observability
kubectl get prometheusrules,alertmanagerconfigs -n monitoring
kubectl get daemonset fluent-bit -n monitoring
kubectl logs -n monitoring daemonset/fluent-bit --tail=100
kubectl logs -n observability deployment/loki --tail=100
```

If Prometheus has no web probe target, inspect the Blackbox Exporter target/config, DNS/service endpoints, Prometheus targets, and scrape errors. If logs do not appear, inspect Fluent Bit parser/filter/output errors, RBAC, Loki readiness, and port 3100 connectivity; query `{service="unknown"}` while checking labels. For no traces, obtain/validate the instructor config, check the Collector exporter endpoint and instrumentation, and inspect Collector/Jaeger logs. Never include secret values in captured output.

## Removal / cleanup precautions

No cleanup script is supplied. The Loki `emptyDir` and Jaeger in-memory traces are ephemeral. Removing namespaces or chart releases may delete resources and evidence. Before cleanup, capture required assignment evidence, inspect the exact resources and Helm release, and obtain approval. Never delete MySQL data, PVCs, or the Kind cluster as part of observability cleanup.
