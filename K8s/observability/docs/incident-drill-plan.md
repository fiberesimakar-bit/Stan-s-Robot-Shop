# Instructor-Led Incident Drill Plan

**Status: Planned, not performed.** The present application has unhealthy dependencies and the cluster identity is inconsistent. Do not simulate impact or trigger destructive faults without instructor/incident-lead approval and an explicit data-safety plan.

## Objectives mapped to the brief

1. Observe the instructor-selected failure without assigning blame.
2. Detect it through the SLO alert and capture the alert/Slack/runbook path.
3. Use dashboard, searchable service/level logs, and a trace to diagnose the request where those systems are available.
4. Restore service using only an instructor-approved, evidence-supported action.
5. Verify recovery and produce a fact-based postmortem and follow-up actions.

## Preconditions

- Instructor/incident lead provides the scenario, start signal, allowed actions, stop conditions, and participants.
- Cluster context and Kind/Docker inventory identify the same intended cluster.
- Robot Shop baseline is healthy enough for the agreed scenario; MySQL state and backup/restore constraints are understood.
- Dashboard, Prometheus rule, Alertmanager, Slack Secret/route, Fluent Bit, Loki, Jaeger, and the local Collector alternative are installed and verified as applicable. Clearly record that the local Collector is not instructor-provided; verify app OTLP instrumentation separately.
- Capture storage and observer are assigned; redact secrets and customer data from evidence.
- Rollback and abort criteria are agreed before the drill. No PVC, database, namespace, or cluster deletion is part of this plan.

## Execution outline

1. Record baseline time in UTC, cluster/context identity, Deployment readiness, service endpoints, dashboard state, and current alert state.
2. Wait for the instructor's scenario start. Record the exact UTC timestamp and scenario as supplied; do not inject a failure unless specifically authorized.
3. Capture alert firing/delivery, relevant metric panels, and a sample searchable log with `service` and `level` labels.
4. Trace one instructor-approved representative request. Record its trace ID only in the evidence store and verify the trace in Jaeger.
5. Follow the runbook. Record observations, hypotheses, decisions, approvals, and actions with UTC timestamps and source references.
6. Perform only explicitly approved recovery actions. Capture post-action workload, endpoint, storefront, alert, log, and trace checks.
7. Obtain the instructor's drill completion signal, preserve artifacts, and complete the postmortem with evidence.

## Abort conditions

Stop and contact the instructor/incident lead if the cluster identity is uncertain, unexpected user/data impact occurs, MySQL data preservation is unclear, the scenario exceeds its approved scope, evidence contains secrets, or the approved rollback is unavailable.

## Evidence checklist

Use the [evidence capture index](../../../submission/evidence/README.md) and [incident drill record](../templates/incident-drill-record.md). Record only observed facts. If a tool or signal was unavailable, record the failed check and exact error; do not mark it passed.
