---
name: predictive-scaling
description: 과거 트래픽 패턴과 시계열 예측을 기반으로 리소스 수요를 사전 예측하고 스케일링을 권고한다. 시간대별/요일별 계절성 분석, 이벤트 기반 수요 급증 예측, 비용 대비 성능 최적 구성 제안을 수행하며 cost-governance와 연동하여 예산 범위 내 스케일링을 보장한다.
argument-hint: "[service-name or scaling-target]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus,mcp__eks"
---

## When to Use

- Sub-Phase 5 (Govern) 확장 — `cost-governance`와 연동하여 비용 효율적 스케일링
- 매일 cron으로 다음 24시간 수요 예측 및 스케일링 계획 생성
- 알려진 이벤트(마케팅 캠페인, 정기 배치 등) 전 사전 스케일링 준비
- `autopilot-deploy`의 canary 단계에서 트래픽 증가 예측 시

사용 제외:

- 트래픽 패턴이 불규칙하여 예측이 무의미한 서비스 (reactive HPA로 충분)
- 과거 데이터가 14일 미만인 신규 서비스 (최소 2주 학습 필요)

## Prerequisites

- **awslabs.cloudwatch-mcp-server==0.0.25** — 과거 메트릭 조회.
- **awslabs.prometheus-mcp-server==0.2.15** — 시계열 데이터.
- **awslabs.eks-mcp-server** — HPA/VPA 현재 설정 조회.
- 과거 트래픽 데이터: 최소 14일, 권장 30일 이상.
- 스케일링 정의: `.omao/plans/scaling/targets/${service}.yaml`.
- `cost-governance` 예산 파일 접근 — 비용 상한 내 스케일링 보장.

## 스케일링 대상 정의

```yaml
# .omao/plans/scaling/targets/rag-qa-agent.yaml
service: rag-qa-agent
namespace: production
scaling_targets:
  - resource: deployment/rag-qa-agent
    type: horizontal
    min_replicas: 2
    max_replicas: 20
    metrics:
      - name: cpu_utilization
        target_pct: 70
      - name: requests_per_second
        target: 100
    
  - resource: deployment/rag-qa-agent
    type: vertical
    containers:
      - name: main
        cpu_range: [500m, 4000m]
        memory_range: [512Mi, 4Gi]

prediction_config:
  lookback_days: 30
  forecast_hours: 24
  seasonality: [hourly, daily, weekly]
  confidence_interval: 0.95
  
cost_constraints:
  max_hourly_cost_usd: 50
  prefer_spot: true
  spot_ratio: 0.7
```

## 예측 알고리즘

### 1. Seasonal Decomposition

시계열을 트렌드, 계절성, 잔차로 분해합니다.

```python
import numpy as np
from dataclasses import dataclass

@dataclass
class ForecastResult:
    timestamps: list[str]
    predicted_values: list[float]
    upper_bound: list[float]  # 95% CI
    lower_bound: list[float]  # 95% CI
    recommended_replicas: list[int]

def seasonal_forecast(historical_data: list[float], 
                      periods_per_day: int = 24,
                      forecast_hours: int = 24) -> ForecastResult:
    """계절성 분해 기반 수요 예측."""
    data = np.array(historical_data)
    
    # 일간 계절성 추출
    daily_pattern = np.array([
        np.mean(data[i::periods_per_day]) 
        for i in range(periods_per_day)
    ])
    
    # 트렌드 추출 (7일 이동 평균)
    trend = np.convolve(data, np.ones(7*periods_per_day)/(7*periods_per_day), mode='valid')
    
    # 예측: 최근 트렌드 + 계절성 패턴
    forecast = []
    for h in range(forecast_hours):
        hour_of_day = h % periods_per_day
        predicted = trend[-1] + daily_pattern[hour_of_day]
        forecast.append(predicted)
    
    # 신뢰구간
    residual_std = np.std(data - np.tile(daily_pattern, len(data)//periods_per_day + 1)[:len(data)])
    upper = [f + 1.96 * residual_std for f in forecast]
    lower = [f - 1.96 * residual_std for f in forecast]
    
    return ForecastResult(
        timestamps=[...],
        predicted_values=forecast,
        upper_bound=upper,
        lower_bound=lower,
        recommended_replicas=compute_replicas(upper),  # upper bound 기준
    )
```

### 2. Event-Aware Adjustment

알려진 이벤트(마케팅, 배치 작업 등)를 반영하여 예측을 보정합니다.

```python
def event_adjustment(base_forecast: list[float], 
                     events: list[dict]) -> list[float]:
    """알려진 이벤트 기반 예측 보정."""
    adjusted = base_forecast.copy()
    for event in events:
        start_hour = event["start_hour"]
        duration_hours = event["duration_hours"]
        multiplier = event["traffic_multiplier"]
        for h in range(start_hour, start_hour + duration_hours):
            if h < len(adjusted):
                adjusted[h] *= multiplier
    return adjusted
```

### 3. Cost-Optimized Replica Calculation

비용 제약 내에서 최적 replica 수를 계산합니다.

```python
def compute_replicas(predicted_load: list[float], 
                     target_utilization: float = 0.7,
                     max_hourly_cost: float = 50,
                     cost_per_replica_hour: float = 2.5) -> list[int]:
    """비용 제약 내 최적 replica 수 계산."""
    replicas = []
    for load in predicted_load:
        ideal = int(np.ceil(load / target_utilization))
        max_by_cost = int(max_hourly_cost / cost_per_replica_hour)
        replicas.append(min(ideal, max_by_cost))
    return replicas
```

## 실행 흐름

### Step 1: 과거 데이터 수집

```bash
# 30일 시계열 데이터 조회
mcp__prometheus__query_range \
  --query 'sum(rate(agent_request_total{service="rag-qa-agent"}[5m]))' \
  --start "$(date -u -d '-30 days' +%s)" \
  --end "$(date -u +%s)" \
  --step 3600
```

### Step 2: 예측 실행 및 스케일링 계획 생성

### Step 3: Cost Governance 검증

예측된 스케일링 계획이 예산 범위 내인지 `cost-governance`에 확인합니다.

### Step 4: 스케일링 권고 생성

```markdown
## Scaling Recommendation — rag-qa-agent (2026-05-09)

### Predicted Traffic Pattern
- Peak: 14:00-16:00 UTC (예상 RPS: 850)
- Trough: 03:00-06:00 UTC (예상 RPS: 120)

### Recommended Schedule
| Time (UTC) | Replicas | Estimated Cost/hr |
|------------|----------|-------------------|
| 00:00-06:00 | 3 | $7.50 |
| 06:00-09:00 | 8 | $20.00 |
| 09:00-14:00 | 12 | $30.00 |
| 14:00-18:00 | 16 | $40.00 |
| 18:00-24:00 | 8 | $20.00 |

### Daily Estimated Cost: $580 (budget: $600/day)
```

### Step 5: 자동 적용 (승인 후)

사람 승인 후 EKS HPA/CronHPA 설정을 업데이트합니다.

## 상태 관리

- `.omao/plans/scaling/targets/${service}.yaml` — 스케일링 대상 정의
- `.omao/plans/scaling/forecasts/${service}-${date}.json` — 일간 예측 결과
- `.omao/plans/scaling/schedules/${service}-${date}.yaml` — 적용된 스케일링 스케줄
- `.omao/state/scaling/${service}/current.json` — 현재 스케일링 상태

## 기존 스킬 연동

| 연동 대상 | 방향 | 설명 |
|-----------|------|------|
| `cost-governance` | ↔ 양방향 | 예산 제약 수신 / 예상 비용 전달 |
| `autopilot-deploy` | → 출력 | 배포 시 트래픽 증가 예측 정보 제공 |
| `anomaly-detection` | ← 입력 | 예측 대비 실제 트래픽 이상 탐지 결과 수신 |
| `slo-management` | ← 입력 | SLO 위반 위험 시 스케일업 트리거 |
| `continuous-eval` | ← 입력 | 평가 부하 예측 (golden dataset 크기 기반) |

## 참고 자료

### 공식 문서

- [AWS Predictive Scaling](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-predictive-scaling.html) — AWS 네이티브 예측 스케일링
- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) — 수평 자동 스케일링
- [KEDA](https://keda.sh/) — 이벤트 기반 자동 스케일링

### 기술 블로그

- [Google — Predictive Autoscaling](https://cloud.google.com/blog/products/compute/predictive-autoscaling-in-google-cloud) — 예측 스케일링 패턴
- [Uber — Forecasting at Scale](https://www.uber.com/blog/forecasting-introduction/) — 대규모 시계열 예측

### 관련 문서 (내부)

- [cost-governance skill](../cost-governance/SKILL.md) — 비용 제약 소스
- [autopilot-deploy skill](../autopilot-deploy/SKILL.md) — 배포 시 스케일링 연동
- [anomaly-detection skill](../anomaly-detection/SKILL.md) — 예측 이탈 탐지
- [slo-management skill](../slo-management/SKILL.md) — SLO 기반 스케일업 트리거
