# agenticops — AIDLC Operations Plugin

`agenticops`는 oh-my-aidlcops(OMA) 마켓플레이스의 **OPERATE** 플러그인입니다. AIDLC 3-phase lifecycle(Inception → Construction → **Operations**) 중 [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows)가 placeholder로 남겨둔 Operations 단계를 agent-native 워크플로우로 확장합니다.

## 철학: Humans Approve, Agents Execute

Operations 단계에서 운영 업무의 대부분은 agent가 자동으로 실행합니다. 사람은 결과를 승인·반려하는 checkpoint gate에만 개입합니다.

- **Deploy**: Agent가 canary 1% → 10% → 50% → 100% 단계별 롤아웃을 자동 실행하고 SLO 위반 시 circuit breaker로 즉시 롤백합니다. 프로덕션 100% 승격은 사람 승인이 필요합니다.
- **Observe**: Langfuse trace, Prometheus 메트릭, CloudWatch 알람을 agent가 지속 수집·상관분석합니다.
- **Evaluate**: 매 배포·매 1시간마다 Ragas 기반 지표(faithfulness, answer relevance, context precision, toxicity, PII leakage)를 자동 평가하고 regression gate를 통과하지 못하면 자동 차단합니다.
- **Improve**: 프로덕션 trace에서 성능 저하 패턴을 탐지하고 프롬프트·skill 수정안을 PR draft로 제안합니다. 학습 데이터 승격·재학습 실행은 사람 승인 후 트리거됩니다.
- **Govern cost**: AWS Pricing + Cost Explorer MCP로 agent별 비용을 귀속 집계하고 예산 초과 예정 시 배포를 veto하거나 모델 다운그레이드(Opus → Sonnet → Haiku)를 권고합니다.

## 5 Skills — 구성과 상호작용

| Skill | 역할 | 트리거 |
|-------|------|--------|
| [`self-improving-loop`](./skills/self-improving-loop/SKILL.md) | Langfuse trace → regression 분석 → prompt·skill 수정안 PR draft | 주간 배치 또는 수동 호출 |
| [`autopilot-deploy`](./skills/autopilot-deploy/SKILL.md) | Canary progressive rollout, SLO 기반 circuit breaker, 자동 롤백 | 배포 요청 또는 `/oma:agenticops` |
| [`incident-response`](./skills/incident-response/SKILL.md) | CloudWatch/Prometheus 알람 수신 → runbook 조회 → 진단 → 사람 승인 remediation | 알람 이벤트 |
| [`continuous-eval`](./skills/continuous-eval/SKILL.md) | Ragas 기반 품질·안전 평가 (배포마다 + 시간별) | 배포 trigger 또는 cron |
| [`cost-governance`](./skills/cost-governance/SKILL.md) | 비용 귀속, 예산 alert, 모델 다운그레이드 권고, 배포 veto | 예산 임계 도달 또는 배포 gate |

## Skill 조합 원칙

- `continuous-eval` 결과는 `self-improving-loop`의 입력 신호가 됩니다. 품질 regression이 임계치를 넘으면 self-improving-loop가 자동으로 진단·수정안 작업을 시작합니다.
- `incident-response`가 SEV1/SEV2 이벤트를 검출하면 진행 중인 `autopilot-deploy`를 즉시 일시중지합니다. 인시던트 해결 전까지 canary 승격은 차단됩니다.
- `cost-governance`는 `autopilot-deploy`의 pre-flight gate입니다. 배포가 월간 예산 ceiling을 초과할 것으로 예상되면 deploy를 veto하고 모델 다운그레이드를 권고합니다.
- `self-improving-loop`가 생성한 PR이 머지되면 `continuous-eval`이 즉시 golden dataset 기준으로 재평가하여 회귀 여부를 확인합니다.

## Operations Phase 활성화

본 플러그인은 `aidlc-rule-details/extensions/operations-phase.opt-in.md`를 제공합니다. awslabs/aidlc-workflows의 core-workflow.md가 Requirements Analysis 단계에서 이 opt-in 파일을 자동으로 로드합니다. 사용자가 opt-in을 선택하면 Operations 단계가 활성화되고 위 5개 skill이 해당 단계의 sub-phase(Deploy → Observe → Evaluate → Improve) 자동화를 담당합니다.

Operations 단계는 Inception·Construction 단계가 모두 완료된 이후에만 활성화됩니다. Inception artifact(requirements.md, user-stories.md)와 Construction artifact(components.md, test-plan.md)가 존재하지 않으면 opt-in 프롬프트는 표시되지 않습니다.

## Self-Improving Loop ADR 준수

`self-improving-loop` skill은 engineering-playbook의 [ADR — Self-Improving Agent Loop 도입 의사결정](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/design-architecture/advanced-patterns/adr-self-improving-loop.md)에 정의된 7개 Decision Point를 전제로 동작합니다.

- Scope: self-hosted SLM 전용 (Qwen3, Llama 4, GLM-5). Bedrock AgentCore Claude/Nova 등 폐쇄 모델은 대상 아님.
- 자동화 경계: Rollout/Score/Filter(3단계)만 자동, Train/Deploy(2단계)는 사람 승인 필수.
- 데이터 거버넌스: PII / Consent / 지역 / 기밀 4-gate 통과 의무.
- Reward DRI 지정, 비용 ceiling, 롤백 경계, 조직 pilot 범위는 ADR 본문 참조.

## MCP 의존성

본 플러그인의 skill들은 awslabs/mcp가 제공하는 hosted MCP 서버를 런타임 데이터 레이어로 사용합니다. 커스텀 MCP는 구현하지 않습니다.

- `awslabs.cloudwatch-mcp-server@latest` — 알람·로그 조회
- `awslabs.prometheus-mcp-server@latest` — SLO 메트릭 쿼리
- `awslabs.aws-pricing-mcp-server@latest` — 비용 추정
- `awslabs.cost-explorer-mcp-server@latest` — 실측 비용 귀속
- `awslabs.eks-mcp-server@latest` — 배포 오케스트레이션

## 상태 관리

본 플러그인이 생성·참조하는 상태 파일은 OMA 표준 `.omao/` 디렉토리를 따릅니다.

- `.omao/plans/self-improving/` — Langfuse 분석 리포트, prompt diff draft
- `.omao/state/autopilot-deploy/` — 진행 중 canary 단계, circuit breaker 상태
- `.omao/state/incident/` — SEV1/2/3 타임라인, runbook 실행 이력
- `.omao/plans/eval/` — 시간별 Ragas 결과, golden dataset 변경 이력
- `.omao/plans/cost/` — 월별 agent별 비용 귀속, 예산 alert 이력

## 참고 자료

- [OMA Marketplace](../../CLAUDE.md) — 상위 플러그인 카탈로그
- [ADR: Self-Improving Loop](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/design-architecture/advanced-patterns/adr-self-improving-loop.md) — 운영 원칙
- [Self-Improving Agent Loop 설계](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/design-architecture/advanced-patterns/self-improving-agent-loop.md) — 5-Stage 아키텍처
- [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) — Core workflow (Operations placeholder 확장 대상)
- [awslabs/mcp](https://github.com/awslabs/mcp) — Hosted MCP 서버 카탈로그
