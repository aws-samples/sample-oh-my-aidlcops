---
name: anomaly-detection
description: CloudWatch 메트릭과 Prometheus 시계열 데이터에서 통계적 이상 징후를 자동 탐지하여 incident-response의 입력 소스로 제공한다. 베이스라인 학습(7일 이동 평균 + 3σ), 다변량 상관 분석, 계절성 보정을 수행하며 탐지된 anomaly를 severity 분류하여 알람을 생성한다.
argument-hint: "[target-metric or agent-name]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus"
---

## When to Use

- Sub-Phase 2 (Observe)에서 프로덕션 메트릭의 이상 패턴을 사전 탐지할 때
- `incident-response`의 알람 소스로 — CloudWatch/Prometheus 정적 임계값으로 잡히지 않는 이상 징후 탐지
- 배포 직후 canary 메트릭의 비정상 변동을 조기 감지할 때
- 주기적 cron (5분 간격)으로 핵심 메트릭 모니터링

사용 제외:

- 정적 임계값으로 충분한 단순 알람 (CloudWatch Alarm 직접 사용)
- 베이스라인 데이터가 7일 미만인 신규 메트릭 (최소 7일 학습 필요)

## Prerequisites

- **awslabs.cloudwatch-mcp-server==0.0.25** — 메트릭 조회 (`@latest` 금지, PyPI 버전 pin 필수).
- **awslabs.prometheus-mcp-server==0.2.15** — 시계열 쿼리.
- 베이스라인 설정: `.omao/plans/observability/baselines/${metric}.yaml`.
- `incident-response` skill 연동 — anomaly 탐지 시 자동 알람 생성.
- `autopilot-deploy` 상태 파일 접근 — 배포 직후 감도 조정.

## 탐지 알고리즘

### 1. Statistical Baseline (3σ)

7일 이동 평균과 표준편차를 기반으로 정상 범위를 정의합니다.

```python
import numpy as np
from datetime import datetime, timedelta

def compute_baseline(metric_data: list[float], window_days: int = 7) -> dict:
    """7일 이동 평균 + 3σ 기반 정상 범위 계산."""
    data = np.array(metric_data)
    return {
        "mean": float(np.mean(data)),
        "std": float(np.std(data)),
        "upper_bound": float(np.mean(data) + 3 * np.std(data)),
        "lower_bound": float(np.mean(data) - 3 * np.std(data)),
        "window_days": window_days,
        "computed_at": datetime.utcnow().isoformat() + "Z",
    }
```

### 2. Seasonality Correction

시간대별/요일별 패턴을 보정하여 false positive를 줄입니다.

```python
def seasonal_adjust(value: float, hour: int, day_of_week: int, 
                    seasonal_profile: dict) -> float:
    """계절성 프로파일 기반 보정값 반환."""
    factor = seasonal_profile.get(f"{day_of_week}_{hour}", 1.0)
    return value / factor if factor != 0 else value
```

### 3. Multi-variate Correlation

단일 메트릭 이상이 아닌, 관련 메트릭 간 상관관계 붕괴를 탐지합니다.

```python
def correlation_check(metrics: dict[str, list[float]], 
                      expected_correlations: dict) -> list[dict]:
    """메트릭 간 상관관계 이탈 탐지."""
    anomalies = []
    for pair, expected_r in expected_correlations.items():
        m1, m2 = pair.split(":")
        actual_r = np.corrcoef(metrics[m1], metrics[m2])[0, 1]
        if abs(actual_r - expected_r) > 0.3:
            anomalies.append({
                "type": "correlation_breakdown",
                "metrics": pair,
                "expected_r": expected_r,
                "actual_r": float(actual_r),
            })
    return anomalies
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
# CloudWatch 메트릭 조회 (최근 1시간, 1분 간격)
mcp__cloudwatch__get_metric_data \
  --metric-name "agent_latency_p99" \
  --namespace "AgenticOps" \
  --period 60 \
  --start-time "$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)"

# Prometheus 범위 쿼리
mcp__prometheus__query_range \
  --query 'rate(agent_request_errors_total[5m])' \
  --start "$(date -u -d '-1 hour' +%s)" \
  --end "$(date -u +%s)" \
  --step 60
```

### Step 2: 베이스라인 비교 및 이상 판정

### Step 3: Anomaly 이벤트 생성 및 라우팅

탐지된 anomaly는 `.omao/state/anomaly/` 에 기록하고 severity에 따라 라우팅합니다.

### Step 4: 배포 컨텍스트 연동

`autopilot-deploy`의 최근 배포 이벤트와 anomaly 시점을 매핑하여 change-correlated anomaly를 식별합니다.

## 상태 관리

- `.omao/plans/observability/baselines/${metric}.yaml` — 메트릭별 베이스라인
- `.omao/state/anomaly/${timestamp}-${metric}.json` — 탐지된 anomaly 이벤트
- `.omao/state/anomaly/correlation-matrix.json` — 메트릭 간 상관관계 매트릭스

## 기존 스킬 연동

| 연동 대상 | 방향 | 설명 |
|-----------|------|------|
| `incident-response` | → 출력 | Critical/Warning anomaly를 알람으로 전달 |
| `autopilot-deploy` | ← 입력 | 배포 이벤트 시점을 anomaly 컨텍스트로 수신 |
| `continuous-eval` | ← 입력 | 품질 메트릭 regression을 anomaly 소스로 활용 |
| `cost-governance` | → 출력 | 비용 메트릭 이상을 cost alert로 전달 |

## 참고 자료

### 공식 문서

- [CloudWatch Anomaly Detection](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Anomaly_Detection.html) — AWS 네이티브 이상 탐지
- [Prometheus Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/) — 사전 집계 규칙
- [awslabs/mcp — cloudwatch-mcp-server](https://github.com/awslabs/mcp/tree/main/src/cloudwatch-mcp-server) — CloudWatch MCP

### 관련 문서 (내부)

- [incident-response skill](../incident-response/SKILL.md) — anomaly 알람 수신자
- [autopilot-deploy skill](../autopilot-deploy/SKILL.md) — 배포 컨텍스트 제공자
- [continuous-eval skill](../continuous-eval/SKILL.md) — 품질 메트릭 소스
- [cost-governance skill](../cost-governance/SKILL.md) — 비용 anomaly 수신자
