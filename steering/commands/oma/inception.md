---
name: oma:inception
description: AIDLC Phase 1(Inception)만 단독 실행한다. workspace 감지, 요구사항 분석, 유저스토리 작성, workflow plan 생성까지 수행해 `.omao/plans/` 산출물을 생산한다. 구현 단계는 포함하지 않는다.
---
<objective>
aidlc-inception 플러그인의 스킬을 규정 순서대로 실행해 스펙(spec), 유저스토리(stories), workflow plan 3종 산출물을 생성한다. 이 산출물은 이후 `/oma:construction` 또는 `/oma:aidlc-loop`의 입력으로 재사용된다.
</objective>

<when_to_use>
- 구현 없이 요구사항·스펙·유저스토리·워크플로우 플랜까지만 산출하고 싶을 때
- 브라운필드 프로젝트에서 기존 코드베이스를 읽고 AIDLC 산출물을 역생성(reverse-engineering)하고 싶을 때
- 여러 팀 간 스펙 합의가 선행되어야 하는 경우, 구현 단계를 분리해 별도 승인 사이클에 진입할 때
- 구현까지 바로 이어가고 싶다면 `/oma:aidlc-loop` 또는 `/oma:autopilot`을 사용한다
</when_to_use>

<execution_context>
@steering/workflows/aidlc-full-loop.md
</execution_context>

<process>
`aidlc-full-loop.md`의 5-checkpoint 중 **Inception 범위**만 실행한다.

1. **Gather Context** — greenfield vs brownfield 판정, 기존 `.omao/plans/` 파일 로드, engineering-playbook 스타일 가이드 적용 여부 확인
2. **Pre-flight Checks** — aidlc-inception 플러그인 설치 확인, awslabs/aidlc-workflows 버전 정합 확인
3. **Plan** — 스펙 섹션 구조, 유저스토리 템플릿, workflow 플랜 항목을 사용자와 미리 합의
4. **Execute** — aidlc-inception 플러그인 스킬을 다음 순서로 호출
   - `workspace-detection` → `requirements-analysis` → `user-stories` → `workflow-planning`
5. **Validate** — 산출물 3종(`spec.md`, `stories.md`, `workflow-plan.md`)의 필수 섹션·링크 무결성 점검

Construction/Operations 단계로는 자동 전환하지 않는다. 다음 단계 진행은 사용자가 명시적으로 `/oma:construction` 또는 `/oma:aidlc-loop`를 호출해야 시작된다.
</process>

<outputs>
- `.omao/plans/spec.md` — 요구사항 스펙
- `.omao/plans/stories.md` — 유저스토리 리스트
- `.omao/plans/workflow-plan.md` — 단계별 workflow 분해
</outputs>
