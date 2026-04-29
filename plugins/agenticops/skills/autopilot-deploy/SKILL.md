---
name: autopilot-deploy
description: Agent 또는 skill의 프로덕션 배포를 canary 1% → 10% → 50% → 100% 4단계로 자동 진행한다. 각 단계는 continuous-eval 통과와 SLO 준수를 gate로 하며 circuit breaker가 SLO 위반을 감지하면 즉시 이전 단계로 자동 롤백한다. 100% 승격은 사람 승인이 필수다.
argument-hint: "[deployment-target, e.g. rag-qa-agent:v2.3.1]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus"
license: Apache-2.0
---

## When to Use

- 새로운 agent 버전 또는 skill 수정이 `continuous-eval` golden dataset를 통과했고 프로덕션 반영이 필요할 때
- `self-improving-loop`가 생성한 PR이 머지되어 canary 검증이 필요할 때
- 모델 교체(예: Qwen3-7B → Qwen3-14B)를 점진 배포하고 회귀 감시가 필요할 때

사용 제외:

- Inception/Construction 단계가 미완료인 경우. Operations 단계는 하위 phase 완료 후 활성화.
- `cost-governance`가 예산 초과 veto를 건 배포.
- `incident-response`가 SEV1 상태로 freeze한 클러스터.

## Prerequisites

- **Kubernetes cluster** (EKS 권장) + **Argo Rollouts** 또는 **Flagger** CRD 설치.
- **Prometheus** SLO 메트릭 수집 (`agent_request_latency_seconds`, `agent_error_rate`, `agent_tokens_total`).
- **awslabs.eks-mcp-server==0.1.28**, **awslabs.prometheus-mcp-server==0.2.15** MCP 설정 완료 (`@latest` 금지, PyPI 버전 pin 필수).
- 배포 대상의 최근 `continuous-eval` 리포트가 pass 상태여야 합니다.
- SLO 정의 파일 (`.omao/plans/slo/${target}.yaml`)이 존재해야 합니다.

## Progressive Rollout 4-Stage

각 단계는 트래픽 비율 상승 → 30분 soak → SLO 검증 → gate 통과 시 다음 단계 순서로 진행됩니다. 4단계 전체는 약 2~3시간 소요됩니다.

### Stage 1: Canary 1% — Smoke Test (30분)

트래픽의 1%를 candidate 버전으로 라우팅합니다. 이 단계의 목적은 런타임 실패(CrashLoopBackOff, image pull error, RBAC 거부)를 빠르게 감지하는 것입니다.

```bash
kubectl argo rollouts set image rollout/${TARGET} \
  agent=${REGISTRY}/${TARGET}:${VERSION}

kubectl argo rollouts promote rollout/${TARGET} --stage canary-1
```

통과 조건:

- `rate(agent_errors_total{version="$VERSION"}[5m]) < 0.01` (에러율 1% 미만)
- `histogram_quantile(0.99, agent_request_latency_seconds_bucket) < 5.0` (P99 5초 미만)
- Pod restart count == 0

### Stage 2: Canary 10% — Stability Gate (30분)

트래픽 10% 전환. 이 단계에서는 `continuous-eval`를 1회 inline 실행하여 품질 지표를 확인합니다.

```bash
kubectl argo rollouts promote rollout/${TARGET} --stage canary-10
/continuous-eval ${TARGET}:${VERSION} --mode canary
```

통과 조건 (Stage 1 조건 + 다음):

- `faithfulness` ≥ baseline
- `answer_relevance` ≥ baseline
- `toxicity` == 0 (tolerance 0)
- `pii_leakage` == 0 (tolerance 0)

### Stage 3: Canary 50% — SLO Gate (60분)

트래픽 50% 전환. 본격적인 프로덕션 부하에 노출되므로 soak 시간을 60분으로 늘립니다.

통과 조건:

- 모든 Stage 2 조건 유지
- `user_feedback_positive_ratio` ≥ baseline × 0.95
- P95 latency burn rate < 2× baseline

### Stage 4: 100% — Human Approval (manual)

본 skill은 50% 단계까지 자동 진행하며 100% 승격은 사람 승인을 요구합니다. GitHub Issue comment 또는 Slack approval workflow로 명시적 승인 후 다음 명령을 실행합니다.

```bash
kubectl argo rollouts promote rollout/${TARGET} --full
```

## Circuit Breaker

각 단계에서 다음 조건 중 하나가 감지되면 즉시 이전 단계로 롤백합니다.

| 트리거 | 임계값 | 반응 |
|--------|--------|------|
| 에러율 spike | `rate(errors) > 5 × baseline` for 2m | 즉시 롤백 + SEV2 trigger |
| Latency regression | P99 > 2 × baseline for 5m | 즉시 롤백 + SEV3 trigger |
| Evaluation regression | `continuous-eval faithfulness` < baseline - 5pp | 즉시 롤백 + SEV3 trigger |
| Toxicity/PII positive | 1건 이상 | 즉시 롤백 + SEV1 trigger |
| Pod crash loop | `pod_restart_total` > 3 within 10m | 즉시 롤백 + 인프라 팀 호출 |

롤백은 `kubectl argo rollouts abort rollout/${TARGET}` 로 실행되며 이전 stable revision으로 자동 복귀합니다.

## 상태 관리

본 skill은 진행 상태를 `.omao/state/autopilot-deploy/${target}.json` 에 실시간 기록합니다.

```json
{
  "target": "rag-qa-agent",
  "version": "v2.3.1",
  "current_stage": "canary-50",
  "started_at": "2026-04-21T10:15:00Z",
  "stage_history": [
    {"stage": "canary-1", "started": "10:15Z", "completed": "10:45Z", "result": "pass"},
    {"stage": "canary-10", "started": "10:45Z", "completed": "11:15Z", "result": "pass"}
  ],
  "circuit_breaker_status": "armed",
  "awaiting_human_approval": false
}
```

`incident-response` skill은 이 파일을 읽어 SEV1/SEV2 이벤트 발생 시 `circuit_breaker_status`를 `tripped`로 갱신하고 본 skill의 진행을 중단시킵니다.

## Example Inputs/Outputs

**Input**: `/autopilot-deploy rag-qa-agent:v2.3.1`

**Output (성공)**:

```
[10:15Z] Stage 1 (canary-1): STARTED
[10:45Z] Stage 1: PASS (error_rate=0.002, p99_latency=3.1s)
[10:45Z] Stage 2 (canary-10): STARTED
[11:12Z] continuous-eval: faithfulness=0.89 ≥ baseline 0.87 PASS
[11:15Z] Stage 2: PASS
[11:15Z] Stage 3 (canary-50): STARTED
[12:15Z] Stage 3: PASS (user_feedback_positive=0.73 ≥ 0.71)
[12:15Z] AWAITING HUMAN APPROVAL for 100% promotion
         Review at: https://grafana.example.com/d/rollout/rag-qa-agent
         Approve via: gh issue comment <issue-id> --body "/approve-promotion"
```

**Output (회귀)**:

```
[10:15Z] Stage 1 (canary-1): STARTED
[10:22Z] CIRCUIT BREAKER TRIPPED: error_rate=0.08 > 0.01 threshold
[10:22Z] Automatic rollback initiated
[10:23Z] Rolled back to v2.3.0 (previous stable)
[10:23Z] SEV2 incident opened: see .omao/state/incident/sev2-20260421-1023.json
```

## 참고 자료

### 공식 문서

- [Argo Rollouts — Canary Strategy](https://argoproj.github.io/argo-rollouts/features/canary/) — 점진 배포 CRD
- [Flagger — Progressive Delivery](https://docs.flagger.app/) — 대안 progressive rollout 컨트롤러
- [Prometheus Query Functions](https://prometheus.io/docs/prometheus/latest/querying/functions/) — SLO burn rate 계산
- [awslabs/mcp — eks-mcp-server](https://github.com/awslabs/mcp/tree/main/src/eks-mcp-server) — 배포 오케스트레이션 MCP

### 기술 블로그

- [Google SRE — Canarying Releases](https://sre.google/workbook/canarying-releases/) — Progressive rollout 원칙
- [AWS — Deployment strategies for Amazon EKS](https://docs.aws.amazon.com/prescriptive-guidance/latest/deployment-strategies-for-eks/) — EKS 배포 전략

### 관련 문서 (내부)

- [continuous-eval skill](../continuous-eval/SKILL.md) — 각 stage gate의 품질 검증자
- [incident-response skill](../incident-response/SKILL.md) — Circuit breaker trigger 수신 대상
- [cost-governance skill](../cost-governance/SKILL.md) — Pre-flight 배포 veto 판정자
- [self-improving-loop skill](../self-improving-loop/SKILL.md) — 본 skill의 상류(PR 제공자)
