# Robot Shop Availability SLO and Error-Budget Policy

**Status: Proposed and configured locally; not approved by the instructor/project owner or measured in a deployed monitoring stack.**

## Objective and measurement

- **Service:** Robot Shop storefront (`web`).
- **Objective:** At least **99.0% successful synthetic requests** in each rolling 30-day window.
- **Probe:** HTTP `GET /` to `http://web.default.svc.cluster.local:8080/` from the cluster, every 30 seconds.
- **Timeout:** Five seconds.
- **Success:** HTTP 2xx received before timeout. Connection failures, timeouts, and non-2xx responses are unsuccessful.
- **Measurement window:** Rolling 30 days; no maintenance exclusion is currently defined.
- **Source:** Prometheus Blackbox Exporter `probe_success` from job `robot-shop-web-probe`.

```text
SLI = successful scheduled probes / all scheduled probes
```

The Prometheus query for observed samples is:

```promql
avg_over_time(probe_success{job="robot-shop-web-probe"}[30d])
```

An absent series is **not** a successful SLI. The configured `RobotShopProbeMissing` alert detects missing measurements; record gaps and probe-system outages separately before reporting an SLI result.

This objective measures storefront reachability, not transaction success, backend health, or all real-user HTTP traffic. The local application instrumentation adds request/error/route-latency metrics to cart and payment only; it does not provide application-wide coverage.

## Error budget

At 99.0%, the allowed failure fraction is 1.0%:

- **30-day time budget:** `30 days × 24 hours × 1.0% = 7.2 hours` (7 hours, 12 minutes).
- **At a 30-second probe interval:** 86,400 scheduled probes per 30 days; up to 864 unsuccessful probes fit within a 1.0% budget, assuming no missing measurements.
- **Budget remaining:** `1 - (1 - SLI) / 0.01`; clamp the reported value to [0, 1] and flag values below 0 as exhausted.

## Alert and response policy

The local Prometheus rules detect a failed probe lasting two minutes, missing probe data for five minutes, a rolling 30-day SLI below 99%, and a rapid-burn condition with more than 14.4% probe failures in both 5-minute and 1-hour windows. Each rule links to the runbook in the personal GitHub repository's `main` branch. Recheck that URL if the repository or branch changes.

When the error budget is exhausted, pause nonessential risky changes, prioritize restoring storefront availability and preserving data, and agree on corrective actions before resuming. For a page-level probe/fast-burn alert, acknowledge it and follow the [availability runbook](../runbooks/robot-shop-availability.md). The Slack route configuration is present locally, but delivery requires an instructor/project-owner-provided webhook Secret and must be verified during the approved incident drill.

## Review and acceptance

Confirm the 99.0% objective and probe scope with the instructor/project owner. To accept the SLO as operational, capture the deployed rule and target, a valid SLI result over the required window (or a clearly identified short demonstration window), successful failure-alert delivery, the linked runbook, and evidence from the drill. This document and local Prometheus YAML do not establish that the target is met.
