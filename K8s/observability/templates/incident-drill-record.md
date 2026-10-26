# Incident Drill Evidence Record

> Copy this template for the instructor-led drill. Store actual outputs/screenshots in the approved evidence folder. Never enter webhook URLs, tokens, passwords, or personal/customer data.

## Drill identification

- Instructor / incident lead:
- Scenario as stated by instructor:
- Drill date:
- Start signal (UTC, source):
- End signal (UTC, source):
- Participants/roles:
- Approved scope and stop conditions:
- Cluster context and Kind cluster name:
- Evidence folder/index:

## Baseline before the drill

- Deployment/Pod readiness command and timestamp:
- Service/endpoints command and timestamp:
- Baseline SLO/dashboard screenshot reference:
- Baseline alert state/reference:
- Database data-safety status and explicit approval:
- Observed limitations:

## Timestamped timeline (UTC)

| UTC timestamp | Observation / decision / action | Actor role | Approval/source | Evidence reference |
|---|---|---|---|---|
| Pending drill | | | | |

## Required signal evidence

- Alert rule/name and firing timestamp:
- Alertmanager/Slack delivery evidence (redacted):
- Dashboard time range and requests/errors/latency panel references:
- LogQL query and matching `service`/`level` labels:
- Trace request description, trace ID reference, Jaeger screenshot:
- If any signal was unavailable, exact error and diagnostic reference:

## Recovery verification

- Approved mitigation and approving role:
- Deployment/Pod readiness after mitigation:
- Service endpoint and storefront request result:
- Alert resolution state and timestamp:
- Log/trace verification:
- Stability observation duration/results:
- Data integrity or backup verification:
- Remaining impact/unknowns:

## Post-drill handoff

- Follow-up action owner / due date:
- Postmortem file:
- Instructor review / acceptance:
- Evidence copied to approved submission location:
