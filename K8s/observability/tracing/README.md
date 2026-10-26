# Tracing hand-in

The assignment requires a request trace through the **instructor-provided OpenTelemetry Collector configuration** and Jaeger. A workspace/repository search found no Collector config, so none is supplied or fabricated here.

`jaeger.yaml` provides a pinned Jaeger all-in-one receiver/UI for the local exercise:

- UI: service `jaeger.observability.svc.cluster.local:16686`
- OTLP/gRPC: `jaeger.observability.svc.cluster.local:4317`
- OTLP/HTTP: `jaeger.observability.svc.cluster.local:4318`

This Jaeger manifest is a receiver only. It does not instrument the Robot Shop services or make a trace appear. Existing application source uses Instana instrumentation, not a verified OpenTelemetry SDK/exporter configuration.

## Required input and verification

1. Obtain the instructor's original Collector file and written instructions for endpoints, credentials, namespace, and resource requests. Keep its source/provenance with the submission; redact secret values.
2. Validate the supplied Collector config with the Collector distribution/version specified by the instructor. Do not rewrite the file as a substitute.
3. Confirm Robot Shop can serve the agreed request and that the approved instrumentation/export path is enabled.
4. Record the UTC request time and safe request description, send one representative request, and search Jaeger by service/time.
5. Verify the trace has expected service names and linked spans; capture a screenshot and private trace ID reference in `submission/evidence/README.md`.
6. If no trace appears, capture Collector exporter errors and Jaeger receiver logs without credentials. Do not report tracing as complete merely because Jaeger is Ready.

## Pending

- Original Collector configuration: **not found**.
- Instructor endpoint/credentials and config version: **not supplied**.
- Runtime Collector, instrumented request, and Jaeger trace: **not deployed or verified**.
