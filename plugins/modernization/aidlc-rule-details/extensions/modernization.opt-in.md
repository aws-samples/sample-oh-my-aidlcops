# PRIORITY: This extension activates MANDATORY checks for Legacy-to-AWS Modernization domain

**Extension**: Modernization — Brownfield Legacy-to-AWS (modernization)

## Opt-In Prompt

다음 질문은 이 확장이 로드되었을 때 Inception stage 의 Extensions Loading 단계에 자동으로 포함됩니다.

```markdown
## Question: Modernization Flow
Should the workflow activate modernization-specific rules (6R justification, risk-discovery gating, cutover rollback triggers, post-cutover signoff)?

A) Yes — activate workload-assessment, modernization-strategy, to-be-architecture, containerization, and cutover-planning skills with mandatory data-driven 6R decisions and rollback criteria (recommended for any brownfield migration to AWS)
B) No — use the default AIDLC flow without modernization-specific rules (suitable for greenfield-only projects)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```

## When to Load

본 확장은 다음 중 **하나 이상** 의 조건을 만족하거나 사용자가 명시적으로 modernization 옵트인을 선택할 때 활성화됩니다.

1. **기존 코드베이스 시그널 탐지** — workspace-detection 이 `workspace_type: brownfield` 로 판정
2. **레거시 스택 키워드** — `Oracle`, `Weblogic`, `WebSphere`, `mainframe`, `cobol`, `VMware`, `on-premise`, `on-prem` 중 하나 이상이 프로젝트 컨텍스트에 등장
3. **사용자 명시 옵트인** — Requirements Analysis 단계에서 `modernization` 옵트인을 선택

조건을 만족하지 않으면 확장은 비활성 상태로 유지되며 어떤 규칙도 강제되지 않습니다.

## MANDATORY: Workload Assessment Output Artifact Present

- `modernization-strategy` skill 실행 전 `.omao/plans/modernization/assessment-report.md` 가 반드시 존재해야 합니다
- assessment-report.md 는 다음 필드를 필수로 포함합니다:
  - `dependency_graph` (Mermaid)
  - `database` (엔진·크기·QPS)
  - `traffic` (peak rps, p95 latency)
  - `rto_rpo`
  - `compliance` (규제 목록)
  - `five_lenses` (5축 점수)
  - `readiness_score`

누락 시 `FINDING-MOD-001` 로 기록하고 다음 skill 의 실행을 차단합니다.

## MANDATORY: 6R Decision Justified with Cost/Time/Risk Data

- `strategy-decision.md` 의 `decided_pattern` 은 반드시 `cost_time_risk_matrix` 표로 뒷받침되어야 합니다
- 매트릭스는 최소 2개 이상의 후보 패턴에 대해 다음 수치를 포함합니다:
  - 3년 TCO (USD)
  - 마이그레이션 공수 (인-월)
  - 기술 리스크 (1-5)
  - 비즈니스 리스크 (1-5)
  - 컴플라이언스 리스크 (1-5)
- `considered_alternatives` 와 `rejected_reasons` 가 명시적으로 기록되어야 합니다
- 주관적 수식어("현대적이다", "좋다") 로만 근거를 제시하면 `FINDING-MOD-002` 로 차단합니다

## MANDATORY: Risk Discovery PASS Required Before Containerization

- `containerization` skill 시작 전 `risk-discovery` (aidlc construction) 의 재실행 결과가 PASS 여야 합니다
- 4축 리스크 각각에 대해 완화 조치(mitigation) 가 기록되어야 합니다:
  - 재무 리스크
  - 기술 리스크 (아키텍처 일관성, 데이터 정합성)
  - 조직 리스크 (팀 스킬, 운영 준비도)
  - 규정 리스크 (해당 규제의 통제 매핑)
- FAIL 또는 PARTIAL 상태에서 containerization 을 진행하려 시도하면 `FINDING-MOD-003` 로 차단합니다

## MANDATORY: Cutover Plan Includes Explicit Rollback Trigger Criteria

- `cutover-plan.md` 의 `rollback_triggers` 섹션은 다음 4종을 **수치로** 포함해야 합니다:
  - HTTP 5xx rate 임계값 (예: > 1%, 관측 기간 5 min)
  - P99 Latency 임계값 (예: > 1.5× baseline)
  - SLO Error Budget 소모율 (예: 시간당 10%)
  - DB Replica lag 임계값 (예: > 60s)
- 각 trigger 는 관측 기간과 자동/수동 액션을 명시해야 합니다
- "경험에 따라" 또는 "상황 봐서" 같은 정성적 서술은 `FINDING-MOD-004` 로 차단합니다

## MANDATORY: Post-Cutover Validation Checklist Signed Before Operations Handoff

- Green 100% 도달 후 24시간 이내 Post-Cutover Checklist (cutover-planning skill Step 7) 가 전체 완료되어야 합니다
- 체크리스트 서명(`signed_by`) 과 타임스탬프가 `audit.md` 에 기록되어야 합니다
- 서명 없이 `agenticops/operations-phase` 로 인계를 시도하면 `FINDING-MOD-005` 로 차단합니다

## Blocking Findings

다음 FINDING 중 하나라도 발견되면 해당 Stage 를 진행하지 못합니다.

- **FINDING-MOD-001**: assessment-report.md 누락 또는 필수 필드 공백 (dependency_graph, five_lenses, readiness_score 등)
- **FINDING-MOD-002**: 6R 결정이 cost/time/risk 수치 없이 정성적 근거로만 기록됨
- **FINDING-MOD-003**: risk-discovery PASS 없이 containerization 진행 시도
- **FINDING-MOD-004**: cutover-plan 의 rollback trigger 에 정량 임계값 누락
- **FINDING-MOD-005**: Post-Cutover Checklist 서명 없이 Operations 인계 시도
- **FINDING-MOD-006**: Security Group `0.0.0.0/0` 인바운드 규칙이 to-be-architecture 또는 실제 배포 매니페스트에서 탐지
- **FINDING-MOD-007**: 컨테이너 이미지에 Trivy/grype HIGH 또는 CRITICAL 취약점이 존재하는데 `.trivyignore` 근거 없이 진행

## Integration with core-workflow.md

- `core-workflow.md` 의 Inception Extensions Loading 단계에서 본 `modernization.opt-in.md` 가 스캔됩니다
- "When to Load" 조건 중 하나 이상이 충족되면 opt-in 프롬프트가 Extensions 질문 목록에 삽입됩니다
- 사용자가 A(Yes) 를 선택하면 `aidlc-docs/aidlc-state.md` 의 `## Extension Configuration` 섹션에 `modernization: enabled` 가 기록됩니다
- 본 확장이 활성화되면 `modernization` 플러그인의 5개 skill 이 Inception·Construction 실행 환경에 자동 등록됩니다
- 각 skill 은 본 문서의 MANDATORY 섹션을 자가 검증하며, blocking finding 발생 시 실행을 중단합니다

## Integration with modernization Skills

본 확장이 활성화되면 다음 skill 이 단계별 실행 환경에 등록됩니다.

- `skills/workload-assessment/SKILL.md` — Inception 초입, As-Is 분석
- `skills/modernization-strategy/SKILL.md` — Inception, 6R 결정
- `skills/to-be-architecture/SKILL.md` — Inception 말기 ~ Construction 초입, To-Be 설계
- `skills/containerization/SKILL.md` — Construction, 이미지 빌드
- `skills/cutover-planning/SKILL.md` — Construction 말기, 트래픽 전환

교차 skill 통합:

- `risk-discovery` (aidlc construction) — 각 phase 경계에서 자동 호출
- `audit-trail` (agenticops) — 모든 산출물 생성 후 자동 호출, 주요 결정을 감사 로그에 고정

## Rule Details Loading

opt-in 승인 후 로드할 상세 규칙 파일 경로는 다음과 같습니다(존재 순서대로 첫 번째 매치 사용).

1. `.aidlc/aidlc-rules/aws-aidlc-rule-details/extensions/modernization.md`
2. `.aidlc-rule-details/extensions/modernization.md`
3. `.kiro/aws-aidlc-rule-details/extensions/modernization.md`
4. `.amazonq/aws-aidlc-rule-details/extensions/modernization.md`

상세 규칙 파일이 아직 제공되지 않은 경우 본 opt-in 파일이 정의한 MANDATORY 블록을 최소 기준으로 사용합니다.

## References

- [modernization plugin — CLAUDE.md](../../CLAUDE.md) — 플러그인 전체 설명
- [awslabs/aidlc-workflows — core-workflow.md](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rules/core-workflow.md) — Extensions Loading 규약
- [aws-samples/sample-ai-driven-modernization-with-kiro](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro) — MIT-0 원천 방법론
- [AWS Prescriptive Guidance — 6R Strategy](https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/welcome.html) — 공식 6R 가이드
- 교차 플러그인: [aidlc plugin (construction)](../../../aidlc/CLAUDE.md) — risk-discovery 제공
- 교차 플러그인: [agenticops plugin](../../../agenticops/CLAUDE.md) — audit-trail 제공
