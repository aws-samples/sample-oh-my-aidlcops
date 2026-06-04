---
name: predictive-scaling
description: 과거 트래픽 패턴과 시계열 예측을 기반으로 리소스 수요를 사전 예측하고 스케일링을 권고한다. 시간대별/요일별 계절성 분석, 이벤트 기반 수요 급증 예측, 비용 대비 성능 최적 구성 제안을 수행하며 cost-governance와 연동하여 예산 범위 내 스케일링을 보장한다.
argument-hint: "[service-name or scaling-target]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus,mcp__eks"
ontology:
  references: [Deployment, Budget]
---

## When to Use

- Sub-Phase 5 (Govern) 확장 — `cost-governance`와 연동하여 비용 효율적 스케일링
- 매일 cron으로 다음 24시간 수요 예측 및 스케일링 계획 생성
- 알려진 이벤트(마케팅 캠페인, 정기 배치 등) 전 사전 스케일링 준비
- `slo-management`에서 SLO 위반 위험 감지 시 스케일업 트리거
- `autopilot-deploy`의 canary 단계에서 트래픽 증가 예측 시

사용 제외:

- 트래픽 패턴이 완전히 불규칙한 서비스 (reactive HPA로 충분)
- 과거 데이터가 14일 미만인 신규 서비스 (최소 2주 학습 필요)
- 이미 max_replicas에 도달한 서비스 (클러스터 용량 확장 필요)

## Prerequisites

- **awslabs.cloudwatch-mcp-server==0.0.25** — 과거 메트릭 조회.
- **awslabs.prometheus-mcp-server==0.2.15** — 시계열 데이터.
- **awslabs.eks-mcp-server==0.1.28** — HPA/Deployment 현재 설정 조회 전용 (`@latest` 금지, PyPI 버전 pin 필수). 승인된 스케일링 스케줄 적용(CronHPA 업데이트)은 EKS MCP가 아닌 `kubectl` Bash 명령으로 실행하며, EKS MCP는 read-only 기본값을 유지합니다.
- 과거 트래픽 데이터: 최소 14일, 권장 30일 이상.
- 스케일링 정의: `.omao/plans/scaling/targets/${service}.yaml`.
- `cost-governance` 예산 파일 접근 — 비용 상한 내 스케일링 보장.

## 스케일링 대상 정의

```yaml
# .omao/plans/scaling/targets/rag-qa-agent.yaml
service: rag-qa-agent
namespace: production
owner: ml-platform-team

scaling_targets:
  - resource: deployment/rag-qa-agent
    type: horizontal
    current_hpa:
      min_replicas: 2
      max_replicas: 20
      target_cpu_pct: 70
    metrics:
      - name: cpu_utilization
        target_pct: 70
        query: 'avg(rate(container_cpu_usage_seconds_total{pod=~"rag-qa-agent.*"}[5m])) / avg(kube_pod_container_resource_requests{resource="cpu",pod=~"rag-qa-agent.*"})'
      - name: requests_per_second
        target: 100
        query: 'sum(rate(agent_request_total{service="rag-qa-agent"}[5m]))'
      - name: memory_utilization
        target_pct: 80
        query: 'avg(container_memory_working_set_bytes{pod=~"rag-qa-agent.*"}) / avg(kube_pod_container_resource_requests{resource="memory",pod=~"rag-qa-agent.*"})'

prediction_config:
  lookback_days: 30
  forecast_hours: 24
  granularity_minutes: 60
  seasonality: [hourly, daily, weekly]
  confidence_interval: 0.95
  
cost_constraints:
  max_hourly_cost_usd: 50
  cost_per_replica_hour_usd: 2.50
  prefer_spot: true
  spot_ratio: 0.7
  spot_discount: 0.6  # spot은 on-demand의 60%

events_calendar:
  - name: "Daily reindex"
    cron: "0 3 * * *"
    duration_hours: 1
    traffic_multiplier: 0.3  # 트래픽 감소
  - name: "Weekly report generation"
    cron: "0 9 * * 1"
    duration_hours: 2
    traffic_multiplier: 2.5  # 트래픽 증가
```

## 예측 알고리즘

### 1. Seasonal Decomposition + Trend

시계열을 트렌드, 계절성, 잔차로 분해합니다.

```python
import os
import numpy as np
import yaml
from datetime import datetime, timedelta

def seasonal_forecast(historical_data: list[float], 
                      timestamps: list[str],
                      forecast_hours: int = 24,
                      confidence: float = 0.95) -> list[dict]:
    """계절성 분해 기반 수요 예측.
    
    방법:
    1. 7일 이동 평균으로 트렌드 추출
    2. 시간대별(24h) + 요일별(7d) 계절성 패턴 추출
    3. 잔차의 표준편차로 신뢰구간 계산
    4. 트렌드 + 계절성으로 예측값 생성
    """
    data = np.array(historical_data)
    periods_per_day = 24  # 시간 단위
    
    if len(data) < periods_per_day * 7:
        raise ValueError("Minimum 7 days of hourly data required")
    
    # 1. 트렌드 추출 (7일 이동 평균)
    window = periods_per_day * 7
    if len(data) >= window:
        trend = np.convolve(data, np.ones(window)/window, mode='valid')
        trend_slope = (trend[-1] - trend[0]) / len(trend) if len(trend) > 1 else 0
        trend_last = trend[-1]
    else:
        trend_slope = 0
        trend_last = np.mean(data)
    
    # 2. 시간대별 계절성 (24시간 패턴)
    hourly_pattern = np.zeros(periods_per_day)
    hourly_counts = np.zeros(periods_per_day)
    for i, ts in enumerate(timestamps):
        hour = datetime.fromisoformat(ts.replace("Z", "+00:00")).hour
        hourly_pattern[hour] += data[i]
        hourly_counts[hour] += 1
    hourly_pattern = hourly_pattern / np.maximum(hourly_counts, 1)
    
    # 3. 요일별 보정 계수
    daily_factors = np.ones(7)
    daily_counts = np.zeros(7)
    daily_sums = np.zeros(7)
    for i, ts in enumerate(timestamps):
        dow = datetime.fromisoformat(ts.replace("Z", "+00:00")).weekday()
        daily_sums[dow] += data[i]
        daily_counts[dow] += 1
    daily_avgs = daily_sums / np.maximum(daily_counts, 1)
    overall_avg = np.mean(data)
    if overall_avg > 0:
        daily_factors = daily_avgs / overall_avg
    
    # 4. 잔차 계산 및 신뢰구간
    residuals = []
    for i, ts in enumerate(timestamps):
        hour = datetime.fromisoformat(ts.replace("Z", "+00:00")).hour
        expected = hourly_pattern[hour]
        residuals.append(data[i] - expected)
    residual_std = np.std(residuals)
    
    # z-score for 95% confidence interval (hardcoded to avoid scipy dependency)
    z = 1.96
    
    # 5. 예측 생성
    now = datetime.utcnow()
    predictions = []
    for h in range(forecast_hours):
        future_time = now + timedelta(hours=h)
        hour_of_day = future_time.hour
        day_of_week = future_time.weekday()
        
        # 예측 = 시간대 패턴 × 요일 보정 + 트렌드
        if overall_avg > 0:
            predicted = hourly_pattern[hour_of_day] * daily_factors[day_of_week]
            predicted += trend_slope * h  # 트렌드 보정
        else:
            predicted = trend_last + trend_slope * h
        
        upper = predicted + z * residual_std
        lower = max(0, predicted - z * residual_std)
        
        predictions.append({
            "hour": h,
            "timestamp": future_time.isoformat() + "Z",
            "predicted_rps": round(float(predicted), 2),
            "upper_ci": round(float(upper), 2),
            "lower_ci": round(float(lower), 2),
        })
    
    return predictions
```

### 2. Event-Aware Adjustment

알려진 이벤트를 반영하여 예측을 보정합니다.

```python
def apply_event_adjustments(predictions: list[dict], 
                            events_calendar: list[dict]) -> list[dict]:
    """알려진 이벤트 기반 예측 보정.
    
    이벤트 캘린더의 traffic_multiplier를 적용합니다.
    """
    adjusted = []
    for pred in predictions:
        ts = datetime.fromisoformat(pred["timestamp"].replace("Z", "+00:00"))
        multiplier = 1.0
        event_name = None
        
        for event in events_calendar:
            # 간단한 cron 매칭 (시간/요일)
            parts = event["cron"].split()
            cron_min, cron_hour = int(parts[0]), int(parts[1])
            cron_dow = parts[4]
            
            # 요일 매칭 (cron: 0=Sun..6=Sat → Python isoweekday: 1=Mon..7=Sun)
            dow_match = (cron_dow == "*" or int(cron_dow) == ts.isoweekday() % 7)
            # 시간 매칭 (duration 고려)
            hour_match = (cron_hour <= ts.hour < cron_hour + event["duration_hours"])
            
            if dow_match and hour_match:
                multiplier = event["traffic_multiplier"]
                event_name = event["name"]
                break
        
        adj_pred = pred.copy()
        adj_pred["predicted_rps"] = round(pred["predicted_rps"] * multiplier, 2)
        adj_pred["upper_ci"] = round(pred["upper_ci"] * multiplier, 2)
        adj_pred["lower_ci"] = round(max(0, pred["lower_ci"] * multiplier), 2)
        if event_name:
            adj_pred["event"] = event_name
            adj_pred["multiplier"] = multiplier
        adjusted.append(adj_pred)
    
    return adjusted
```

### 3. Cost-Optimized Replica Calculation

비용 제약 내에서 최적 replica 수를 계산합니다.

```python
def compute_scaling_schedule(predictions: list[dict],
                             scaling_config: dict,
                             cost_constraints: dict) -> list[dict]:
    """비용 제약 내 최적 스케일링 스케줄 계산.
    
    원칙:
    - upper_ci 기준으로 replica 수 결정 (안전 마진)
    - 비용 상한 초과 시 target_utilization을 높여 replica 감소
    - spot 인스턴스 비율 적용
    """
    target_rps_per_replica = next(
        (m["target"] for m in scaling_config.get("metrics", [])
         if m.get("name") == "requests_per_second"),
        100,
    )
    min_replicas = scaling_config.get("current_hpa", {}).get("min_replicas", 2)
    max_replicas = scaling_config.get("current_hpa", {}).get("max_replicas", 20)
    
    cost_per_hour = cost_constraints.get("cost_per_replica_hour_usd", 2.5)
    max_hourly_cost = cost_constraints.get("max_hourly_cost_usd", 50)
    spot_ratio = cost_constraints.get("spot_ratio", 0.7)
    spot_discount = cost_constraints.get("spot_discount", 0.6)
    
    # Effective cost per replica (spot 혼합)
    effective_cost = cost_per_hour * (spot_ratio * spot_discount + (1 - spot_ratio) * 1.0)
    max_replicas_by_cost = int(max_hourly_cost / effective_cost)
    
    schedule = []
    for pred in predictions:
        # Upper CI 기준 필요 replica 수
        needed_rps = pred["upper_ci"]
        ideal_replicas = int(np.ceil(needed_rps / target_rps_per_replica))
        
        # 제약 적용
        replicas = max(min_replicas, min(ideal_replicas, max_replicas, max_replicas_by_cost))
        
        hourly_cost = replicas * effective_cost
        
        schedule.append({
            "timestamp": pred["timestamp"],
            "hour": pred["hour"],
            "predicted_rps": pred["predicted_rps"],
            "upper_ci_rps": pred["upper_ci"],
            "replicas": replicas,
            "hourly_cost_usd": round(hourly_cost, 2),
            "event": pred.get("event"),
        })
    
    return schedule
```

## 실행 흐름

### Step 1: 과거 데이터 수집

```bash
# 30일 시계열 데이터 조회 (시간 단위)
mcp__prometheus__query_range \
  --query 'sum(rate(agent_request_total{service="rag-qa-agent"}[5m]))' \
  --start "$(date -u -d '-30 days' +%s)" \
  --end "$(date -u +%s)" \
  --step 3600

# CloudWatch에서 CPU 사용률 조회
mcp__cloudwatch__get_metric_data \
  --metric-name "CPUUtilization" \
  --namespace "ContainerInsights" \
  --dimensions '[{"Name":"PodName","Value":"rag-qa-agent"}]' \
  --period 3600 \
  --start-time "$(date -u -d '-30 days' +%Y-%m-%dT%H:%M:%SZ)"
```

### Step 2: 예측 실행

```python
def run_forecast(service: str) -> dict:
    """전체 예측 파이프라인 실행."""
    # 설정 로드
    config_file = f".omao/plans/scaling/targets/{service}.yaml"
    with open(config_file) as f:
        config = yaml.safe_load(f)
    
    pred_config = config["prediction_config"]
    
    # 과거 데이터 수집
    historical_data, timestamps = fetch_historical_traffic(
        service, days=pred_config["lookback_days"]
    )
    
    # 예측 실행
    predictions = seasonal_forecast(
        historical_data, timestamps,
        forecast_hours=pred_config["forecast_hours"],
        confidence=pred_config["confidence_interval"],
    )
    
    # 이벤트 보정
    if config.get("events_calendar"):
        predictions = apply_event_adjustments(predictions, config["events_calendar"])
    
    # 스케일링 스케줄 계산
    schedule = compute_scaling_schedule(
        predictions,
        config["scaling_targets"][0],
        config["cost_constraints"],
    )
    
    return {
        "service": service,
        "predictions": predictions,
        "schedule": schedule,
        "generated_at": datetime.utcnow().isoformat() + "Z",
    }
```

### Step 3: Cost Governance 검증

```python
def verify_cost_budget(schedule: list[dict], service: str) -> dict:
    """예측된 스케일링 비용이 예산 범위 내인지 검증.
    
    cost-governance의 per_agent 예산과 비교합니다.
    """
    daily_cost = sum(s["hourly_cost_usd"] for s in schedule)
    monthly_projected = daily_cost * 30
    
    # cost-governance 예산 로드
    budget_file = ".omao/plans/cost/budget.yaml"
    if os.path.exists(budget_file):
        with open(budget_file) as f:
            budget = yaml.safe_load(f)
        agent_budget = budget.get("monthly_ceiling_usd", {}).get("per_agent", {}).get(service)
    else:
        agent_budget = None
    
    result = {
        "daily_cost_usd": round(daily_cost, 2),
        "monthly_projected_usd": round(monthly_projected, 2),
        "agent_budget_usd": agent_budget,
        "within_budget": True,
    }
    
    if agent_budget and monthly_projected > agent_budget:
        result["within_budget"] = False
        result["overage_usd"] = round(monthly_projected - agent_budget, 2)
        result["recommendation"] = "Reduce max_replicas or increase spot_ratio"
    
    return result
```

### Step 4: 스케일링 권고 생성 및 저장

```python
def generate_scaling_recommendation(service: str, schedule: list[dict],
                                    cost_check: dict) -> str:
    """스케일링 권고 마크다운 생성."""
    now = datetime.utcnow().strftime("%Y-%m-%d")
    
    # Peak/Trough 식별
    peak = max(schedule, key=lambda s: s["replicas"])
    trough = min(schedule, key=lambda s: s["replicas"])
    daily_cost = sum(s["hourly_cost_usd"] for s in schedule)
    
    report = f"""## Scaling Recommendation — {service} ({now})

### Predicted Traffic Pattern
- **Peak**: {peak['timestamp'][:16]} UTC (예상 RPS: {peak['upper_ci_rps']}, replicas: {peak['replicas']})
- **Trough**: {trough['timestamp'][:16]} UTC (예상 RPS: {trough['upper_ci_rps']}, replicas: {trough['replicas']})

### Recommended Schedule

| Time (UTC) | Predicted RPS | Upper CI | Replicas | Cost/hr | Event |
|------------|--------------|----------|----------|---------|-------|
"""
    for s in schedule:
        event = s.get("event", "-")
        report += f"| {s['timestamp'][11:16]} | {s['predicted_rps']} | {s['upper_ci_rps']} | {s['replicas']} | ${s['hourly_cost_usd']} | {event} |\n"
    
    report += f"""
### Cost Summary
- **Daily Estimated Cost**: ${daily_cost:.2f}
- **Monthly Projected**: ${daily_cost * 30:.2f}
- **Budget Status**: {'✅ Within budget' if cost_check['within_budget'] else '⚠️ Over budget by $' + str(cost_check.get('overage_usd', 0))}
"""
    
    if not cost_check["within_budget"]:
        report += f"\n### ⚠️ Cost Warning\n{cost_check.get('recommendation', '')}\n"
    
    # 저장
    forecast_dir = f".omao/plans/scaling/forecasts"
    os.makedirs(forecast_dir, exist_ok=True)
    with open(f"{forecast_dir}/{service}-{now}.md", "w") as f:
        f.write(report)
    
    return report
```

### Step 5: 자동 적용 (승인 후)

사람 승인 후 EKS CronHPA 또는 scheduled scaling을 업데이트합니다.

```python
def apply_scaling_schedule(service: str, schedule: list[dict], 
                           approved: bool = False) -> dict:
    """승인된 스케일링 스케줄을 EKS에 적용.
    
    ⚠️ 사람 승인 필수 — approved=True일 때만 실행.
    """
    if not approved:
        return {
            "status": "pending_approval",
            "message": "Scaling schedule requires human approval before application.",
            "approval_path": f".omao/plans/scaling/schedules/{service}-approved.yaml",
        }
    
    # CronHPA manifest 생성
    cron_entries = []
    prev_replicas = None
    for s in schedule:
        if s["replicas"] != prev_replicas:
            ts = datetime.fromisoformat(s["timestamp"].replace("Z", "+00:00"))
            cron_entries.append({
                "schedule": f"{ts.minute} {ts.hour} * * *",
                "minReplicas": s["replicas"],
                "maxReplicas": max(s["replicas"] + 2, s["replicas"]),
            })
            prev_replicas = s["replicas"]
    
    # EKS에 적용
    # mcp__eks__apply_yaml(yaml_path=..., cluster_name=..., namespace=...)
    
    return {
        "status": "applied",
        "cron_entries": len(cron_entries),
        "message": f"Applied {len(cron_entries)} scaling schedule entries",
    }
```

## 상태 관리

- `.omao/plans/scaling/targets/${service}.yaml` — 스케일링 대상 정의
- `.omao/plans/scaling/forecasts/${service}-${date}.md` — 일간 예측 및 권고
- `.omao/plans/scaling/schedules/${service}-approved.yaml` — 승인된 스케줄
- `.omao/state/scaling/${service}/current.json` — 현재 스케일링 상태
- `.omao/state/scaling/${service}/history.jsonl` — 예측 vs 실제 비교 이력

## Example Inputs/Outputs

**Input**: `/predictive-scaling rag-qa-agent`

**Output (normal)**:

```
[00:05:00Z] Predictive scaling for: rag-qa-agent
[00:05:01Z] Loading config: .omao/plans/scaling/targets/rag-qa-agent.yaml
[00:05:02Z] Fetching 30-day historical data...
             Data points: 720 (hourly, 30 days)
             Average RPS: 450, Peak: 1200, Trough: 80

[00:05:04Z] Forecast generated (next 24 hours):
             Peak: 14:00 UTC — predicted 980 RPS (upper CI: 1150)
             Trough: 04:00 UTC — predicted 95 RPS (upper CI: 140)

[00:05:04Z] Event adjustments applied:
             03:00-04:00 UTC: "Daily reindex" (×0.3) → RPS reduced

[00:05:05Z] Scaling schedule:
             | Time  | Replicas | Cost/hr |
             | 00:00 | 3        | $4.50   |
             | 06:00 | 6        | $9.00   |
             | 09:00 | 10       | $15.00  |
             | 14:00 | 12       | $18.00  |
             | 18:00 | 8        | $12.00  |
             | 22:00 | 4        | $6.00   |

[00:05:05Z] Cost verification:
             Daily: $258.00
             Monthly projected: $7,740
             Budget (per_agent): $8,000
             Status: ✅ Within budget (96.8%)

[00:05:06Z] Recommendation saved: .omao/plans/scaling/forecasts/rag-qa-agent-2026-05-08.md
[00:05:06Z] AWAITING HUMAN APPROVAL for schedule application.
```

**Output (over budget)**:

```
[00:05:05Z] Cost verification:
             Daily: $312.00
             Monthly projected: $9,360
             Budget (per_agent): $8,000
             Status: ⚠️ Over budget by $1,360/month

[00:05:05Z] Optimization suggestions:
             1. Increase spot_ratio 0.7 → 0.85 (saves ~$1,100/mo)
             2. Reduce peak replicas 12 → 10 (saves ~$720/mo, risk: SLO pressure)
             3. Request budget increase from cost-governance

[00:05:06Z] Sending cost verification request to cost-governance...
```

**Output (SLO-triggered scale-up)**:

```
[10:15:00Z] SLO-triggered scaling for: rag-qa-agent
[10:15:00Z] Trigger: slo-management reports latency_p99 burn rate 2.3x
[10:15:01Z] Current state: 8 replicas, CPU 82%, RPS 750
[10:15:01Z] Immediate recommendation: scale to 12 replicas
             Reason: reduce per-pod load to meet P99 < 500ms SLO
             Cost impact: +$6.00/hr (+$144/day)
             Budget check: within limits

[10:15:02Z] AWAITING HUMAN APPROVAL for immediate scale-up.
```

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
- [Karpenter](https://karpenter.sh/) — 노드 수준 자동 스케일링

### 기술 블로그

- [Google — Predictive Autoscaling](https://cloud.google.com/blog/products/compute/predictive-autoscaling-in-google-cloud) — 예측 스케일링 패턴
- [Uber — Forecasting at Scale](https://www.uber.com/blog/forecasting-introduction/) — 대규모 시계열 예측

### 관련 문서 (내부)

- [cost-governance skill](../cost-governance/SKILL.md) — 비용 제약 소스
- [autopilot-deploy skill](../autopilot-deploy/SKILL.md) — 배포 시 스케일링 연동
- [anomaly-detection skill](../anomaly-detection/SKILL.md) — 예측 이탈 탐지
- [slo-management skill](../slo-management/SKILL.md) — SLO 기반 스케일업 트리거
