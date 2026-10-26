# Capstone 2 Completion Checklist

**Source:** `CAPSTONE PROJECT.pdf`, supplied outside the repository. No separate rubric file was found in the workspace. This checklist distinguishes local artifacts from deployed/observed results.

## Confirmed complete locally

- [x] Robot Shop Helm chart, Kubernetes manifests, and load generator are present.
- [x] Cart and payment source expose business Prometheus metrics.
- [x] The five Helm-injected `INSTANA_AGENT_HOST` entries are removed locally, as directed by the brief.
- [x] Local dashboard-as-code, Prometheus/Blackbox configuration, Fluent Bit/Loki configuration, Jaeger receiver manifest, SLO policy, alert route, runbook, drill plan, postmortem template, and evidence index are present.
- [x] Cart and payment source now defines route-labelled HTTP request counters, response status codes, and duration histograms for the dashboard.
- [x] A local validation script is present; see `SUBMISSION.md` for the actual run result.

## Implemented locally, runtime not verified

- [ ] Install kube-prometheus-stack and verify scrape targets, dashboard data, Prometheus rules, and workload/resource panels.
- [ ] Deploy the application and approved load generator; demonstrate a successful storefront/transaction test.
- [ ] Deploy Fluent Bit and Loki; demonstrate real LogQL results searchable by service and level.
- [ ] Publish the SLO runbook link, provision Slack securely, and demonstrate the alert firing and delivery during the drill.
- [ ] Cart/payment metrics have not been exercised at `/metrics`, and their modified images have not been rebuilt/deployed. Other Robot Shop services remain without this HTTP instrumentation.
- [ ] Capture actual evidence and include the dashboard, logging/tracing, SLO, and postmortem deliverables in the submission.

## Blocked on instructor input or approved live actions

- [ ] Trace a request using the instructor's original OpenTelemetry Collector configuration and Jaeger. No such config was found in the repository/workspace; do not substitute one.
- [ ] Complete the instructor-led incident drill and fill the postmortem from observed evidence. No timing, cause, impact, alert delivery, or recovery result may be invented.
- [ ] Replace/roll out MySQL only after its unknown ephemeral data state is addressed and the rollout is explicitly approved.
- [ ] Resolve the Docker/Kind inventory discrepancy before relying on the current API context for deployment.

## Current live blockers

- MySQL 5.7.35 is `CrashLoopBackOff`, last termination `OOMKilled`, exit 137, with a 3 GiB limit. Logs only show the entrypoint banner. No stable process or working Metrics API is available for runtime memory analysis.
- The MySQL seed archive expands to about 64.6 MB and creates a large InnoDB full-text index; this is a plausible startup-memory contributor, not a proven root cause. The proposed `innodb_ft_total_cache_size=32M` is local and startup success is unverified.
- MySQL has no PVC or data mount in its Pod; whether container-layer data exists is unknown and no safe logical backup was possible.
- RabbitMQ is also crash-looping with repeated OOMKilled/137 terminations under its existing 1536 MiB limit; cause remains unknown.
- Ratings and shipping are unready; no end-to-end transaction has passed.
- No observability component, trace, Slack notification, or drill result has been verified live.

## Evidence boundaries

- Local YAML/JSON/Helm validation is not a live deployment or runtime test.
- The brief is supplied outside this repository; no separate rubric or instructor Collector file was found in the workspace.
- No Helm upgrade, rollback, Kubernetes apply/delete, restart, backup, or cluster mutation has been performed in this task.
