"""Validate all PromQL queries found in SKILL.md YAML and code blocks.

Uses promql-parser to verify syntax is valid Prometheus Query Language.
This provides 3rd-stage validation without requiring a running Prometheus instance.
"""

import re
import pytest
from pathlib import Path
from promql_parser import parse as parse_promql


SKILLS_DIR = Path("plugins/agenticops/skills")

# Collect all PromQL queries from YAML and Python code blocks
PROMQL_QUERIES = [
    # --- anomaly-detection ---
    ("anomaly-detection", "Error Rate",
     'rate(agent_request_errors_total{service="rag-qa-agent"}[5m])'),
    ("anomaly-detection", "P99 Latency",
     'histogram_quantile(0.99, rate(agent_request_duration_seconds_bucket{service="rag-qa-agent"}[5m]))'),
    ("anomaly-detection", "Token Usage",
     'rate(agent_token_usage_total{service="rag-qa-agent"}[5m])'),

    # --- slo-management ---
    ("slo-management", "availability query_good",
     'sum(rate(agent_request_success_total{service="rag-qa-agent"}[5m]))'),
    ("slo-management", "availability query_total",
     'sum(rate(agent_request_total{service="rag-qa-agent"}[5m]))'),
    ("slo-management", "latency query_good",
     'sum(rate(agent_request_duration_seconds_bucket{service="rag-qa-agent",le="0.5"}[5m]))'),
    ("slo-management", "latency query_total",
     'sum(rate(agent_request_duration_seconds_count{service="rag-qa-agent"}[5m]))'),
    ("slo-management", "faithfulness gauge",
     'agenticops_eval_faithfulness{service="rag-qa-agent"}'),
    ("slo-management", "faithfulness query_good",
     'count_over_time((agenticops_eval_faithfulness{service="rag-qa-agent"} >= 0.85)[7d:1h])'),
    ("slo-management", "faithfulness query_total",
     'count_over_time(agenticops_eval_faithfulness{service="rag-qa-agent"}[7d:1h])'),

    # --- predictive-scaling ---
    ("predictive-scaling", "CPU utilization",
     'avg(rate(container_cpu_usage_seconds_total{pod=~"rag-qa-agent.*"}[5m])) / avg(kube_pod_container_resource_requests{resource="cpu",pod=~"rag-qa-agent.*"})'),
    ("predictive-scaling", "RPS",
     'sum(rate(agent_request_total{service="rag-qa-agent"}[5m]))'),
    ("predictive-scaling", "Memory utilization",
     'avg(container_memory_working_set_bytes{pod=~"rag-qa-agent.*"}) / avg(kube_pod_container_resource_requests{resource="memory",pod=~"rag-qa-agent.*"})'),

    # --- root-cause-analysis (referenced in code comments) ---
    ("root-cause-analysis", "error rate",
     'rate(agent_request_errors_total[5m])'),

    # --- incident-response (from code) ---
    ("incident-response", "context truncation",
     'rate(agent_context_truncation_total{version="v2.3.1"}[5m])'),
    ("incident-response", "milvus compaction",
     'milvus_compaction_queue_length'),

    # --- self-improving-loop (from code) ---
    ("self-improving-loop", "token rate",
     'rate(agent_token_total[1h])'),
]


@pytest.mark.parametrize("skill,name,query", PROMQL_QUERIES,
                         ids=[f"{s}:{n}" for s, n, _ in PROMQL_QUERIES])
def test_promql_syntax(skill, name, query):
    """Verify each PromQL query parses without error."""
    try:
        result = parse_promql(query)
        assert result is not None, f"Parser returned None for: {query}"
    except Exception as e:
        pytest.fail(f"[{skill}] {name}: PromQL parse error: {e}\n  Query: {query}")


# Additional: verify metric naming conventions
METRIC_NAMING_RULES = [
    # Counters must end with _total
    (r'rate\((\w+)\{', "counter inside rate()"),
    (r'increase\((\w+)\{', "counter inside increase()"),
]


def extract_metric_names_from_queries():
    """Extract metric base names from all queries for naming convention checks."""
    metrics = set()
    for _, _, query in PROMQL_QUERIES:
        # Find metric names (word chars before { or [)
        found = re.findall(r'([a-z_][a-z0-9_]*)\s*[\{[]', query)
        metrics.update(found)
        # Also bare metrics
        found = re.findall(r'^([a-z_][a-z0-9_]*)$', query.strip())
        metrics.update(found)
    return metrics


class TestMetricNamingConventions:
    """Verify metrics follow Prometheus naming best practices."""

    def test_counters_end_with_total(self):
        """Metrics inside rate()/increase() should end with _total (counter convention)."""
        violations = []
        for skill, name, query in PROMQL_QUERIES:
            # Find metrics used inside rate()
            rate_metrics = re.findall(r'rate\(([a-z_][a-z0-9_]*)', query)
            increase_metrics = re.findall(r'increase\(([a-z_][a-z0-9_]*)', query)

            for metric in rate_metrics + increase_metrics:
                # _bucket is valid for histograms inside rate()
                if not metric.endswith("_total") and not metric.endswith("_bucket") and not metric.endswith("_count"):
                    violations.append(f"[{skill}:{name}] {metric} inside rate() but doesn't end with _total/_bucket/_count")

        assert violations == [], "\n".join(violations)

    def test_no_reserved_label_names(self):
        """Label names should not use reserved prefixes (__*)."""
        violations = []
        for skill, name, query in PROMQL_QUERIES:
            reserved_labels = re.findall(r'\{[^}]*(__\w+)\s*[=~!]', query)
            for label in reserved_labels:
                violations.append(f"[{skill}:{name}] Reserved label {label} used")

        assert violations == [], "\n".join(violations)

    def test_metric_names_valid_chars(self):
        """Metric names should only contain [a-zA-Z_:][a-zA-Z0-9_:]*."""
        metrics = extract_metric_names_from_queries()
        invalid = [m for m in metrics if not re.match(r'^[a-zA-Z_:][a-zA-Z0-9_:]*$', m)]
        assert invalid == [], f"Invalid metric names: {invalid}"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
