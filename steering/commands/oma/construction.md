---
name: oma:construction
description: AIDLC Phase 2(Construction)만 단독 실행한다. Inception 산출물을 입력으로 받아 컴포넌트 설계, 코드 생성, agentic TDD 테스트, PR 초안까지 수행한다. Inception 산출물이 선행 존재해야 한다.
---
<objective>
aidlc-construction 플러그인의 스킬을 순서대로 실행해 컴포넌트 설계, 코드 스캐폴딩, 테스트, PR 초안을 생산한다. 기존에 정의된 스펙·유저스토리·workflow plan을 그대로 소비하며 구현 일관성을 유지한다.
</objective>

<when_to_use>
- Inception 산출물(`.omao/plans/spec.md`, `stories.md`, `workflow-plan.md`)이 이미 승인 완료된 상태에서 구현만 수행할 때
- 다른 팀이 작성한 스펙을 받아 구현 책임만 맡은 경우
- Inception 단계를 재실행하지 않고 변경된 유저스토리만 가지고 코드를 갱신하고 싶을 때
- Inception 산출물이 없으면 이 명령은 Pre-flight 단계에서 중단된다. `/oma:inception`부터 실행한다
</when_to_use>

<execution_context>
@steering/workflows/aidlc-full-loop.md
</execution_context>

<process>
`aidlc-full-loop.md`의 5-checkpoint 중 **Construction 범위**만 실행한다.

1. **Gather Context** — `.omao/plans/` 산출물 3종 로드, 기존 코드베이스 구조 스캔, 테스트 프레임워크 감지
2. **Pre-flight Checks** — Inception 산출물 존재 여부, aidlc-construction 플러그인 설치, 테스트 러너·빌드 도구 동작 확인
3. **Plan** — 컴포넌트 설계 다이어그램, 파일 생성 경로, TDD 테스트 케이스 목록을 사용자와 합의
4. **Execute** — aidlc-construction 플러그인 스킬을 다음 순서로 호출
   - `component-design` → `agentic-tdd` → `code-generation` → `pr-draft`
5. **Validate** — 단위 테스트 통과, 린트·타입체크 통과, PR 초안에 ADR·스펙 링크 포함 여부 확인

Operations 단계로 자동 전환하지 않으며 PR 머지 후 운영 자동화는 `/oma:agenticops`를 통해 별도로 활성화한다.
</process>

<prerequisites>
- `.omao/plans/spec.md` 존재
- `.omao/plans/stories.md` 존재
- `.omao/plans/workflow-plan.md` 존재
- aidlc-construction 플러그인 설치 (`plugins/aidlc-construction/`)
</prerequisites>
