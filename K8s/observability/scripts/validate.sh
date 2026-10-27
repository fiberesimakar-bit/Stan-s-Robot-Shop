#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OBS="$ROOT/K8s/observability"
CHART="$ROOT/K8s/helm"

for tool in helm python3 bash; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required tool not found: %s\n' "$tool" >&2
    exit 1
  fi
done

helm lint "$CHART"
helm template robot-shop "$CHART" \
  --set payment.gateway=https://example.invalid \
  --set eum.key=local-validation-placeholder \
  --set eum.url=https://example.invalid \
  > /tmp/robot-shop-rendered.yaml

python3 - "$ROOT" "$OBS" <<'PY'
import json
import pathlib
import re
import sys

import yaml

root = pathlib.Path(sys.argv[1])
obs = pathlib.Path(sys.argv[2])
dashboard_path = obs / "prometheus/robot-shop-dashboard.json"
dashboard = json.loads(dashboard_path.read_text())
assert len(dashboard["panels"]) >= 8, "dashboard needs service and resource panels"
panel_titles = {panel["title"] for panel in dashboard["panels"]}
for expected in (
    "Synthetic request rate",
    "Synthetic error ratio (5m)",
    "Storefront latency (p95, 1h)",
    "Robot Shop Deployment replicas",
    "Application HTTP request and 5xx rate (cart/payment)",
    "Application HTTP route latency (p95, cart/payment)",
):
    assert expected in panel_titles, f"missing dashboard panel: {expected}"
ids = [panel["id"] for panel in dashboard["panels"]]
assert len(ids) == len(set(ids)), "dashboard panel IDs must be unique"
expressions = [target["expr"] for panel in dashboard["panels"] for target in panel.get("targets", [])]
assert any("http_requests_total" in expr for expr in expressions)
assert any("http_request_duration_seconds_bucket" in expr for expr in expressions)
assert any("sum by (service)" in expr and 'status_code=~"5.."' in expr for expr in expressions)
assert all(panel.get("datasource", {}).get("uid") == "prometheus" for panel in dashboard["panels"])
print(f"PASS: dashboard JSON ({len(dashboard['panels'])} panels, unique IDs)")

yaml_paths = sorted(obs.rglob("*.yaml"))
documents = 0
parsed = {}
for path in yaml_paths:
    with path.open() as stream:
        parsed[path] = list(yaml.safe_load_all(stream))
    documents += len([doc for doc in parsed[path] if doc is not None])
print(f"PASS: YAML syntax ({len(yaml_paths)} files, {documents} documents)")

prom_values = yaml.safe_load((obs / "prometheus/values.yaml").read_text())
ns_selector = prom_values["alertmanager"]["alertmanagerSpec"]["alertmanagerConfigNamespaceSelector"]
assert ns_selector.get("matchLabels", {}).get("kubernetes.io/metadata.name") == "monitoring"
assert "matchNames" not in ns_selector
assert {target["labels"]["service"] for target in prom_values["prometheus"]["prometheusSpec"]["additionalScrapeConfigs"][0]["static_configs"]} == {"cart", "payment"}
probe_config = prom_values["prometheus"]["prometheusSpec"]["additionalScrapeConfigs"][1]
assert probe_config["job_name"] == "robot-shop-web-probe"
assert probe_config["static_configs"][0]["targets"] == ["http://web.default.svc.cluster.local:8080/"]
assert probe_config["relabel_configs"][-2]["replacement"] == "blackbox-exporter.monitoring.svc.cluster.local:9115"
blackbox_docs = parsed[obs / "prometheus/blackbox.yaml"]
blackbox_deployment = next(doc for doc in blackbox_docs if doc and doc.get("kind") == "Deployment")
blackbox_service = next(doc for doc in blackbox_docs if doc and doc.get("kind") == "Service")
assert blackbox_service["spec"]["selector"] == blackbox_deployment["spec"]["selector"]["matchLabels"]
datasources = prom_values["grafana"]["additionalDataSources"]
loki_datasource = next((source for source in datasources if source.get("type") == "loki"), None)
assert loki_datasource is not None, "Grafana Loki datasource is missing"
assert loki_datasource["uid"] == "loki"
assert loki_datasource["url"] == "http://loki.observability.svc.cluster.local:3100"
print("PASS: Prometheus scrape targets and Alertmanager namespace selector")
print("PASS: Grafana Loki datasource points to the Loki Service")

rule_docs = [doc for doc in yaml.safe_load_all((obs / "prometheus/robot-shop-rules.yaml").read_text()) if doc]
alert_names = {rule["alert"] for group in rule_docs[0]["spec"]["groups"] for rule in group["rules"]}
assert alert_names == {
    "RobotShopWebProbeFailing",
    "RobotShopAvailabilitySLOBurn",
    "RobotShopAvailabilityFastBurn",
    "RobotShopProbeMissing",
}
assert all(rule["annotations"].get("runbook_url") for group in rule_docs[0]["spec"]["groups"] for rule in group["rules"])
expected_runbook = "https://github.com/fiberesimakar-bit/Stan-s-Robot-Shop/blob/main/K8s/observability/runbooks/robot-shop-availability.md"
assert all(rule["annotations"]["runbook_url"] == expected_runbook for group in rule_docs[0]["spec"]["groups"] for rule in group["rules"])
alertmanager_config = next(doc for doc in yaml.safe_load_all((obs / "prometheus/alertmanager-config.yaml").read_text()) if doc)
slack = alertmanager_config["spec"]["receivers"][0]["slackConfigs"][0]
assert slack["apiURL"] == {"name": "robot-shop-slack", "key": "slack_api_url"}
print("PASS: Prometheus alert rules, published runbook URL, and Slack Secret reference")

blackbox_doc = next(doc for doc in parsed[obs / "prometheus/blackbox.yaml"] if doc and doc.get("kind") == "ConfigMap")
yaml.safe_load(blackbox_doc["data"]["blackbox.yml"])
loki_doc = next(doc for doc in parsed[obs / "logging/loki.yaml"] if doc and doc.get("kind") == "ConfigMap")
loki_config = yaml.safe_load(loki_doc["data"]["config.yaml"])
assert loki_config["schema_config"]["configs"][0]["store"] == "tsdb"
print("PASS: embedded Blackbox and Loki configuration YAML")

fluentbit_docs = parsed[obs / "logging/fluent-bit.yaml"]
fluent_config_map = next(doc for doc in fluentbit_docs if doc and doc.get("kind") == "ConfigMap")
fluent_config = fluent_config_map["data"]["fluent-bit.conf"]
normalize_lua = fluent_config_map["data"]["normalize.lua"]
for section in ("[INPUT]", "[FILTER]", "[OUTPUT]"):
    assert section in fluent_config, f"Fluent Bit config missing {section}"
assert "Name                      loki" in fluent_config, "Fluent Bit Loki output is missing"
assert "service=$service" in fluent_config and "level=$level" in fluent_config and "namespace=$namespace" in fluent_config
assert "Host                      loki.observability.svc.cluster.local" in fluent_config
assert 'record["namespace"] = kubernetes["namespace_name"] or "unknown"' in normalize_lua
print("PASS: Fluent Bit pipeline and service/level label checks")

mysql_source = (root / "K8s/helm/files/mysql-memory.cnf").read_text().strip()
mysql_cm = next(
    doc for doc in yaml.safe_load_all((root / "K8s/helm/templates/mysql-configmap.yaml").read_text())
    if doc and doc.get("kind") == "ConfigMap"
)
assert mysql_cm["data"]["mysql-memory.cnf"].strip() == mysql_source
assert "innodb_ft_total_cache_size=32M" in mysql_source
rendered = pathlib.Path("/tmp/robot-shop-rendered.yaml").read_text()
assert re.search(r"checksum/mysql-config:\s*[0-9a-f]{64}", rendered)
assert "innodb_ft_total_cache_size=32M" in rendered
assert "INSTANA_AGENT_HOST" not in rendered
assert "PAYMENT_GATEWAY" in rendered and "https://example.invalid" in rendered
assert "INSTANA_EUM_KEY" in rendered and "INSTANA_EUM_REPORTING_URL" in rendered
print("PASS: Helm render assertions, MySQL ConfigMap parity, and preserved optional settings")

collector_docs = [doc for doc in yaml.safe_load_all((obs / "tracing/otel-collector.yaml").read_text()) if doc]
collector_config = yaml.safe_load((obs / "tracing/collector-config.yaml").read_text())
trace_pipeline = collector_config["service"]["pipelines"]["traces"]
assert trace_pipeline["receivers"] == ["otlp"]
assert trace_pipeline["exporters"] == ["otlp/jaeger"]
assert collector_config["exporters"]["otlp/jaeger"]["endpoint"] == "jaeger.observability.svc.cluster.local:4317"
assert any(doc.get("kind") == "Service" and doc["metadata"]["name"] == "otel-collector" for doc in collector_docs)
collector_deployment = next(doc for doc in collector_docs if doc.get("kind") == "Deployment")
assert any(volume.get("configMap", {}).get("name") == "otel-collector-config" for volume in collector_deployment["spec"]["template"]["spec"]["volumes"])
assert collector_deployment["spec"]["template"]["spec"]["containers"][0]["image"] == "otel/opentelemetry-collector-contrib:0.116.1"
assert (obs / "tracing/jaeger.yaml").exists()
assert "instructor-provided" in (obs / "tracing/README.md").read_text()
jaeger_docs = [doc for doc in yaml.safe_load_all((obs / "tracing/jaeger.yaml").read_text()) if doc]
jaeger_service = next(doc for doc in jaeger_docs if doc.get("kind") == "Service")
jaeger_ports = {port["name"]: port["port"] for port in jaeger_service["spec"]["ports"]}
assert jaeger_ports["otlp-grpc"] == 4317 and jaeger_ports["otlp-http"] == 4318
print("PASS: local OTLP Collector pipeline and Jaeger endpoint configuration (static checks only)")

markdown_paths = [
    root / "SUBMISSION.md",
    root / "K8s/README.md",
    *sorted(obs.rglob("*.md")),
    *sorted((root / "submission").rglob("*.md")),
]
missing_links = []
for markdown_path in markdown_paths:
    for target in re.findall(r"\[[^]]+\]\(([^)]+)\)", markdown_path.read_text()):
        if "://" in target or target.startswith(("#", "mailto:")):
            continue
        local_target = target.split("#", 1)[0].split("?", 1)[0]
        if local_target and not (markdown_path.parent / local_target).resolve().exists():
            missing_links.append((markdown_path, target))
assert not missing_links, f"broken relative Markdown links: {missing_links}"
print(f"PASS: relative Markdown links ({len(markdown_paths)} documents)")

placeholder_paths = [
    root / "SUBMISSION.md",
    root / "K8s",
    root / "submission",
]
placeholder_matches = []
for base in placeholder_paths:
    candidates = [base] if base.is_file() else base.rglob("*")
    for path in candidates:
        if path.is_file() and path.suffix in {".md", ".yaml", ".yml", ".json"}:
            text = path.read_text()
            if re.search(r"<YOUR_[^>]+>|CHANGE_ME|REPLACE_ME", text):
                placeholder_matches.append(str(path))
assert not placeholder_matches, f"unresolved submission placeholders: {placeholder_matches}"
print("PASS: no unresolved submission placeholders")

payment_source = (root / "payment/payment.py").read_text()
compile(payment_source, str(root / "payment/payment.py"), "exec")
assert "http_requests_total" in payment_source
assert "http_request_duration_seconds" in payment_source
print("PASS: payment HTTP metric source and Python syntax")

cart_source = (root / "cart/server.js").read_text()
assert "http_requests_total" in cart_source
assert "http_request_duration_seconds" in cart_source
print("PASS: cart HTTP metric source assertions")
PY

bash -n "$OBS/scripts/install-observability.sh" "$OBS/scripts/validate.sh"
if command -v node >/dev/null 2>&1; then
  node --check "$ROOT/cart/server.js"
  printf '%s\n' "PASS: cart JavaScript syntax"
else
  printf '%s\n' "SKIP: Node.js is unavailable; cart JavaScript syntax was not executed"
fi
git -C "$ROOT" diff --check
printf '%s\n' "PASS: shell syntax and git diff --check"
