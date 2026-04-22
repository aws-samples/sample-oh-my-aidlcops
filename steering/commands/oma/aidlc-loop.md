---
name: oma:aidlc-loop
description: 단일 기능에 대해 AIDLC(Inception→Construction)를 1회 순회한다. 유저스토리 1개, GitHub 이슈 1개 범위의 개발 작업을 스펙 합의, 설계, 구현, 테스트까지 일관된 규약으로 처리하도록 설계됐다.
---
<objective>
하나의 기능 요구사항에 대해 AIDLC Phase 1(Inception)과 Phase 2(Construction)를 순차 실행해 스펙, 설계, 코드, 테스트, PR을 한 번에 산출한다. Operations 위상은 포함하지 않으며, 기존 운영 파이프라인에 통합되는 기능 단위 개발에 사용한다.
</objective>

<when_to_use>
- 하나의 유저스토리나 GitHub Issue 범위 안에서 스펙부터 PR까지 일관 추적하고 싶을 때
- 팀의 AIDLC 규약(스펙 승인 → 설계 승인 → 테스트 우선 구현)을 강제해야 할 때
- 운영 자동화 활성화까지는 필요 없고 기능 구현까지만 범위를 제한하고 싶을 때
- 전체 루프가 필요하면 `/oma:autopilot`, 요구사항 정리만 필요하면 `/oma:inception`을 사용한다
</when_to_use>

<execution_context>
@steering/workflows/aidlc-full-loop.md
</execution_context>

<process>
`aidlc-full-loop.md`의 5-checkpoint 워크플로우를 **단일 기능 범위로 축소**하여 실행한다.

1. **Gather Context** — 기능 요구사항(자연어 요약), 관련 이슈 ID, brownfield 기존 모듈 식별
2. **Pre-flight Checks** — `.omao/plans/` 내 동일 기능 중복 산출물 여부, 기존 ADR/스펙과의 모순 검증
3. **Plan** — 하나의 `spec.md`, 유저스토리 1~3개, 컴포넌트 설계 1개 단위로 최소화
4. **Execute** — Inception 산출물 작성 → **CHECKPOINT (스펙 승인)** → Construction(TDD 기반 구현) → **CHECKPOINT (PR 리뷰)**
5. **Validate** — 단위 테스트 통과, ADR 링크, PR 초안 생성 확인

Operations 체크포인트는 생략한다. 운영 계측이 필요하면 후속으로 `/oma:agenticops`를 실행해 기능을 기존 관측성 파이프라인에 연결한다.
</process>

<state_handling>
- 활성화 시: `.omao/state/active-mode` = `oma:aidlc-loop`
- 스펙 승인 체크포인트: `.omao/plans/spec.md` 최신화 후 사용자 응답 대기
- 완료 또는 중단 시: `.omao/state/active-mode` 초기화, `.omao/notepad.md`에 진행 이력 누적
</state_handling>
