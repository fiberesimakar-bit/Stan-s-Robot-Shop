# Robot Shop Availability Alert Runbook

- **Alerts:** `RobotShopWebProbeFailing`, `RobotShopProbeMissing`, `RobotShopAvailabilitySLOBurn`, `RobotShopAvailabilityFastBurn`
- **Scope:** Robot Shop in Kubernetes namespace `default`
- **Status:** Draft until the runbook URL is published, rules are installed, and the instructor-approved drill verifies the alert route.

## Symptoms and impact

The storefront synthetic check fails or is missing; users may see connection errors, non-2xx responses, slow page loads, or failed checkout. A probe only tests `GET /`; it does not prove purchase flow or every dependency is healthy.

## 1. Acknowledge and establish scope

- Record the alert firing time and affected service from Alertmanager/Slack.
- Open the linked dashboard and compare synthetic availability, probe latency, HTTP status, deployment availability, restarts, CPU, and memory.
- Check whether the alert is active, resolved, or missing its Prometheus series. No data is not a healthy result.
- Do not include Slack webhook values, Kubernetes tokens, database credentials, or customer data in incident notes.

## 2. Safe diagnostics

Verify context before issuing read-only commands:

```sh
kubectl config current-context
kind get clusters
kubectl get nodes -o wide
kubectl get deployments,pods,services,endpoints -n default -o wide
kubectl get events -n default --sort-by=.lastTimestamp
kubectl get pods -n monitoring
kubectl get pods -n observability
```

For this project, the expected context is `kind-robot-shop` and the intended cluster name is `robot-shop`. Stop if context and Kind inventory disagree; do not create, delete, or recreate the cluster as incident response.

For an affected service, inspect current and previous logs and Pod details:

```sh
kubectl describe pod -n default <pod-name>
kubectl logs -n default <pod-name> --all-containers --tail=200
kubectl logs -n default <pod-name> --all-containers --previous --tail=200
```

Compare readiness, restart counts, termination reasons, Service endpoints, recent Events, requests/limits, and available metrics. If a workload is OOMKilled, capture its limit, last termination, timestamps, and cAdvisor evidence before proposing a change. The Metrics API may be absent; report that limitation instead of inventing usage.

Check dependencies according to the failed request: MongoDB/catalogue, Redis/cart, MySQL/shipping, RabbitMQ/payment/dispatch. Do not infer that a dependent service is healthy only because its Pod is Running.

## 3. Escalation and safety limits

- Notify the instructor/incident lead and the application owner if the cluster identity, data state, or expected impact is unclear.
- Current MySQL has no PVC in its Deployment and is crash-looping; data presence is unknown. Do not restart, replace, delete, roll back, or modify it until the data-preservation plan and rollout are approved.
- RabbitMQ has a history of OOM kills. Do not increase memory limits blindly. Capture actual broker logs, termination evidence, and resource/limit metrics first.
- Do not apply Helm, Kubernetes, monitoring, logging, or tracing changes during the drill unless the instructor/incident lead explicitly authorizes that action.
- Preserve evidence before mitigation. Redact tokens, webhook URLs, and credentials from any shared output.

## 4. Recovery and verification

Select the smallest reversible mitigation that the observed evidence supports and record who approved it. If a recent Helm change is implicated, inspect the exact rendered diff and revision before considering rollback; do not roll back blindly. Helm rollback does not restore ephemeral database data and may restore a known OOM configuration.

After an approved mitigation, verify each item before declaring recovery:

1. Relevant Deployment desired, updated, available, and ready replica counts agree.
2. Affected Pods are Ready and restart counts remain stable for the agreed observation window.
3. Services have ready endpoints and the storefront HTTP probe returns 2xx.
4. A test transaction is successful if explicitly approved and dependencies are available.
5. Prometheus target health and the alert state are correct; the alert resolves for the expected reason.
6. Fluent Bit delivers logs searchable in Loki by `service` and `level`.
7. A representative trace is visible in Jaeger if the instructor's Collector configuration and instrumentation are in place.
8. No secret values or customer information appear in evidence.

## 5. Incident record

Record the timeline, decisions, impact, uncertainty, and evidence references in the [incident-drill record](../templates/incident-drill-record.md), then complete the [blameless postmortem](../templates/postmortem.md). Distinguish confirmed causes from hypotheses; do not fill unknown fields with guesses.
