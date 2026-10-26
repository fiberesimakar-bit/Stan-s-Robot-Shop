# Capstone 2 Evidence Index

This is an index/template only. It contains no fabricated screenshots, command output, trace IDs, or drill results. Keep secrets and user/customer data out of all evidence. Follow instructor rules for storage and redaction.

Use [capture-template.md](./capture-template.md) to record each dashboard, log-search, trace, SLO/alert, screenshot, and drill artifact.

## Required capture plan

| ID | Requirement | Evidence to capture | Current state |
|---|---|---|---|
| E01 | Correct cluster/application baseline | `kubectl config current-context`, `kind get clusters`, node and workload readiness output with timestamp | Pending; Docker/Kind inventory mismatch; several workloads unhealthy |
| E02 | Application and load | Storefront browser screenshot, approved load-generator parameters, successful request/transaction output | Pending; do not run load until backend health and resource capacity are confirmed |
| E03 | Prometheus/Grafana dashboard | Grafana dashboard screenshot with time range; Prometheus target status; panel queries and no-data explanations | Configuration local; live deployment pending |
| E04 | Logs in Loki | LogQL query/result demonstrating at least two service values and normalized `level` labels | Configuration local; live ingestion/search pending |
| E05 | Trace in Jaeger | Instructor Collector provenance/config identity (no secret values), request description, Jaeger trace screenshot and trace ID in private evidence store | Blocked on instructor config and runtime |
| E06 | SLO and Slack alert | SLO query/window, alert rule firing/resolved status, redacted delivery screenshot, runbook link | Configuration local; webhook and live firing pending |
| E07 | Incident drill/postmortem | Instructor-approved drill record, timestamped evidence, completed blameless postmortem | Pending instructor-led drill |

## Capture template

For each artifact, record:

- Evidence ID:
- Requirement:
- Capture timestamp (UTC):
- Command/query/URL:
- Expected result:
- Actual observed result:
- Screenshot/file name:
- Redactions applied:
- Validation reviewer:
- Pass / fail / blocked (with reason):

## Commands for baseline evidence

Run only against the confirmed target cluster:

```sh
kubectl config current-context
kind get clusters
kubectl get nodes -o wide
helm history robot-shop -n default
kubectl get deployments,pods,services,endpoints -n default -o wide
kubectl get events -n default --field-selector type=Warning --sort-by=.lastTimestamp
```

The existing API context and Kind inventory currently disagree. Capture that discrepancy as a blocker; do not hide it by creating/deleting a cluster or changing contexts.
