---
name: anomaly-detection
description: CloudWatch 메트릭과 Prometheus 시계열 데이터에서 통계적 이상 징후를 자동 탐지하여 incident-response의 입력 소스로 제공한다. 베이스라인 학습(7일 이동 평균 + 3σ), 다변량 상관 분석, 계절성 보정을 수행하며 탐지된 anomaly를 severity 분류하여 알람을 생성한다.
argument-hint: "[target-metric or agent-name]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus"
ontology:
  produces: [Incident]
  references: [Deployment, Agent]
---

## When to Use

- Sub-Phase 2 (Observe)에서 프로덕션 메트릭의 이상 패턴을 사전 탐지할 때
- `incident-response`의 알람 소스로 — CloudWatch/Prometheus 정적 임계값으로 잡히지 않는 이상 징후 탐지
- 배포 직후 canary 메트릭의 비정상 변동을 조기 감지할 때
- 주기적 cron (5분 간격)으로 핵심 메트릭 모니터링

사용 제외:

- 정적 임계값으로 충분한 단순 알람 (CloudWatch Alarm 직접 사용)
- 베이스라인 데이터가 7일 미만인 신규 메트릭 (최소 7일 학습 필요)
- 일회성 스파이크가 정상인 배치 작업 메트릭 (이벤트 캘린더로 제외 처리)

## Prerequisites

- **awslabs.cloudwatch-mcp-server==0.0.25** — 메트릭 조회 (`@latest` 금지, PyPI 버전 pin 필수).
- **awslabs.prometheus-mcp-server==0.2.15** — 시계열 쿼리.
- 베이스라인 설정: `.omao/plans/observability/baselines/` 디렉토리 (본 skill이 자동 생성).
- `incident-response` skill 연동 — anomaly 탐지 시 자동 알람 생성.
- `autopilot-deploy` 상태 파일 접근 — 배포 직후 감도 조정 (배포 후 15분간 sensitivity 하향).
- 모니터링 대상 정의: `.omao/plans/observability/monitoring-targets.yaml`.

## 모니터링 대상 정의

```yaml
# .omao/plans/observability/monitoring-targets.yaml
targets:
  - name: rag-qa-agent
    metrics:
      - source: prometheus
        query: 'rate(agent_request_errors_total{service="rag-qa-agent"}[5m])'
        display_name: "Error Rate"
        baseline_window_days: 7
        sensitivity: 3.0  # σ multiplier
        
      - source: prometheus
        query: 'histogram_quantile(0.99, rate(agent_request_duration_seconds_bucket{service="rag-qa-agent"}[5m]))'
        display_name: "P99 Latency"
        baseline_window_days: 7
        sensitivity: 3.0
        
      - source: cloudwatch
        namespace: "AWS/Bedrock"
        metric_name: "InvocationLatency"
        dimensions:
          ModelId: "anthropic.claude-sonnet-4-6-v1:0"
        display_name: "Bedrock Invocation Latency"
        baseline_window_days: 7
        sensitivity: 3.0

      - source: prometheus
        query: 'rate(agent_token_usage_total{service="rag-qa-agent"}[5m])'
        display_name: "Token Usage"
        baseline_window_days: 7
        sensitivity: 2.5  # 비용 관련은 더 민감하게

    correlations:
      - pair: "Error Rate:P99 Latency"
        expected_r: 0.7
        description: "에러율과 레이턴시는 양의 상관관계"
      - pair: "Token Usage:P99 Latency"
        expected_r: 0.5
        description: "토큰 사용량과 레이턴시는 중간 상관관계"

    exclusions:
      - type: scheduled
        cron: "0 3 * * *"  # 매일 03:00 UTC
        duration_min: 30
        reason: "Daily reindex batch job"

schedule:
  interval_minutes: 5
  baseline_refresh_hours: 6
```

## 탐지 알고리즘

### 1. Statistical Baseline (Adaptive 3σ)

7일 이동 평균과 표준편차를 기반으로 정상 범위를 정의합니다. 베이스라인은 6시간마다 자동 갱신됩니다.

```python
import numpy as np
from datetime import datetime, timedelta
from dataclasses import dataclass, field
import json
import yaml

@dataclass
class Baseline:
    metric_name: str
    mean: float
    std: float
    upper_bound: float
    lower_bound: float
    sensitivity: float
    window_days: int
    computed_at: str
    seasonal_profile: dict = field(default_factory=dict)

def compute_baseline(metric_data: list[float], timestamps: list[str],
                     sensitivity: float = 3.0, window_days: int = 7) -> Baseline:
    """7일 이동 평균 + Nσ 기반 정상 범위 계산.
    
    Args:
        metric_data: 시계열 데이터 포인트
        timestamps: ISO 8601 타임스탬프 목록
        sensitivity: σ 배수 (기본 3.0)
        window_days: 베이스라인 윈도우 (기본 7일)
    
    Returns:
        Baseline 객체 (정상 범위 포함)
    """
    data = np.array(metric_data)
    
    # Outlier 제거 (IQR 방식) — 베이스라인 오염 방지
    q1, q3 = np.percentile(data, [25, 75])
    iqr = q3 - q1
    mask = (data >= q1 - 1.5 * iqr) & (data <= q3 + 1.5 * iqr)
    clean_data = data[mask]
    
    mean = float(np.mean(clean_data))
    std = float(np.std(clean_data))
    
    # 계절성 프로파일 생성 (시간대별 평균)
    seasonal = {}
    for ts, val in zip(timestamps, metric_data):
        hour = datetime.fromisoformat(ts.replace("Z", "+00:00")).hour
        dow = datetime.fromisoformat(ts.replace("Z", "+00:00")).weekday()
        key = f"{dow}_{hour}"
        seasonal.setdefault(key, []).append(val)
    seasonal_profile = {k: float(np.mean(v)) for k, v in seasonal.items()}
    
    return Baseline(
        metric_name="",
        mean=mean,
        std=std,
        upper_bound=mean + sensitivity * std,
        lower_bound=max(0, mean - sensitivity * std),
        sensitivity=sensitivity,
        window_days=window_days,
        computed_at=datetime.utcnow().isoformat() + "Z",
        seasonal_profile=seasonal_profile,
    )
```

### 2. Seasonality Correction

시간대별/요일별 패턴을 보정하여 false positive를 줄입니다.

```python
def seasonal_adjust(value: float, timestamp: str, 
                    seasonal_profile: dict, global_mean: float) -> tuple[float, float]:
    """계절성 프로파일 기반 보정.
    
    편차 기반 보정: value - seasonal_mean + global_mean
    (비율 기반 value/factor는 저트래픽 시간대에서 false critical을 유발하므로 사용 금지)
    
    Returns:
        (adjusted_value, seasonal_mean)
    """
    dt = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    key = f"{dt.weekday()}_{dt.hour}"
    seasonal_mean = seasonal_profile.get(key)
    
    if seasonal_mean is None:
        return value, global_mean
    
    # 편차 기반 보정: 현재 값에서 시간대 평균을 빼고 전역 평균을 더함
    adjusted = value - seasonal_mean + global_mean
    return adjusted, seasonal_mean


def is_in_exclusion_window(timestamp: str, exclusions: list[dict]) -> bool:
    """현재 시점이 제외 윈도우(배치 작업 등)에 해당하는지 확인."""
    dt = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    for exc in exclusions:
        if exc["type"] == "scheduled":
            # 간단한 cron 매칭 (시간/분만)
            parts = exc["cron"].split()
            cron_min, cron_hour = int(parts[0]), int(parts[1])
            if dt.hour == cron_hour and dt.minute >= cron_min:
                if (dt.minute - cron_min) < exc["duration_min"]:
                    return True
    return False
```

### 3. Multi-variate Correlation Analysis

단일 메트릭 이상이 아닌, 관련 메트릭 간 상관관계 붕괴를 탐지합니다.

```python
def correlation_check(metrics: dict[str, list[float]], 
                      expected_correlations: list[dict],
                      window_size: int = 60) -> list[dict]:
    """메트릭 간 상관관계 이탈 탐지.
    
    Args:
        metrics: {metric_name: [values]} 딕셔너리
        expected_correlations: 기대 상관관계 정의 목록
        window_size: 상관관계 계산 윈도우 (데이터 포인트 수)
    
    Returns:
        탐지된 상관관계 이상 목록
    """
    anomalies = []
    for corr_def in expected_correlations:
        m1_name, m2_name = corr_def["pair"].split(":")
        expected_r = corr_def["expected_r"]
        
        m1_data = metrics.get(m1_name, [])
        m2_data = metrics.get(m2_name, [])
        
        if len(m1_data) < window_size or len(m2_data) < window_size:
            continue
        
        # 최근 window_size 포인트로 상관관계 계산
        recent_m1 = np.array(m1_data[-window_size:])
        recent_m2 = np.array(m2_data[-window_size:])
        
        # 분산이 0이면 상관관계 계산 불가
        if np.std(recent_m1) == 0 or np.std(recent_m2) == 0:
            continue
            
        actual_r = float(np.corrcoef(recent_m1, recent_m2)[0, 1])
        deviation = abs(actual_r - expected_r)
        
        if deviation > 0.3:  # 상관관계 0.3 이상 이탈
            anomalies.append({
                "type": "correlation_breakdown",
                "pair": corr_def["pair"],
                "description": corr_def.get("description", ""),
                "expected_r": expected_r,
                "actual_r": actual_r,
                "deviation": deviation,
                "severity": "critical" if deviation > 0.5 else "warning",
                "detected_at": datetime.utcnow().isoformat() + "Z",
            })
    
    return anomalies
```

### 4. Anomaly Scoring & Classification

```python
@dataclass
class AnomalyEvent:
    metric_name: str
    timestamp: str
    value: float
    baseline_mean: float
    baseline_std: float
    sigma_deviation: float
    severity: str  # critical, warning, info
    type: str      # point_anomaly, correlation_breakdown, trend_shift
    context: dict = field(default_factory=dict)

def classify_anomaly(value: float, baseline: Baseline, 
                     timestamp: str) -> AnomalyEvent | None:
    """단일 데이터 포인트의 이상 여부 판정 및 severity 분류."""
    
    # 계절성 보정
    adjusted_value, seasonal_mean = seasonal_adjust(value, timestamp, baseline.seasonal_profile, baseline.mean)
    adjusted_mean = baseline.mean
    
    if baseline.std == 0:
        return None
    
    sigma = abs(adjusted_value - adjusted_mean) / baseline.std
    
    if sigma < 2.0:
        return None  # 정상 범위
    
    # Severity 분류
    if sigma >= 5.0:
        severity = "critical"
    elif sigma >= baseline.sensitivity:  # 기본 3.0
        severity = "warning"
    else:
        severity = "info"
    
    return AnomalyEvent(
        metric_name=baseline.metric_name,
        timestamp=timestamp,
        value=value,
        baseline_mean=baseline.mean,
        baseline_std=baseline.std,
        sigma_deviation=sigma,
        severity=severity,
        type="point_anomaly",
        context={
            "seasonal_factor": factor,
            "adjusted_value": adjusted_value,
            "upper_bound": baseline.upper_bound,
            "lower_bound": baseline.lower_bound,
        },
    )
```

## Anomaly Severity 분류

| Severity | 기준 | 후속 조치 |
|----------|------|----------|
| **Critical** | 5σ 이상 이탈 또는 다변량 상관 붕괴 3건 이상 동시 | `incident-response` SEV2 자동 호출 |
| **Warning** | 3σ~5σ 이탈 또는 계절성 보정 후에도 이상 | `incident-response` SEV3 큐에 적재 |
| **Info** | 2σ~3σ 이탈 (계절성 보정 전) | 로그 기록만, 주간 리뷰 큐 |

## 실행 흐름

### Step 1: 메트릭 수집

```bash
# 모니터링 대상 로드
TARGETS_FILE=".omao/plans/observability/monitoring-targets.yaml"

# Prometheus 메트릭 조회 (최근 1시간, 1분 간격)
mcp__prometheus__query_range \
  --query 'rate(agent_request_errors_total{service="rag-qa-agent"}[5m])' \
  --start "$(date -u -d '-1 hour' +%s)" \
  --end "$(date -u +%s)" \
  --step 60

# CloudWatch 메트릭 조회
mcp__cloudwatch__get_metric_data \
  --metric-name "InvocationLatency" \
  --namespace "AWS/Bedrock" \
  --dimensions '[{"Name":"ModelId","Value":"anthropic.claude-sonnet-4-6-v1:0"}]' \
  --period 60 \
  --start-time "$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### Step 2: 베이스라인 로드 또는 갱신

```python
import os
import yaml

BASELINE_DIR = ".omao/plans/observability/baselines"

def load_or_refresh_baseline(metric_name: str, metric_config: dict,
                             force_refresh: bool = False) -> Baseline:
    """베이스라인 로드. 6시간 이상 경과 시 자동 갱신."""
    baseline_file = os.path.join(BASELINE_DIR, f"{metric_name}.yaml")
    
    if os.path.exists(baseline_file) and not force_refresh:
        with open(baseline_file) as f:
            data = yaml.safe_load(f)
        computed_at = datetime.fromisoformat(data["computed_at"].replace("Z", "+00:00"))
        age_hours = (datetime.utcnow() - computed_at.replace(tzinfo=None)).total_seconds() / 3600
        
        if age_hours < 6:  # 6시간 미만이면 기존 베이스라인 사용
            return Baseline(**data)
    
    # 베이스라인 갱신: 7일 데이터 조회
    window_days = metric_config.get("baseline_window_days", 7)
    historical_data, timestamps = fetch_historical_data(
        metric_config, days=window_days
    )
    
    baseline = compute_baseline(
        historical_data, timestamps,
        sensitivity=metric_config.get("sensitivity", 3.0),
        window_days=window_days,
    )
    baseline.metric_name = metric_name
    
    # 저장
    os.makedirs(BASELINE_DIR, exist_ok=True)
    with open(baseline_file, "w") as f:
        yaml.dump(vars(baseline), f, default_flow_style=False)
    
    return baseline
```

### Step 3: 이상 판정 및 이벤트 생성

```python
def run_detection_cycle(targets_file: str) -> list[AnomalyEvent]:
    """단일 탐지 사이클 실행."""
    with open(targets_file) as f:
        config = yaml.safe_load(f)
    
    all_anomalies = []
    
    for target in config["targets"]:
        target_metrics = {}
        
        for metric_config in target["metrics"]:
            metric_name = metric_config["display_name"]
            
            # 제외 윈도우 확인
            now = datetime.utcnow().isoformat() + "Z"
            if is_in_exclusion_window(now, target.get("exclusions", [])):
                continue
            
            # 현재 값 조회
            current_values, timestamps = fetch_recent_data(metric_config, minutes=5)
            if not current_values:
                continue
            
            target_metrics[metric_name] = current_values
            
            # 베이스라인 로드
            baseline = load_or_refresh_baseline(metric_name, metric_config)
            
            # 각 데이터 포인트 검사
            for val, ts in zip(current_values, timestamps):
                anomaly = classify_anomaly(val, baseline, ts)
                if anomaly and anomaly.severity != "info":
                    all_anomalies.append(anomaly)
        
        # 상관관계 검사
        if target.get("correlations") and len(target_metrics) >= 2:
            corr_anomalies = correlation_check(
                target_metrics, target["correlations"]
            )
            for ca in corr_anomalies:
                all_anomalies.append(AnomalyEvent(
                    metric_name=ca["pair"],
                    timestamp=ca["detected_at"],
                    value=ca["actual_r"],
                    baseline_mean=ca["expected_r"],
                    baseline_std=0,
                    sigma_deviation=0,
                    severity=ca["severity"],
                    type="correlation_breakdown",
                    context=ca,
                ))
    
    return all_anomalies
```

### Step 4: 알람 라우팅

```python
import json
import os

ANOMALY_STATE_DIR = ".omao/state/anomaly"

def route_anomalies(anomalies: list[AnomalyEvent]) -> dict:
    """탐지된 anomaly를 severity에 따라 라우팅."""
    os.makedirs(ANOMALY_STATE_DIR, exist_ok=True)
    
    routed = {"critical": [], "warning": [], "info": []}
    
    for anomaly in anomalies:
        # 상태 파일 기록
        event_file = os.path.join(
            ANOMALY_STATE_DIR,
            f"{anomaly.timestamp.replace(':', '-')}-{anomaly.metric_name.replace(' ', '_')}.json"
        )
        with open(event_file, "w") as f:
            json.dump(vars(anomaly), f, indent=2, default=str)
        
        routed[anomaly.severity].append(anomaly)
    
    # Critical → incident-response SEV2 즉시 호출
    if routed["critical"]:
        trigger_incident_response(
            severity="SEV2",
            source="anomaly-detection",
            anomalies=routed["critical"],
        )
    
    # Warning → incident-response SEV3 큐 적재
    if routed["warning"]:
        enqueue_incident(
            severity="SEV3",
            source="anomaly-detection",
            anomalies=routed["warning"],
        )
    
    return {
        "total_detected": len(anomalies),
        "critical": len(routed["critical"]),
        "warning": len(routed["warning"]),
        "info": len(routed["info"]),
    }
```

### Step 5: 배포 컨텍스트 연동

`autopilot-deploy`의 최근 배포 이벤트와 anomaly 시점을 매핑하여 change-correlated anomaly를 식별합니다.

```python
def check_deploy_context(anomaly: AnomalyEvent) -> dict | None:
    """anomaly 시점에 최근 배포가 있었는지 확인."""
    deploy_state_dir = ".omao/state/autopilot-deploy"
    
    if not os.path.exists(deploy_state_dir):
        return None
    
    # 최근 배포 상태 확인
    for state_file in sorted(os.listdir(deploy_state_dir), reverse=True):
        if not state_file.endswith(".json"):
            continue
        with open(os.path.join(deploy_state_dir, state_file)) as f:
            deploy = json.load(f)
        
        deploy_time = datetime.fromisoformat(deploy.get("started_at", "").replace("Z", "+00:00"))
        anomaly_time = datetime.fromisoformat(anomaly.timestamp.replace("Z", "+00:00"))
        
        # 배포 후 15분 이내 anomaly → change-correlated
        delta_min = (anomaly_time - deploy_time).total_seconds() / 60
        if 0 < delta_min < 15:
            return {
                "correlated_deploy": deploy.get("target"),
                "deploy_version": deploy.get("version"),
                "time_after_deploy_min": delta_min,
                "recommendation": "Consider rollback if anomaly persists",
            }
    
    return None
```

## 상태 관리

- `.omao/plans/observability/monitoring-targets.yaml` — 모니터링 대상 정의
- `.omao/plans/observability/baselines/${metric}.yaml` — 메트릭별 베이스라인 (6시간마다 갱신)
- `.omao/state/anomaly/${timestamp}-${metric}.json` — 탐지된 anomaly 이벤트
- `.omao/state/anomaly/correlation-matrix.json` — 메트릭 간 상관관계 매트릭스 (일간 갱신)
- `.omao/state/anomaly/summary.json` — 최근 24시간 탐지 요약

## Example Inputs/Outputs

**Input**: `/anomaly-detection rag-qa-agent`

**Output (anomaly detected)**:

```
[14:05:00Z] Loading monitoring targets for: rag-qa-agent
[14:05:01Z] Metrics to check: 4 (Error Rate, P99 Latency, Bedrock Latency, Token Usage)
[14:05:01Z] Exclusion check: not in exclusion window
[14:05:02Z] Fetching recent data (5min window)...
[14:05:03Z] Baseline status:
             Error Rate       : loaded (age: 2h, mean=0.012, σ=0.004)
             P99 Latency      : loaded (age: 2h, mean=380ms, σ=45ms)
             Bedrock Latency  : loaded (age: 5h, mean=220ms, σ=30ms)
             Token Usage      : refreshing (age: 7h)...done
[14:05:05Z] Detection results:
             Error Rate       : 0.031 (4.8σ) → WARNING
             P99 Latency      : 890ms (11.3σ) → CRITICAL
             Bedrock Latency  : 245ms (0.8σ) → normal
             Token Usage      : 1250 (1.2σ) → normal
[14:05:05Z] Correlation check:
             Error Rate:P99 Latency — expected r=0.7, actual r=0.92 (Δ=0.22) → normal
             Token Usage:P99 Latency — expected r=0.5, actual r=-0.1 (Δ=0.60) → CRITICAL
[14:05:06Z] Deploy context: canary v2.3.1 deployed 8min ago → CHANGE-CORRELATED
[14:05:06Z] Summary: 2 critical, 1 warning, 0 info
[14:05:06Z] Action: Triggering incident-response SEV2
             Source: anomaly-detection
             Evidence: P99 Latency 11.3σ + correlation breakdown (Token:Latency)
             Context: Correlated with deploy rag-qa-agent:v2.3.1 (8min ago)
[14:05:06Z] Events saved to .omao/state/anomaly/
```

**Output (all normal)**:

```
[14:05:00Z] Loading monitoring targets for: rag-qa-agent
[14:05:03Z] Detection results:
             Error Rate       : 0.013 (0.3σ) → normal
             P99 Latency      : 395ms (0.3σ) → normal
             Bedrock Latency  : 218ms (0.1σ) → normal
             Token Usage      : 980 (0.5σ) → normal
[14:05:04Z] Correlation check: all within expected range
[14:05:04Z] Summary: 0 critical, 0 warning, 0 info
[14:05:04Z] No anomalies detected. Next check in 5 minutes.
```

**Output (exclusion window)**:

```
[03:05:00Z] Loading monitoring targets for: rag-qa-agent
[03:05:01Z] Exclusion check: IN EXCLUSION WINDOW
             Reason: "Daily reindex batch job" (03:00-03:30 UTC)
[03:05:01Z] Skipping detection cycle. Next check at 03:35 UTC.
```

## 기존 스킬 연동

| 연동 대상 | 방향 | 설명 |
|-----------|------|------|
| `incident-response` | → 출력 | Critical/Warning anomaly를 알람으로 전달 |
| `autopilot-deploy` | ← 입력 | 배포 이벤트 시점을 anomaly 컨텍스트로 수신 |
| `continuous-eval` | ← 입력 | 품질 메트릭 regression을 anomaly 소스로 활용 |
| `cost-governance` | → 출력 | 비용 메트릭 이상(Token Usage 급증)을 cost alert로 전달 |
| `root-cause-analysis` | → 출력 | Critical anomaly 발생 시 RCA 트리거 |

## 참고 자료

### 공식 문서

- [CloudWatch Anomaly Detection](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Anomaly_Detection.html) — AWS 네이티브 이상 탐지 (참고용, 본 skill은 커스텀 구현)
- [Prometheus Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/) — 사전 집계 규칙
- [awslabs/mcp — cloudwatch-mcp-server](https://github.com/awslabs/mcp/tree/main/src/cloudwatch-mcp-server) — CloudWatch MCP
- [awslabs/mcp — prometheus-mcp-server](https://github.com/awslabs/mcp/tree/main/src/prometheus-mcp-server) — Prometheus MCP

### 기술 블로그

- [Netflix — Robust Anomaly Detection](https://netflixtechblog.com/rad-outlier-detection-on-big-data-d6b0ff32fb44) — 대규모 시계열 이상 탐지
- [Twitter — AnomalyDetection R Package](https://blog.twitter.com/engineering/en_us/a/2015/introducing-practical-and-robust-anomaly-detection-in-a-time-series) — 계절성 보정 이상 탐지

### 관련 문서 (내부)

- [incident-response skill](../incident-response/SKILL.md) — anomaly 알람 수신자
- [autopilot-deploy skill](../autopilot-deploy/SKILL.md) — 배포 컨텍스트 제공자
- [continuous-eval skill](../continuous-eval/SKILL.md) — 품질 메트릭 소스
- [cost-governance skill](../cost-governance/SKILL.md) — 비용 anomaly 수신자
- [root-cause-analysis skill](../root-cause-analysis/SKILL.md) — Critical anomaly 후속 분석
