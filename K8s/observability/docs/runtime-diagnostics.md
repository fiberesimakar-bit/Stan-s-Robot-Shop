# Runtime Diagnosis — MySQL, RabbitMQ, Ratings, Shipping

**Observation snapshot:** 2026-10-27 (read-only audit, latest check). No workload was restarted or changed for this report. Counts and readiness can change; rerun the documented checks before taking action.

## Latest read-only workload findings

- The Kubernetes API responds through context `kind-robot-shop`, and the `robot-shop-control-plane` node reports `Ready`, but `kind get clusters` reports no Kind clusters. Do not reconcile this by deleting/recreating a cluster; establish which runtime owns the API first.
- At the latest check, MySQL had 119 restarts and RabbitMQ had 136; MySQL's latest termination was `OOMKilled`/137 and RabbitMQ remained in `CrashLoopBackOff`. Previous-container MySQL logs returned only a startup-banner line; RabbitMQ returned no useful prior log lines.
- Ratings and shipping were not Ready. Ratings' previous logs contained repeated connection-refused/database error patterns; its source config uses `mysql` for its PDO host. Shipping's previous logs also contained connection-refused/database error patterns; its Java config defaults `DB_HOST` to `mysql`. Together with MySQL's crash loop, this supports unavailable MySQL as a likely contributor to ratings/shipping failures. It does not establish MySQL's OOM root cause.
- The only PVC listed in namespace `default` was `data-redis-0`; no MySQL PVC was listed. This is not proof the MySQL data directory is empty.
- No workloads were present in `monitoring` or `observability`, so Prometheus/Grafana, Fluent Bit/Loki, Jaeger, and the local Collector had not been deployed.
- Warning events included MySQL endpoint/EndpointSlice update failures with `Unauthorized`, plus MySQL/RabbitMQ BackOff and ratings/shipping readiness failures. The authorization warnings may be a separate control-plane/authentication issue; their cause is not established by the event text.

## MySQL

### Evidence

- Image: `robotshop/rs-mysql-db:latest`, resolved in the running Pod to digest `sha256:2355f9700d771f4326169d7d370ad1824d2d410876036f77342d9663d80f893b`; MySQL `5.7.35-1debian10`.
- Deployment has request `1Gi`, limit `3Gi` (the resource values are local uncommitted changes already present in the worktree).
- Container repeatedly terminates `OOMKilled`, exit 137. Previous Pod logs show only the MySQL entrypoint startup banner. No running mysqld process stayed available for inspection.
- The Pod has no startup, readiness, or liveness probe. Thus the observed restarts are not explained by a failed Kubernetes HTTP probe; the container is being terminated.
- `kubectl top` cannot provide metrics because the Metrics API is unavailable. A previous cAdvisor observation recorded the Pod-scope memory maximum at its configured 3 GiB limit; a later sample taken while it was between restarts was only a few hundred KiB and is not representative of the failed startup peak.
- The custom image is based on `mysql:5.7`, changes the MySQL data directory to `/data/mysql`, and copies `mysql/scripts/*` into `/docker-entrypoint-initdb.d/`. The image declares `/data` as a volume, but the Kubernetes Pod does not mount a PVC or another persistent data volume at `/data`.
- `mysql/scripts/10-dump.sql.gz` expands to 64,581,396 bytes. It creates a `cities` InnoDB table with a full-text index and bulk seed data; `99-finished.sh` marks completion after initialization.
- The mounted memory configuration is included by the image's MySQL config chain. In prior exact-image defaults inspection, `mysqld --print-defaults` included the configured buffer pool, connection, and temporary-table settings. This does not show the live failed process's full effective runtime state.
- The 32 MiB `innodb_ft_total_cache_size` setting is recognized by the exact image's option parser in prior local validation. It has not been deployed, and an options parse does not prove successful startup or prevention of OOM.

### Assessment

**Confirmed:** the process is OOMKilled; its configured memory limit is 3 GiB; the seed import builds a substantial full-text-indexed dataset; the Pod lacks persistent storage; the container does not remain alive long enough for runtime inspection.

**Plausible, unconfirmed:** full-text index construction/cache allocation during the first-run seed import may contribute to the startup peak. The proposed full-text cache cap is compatible with the option parser and is a reasonable local experiment, not a verified fix. Other native allocations, restart/recovery state, image behavior, or node/cgroup conditions remain possible.

**Not established:** that the database is empty, that the memory ConfigMap is effective in the currently running Pod, that index initialization is the only cause, or that a 32 MiB cap is sufficient.

### Data-preserving diagnostic sequence (approval required for mutation)

1. Keep current release, Pod, container layer, and cluster intact. Capture current Pod YAML/status, previous logs, all events, image ID, deployment resources, ConfigMap contents, mount paths, and read-only cAdvisor/cgroup values.
2. Resolve the Kind/Docker/API ownership discrepancy without creating, deleting, or recreating the cluster.
3. Obtain owner approval for the data risk. A logical dump requires a stable MySQL server; there is currently no stable process to execute one against. Do not claim a backup exists.
4. Before any Pod replacement, inspect the node/container runtime's accessible storage for the existing `/data/mysql` layer using an approved read-only method. Do not mount, alter, prune, or delete that storage. If ownership/access cannot be proven, stop and ask the owner.
5. Only after an explicit data disposition and rollout approval, test the candidate config in a recoverable environment or controlled approved rollout. Capture cgroup peak usage, full startup logs, MySQL readiness/SQL ping, and data checks before calling the change successful.

The ConfigMap is mounted through `subPath`; changing its data alone does not update the existing mount. The local MySQL Pod-template checksum addresses that rollout trigger but does not provide a backup, prevent data loss, or establish that rollout is safe.

## RabbitMQ

### Evidence

- Image: `rabbitmq:3.7-management-alpine`; existing Deployment limit `1536Mi`, request `512Mi`.
- The Pod has repeatedly terminated `OOMKilled`, exit 137; last observed restart counts were increasing. The live Service endpoint existed during some checks, but endpoint presence while a container restarts is not a stability test.
- The Deployment has no startup/readiness/liveness probes, so the observed container restarts are not explained by probe failures.
- Current and previous useful application logs were not available in the observed crash state. No RabbitMQ-specific memory telemetry or broker diagnostic was captured.
- No persistent volume is declared for RabbitMQ's data directory in this Deployment.

### Assessment

**Confirmed:** repeated OOMKilled/137 terminations at the configured limit. **Unknown:** whether the pressure is broker heap, native memory, queue growth, startup, node contention, cgroup detection, or another factor. Do not increase limits or change the old image without new evidence and approval.

## Ratings and shipping

- Ratings Pods are not Ready and the readiness endpoint returned HTTP 500. Its service source config targets MySQL at `mysql`; previous logs showed repeated connection-refused/database error patterns.
- Shipping Pods are not Ready; the readiness probe could not connect to port 8080, and a prior container termination had exit code 1/reason `Error`. Its Java JDBC config defaults `DB_HOST` to `mysql`; previous logs showed connection-refused/database error patterns.
- MySQL unavailability is a likely dependency cause for both services, supported by source configuration and previous-log summaries. Confirm with fresh, redacted logs after MySQL is stably available. Do not claim their failures are fully resolved until health checks pass.

## Evidence to collect at next approved diagnostic window

Use read-only commands first and save timestamps:

```sh
kubectl describe pod -n default <pod>
kubectl logs -n default <pod> --all-containers --timestamps --tail=300
kubectl logs -n default <pod> --all-containers --previous --timestamps --tail=300
kubectl get events -n default --field-selector type=Warning --sort-by=.lastTimestamp
kubectl get pod -n default <pod> -o yaml
kubectl get deployment mysql rabbitmq -n default -o yaml
kubectl get configmap mysql-config -n default -o yaml
kubectl get endpointslices -n default
```

Redact secrets. Capture runtime memory/cgroup counters at a controlled interval while the process is alive; record node memory pressure, CPU throttling, OOM events, and restart timestamps. Do not repeatedly restart or exec into an unstable Pod. If it cannot stay running long enough to capture evidence, stop rather than provoking more attempts.
