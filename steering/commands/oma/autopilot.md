---
name: oma:autopilot
description: AIDLC 전체 루프(Inception→Construction→Operations)를 단일 명령으로 자율 실행. 위상 전환 체크포인트에서만 사용자 승인을 받고, 나머지는 에이전트가 주도한다. 신규 프로젝트나 대규모 리아키텍처에 적합.
---
<objective>
AIDLC 3단계(Inception, Construction, Operations)를 순차적으로 자동 실행해 요구사항 정리부터 운영 자동화 활성화까지 일관 수행한다. 각 위상 종료 시점에만 휴먼 체크포인트를 두어 에이전트가 다음 단계로 넘어가기 전 사용자 승인을 획득한다.
</objective>

<when_to_use>
- 신규 프로젝트 초기화로 스펙부터 운영 계측까지 전 구간을 한 번에 밟고 싶을 때
- PoC에서 MVP로 승격하면서 AIDLC 산출물(스펙, 설계, ADR, 테스트, 관측성) 전체를 체계적으로 확보해야 할 때
- 대규모 리아키텍처처럼 여러 기능이 묶인 변경을 에이전트 주도로 한 루프에 처리할 때
- 단일 기능만 필요한 경우에는 이 명령 대신 `/oma:aidlc-loop`를 사용한다
</when_to_use>

<execution_context>
@steering/workflows/aidlc-full-loop.md
</execution_context>

<process>
워크플로우는 `aws-samples/sample-apex-skills`의 5-checkpoint 구조를 따르며 `aidlc-full-loop.md`에 정의된 단계를 그대로 수행한다.

1. **Gather Context** — workspace 유형(greenfield/brownfield) 감지, `.omao/project-memory.json`과 engineering-playbook 스타일 가이드 로드
2. **Pre-flight Checks** — awslabs/aidlc-workflows 설치 확인, 플러그인(aidlc, agenticops) 존재 검증, 기존 `.omao/plans/` 충돌 여부 점검
3. **Plan** — Inception 산출물 3종(spec, stories, workflow plan)과 Construction 분해도, Operations 계측 항목을 한 번에 설계
4. **Execute** — Inception → **CHECKPOINT** → Construction → **CHECKPOINT** → Operations 순으로 수행
5. **Validate** — `.omao/plans/` 산출물 완전성, 테스트 통과, Langfuse/OTel 연결 확인

각 체크포인트에서는 산출물 요약과 함께 "proceed / revise" 응답을 요구하며, 사용자 응답 전까지 다음 단계로 진행하지 않는다. `.omao/state/active-mode`에 `oma:autopilot`을 기록해 다른 Tier-0가 중복 기동하지 않도록 한다.
</process>

<state_handling>
- 활성화 시: `.omao/state/active-mode` = `oma:autopilot`
- 체크포인트 대기 시: `.omao/state/sessions/{sessionId}/checkpoint.json` 기록
- 종료 또는 `/oma:cancel` 호출 시: `.omao/state/active-mode` 초기화
</state_handling>
