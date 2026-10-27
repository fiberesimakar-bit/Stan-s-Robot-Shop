# DevOps Capstone 2 — Robot Shop Submission Package

**Submission status: Not yet fully verified.** Local configuration and documentation are prepared, but cluster installation, searchable logs, a trace, Slack alert delivery, the incident drill, and healthy application operation have not been demonstrated. This report follows the supplied `CAPSTONE PROJECT.pdf`; no separate rubric file was found in the workspace.

## Project overview and architecture

Robot Shop is a Helm-managed Kubernetes microservices store. Its workload set includes web, catalogue, cart, user, payment, shipping, ratings, dispatch, MongoDB, MySQL, Redis, and RabbitMQ. Capstone 2 adds:

- Prometheus/Grafana with a Robot Shop dashboard, a Blackbox synthetic probe, and SLO alerts.
- Fluent Bit collection and Kubernetes metadata enrichment, with Loki storage/querying.
- Jaeger and a local OpenTelemetry Collector Contrib template for OTLP traces. The template is not instructor-provided, and Robot Shop OTLP instrumentation remains incomplete.
- A measurable availability objective, error-budget policy, Slack alert route, runbook, instructor-led incident drill, and evidence-based blameless postmortem.

The observability configurations target a local Kind cluster and use pinned component versions. Loki and Jaeger storage are intentionally ephemeral for this local demo. They are not production-hardened.

The brief focuses on healthy `web`, `catalogue`, `cart`, and `payment` services, with the other Robot Shop services running, and steady traffic from the supplied load generator. Its grading weights are 50% working system, 30% automation/documentation, and 20% demo/Q&A; runtime and demo evidence is still pending.

## Requirement completion matrix

Status meanings: **Local complete** means the artifact exists and its stated static checks pass; it does not imply runtime acceptance. **Pending runtime** requires approved deployment and evidence. **Blocked** requires instructor input, a safe cluster, or explicit approval.

| Brief requirement / deliverable | Repository resource | Work completed | Validation evidence | Remaining gap | Can finish locally? |
|---|---|---|---|---|
| Deploy Robot Shop and generate steady load; focus on web, catalogue, cart, and payment while other services run | `K8s/helm/`, `K8s/load-deployment.yaml`, `load-gen/` | Existing chart, app manifests, and load generator retained | Helm lint/render local checks; live readiness snapshot showed mysql, rabbitmq, ratings, and shipping unready | Resolve cluster identity, data safety, and database/broker health; then approve app rollout, steady load, and service-health evidence | No: live cluster/application access and approval required |
| Remove Instana agent settings | Five workload Helm templates under `K8s/helm/templates/` | Removed five `INSTANA_AGENT_HOST` chart env entries locally | Rendered chart asserted no `INSTANA_AGENT_HOST`; optional payment/EUM settings retained | Deployment/runtime evidence remains | Yes, local edit is complete; runtime verification is not |
| kube-prometheus-stack and requests/errors/latency dashboard-as-code | `K8s/observability/prometheus/`, `cart/server.js`, `payment/payment.py` | Pinned chart values, service scrape config, Blackbox probe, dashboard JSON, alerts, and route-labelled HTTP request/5xx/latency instrumentation for cart/payment added | Dashboard JSON/panel IDs and YAML syntax validated; Helm templates lint/render; Python syntax validated; Node syntax check unavailable in this environment | Rebuild images and install after approval. Other services remain uninstrumented; synthetic probe panels are distinguished from application traffic | Partly: source/config locally; runtime and images need cluster approval |
| Fluent Bit logs to Loki; searchable by service and level | `K8s/observability/logging/` | Loki and Fluent Bit manifests, CRI parser, Kubernetes metadata filter, normalized severity, labels, and LogQL examples added | Static YAML and pipeline/label checks passed | Install only after cluster approval; prove results for multiple services/levels | Partly: manifests locally; runtime requires approved cluster |
| Trace a request through OpenTelemetry and Jaeger | `K8s/observability/tracing/jaeger.yaml`, `collector-config.yaml`, `otel-collector.yaml`, tracing README | Jaeger plus a clearly labeled local OTLP receiver/exporter template added; no instructor configuration is claimed | YAML syntax and static pipeline/endpoint assertions only; no Collector binary validation or live trace | Application OTLP instrumentation and app image rebuild are not implemented. Instructor's required original Collector configuration is unavailable, so exact brief compliance cannot be claimed | Partly: local receiver config exists; instrumentation and runtime evidence do not |
| Availability SLO and error-budget policy | `K8s/observability/docs/availability-slo.md` | 99.0% proposed 30-day synthetic SLI, 30s cadence, 5s timeout, and calculations documented | PromQL and 7h12m/864-probe budget arithmetic reviewed | Target approval and live measurement pending; missing probe data is not healthy | Policy locally drafted; target approval/live measurement are not |
| Slack alert that links runbook | `prometheus/robot-shop-rules.yaml`, `prometheus/alertmanager-config.yaml`, runbook | Probe, missing-data, and burn alerts link to the published personal-repository runbook; Slack route references a Secret name/key and no webhook is committed | Static checks verify all rule URLs match the published runbook path and the Secret reference shape | Provision a real webhook Secret securely, install the route, and prove firing/delivery | Partly: config locally; webhook and live drill require approved runtime |
| Instructor-led incident drill and blameless postmortem | `docs/incident-drill-plan.md`, `templates/incident-drill-record.md`, `templates/postmortem.md` | Plan, abort conditions, evidence fields, timeline, and postmortem template prepared | Template/document presence | Complete approved drill and write from observed evidence; do not invent impact/root cause | No: instructor-led drill required |
| Hand-in artifacts: dashboard-as-code, logging/tracing config, SLO policy, postmortem | `K8s/observability/`, `submission/evidence/` | Local configurations, evidence index, and templates assembled | Local static validation | Capture runtime proof; Collector provenance and completed postmortem remain missing | Partly: artifacts locally; runtime evidence needs approved environment |

The user confirmed that no additional instructor files or setup instructions are available. A compatible local Collector template is included as a best-effort alternative, but the instructor-specific config requirement remains unmet. No separate rubric/checklist document was found in the repository/workspace.

## Deliverables and locations

- [Observability setup, versions, validation, LogQL, Slack, and cleanup precautions](K8s/observability/README.md)
- [Prometheus chart values](K8s/observability/prometheus/values.yaml)
- [Robot Shop Grafana dashboard JSON](K8s/observability/prometheus/robot-shop-dashboard.json)
- [Prometheus scrape probe and alert rules](K8s/observability/prometheus/blackbox.yaml), [robot-shop-rules.yaml](K8s/observability/prometheus/robot-shop-rules.yaml), [Alertmanager Slack route](K8s/observability/prometheus/alertmanager-config.yaml)
- [Loki](K8s/observability/logging/loki.yaml) and [Fluent Bit](K8s/observability/logging/fluent-bit.yaml) configuration
- [Jaeger receiver](K8s/observability/tracing/jaeger.yaml), [local OTLP Collector configuration](K8s/observability/tracing/collector-config.yaml), and [Collector deployment](K8s/observability/tracing/otel-collector.yaml); app instrumentation and runtime tracing remain incomplete
- [SLO/error-budget policy](K8s/observability/docs/availability-slo.md), [availability runbook](K8s/observability/runbooks/robot-shop-availability.md)
- [Incident drill plan](K8s/observability/docs/incident-drill-plan.md), [drill record template](K8s/observability/templates/incident-drill-record.md), and [postmortem template](K8s/observability/templates/postmortem.md)
- [Read-only MySQL/RabbitMQ diagnosis and data-safe next steps](K8s/observability/docs/runtime-diagnostics.md)
- [Evidence capture index](submission/evidence/README.md)
- [Per-artifact evidence capture form](submission/evidence/capture-template.md)
- [Local validation script](K8s/observability/scripts/validate.sh) and [approval-gated install script](K8s/observability/scripts/install-observability.sh)

## Local validation

From the repository root:

```sh
bash K8s/observability/scripts/validate.sh
```

Expected checks: Helm lint (an icon recommendation may appear), rendered-chart assertions for the checksum/agent removal/optional settings, dashboard JSON and panel checks, YAML parsing, embedded Loki/Blackbox config parsing, Grafana's Loki datasource, Fluent Bit pipeline/labels, MySQL ConfigMap parity, and shell syntax. A zero exit code means only static/local validation passed; it does not claim that the cluster is healthy or observability is live.

The repository has no meaningful application test suite; the `cart` npm test is a placeholder that exits with an error. Existing GitHub Actions builds the Docker Compose stack and excludes the Kubernetes directory. It does not validate Kubernetes or these observability configurations. Source syntax checks do not exercise a live app or verify exposition through its `/metrics` endpoint.

## Deployment (approval required)

Do not run this until the expected cluster identity is resolved, the database data risk is accepted/mitigated, and the owner approves cluster changes:

```sh
ALLOW_CLUSTER_CHANGES=YES bash K8s/observability/scripts/install-observability.sh
```

The installer requires both `kubectl` context `kind-robot-shop` and `kind get clusters` containing `robot-shop`; it exits if the Docker/Kind discrepancy persists. Review available node capacity and the entire rendered configuration first. The installer changes observability resources only; it does not repair Robot Shop.

The cart and payment code now emits route-labelled request counters (including status code) and duration histograms using the existing Prometheus client dependencies. Build new cart/payment images and make them available to Kind through an approved image-build/load workflow; then inspect `/metrics` and verify the dashboard queries. Other services need equivalent instrumentation if the instructor expects service-wide HTTP metrics rather than the two instrumented components plus a web synthetic probe.

Build commands (local image creation only; not run in this session):

```sh
docker build --tag robotshop/rs-cart:latest ./cart
docker build --tag robotshop/rs-payment:latest ./payment
```

Loading them into Kind and activating them requires the cluster inventory to be resolved and explicit approval. A chart upgrade also rolls MySQL because of the checksum annotation, so the unknown MySQL data state must be addressed first.

## Evidence to capture from the actual environment

Use the [evidence index](submission/evidence/README.md). At minimum capture:

1. Correct Kubernetes context, Kind inventory, node readiness, and Robot Shop baseline/readiness.
2. Successful storefront and approved transaction/load test output.
3. Grafana dashboard with time range, Prometheus target state, and requests/errors/latency panels populated (explain synthetic vs application metrics). Build and deploy updated cart/payment images first for the new app metrics.
4. Loki results for at least two `service` values and `level` values, with the exact LogQL query and timestamp.
5. A representative request trace in Jaeger through the clearly labeled local Collector alternative; record its project-created provenance and private trace reference. This does not satisfy the exact instructor-config wording.
6. SLO query/window, alert rule state, Slack delivery (redacted), and clickable published runbook URL.
7. Instructor-authorized drill timestamps, decisions, evidence, recovery verification, and a completed blameless postmortem.

Do not stage empty templates as proof that a test passed. Preserve actual outputs/screenshots and redact secrets.

## Current known issues and limits

- Active API context is `kind-robot-shop`, but `kind get clusters` and Docker inventory do not list the expected cluster/node. The install script intentionally refuses to proceed until reconciled.
- MySQL 5.7.35 repeatedly OOMKills with exit 137 under the existing 3 GiB limit. The seed archive expands to about 64.6 MB and includes an InnoDB full-text index, a plausible startup-memory contributor but not a proven cause. MySQL logs show only an entrypoint banner; the process is unavailable to inspect. The proposed `innodb_ft_total_cache_size=32M` option has been accepted by defaults parsing for the exact image in prior local checks, but does not prove successful startup or a fix.
- MySQL has no PVC/data mount in the Pod; whether its container-layer data exists is unknown. No backup could be taken while it crashes. Do not replace the Pod until data risk is addressed and a rollout is approved.
- RabbitMQ (3.7 management alpine) has repeatedly OOMKilled under the existing 1536 MiB limit; its precise cause is unknown. Its manifest has no probes. Do not raise limits blindly.
- Ratings and shipping are unready while dependencies fail; no end-to-end purchase test has passed.
- Prometheus scrapes cart/payment `/metrics` and a synthetic web probe. Local cart/payment source instrumentation must be rebuilt and deployed before the HTTP panels can return application data; other services remain uninstrumented.
- Fluent Bit/Loki, dashboard, rules, Slack, Jaeger, and drill have not been applied or runtime-verified.
- Loki uses local ephemeral storage, and Jaeger all-in-one storage is not durable.
- The instructor's Collector config and Slack webhook are unavailable. The local Collector alternative is not instructor-provided; do not claim exact compliance or Slack delivery without genuine evidence.

## Shortest safe next actions

1. Run `bash K8s/observability/scripts/validate.sh` and retain its output.
2. The instructor Collector file is unavailable. Use the documented local template only as a transparent alternative; confirm the SLO target, Slack setup, and drill scenario with the instructor if possible.
3. Resolve the Docker/Kind inventory mismatch read-only; preserve current contexts/resources and database data.
4. Get explicit approval and a MySQL data-preservation decision before any application rollout. Diagnose RabbitMQ separately from MySQL.
5. After approval and stable capacity, install observability with the guarded script, configure Slack Secret from a protected file, and verify every target/query/alert/trace.
6. Obtain instructor approval to run the incident drill; capture evidence and only then complete the postmortem.
7. Re-run local validation and assemble the real evidence directory before submission.
