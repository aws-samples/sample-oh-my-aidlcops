# Operations Phase — Opt-In

**Extension**: AIDLC Operations Phase (agenticops)

## Opt-In Prompt

다음 질문은 이 확장이 로드되었을 때 Requirements Analysis 단계의 clarifying questions에 자동으로 포함됩니다.

```markdown
## Question: Operations Phase Automation
Should the AIDLC Operations phase be activated with agenticops automation?

A) Yes — activate Operations phase with autopilot-deploy, continuous-eval, incident-response, cost-governance, and self-improving-loop (recommended for production deployments with Langfuse / Prometheus / CloudWatch observability in place)
B) No — skip Operations phase automation (suitable for local prototypes and design-only scopes)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```

---

# Operations Phase — 적용 규칙

## Purpose

본 확장은 awslabs/aidlc-workflows의 core-workflow.md가 placeholder로 남겨둔 **Operations phase**를 agent 기반 자동화 파이프라인으로 채운다. Inception(Phase 1)·Construction(Phase 2)이 완료된 이후 활성화되며, 프로덕션 배포·관측·평가·개선·비용 거버넌스를 sub-phase로 구성한다.

## MANDATORY: Operations Phase Loading Rules

**CRITICAL**: Operations phase를 활성화하려면 다음 사전 조건을 반드시 확인한다. 하나라도 만족하지 않으면 opt-in 프롬프트를 표시하지 않는다.

1. **Inception 완료 확인** — `aidlc-docs/requirements.md`, `aidlc-docs/user-stories.md` 존재 및 Inception stage가 `Completed` 상태인지 `aidlc-docs/aidlc-state.md`에서 검증한다.
2. **Construction 완료 확인** — `aidlc-docs/components.md`, `aidlc-docs/test-plan.md` 존재 및 Construction stage가 `Completed` 상태인지 검증한다.
3. **관측성 기반 확인** — Langfuse v3.x, Prometheus, CloudWatch Logs 중 최소 2개 이상의 엔드포인트가 `aidlc-docs/infrastructure.md`에 기록되어 있어야 한다. 전무할 경우 Operations phase는 활성화되지 않는다.

세 조건을 모두 만족하면 본 opt-in 프롬프트를 Requirements Analysis 단계의 질문 목록에 삽입한다.

## Phase Structure — Deploy → Observe → Evaluate → Improve → Repeat

Operations phase는 5개 sub-phase로 구성되며, 각 sub-phase는 agenticops 플러그인의 특정 skill로 매핑된다.

### Sub-Phase 1: Deploy

**담당 Skill**: `autopilot-deploy`

Canary 1% → 10% → 50% → 100%의 4단계 progressive rollout을 자동 실행한다. 각 단계는 `continuous-eval` gate와 SLO 검증을 통과해야 다음 단계로 승격된다. 100% 승격은 사람 승인이 필수이며, 그 이전 단계는 agent가 자동 진행한다.

**Human Checkpoint Gate**:
- 프로덕션 100% 승격 (필수 승인)
- 이전 단계 rollback 후 재시도 여부 결정

### Sub-Phase 2: Observe

**담당 Skill**: `autopilot-deploy` (내장 관측), `incident-response` (알람 수신)

배포된 agent의 trace·메트릭·로그를 Langfuse + Prometheus + CloudWatch에서 지속 수집한다. 알람 임계 초과 시 `incident-response`가 자동 수신하여 severity 분류 및 진단을 시작한다.

**Human Checkpoint Gate**:
- SEV1 발생 시 즉시 on-call 호출 (agent는 진단만 수행, remediation은 사람이 실행)

### Sub-Phase 3: Evaluate

**담당 Skill**: `continuous-eval`

매 배포 직후 + 매 1시간 cron으로 Ragas 기반 품질·안전 평가를 수행한다. Faithfulness, Answer Relevance, Context Precision, Toxicity, PII Leakage 5개 지표를 측정하여 regression gate(baseline 대비 5%p 하락 차단, toxicity/PII tolerance 0)로 배포 승격을 제어한다.

**Human Checkpoint Gate**:
- Golden dataset 업데이트 승인
- Regression 임계값 조정 승인

### Sub-Phase 4: Improve

**담당 Skill**: `self-improving-loop`

프로덕션 trace에서 regression 원인을 분석하고 prompt·skill 수정안을 Draft PR 형태로 제안한다. 본 sub-phase는 engineering-playbook의 [ADR — Self-Improving Agent Loop 도입 의사결정](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/design-architecture/advanced-patterns/adr-self-improving-loop.md)을 준수하며, **Train/Deploy 단계의 자동 실행은 금지된다**.

**Human Checkpoint Gate** (ADR §2에 따라 필수):
- Draft PR 머지 승인 (코드 리뷰 필수)
- Train Job 트리거 승인 (reward model 변경 동반 시)
- Canary 배포 각 단계 승격 승인 (10% → 50% → 100%)

### Sub-Phase 5: Govern (Cross-cutting)

**담당 Skill**: `cost-governance`

위 4개 sub-phase 전체에 걸쳐 비용 거버넌스를 cross-cutting으로 적용한다. 배포 전 pre-flight veto, 배포 중 burn rate 모니터링, 배포 후 agent별 비용 귀속을 담당하며 월간 예산 초과 시 autopilot-deploy를 차단한다.

**Human Checkpoint Gate**:
- 월간 예산 정의 및 갱신
- Model downgrade PR 머지 승인
- Pre-flight veto override 승인

## Agent 책임 매트릭스

| Sub-Phase | Agent 자동 실행 범위 | 사람 승인 필수 범위 |
|-----------|---------------------|--------------------|
| Deploy | Canary 1%/10%/50% 승격, SLO 검증, 자동 롤백 | 100% 승격 |
| Observe | 알람 수신, severity 분류, 진단 쿼리 | SEV1 remediation |
| Evaluate | Ragas 실행, gate 판정, Prometheus 푸시 | Golden dataset 변경 |
| Improve | Trace 분석, regression 탐지, Draft PR 생성 | PR 머지, Train Job 실행, Canary 승격 |
| Govern | 일간 비용 집계, burn rate 계산, downgrade 권고 PR 생성 | 예산 정의, downgrade PR 머지, Veto override |

## Extension Integration with core-workflow.md

본 확장은 awslabs/aidlc-workflows의 `aws-aidlc-rules/core-workflow.md`가 정의한 MANDATORY Extensions Loading 규칙에 따라 로드된다. 구체적 연동 방식:

1. **Discovery** — core-workflow.md의 Extensions Loading 단계에서 본 `operations-phase.opt-in.md`가 스캔된다.
2. **Conditional Prompt** — 상단 "Operations Phase Loading Rules"의 3개 사전 조건이 모두 충족될 때에만 opt-in 프롬프트가 Requirements Analysis 질문에 삽입된다.
3. **Rule Activation** — 사용자가 A(Yes)를 선택하면 `aidlc-docs/aidlc-state.md`의 `## Extension Configuration` 섹션에 `operations-phase: enabled` 가 기록된다.
4. **Operations Phase Start** — Construction stage 완료 후 core-workflow.md는 `aidlc-state.md`의 해당 플래그를 확인하고 Operations phase로 전환한다. 전환 시 agenticops 플러그인의 5개 skill이 순차 활성화된다.
5. **Rule Enforcement** — 각 sub-phase는 "Agent 책임 매트릭스"의 경계를 준수해야 한다. 경계 위반(예: Agent가 사람 승인 없이 100% 승격)은 blocking finding으로 처리되고 `aidlc-docs/audit.md`에 기록된다.

## Integration with agenticops Skills

본 확장이 활성화되면 agenticops 플러그인의 다음 skill들이 Operations phase 실행 환경에 자동 등록된다.

- `skills/autopilot-deploy/SKILL.md` — Sub-Phase 1 Deploy
- `skills/incident-response/SKILL.md` — Sub-Phase 2 Observe (알람 핸들러)
- `skills/continuous-eval/SKILL.md` — Sub-Phase 3 Evaluate
- `skills/self-improving-loop/SKILL.md` — Sub-Phase 4 Improve
- `skills/cost-governance/SKILL.md` — Sub-Phase 5 Govern (cross-cutting)

Skill 간 상호작용 원칙은 agenticops 플러그인의 `CLAUDE.md` "Skill 조합 원칙"을 참조한다. 주요 경로는 다음과 같다.

- `continuous-eval` 실패 → `self-improving-loop` 자동 호출
- `incident-response` SEV1/2 → `autopilot-deploy` freeze
- `cost-governance` veto → `autopilot-deploy` pre-flight 차단

## State Management

Operations phase가 활성화되면 다음 상태 파일을 사용한다. 모든 파일은 `aidlc-state.md`와 `.omao/` 상태 디렉토리에 이중 기록된다.

| 파일 | 역할 |
|------|------|
| `aidlc-docs/aidlc-state.md` | Operations phase 활성화 여부, 현재 sub-phase |
| `.omao/state/autopilot-deploy/` | 진행 중인 canary rollout 상태 |
| `.omao/state/incident/` | SEV1/2/3 incident 타임라인 |
| `.omao/plans/eval/` | Ragas 평가 결과, golden dataset |
| `.omao/plans/self-improving/` | Trace 분석 리포트, Draft PR payload |
| `.omao/plans/cost/` | 비용 집계, alert 이력, downgrade 권고 |
| `aidlc-docs/audit.md` | 모든 human checkpoint의 승인·반려 기록 |

## Blocking Findings

다음 상황은 Operations phase 진행을 중단시키는 blocking finding으로 처리된다.

1. **ADR 경계 위반** — `self-improving-loop`가 Train/Deploy를 자동 트리거하려 시도하는 경우
2. **SEV1 freeze 우회** — `incident-response`가 SEV1 freeze를 걸었음에도 `autopilot-deploy`가 승격을 시도
3. **예산 veto 우회** — `cost-governance`가 veto를 발행했음에도 override 없이 배포가 진행되는 경우
4. **Golden dataset PII 누락** — `continuous-eval` golden dataset에 Presidio 스캔이 수행되지 않은 경우
5. **관측성 공백** — Operations phase 진입 시점에 Langfuse·Prometheus·CloudWatch 중 2개 이상의 엔드포인트가 다운된 경우

각 blocking finding은 `aidlc-docs/audit.md`에 rule ID(`OPERATIONS-01` ~ `OPERATIONS-05`)와 함께 기록된다.

## References

- [agenticops plugin — CLAUDE.md](../../CLAUDE.md) — 플러그인 전체 설명
- [awslabs/aidlc-workflows — core-workflow.md](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rules/core-workflow.md) — Extensions Loading 규약
- [awslabs/aidlc-workflows — operations.md placeholder](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rule-details/operations/operations.md) — 본 확장이 대체하는 placeholder
- [ADR — Self-Improving Agent Loop](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/design-architecture/advanced-patterns/adr-self-improving-loop.md) — Improve sub-phase 운영 원칙
- [Self-Improving Agent Loop 설계](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/design-architecture/advanced-patterns/self-improving-agent-loop.md) — 5-Stage 아키텍처
