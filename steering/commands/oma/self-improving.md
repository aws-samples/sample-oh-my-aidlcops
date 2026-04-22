---
name: oma:self-improving
description: Langfuse trace와 운영 시그널을 입력으로 받아 프롬프트·스킬 개선 PR을 자동 생성하는 피드백 루프를 1회 또는 주기적으로 실행한다. agenticops의 self-improving-loop 스킬을 직접 호출한다.
---
<objective>
운영 중 수집된 Langfuse trace, 평가 점수, 비용 지표에서 regression candidate를 식별해 프롬프트 또는 스킬 diff를 제안하는 드래프트 PR을 생성한다. 사람이 승인하기 전까지는 어떤 변경도 실제 배포에 반영되지 않는다.
</objective>

<when_to_use>
- Langfuse에서 faithfulness 하락, latency 급증, token 비용 이상이 감지됐을 때
- 주간·월간 주기로 "지금까지의 trace를 기반으로 개선할 것"이라는 루프를 수동 트리거하고 싶을 때
- 3개 축 동시 운영이 필요하면 `/oma:agenticops`로 전환한다
- 이 명령은 **1회성 피드백 루프**를 실행하며 연속 모드가 아니다
</when_to_use>

<execution_context>
@steering/workflows/self-improving-deploy.md
</execution_context>

<process>
`self-improving-deploy.md` 워크플로우를 단일 이터레이션으로 수행한다. engineering-playbook의 `self-improving-agent-loop.md` ADR 규약을 준수한다.

1. **Gather Context** — 최근 24시간 Langfuse trace, 현재 프롬프트·스킬 스냅샷, 최근 배포 이력 수집
2. **Pre-flight Checks** — regression candidate 식별(faithfulness, latency, cost 중 최소 1개 임계 위반)
3. **Plan** — 프롬프트 diff 또는 스킬 diff 후보안 생성, Ragas 기준 평가 계획 수립
4. **Execute** — draft PR 오픈 (diff + before/after 평가 리포트 첨부)
5. **Validate** — 사람이 리뷰·승인 → 머지 → canary 배포 → continuous-eval 재측정

루프는 1회 종료되며 연속 기동을 원하면 `/oma:agenticops`를 사용한다. `.omao/state/active-mode`에는 `oma:self-improving`을 일시적으로 기록하고 PR 오픈 후 해제한다.
</process>

<references>
- engineering-playbook `docs/agentic-ai-platform/design-architecture/advanced-patterns/adr-self-improving-loop.md` — ADR 정의
- engineering-playbook `docs/agentic-ai-platform/design-architecture/advanced-patterns/self-improving-agent-loop.md` — 상세 설계
- `plugins/agenticops/skills/self-improving-loop/` — 플러그인 스킬 구현
</references>
