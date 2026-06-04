---
name: slo-management
description: SLI 메트릭을 자동 수집하여 SLO 대비 추적하고, Error Budget 소진율에 따라 배포 게이트를 제어한다. 번다운 차트 생성, 예측 기반 SLO 위반 사전 경고, Error Budget 정책(freeze/slow-down/normal) 자동 적용을 수행하며 continuous-eval의 품질 게이트를 보완한다.
argument-hint: "[service-name or slo-name]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus"
ontology:
  references: [Deployment, Budget, Incident]
---

## When to Use

- Sub-Phase 3 (Evaluate) 강화 — `continuous-eval`의 품질 게이트에 SLO 기반 판단 추가
- 매 시간 cron으로 SLI 수집 및 Error Budget 잔량 계산
- `autopilot-deploy`의 배포 게이트에 Error Budget 정책 적용
- 월간/주간 SLO 리포트 생성 시
- Error Budget 소진 속도가 비정상적으로 빠를 때 사전 경고

사용 제외:

- SLO가 정의되지 않은 서비스 (먼저 SLO 정의 필요)
- 메트릭 수집 인프라가 없는 환경
- 30일 미만의 신규 서비스 (최소 1 윈도우 사이클 필요)

## Prerequisites

- **awslabs.cloudwatch-mcp-server==0.0.25** — SLI 메트릭 조회.
- **awslabs.prometheus-mcp-server==0.2.15** — 시계열 SLI 쿼리.
- SLO 정의 파일: `.omao/plans/slo/definitions/${service}.yaml`.
- `autopilot-deploy` 상태 파일 접근 — Error Budget 기반 배포 제어.
- `continuous-eval` 연동 — 품질 SLI 데이터 공유.

## SLO 정의 구조

```yaml
# .omao/plans/slo/definitions/rag-qa-agent.yaml
service: rag-qa-agent
owner: ml-platform-team
created: "2026-04-01T00:00:00Z"

slos:
  - name: availability
    description: "서비스 가용성 — 성공 응답 비율"
    sli:
      type: ratio
      good_events: "agent_request_success_total"
      total_events: "agent_request_total"
      source: prometheus
      query_good: 'sum(rate(agent_request_success_total{service="rag-qa-agent"}[5m]))'
      query_total: 'sum(rate(agent_request_total{service="rag-qa-agent"}[5m]))'
    target: 0.999          # 99.9%
    window: 30d            # 30일 롤링 윈도우
    
  - name: latency_p99
    description: "P99 응답 시간 — 500ms 이하"
    sli:
      type: threshold
      metric: 'histogram_quantile(0.99, rate(agent_request_duration_seconds_bucket{service="rag-qa-agent"}[5m]))'
      source: prometheus
      threshold_ms: 500
      query_good: 'sum(rate(agent_request_duration_seconds_bucket{service="rag-qa-agent",le="0.5"}[5m]))'
      query_total: 'sum(rate(agent_request_duration_seconds_count{service="rag-qa-agent"}[5m]))'
    target: 0.99           # 99%가 500ms 이하
    window: 30d

  - name: quality_faithfulness
    description: "응답 충실도 — continuous-eval 결과"
    sli:
      type: gauge
      metric: "agenticops_eval_faithfulness"
      source: prometheus
      query: 'agenticops_eval_faithfulness{service="rag-qa-agent"}'
      query_good: 'count_over_time((agenticops_eval_faithfulness{service="rag-qa-agent"} >= 0.85)[7d:1h])'
      query_total: 'count_over_time(agenticops_eval_faithfulness{service="rag-qa-agent"}[7d:1h])'
    target: 0.85           # 85% 이상
    window: 7d             # 품질 SLO는 7일 윈도우

  - name: error_rate
    description: "에러율 — 1% 미만"
    sli:
      type: ratio
      good_events: "agent_request_success_total"
      total_events: "agent_request_total"
      source: prometheus
      query_good: 'sum(rate(agent_request_success_total{service="rag-qa-agent"}[5m]))'
      query_total: 'sum(rate(agent_request_total{service="rag-qa-agent"}[5m]))'
    target: 0.99           # 에러율 1% 미만 = 성공률 99%
    window: 7d

error_budget_policy:
  # 경계 규칙: min은 inclusive(이상), max는 exclusive(미만). 최상위 밴드만 max=100 inclusive.
  - remaining_pct_min: 50
    remaining_pct_max: 100  # inclusive (최상위)
    mode: normal
    deploy_allowed: true
    deploy_frequency: "unlimited"
    description: "정상 운영. 배포 제한 없음."
    
  - remaining_pct_min: 25
    remaining_pct_max: 50   # exclusive (50% 미만)
    mode: slow-down
    deploy_allowed: true
    deploy_frequency: "max 1/day"
    description: "주의 구간. 하루 1회 배포로 제한."
    
  - remaining_pct_min: 10
    remaining_pct_max: 25   # exclusive (25% 미만)
    mode: caution
    deploy_allowed: true
    deploy_frequency: "max 1/week"
    description: "경고 구간. 주 1회 배포로 제한. 안정성 우선."
    
  - remaining_pct_min: 0
    remaining_pct_max: 10   # exclusive (10% 미만)
    mode: freeze
    deploy_allowed: false
    exception: "security-patch-only"
    description: "동결. 보안 패치 외 배포 금지."

alerts:
  - at_remaining_pct: 50
    action: notify
    channel: slack
  - at_remaining_pct: 25
    action: notify_and_slow
    channel: slack + pagerduty
  - at_remaining_pct: 10
    action: freeze_and_escalate
    channel: pagerduty
```

## Error Budget 계산

```python
import json
import os
import yaml
from datetime import datetime, timedelta
from dataclasses import dataclass

@dataclass
class ErrorBudget:
    slo_name: str
    target: float
    window_days: int
    total_events: int
    good_events: int
    bad_events: int
    allowed_bad_events: float
    consumed_bad_events: int
    remaining_budget: float       # 남은 bad event 허용량
    remaining_pct: float          # 잔여 비율 (0~100)
    burn_rate: float              # 현재 소진 속도 (1.0 = 정상)
    projected_exhaustion_days: float | None  # 소진 예상 일수

def calculate_error_budget(slo_config: dict, 
                           good_events: int, 
                           total_events: int,
                           window_days: int) -> ErrorBudget:
    """Error Budget 잔량 계산.
    
    Error Budget = (1 - SLO target) × total events
    Remaining = Error Budget - actual bad events
    """
    target = slo_config["target"]
    bad_events = total_events - good_events
    
    # 허용된 bad event 수
    allowed_bad = (1 - target) * total_events
    
    # 잔여 budget
    remaining = max(0, allowed_bad - bad_events)
    remaining_pct = (remaining / allowed_bad * 100) if allowed_bad > 0 else 100.0
    
    # Burn rate: 현재 소진 속도 / 지속 가능 소진 속도
    # 지속 가능 = allowed_bad / window_days (하루 평균 허용량)
    # 롤링 윈도우이므로 경과 일수 = window_days (전체 윈도우 기간에 걸쳐 관측)
    elapsed_days = window_days
    sustainable_daily_burn = allowed_bad / window_days
    actual_daily_burn = bad_events / elapsed_days if elapsed_days > 0 else 0
    burn_rate = actual_daily_burn / sustainable_daily_burn if sustainable_daily_burn > 0 else 0
    
    # 소진 예상 일수
    if actual_daily_burn > 0 and remaining > 0:
        projected_exhaustion = remaining / actual_daily_burn
    else:
        projected_exhaustion = None  # 소진 안 됨 또는 이미 소진
    
    return ErrorBudget(
        slo_name=slo_config["name"],
        target=target,
        window_days=window_days,
        total_events=total_events,
        good_events=good_events,
        bad_events=bad_events,
        allowed_bad_events=allowed_bad,
        consumed_bad_events=bad_events,
        remaining_budget=remaining,
        remaining_pct=remaining_pct,
        burn_rate=burn_rate,
        projected_exhaustion_days=projected_exhaustion,
    )
```

## 실행 흐름

### Step 1: SLI 수집

각 SLO 정의에 따라 해당 메트릭을 조회합니다.

```python
def collect_sli(slo_config: dict) -> tuple[int, int]:
    """SLI 데이터 수집. (good_events, total_events) 반환.
    
    SLI 타입에 따라 수집 방식이 다름:
    - ratio: good/total 이벤트 수 직접 조회
    - threshold: 임계값 이하 이벤트 수 / 전체 이벤트 수
    - gauge: 현재 값이 target 이상인 시간 비율
    """
    sli = slo_config["sli"]
    window_days = slo_config.get("window", "30d")
    window_seconds = int(window_days.replace("d", "")) * 86400
    
    if sli["type"] == "ratio":
        # Prometheus range query
        # good = mcp__prometheus__query(sli["query_good"])
        # total = mcp__prometheus__query(sli["query_total"])
        good = query_prometheus_scalar(sli["query_good"], window_seconds)
        total = query_prometheus_scalar(sli["query_total"], window_seconds)
        return int(good), int(total)
    
    elif sli["type"] == "threshold":
        good = query_prometheus_scalar(sli["query_good"], window_seconds)
        total = query_prometheus_scalar(sli["query_total"], window_seconds)
        return int(good), int(total)
    
    elif sli["type"] == "gauge":
        # Gauge: 시간 기반 — target 이상인 시간 비율 (query_good/query_total 사용)
        good = query_prometheus_scalar(sli["query_good"], window_seconds)
        total = query_prometheus_scalar(sli["query_total"], window_seconds)
        return int(good), int(total)
    
    return 0, 0


def query_prometheus_scalar(query: str, window_seconds: int) -> float:
    """Prometheus instant query 실행."""
    # mcp__prometheus__query(query=f'sum(increase({query}[{window_seconds}s]))')
    return 0.0  # placeholder


def query_prometheus_range(query: str, window_seconds: int, step: int) -> list[float]:
    """Prometheus range query 실행."""
    # mcp__prometheus__query_range(query=query, start=..., end=..., step=step)
    return []  # placeholder
```

### Step 2: Error Budget 계산 및 정책 적용

```python
def evaluate_budget_policy(service: str, budgets: list[ErrorBudget],
                           policy_config: list[dict]) -> dict:
    """Error Budget 잔량에 따라 정책 결정.
    
    가장 낮은 remaining_pct를 기준으로 정책을 적용합니다.
    (하나의 SLO라도 위험하면 전체 서비스에 제한 적용)
    """
    # 가장 낮은 budget을 기준으로 정책 결정
    min_budget = min(budgets, key=lambda b: b.remaining_pct)
    remaining = min_budget.remaining_pct
    
    # 정책 매칭 (min inclusive, max exclusive; 최상위 밴드만 max inclusive)
    active_policy = None
    for policy in sorted(policy_config, key=lambda p: p["remaining_pct_min"]):
        pmin = policy["remaining_pct_min"]
        pmax = policy["remaining_pct_max"]
        if pmax == 100:
            in_band = pmin <= remaining <= pmax
        else:
            in_band = pmin <= remaining < pmax
        if in_band:
            active_policy = policy
            break
    
    if not active_policy:
        active_policy = {"mode": "normal", "deploy_allowed": True}
    
    return {
        "service": service,
        "limiting_slo": min_budget.slo_name,
        "remaining_pct": remaining,
        "mode": active_policy["mode"],
        "deploy_allowed": active_policy["deploy_allowed"],
        "deploy_frequency": active_policy.get("deploy_frequency", "unlimited"),
        "description": active_policy.get("description", ""),
    }
```

### Step 3: 배포 게이트 판정

Error Budget 잔량에 따라 `autopilot-deploy`에 배포 허용/차단 신호를 전달합니다.

```python
def deploy_gate_decision(service: str) -> dict:
    """Error Budget 기반 배포 게이트 판정.
    
    autopilot-deploy의 pre-flight gate에서 호출됩니다.
    """
    # SLO 정의 로드
    slo_file = f".omao/plans/slo/definitions/{service}.yaml"
    with open(slo_file) as f:
        slo_def = yaml.safe_load(f)
    
    # 각 SLO별 budget 계산
    budgets = []
    for slo in slo_def["slos"]:
        window_days = int(slo.get("window", "30d").replace("d", ""))
        good, total = collect_sli(slo)
        budget = calculate_error_budget(slo, good, total, window_days)
        budgets.append(budget)
    
    # 정책 평가
    policy = evaluate_budget_policy(service, budgets, slo_def["error_budget_policy"])
    
    # 게이트 결과 저장
    gate_file = f".omao/state/slo/{service}/deploy-gate.json"
    os.makedirs(os.path.dirname(gate_file), exist_ok=True)
    with open(gate_file, "w") as f:
        json.dump(policy, f, indent=2)
    
    return policy
```

### Step 4: Burn Rate Alert & 예측

Error Budget 소진 속도를 기반으로 사전 경고를 발행합니다.

```python
def check_burn_rate_alerts(service: str, budgets: list[ErrorBudget],
                           alert_config: list[dict]) -> list[dict]:
    """Burn rate 기반 알림 발행."""
    alerts_fired = []
    
    for budget in budgets:
        for alert in alert_config:
            if budget.remaining_pct <= alert["at_remaining_pct"]:
                alert_event = {
                    "service": service,
                    "slo_name": budget.slo_name,
                    "remaining_pct": budget.remaining_pct,
                    "burn_rate": budget.burn_rate,
                    "projected_exhaustion_days": budget.projected_exhaustion_days,
                    "action": alert["action"],
                    "channel": alert["channel"],
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                }
                alerts_fired.append(alert_event)
                
                # 심각도에 따라 후속 조치
                if alert["action"] == "freeze_and_escalate":
                    trigger_deploy_freeze(service, budget)
                    trigger_incident_response(service, budget, severity="SEV3")
    
    return alerts_fired


def predict_budget_exhaustion(budget: ErrorBudget) -> dict:
    """Error Budget 소진 예측.
    
    현재 burn rate가 유지될 경우 소진 시점을 예측합니다.
    """
    if budget.burn_rate <= 1.0:
        return {
            "status": "sustainable",
            "message": f"Current burn rate ({budget.burn_rate:.2f}x) is sustainable",
        }
    
    if budget.projected_exhaustion_days is not None:
        if budget.projected_exhaustion_days < 3:
            urgency = "critical"
        elif budget.projected_exhaustion_days < 7:
            urgency = "warning"
        else:
            urgency = "info"
        
        return {
            "status": "at_risk",
            "urgency": urgency,
            "projected_exhaustion_days": budget.projected_exhaustion_days,
            "burn_rate": budget.burn_rate,
            "message": f"Budget will exhaust in {budget.projected_exhaustion_days:.1f} days at current rate",
        }
    
    return {"status": "exhausted", "message": "Error budget already exhausted"}
```

### Step 5: SLO 리포트 생성

```python
def generate_slo_report(service: str, period: str = "weekly") -> str:
    """SLO 달성 현황 리포트 생성."""
    slo_file = f".omao/plans/slo/definitions/{service}.yaml"
    with open(slo_file) as f:
        slo_def = yaml.safe_load(f)
    
    budgets = []
    for slo in slo_def["slos"]:
        window_days = int(slo.get("window", "30d").replace("d", ""))
        good, total = collect_sli(slo)
        budget = calculate_error_budget(slo, good, total, window_days)
        budgets.append(budget)
    
    # 리포트 생성
    now = datetime.utcnow().strftime("%Y-%m-%d")
    report = f"""# SLO Report — {service} ({period}: {now})

## Summary

| SLO | Target | Actual | Status | Error Budget | Burn Rate |
|-----|--------|--------|--------|--------------|-----------|
"""
    for budget in budgets:
        actual = budget.good_events / budget.total_events if budget.total_events > 0 else 0
        status = "✅" if budget.remaining_pct > 25 else ("⚠️" if budget.remaining_pct > 10 else "🔴")
        report += f"| {budget.slo_name} | {budget.target:.1%} | {actual:.3%} | {status} | {budget.remaining_pct:.1f}% | {budget.burn_rate:.2f}x |\n"
    
    # 정책 상태
    policy = evaluate_budget_policy(service, budgets, slo_def["error_budget_policy"])
    report += f"""
## Current Policy

- **Mode**: {policy['mode']}
- **Deploy Allowed**: {policy['deploy_allowed']}
- **Limiting SLO**: {policy['limiting_slo']}
- **Deploy Frequency**: {policy.get('deploy_frequency', 'unlimited')}

## Burn Rate Analysis

"""
    for budget in budgets:
        prediction = predict_budget_exhaustion(budget)
        report += f"- **{budget.slo_name}**: burn rate {budget.burn_rate:.2f}x — {prediction['message']}\n"
    
    report += f"""
## Recommendations

"""
    for budget in budgets:
        if budget.burn_rate > 2.0:
            report += f"- 🔴 **{budget.slo_name}**: Burn rate critical. Investigate root cause immediately.\n"
        elif budget.burn_rate > 1.5:
            report += f"- ⚠️ **{budget.slo_name}**: Burn rate elevated. Consider reducing deploy frequency.\n"
        elif budget.remaining_pct < 25:
            report += f"- ⚠️ **{budget.slo_name}**: Budget low. Prioritize reliability work.\n"
    
    # 리포트 저장
    report_dir = f".omao/plans/slo/reports"
    os.makedirs(report_dir, exist_ok=True)
    report_file = f"{report_dir}/{service}-{period}-{now}.md"
    with open(report_file, "w") as f:
        f.write(report)
    
    return report
```

## 상태 관리

- `.omao/plans/slo/definitions/${service}.yaml` — SLO 정의
- `.omao/plans/slo/reports/${service}-${period}-${date}.md` — SLO 리포트
- `.omao/plans/slo/overrides/${service}.yaml` — Error Budget freeze override 사유 기록
- `.omao/state/slo/${service}/current.json` — 현재 SLI/Error Budget 상태
- `.omao/state/slo/${service}/deploy-gate.json` — 배포 게이트 판정 결과
- `.omao/state/slo/${service}/history.jsonl` — SLI 이력 (번다운 차트용)
- `.omao/state/slo/${service}/alerts.jsonl` — 발행된 알림 이력

## Example Inputs/Outputs

**Input**: `/slo-management rag-qa-agent`

**Output (normal)**:

```
[10:00:00Z] SLO evaluation for: rag-qa-agent
[10:00:01Z] Collecting SLIs (4 SLOs defined)...
[10:00:03Z] Results:

  availability        : 99.95% (target 99.9%) — Budget: 72.3% remaining
  latency_p99         : 99.2% (target 99.0%) — Budget: 85.1% remaining
  quality_faithfulness: 87.2% (target 85.0%) — Budget: 68.5% remaining
  error_rate          : 99.4% (target 99.0%) — Budget: 61.2% remaining

[10:00:03Z] Policy: NORMAL (min budget: 61.2% from error_rate)
[10:00:03Z] Deploy gate: ALLOWED (unlimited frequency)
[10:00:03Z] Burn rate: all SLOs sustainable (max 0.8x)
[10:00:03Z] State saved to .omao/state/slo/rag-qa-agent/current.json
```

**Output (slow-down)**:

```
[10:00:00Z] SLO evaluation for: rag-qa-agent
[10:00:03Z] Results:

  availability        : 99.85% (target 99.9%) — Budget: 32.1% remaining ⚠️
  latency_p99         : 98.5% (target 99.0%) — Budget: 28.4% remaining ⚠️
  quality_faithfulness: 86.1% (target 85.0%) — Budget: 55.0% remaining
  error_rate          : 99.1% (target 99.0%) — Budget: 45.8% remaining

[10:00:03Z] Policy: SLOW-DOWN (min budget: 28.4% from latency_p99)
[10:00:03Z] Deploy gate: ALLOWED (max 1/day)
[10:00:03Z] Burn rate analysis:
             latency_p99: 2.3x — Budget will exhaust in 4.2 days ⚠️
             availability: 1.8x — Budget will exhaust in 6.1 days ⚠️
[10:00:04Z] Alert fired: notify_and_slow → slack + pagerduty
[10:00:04Z] Recommendation: Investigate latency regression. Consider rollback of recent deploy.
```

**Output (freeze)**:

```
[10:00:00Z] SLO evaluation for: rag-qa-agent
[10:00:03Z] Results:

  availability        : 99.70% (target 99.9%) — Budget: 5.2% remaining 🔴
  latency_p99         : 97.8% (target 99.0%) — Budget: 8.1% remaining 🔴

[10:00:03Z] Policy: FREEZE (min budget: 5.2% from availability)
[10:00:03Z] Deploy gate: BLOCKED (security-patch-only)
[10:00:03Z] Burn rate: availability 4.1x — Budget exhausts in 1.3 days
[10:00:04Z] Alert fired: freeze_and_escalate → pagerduty
[10:00:04Z] Action: Deploy freeze applied. incident-response SEV3 triggered.
[10:00:04Z] BLOCKING: OPERATIONS-07 — Error Budget freeze active.
             Override: security patches only via .omao/plans/slo/overrides/${service}.yaml
```

**Input**: `/slo-management rag-qa-agent --report weekly`

**Output**:

```
[10:00:00Z] Generating weekly SLO report for: rag-qa-agent
[10:00:05Z] Report saved: .omao/plans/slo/reports/rag-qa-agent-weekly-2026-05-08.md
[10:00:05Z] Summary:
             3/4 SLOs meeting target
             1 SLO at risk (latency_p99: burn rate 2.3x)
             Policy: SLOW-DOWN
```

## 기존 스킬 연동

| 연동 대상 | 방향 | 설명 |
|-----------|------|------|
| `continuous-eval` | ← 입력 | 품질 SLI (faithfulness 등) 데이터 수신 |
| `autopilot-deploy` | → 출력 | Error Budget 기반 배포 게이트 신호 전달 |
| `incident-response` | ↔ 양방향 | SLO 위반 시 인시던트 생성 / 인시던트가 Error Budget 소진 |
| `cost-governance` | ← 입력 | 비용 SLI 데이터 수신 (cost per request 등) |
| `anomaly-detection` | ← 입력 | SLI 메트릭 이상 탐지 결과 수신 |
| `predictive-scaling` | → 출력 | SLO 위반 위험 시 스케일업 트리거 |

## 참고 자료

### 공식 문서

- [Google SRE — Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) — SLO 설계 원칙
- [OpenSLO Specification](https://openslo.com/) — SLO 정의 표준
- [AWS CloudWatch Application Signals](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Monitoring-Sections.html) — AWS SLO 기능

### 기술 블로그

- [Google — The Art of SLOs](https://sre.google/workbook/implementing-slos/) — SLO 구현 가이드
- [Nobl9 — Error Budget Policies](https://www.nobl9.com/resources/error-budget-policies) — Error Budget 정책 패턴
- [Sloth — SLO as Code](https://sloth.dev/) — SLO 코드화 도구

### 관련 문서 (내부)

- [continuous-eval skill](../continuous-eval/SKILL.md) — 품질 SLI 소스
- [autopilot-deploy skill](../autopilot-deploy/SKILL.md) — 배포 게이트 수신자
- [incident-response skill](../incident-response/SKILL.md) — SLO 위반 인시던트 수신자
- [cost-governance skill](../cost-governance/SKILL.md) — 비용 SLI 소스
- [predictive-scaling skill](../predictive-scaling/SKILL.md) — SLO 기반 스케일업 트리거
