# Tracing hand-in

The assignment asks for a request trace through the **instructor-provided OpenTelemetry Collector configuration** and Jaeger. The user confirms no instructor file or extra instructions are available. The included [`collector-config.yaml`](./collector-config.yaml) and [`otel-collector.yaml`](./otel-collector.yaml) are a local compatible template, not the instructor's original, and that distinction is intentional.

[`jaeger.yaml`](./jaeger.yaml) provides a pinned Jaeger all-in-one receiver/UI:

- UI: service `jaeger.observability.svc.cluster.local:16686`
- OTLP/gRPC: `jaeger.observability.svc.cluster.local:4317`
- OTLP/HTTP: `jaeger.observability.svc.cluster.local:4318`

The Collector template accepts OTLP/gRPC and OTLP/HTTP on its in-cluster Service and exports traces to Jaeger over OTLP/gRPC. Its health endpoint is used for Kubernetes probes. It is configured without authentication and must remain internal to the trusted cluster network.

Neither Jaeger nor the Collector instruments Robot Shop by itself. Existing application source uses Instana instrumentation; an OpenTelemetry SDK/exporter path for the app is not yet implemented or verified. Therefore the config is an integration endpoint, not evidence that an app trace can currently be produced. The exact instructor-config requirement also remains unmet by this local alternative.

## Verification steps after app instrumentation and approved deployment

1. If the Collector Contrib `0.116.1` binary is already available, validate the standalone Collector configuration before rollout:

   ```sh
   otelcol-contrib validate --config=K8s/observability/tracing/collector-config.yaml
   ```

   The config file is mounted into Kubernetes as a ConfigMap by the gated install script. Do not pull images or start containers without approval.
2. Confirm Robot Shop serves a request and the chosen service's OTLP exporter targets the Collector Service above.
3. Record UTC request time and a safe request description, send one representative request, and search Jaeger by service/time.
4. Verify expected service names and linked spans; capture a screenshot and private trace ID reference in `submission/evidence/README.md`.
5. If no trace appears, capture app instrumentation/exporter status, Collector receiver/exporter errors, and Jaeger receiver logs without credentials. Do not report tracing as complete because the config parsed or a Pod is Ready.

## Pending

- Instructor-provided Collector configuration: **unavailable**; exact instructor-specific configuration cannot be supplied or claimed.
- Robot Shop OTLP instrumentation and app image rebuild: **not implemented**.
- Local Collector config binary/schema validation: **not run**; Collector validation tooling is not installed.
- Runtime Collector, instrumented request, and Jaeger trace: **not deployed or verified**.
