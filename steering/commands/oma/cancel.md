---
name: oma:cancel
description: 현재 활성 Tier-0 모드(autopilot, aidlc-loop, agenticops, self-improving, platform-bootstrap 등)를 안전하게 종료한다. `.omao/state/active-mode`를 읽어 해당 모드의 정리 루틴을 호출한 뒤 상태를 비운다.
---
<objective>
실행 중인 OMA Tier-0 모드를 깔끔하게 중단하고 `.omao/state/active-mode` 및 관련 세션 상태를 정리한다. 진행 중인 체크포인트 대기, 병렬 에이전트 lease, 세션 heartbeat를 모두 종료한다.
</objective>

<when_to_use>
- autopilot이 의도치 않은 경로로 진입했을 때 즉시 중단하고 싶을 때
- agenticops 지속 모드가 더 이상 필요하지 않을 때(예: 운영 종료, 리허설 종료)
- 다른 Tier-0를 새로 시작하기 전에 기존 모드를 강제로 정리해야 할 때
- 작업이 완료되지 않은 경우에는 취소하지 말고 현재 체크포인트를 정상 통과시키는 것을 먼저 고려한다
</when_to_use>

<execution_context>
— (no workflow file; inline cleanup logic)
</execution_context>

<process>
인라인 로직으로 상태 파일과 활성 에이전트를 정리한다. 별도 워크플로우 파일은 두지 않는다.

1. **Read state** — `.omao/state/active-mode`를 읽어 현재 모드 식별. 비어 있으면 "활성 모드 없음"으로 응답 후 종료.
2. **Invoke cleanup** — 모드별 정리 루틴 수행
   - `oma:autopilot` / `oma:aidlc-loop` / `oma:inception` / `oma:construction` — 진행 중 체크포인트 저장, 세션 로그 flush
   - `oma:agenticops` — 3개 에이전트(continuous-eval, incident-response, cost-governance) graceful stop
   - `oma:self-improving` — 열려 있는 draft PR 상태 기록, 미완 작업 안내
   - `oma:platform-bootstrap` — 현재 체크포인트 이전 단계까지 성공한 리소스 목록을 보존
3. **Clear state** — `.omao/state/active-mode` 초기화, `.omao/state/sessions/{sessionId}/cancelled-at` 타임스탬프 기록
4. **Report** — 정리된 항목과 보존된 산출물 경로를 사용자에게 요약

워크플로우 파일이 없는 대신, 해당 로직은 본 명령 실행 시 인라인으로 수행된다. 모드별 구체 정리 단계는 플러그인의 cleanup 스킬을 재사용한다.
</process>

<safety>
- 이 명령은 **파괴적이지 않다**. 산출물(`.omao/plans/`, PR draft)은 제거하지 않는다.
- 제거되는 것은 런타임 상태(`active-mode`, agent lease, heartbeat)뿐이다.
- 명시적으로 `--purge` 옵션을 준 경우에만 세션 로그를 삭제한다(기본값은 보존).
</safety>
