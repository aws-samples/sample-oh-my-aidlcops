---
name: oma:modernize
description: "브라운필드 레거시 워크로드를 AWS 로 현대화하는 6단계 루프 입구. workload-assessment → modernization-strategy → to-be-architecture → containerization → cutover-planning 을 modernization-architect 가 오케스트레이션하며, 각 phase 경계에서 risk-discovery 와 audit-trail 을 자동 호출합니다."
argument-hint: "[target-stack? (ecs|eks|serverless) source-type? (monolith|microservices|legacy-db)]"
---

## 명령 동작

`/oma:modernize` 를 호출하면 `modernization-architect` (opus) 가 세션을 주도합니다. 인자가 생략되면 첫 체크포인트에서 Q&A 로 수집하고, 제공되면 해당 경로로 즉시 진입합니다. 사용자는 각 체크포인트마다 승인·거절·수정을 결정합니다.

## 사용 예

```
/oma:modernize ecs monolith
/oma:modernize eks microservices
/oma:modernize serverless legacy-db
/oma:modernize          # 인자 없이 호출 — Q&A 수집
```

## 6-Stage 워크플로우

### Stage 1. Workload Assessment
- `workload-assessment` skill 호출
- 산출물: `.omao/plans/modernization/assessment-report.md`
- 포함: dependency graph, DB schema, traffic pattern, RTO/RPO, compliance, Five Lenses score

### Stage 2. Strategy Decision (6R)
- `modernization-strategy` skill 호출
- 산출물: `.omao/plans/modernization/strategy-decision.md`
- 필수: cost/time/risk matrix, decided_pattern, rationale, considered_alternatives, rejected_reasons
- **사용자 승인 체크포인트** — `decided_pattern` 명시 승인 필요

### Stage 3. To-Be Architecture
- `to-be-architecture` skill 호출
- 산출물: `.omao/plans/modernization/to-be-architecture.md`
- 포함: compute 선택(ECS/EKS/Serverless), VPC 토폴로지, 매니지드 DB, 관측성, 보안, Compliance Matrix, Mermaid diagram

### Stage 4. Containerization (ECS/EKS 경로 전용)
- `containerization` skill 호출
- 산출물: Dockerfile, multi-arch 빌드 스크립트, ECR push, Task Definition 또는 Deployment 매니페스트
- 게이트: Trivy/grype HIGH/CRITICAL 0건 필수

### Stage 5. Cutover Planning
- `cutover-planning` skill 호출
- 산출물: `.omao/plans/modernization/cutover-plan.md`, `cutover-runbook.md`
- 필수: 전략 선택(Canary/Blue-Green/Rolling), rollback trigger 4종, DMS 동기화 계획

### Stage 6. Operations Handoff
- `audit-trail` (agenticops) 로 전체 타임라인 고정
- `agenticops/operations-phase` 로 인계 (모니터링·비용·인시던트 운영)

## Phase Boundary 호출 규약

각 Stage 종료 직후 다음 교차 플러그인 skill 이 자동 호출됩니다.

- **Stage 1 → 2**: `risk-discovery` (aidlc construction) — 재무/기술/조직/규정 4축 리스크 평가
- **Stage 2 → 3**: `risk-discovery` — 6R 결정의 근거 수치 재검증 (cost/time/risk 가 의견이 아닌 데이터에 기반하는지)
- **Stage 3 → 4**: `risk-discovery` — 아키텍처 일관성 (VPC·IAM·DB·관측성) 과 Compliance Matrix 완전성
- **Stage 4 → 5**: `risk-discovery` PASS 필수 — 데이터 정합성·롤백 경로·동기화 전략 검증
- **Stage 5 → 6**: `audit-trail` (agenticops) — 컷오버 타임라인과 SLO 위반 기준을 감사 로그에 고정

해당 skill 중 FAIL 이 발생하면 다음 Stage 로 진입하지 않고 `modernization-architect` 가 재실행 경로를 제안합니다.

## 재실행 / 롤백

- 각 Stage 종료 후 상태는 `.omao/state/modernization/` 에 저장됩니다
- `--resume-from=<stage>` 로 실패한 지점부터 재시작
- `--dry-run` 으로 실제 변경 없이 계획만 출력
- 컷오버 이후 실패 발생 시 `cutover-plan.md` 의 rollback trigger 에 따라 자동 또는 수동 롤백

## 실패 시 행동

- Stage 1 실패(Five Lenses 수집 불가) → 사용자에게 부족한 정보 요청 후 재시도
- Stage 2 에서 readiness_score == Low → Executive 승인 체크포인트 추가
- Stage 3 에서 Compliance Matrix 공백 → 해당 규제 통제를 To-Be 에 포함시키고 재실행
- Stage 4 에서 보안 스캔 HIGH/CRITICAL → base 이미지 업그레이드 + 재빌드
- Stage 5 에서 rollback trigger 미정의 → 재실행 강제

## 집행 컨텍스트 (Execution Context)

본 커맨드는 다음 워크플로우 정의를 따라 동작합니다.

- `steering/workflows/modernization-loop.md` — modernization 전용 6-stage 루프 정의 (M2 agent 가 생성한 stage-gated-progression.md 와 연계)
- `steering/workflows/stage-gated-progression.md` — stage 경계 gating 규약 (M2 산출물)
- 위 파일이 아직 생성되지 않은 경우에도 본 커맨드는 자체 정의된 Stage 시퀀스로 동작합니다

## 참고 자료

- 플러그인 CLAUDE.md: `/home/ubuntu/workspace/oh-my-aidlcops/plugins/modernization/CLAUDE.md`
- 5개 skill: `../skills/workload-assessment`, `../skills/modernization-strategy`, `../skills/to-be-architecture`, `../skills/containerization`, `../skills/cutover-planning`
- Agent: `../agents/modernization-architect.md`
- [aws-samples/sample-ai-driven-modernization-with-kiro](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro) — MIT-0 원천 방법론
- [AWS Migration Hub](https://aws.amazon.com/migration-hub/) — 공식 포털
