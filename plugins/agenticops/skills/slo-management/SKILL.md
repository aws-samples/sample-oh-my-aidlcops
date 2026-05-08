---
name: slo-management
description: SLI 메트릭을 자동 수집하여 SLO 대비 추적하고, Error Budget 소진율에 따라 배포 게이트를 제어한다. 번다운 차트 생성, 예측 기반 SLO 위반 사전 경고, Error Budget 정책(freeze/slow-down/normal) 자동 적용을 수행하며 continuous-eval의 품질 게이트를 보완한다.
argument-hint: "[service-name or slo-name]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus"
---

## When to Use

- Sub-Phase 3 (Evaluate) 강화 — `continuous-eval`의 품질 게이트에 SLO 기반 판단 추가
- 매 시간 cron으로 SLI 수집 및 Error Budget 잔량 계산
- `autopilot-deploy`의 배포 게이트에 Error Budget 정책 적용
- 월간/주간 SLO 리포트 생성 시

사용 제외:

- SLO가 정의되지 않은 서비스 (먼저 SLO 정의 필요)
- 메트릭 수집 인프라가 없는 환경

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
slos:
  - name: availability
    description: "서비스 가용성"
    sli:
      metric: "agent_request_success_total / agent_request_total"
      source: prometheus
    target: 0.999          # 99.9%
    window: 30d            # 30일 롤링 윈도우
    
  - name: latency_p99
    description: "P99 응답 시간"
    sli:
      metric: "histogram_quantile(0.99, agent_request_duration_seconds_bucket)"
      source: prometheus
    target_max_ms: 500     # 500ms 이하
    window: 30d

  - name: quality_faithfulness
    description: "응답 충실도"
    sli:
      metric: "agenticops_eval_faithfulness"
      source: prometheus
    target: 0.85           # 85% 이상
    window: 7d

error_budget_policy:
  - remaining_pct: ">50"
    mode: normal
    deploy_allowed: true
  - remaining_pct: "25-50"
    mode: slow-down
    deploy_allowed: true
    deploy_frequency: "max 1/day"
  - remaining_pct: "<25"
    mode: freeze
    deploy_allowed: false
    exception: "security-patch-only"
```

## Error Budget 계산

```python
from dataclasses import dataclass

@dataclass
class ErrorBudget:
    total_minutes: float       # 윈도우 내 총 시간 (분)
    allowed_bad_minutes: float # SLO 기반 허용 장애 시간
    consumed_minutes: float    # 실제 소진된 장애 시간
    remaining_pct: float       # 잔여 비율

def calculate_error_budget(slo_target: float, window_days: int,
                           actual_good_events: int, total_events: int) -> ErrorBudget:
    """Error Budget 잔량 계산."""
    total_minutes = window_days * 24 * 60
    allowed_bad_ratio = 1 - slo_target
    allowed_bad_minutes = total_minutes * allowed_bad_ratio
    
    actual_bad_ratio = 1 - (actual_good_events / total_events) if total_events > 0 else 0
    consumed_minutes = total_minutes * actual_bad_ratio
    
    remaining_pct = max(0, (1 - consumed_minutes / allowed_bad_minutes) * 100)
    
    return ErrorBudget(
        total_minutes=total_minutes,
        allowed_bad_minutes=allowed_bad_minutes,
        consumed_minutes=consumed_minutes,
        remaining_pct=remaining_pct,
    )
```

## 실행 흐름

### Step 1: SLI 수집

각 SLO 정의에 따라 해당 메트릭을 조회합니다.

```bash
# Prometheus SLI 조회
mcp__prometheus__query \
  --query 'sum(rate(agent_request_success_total{service="rag-qa-agent"}[30d])) / sum(rate(agent_request_total{service="rag-qa-agent"}[30d]))'
```

### Step 2: Error Budget 계산 및 정책 적용

### Step 3: 배포 게이트 판정

Error Budget 잔량에 따라 `autopilot-deploy`에 배포 허용/차단 신호를 전달합니다.

```python
def deploy_gate_decision(service: str) -> dict:
    """Error Budget 기반 배포 게이트 판정."""
    budget = calculate_current_budget(service)
    policy = get_budget_policy(service, budget.remaining_pct)
    
    return {
        "service": service,
        "remaining_pct": budget.remaining_pct,
        "mode": policy["mode"],
        "deploy_allowed": policy["deploy_allowed"],
        "reason": f"Error budget at {budget.remaining_pct:.1f}%, policy: {policy['mode']}",
    }
```

### Step 4: 번다운 차트 및 예측

Error Budget 소진 속도를 기반으로 윈도우 종료 전 소진 예측을 수행합니다.

### Step 5: SLO 리포트 생성

주간/월간 SLO 달성 현황 리포트를 생성합니다.

## SLO 리포트 구조

```markdown
# SLO Report — {service} ({period})

## Summary
| SLO | Target | Actual | Status | Error Budget Remaining |
|-----|--------|--------|--------|----------------------|
| availability | 99.9% | 99.95% | ✅ | 72% |
| latency_p99 | 500ms | 420ms | ✅ | 85% |
| quality | 85% | 83% | ⚠️ | 18% |

## Error Budget Burn Rate
- Current burn rate: 2.1x (consuming budget 2.1x faster than sustainable)
- Projected exhaustion: 8 days

## Recommendations
- quality SLO: Error budget approaching freeze threshold. Consider pausing non-critical deploys.
```

## 상태 관리

- `.omao/plans/slo/definitions/${service}.yaml` — SLO 정의
- `.omao/plans/slo/reports/${service}-${period}.md` — SLO 리포트
- `.omao/state/slo/${service}/current.json` — 현재 SLI/Error Budget 상태
- `.omao/state/slo/${service}/history.jsonl` — SLI 이력 (번다운 차트용)

## 기존 스킬 연동

| 연동 대상 | 방향 | 설명 |
|-----------|------|------|
| `continuous-eval` | ← 입력 | 품질 SLI (faithfulness 등) 데이터 수신 |
| `autopilot-deploy` | → 출력 | Error Budget 기반 배포 게이트 신호 전달 |
| `incident-response` | ↔ 양방향 | SLO 위반 시 인시던트 생성 / 인시던트가 Error Budget 소진 |
| `cost-governance` | ← 입력 | 비용 SLI 데이터 수신 (cost per request 등) |
| `anomaly-detection` | ← 입력 | SLI 메트릭 이상 탐지 결과 수신 |

## 참고 자료

### 공식 문서

- [Google SRE — Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) — SLO 설계 원칙
- [OpenSLO Specification](https://openslo.com/) — SLO 정의 표준
- [AWS CloudWatch SLO](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-ServiceLevelObjectives.html) — AWS SLO 기능

### 기술 블로그

- [Google — The Art of SLOs](https://sre.google/workbook/implementing-slos/) — SLO 구현 가이드
- [Nobl9 — Error Budget Policies](https://www.nobl9.com/resources/error-budget-policies) — Error Budget 정책 패턴

### 관련 문서 (내부)

- [continuous-eval skill](../continuous-eval/SKILL.md) — 품질 SLI 소스
- [autopilot-deploy skill](../autopilot-deploy/SKILL.md) — 배포 게이트 수신자
- [incident-response skill](../incident-response/SKILL.md) — SLO 위반 인시던트 수신자
- [cost-governance skill](../cost-governance/SKILL.md) — 비용 SLI 소스
