---
name: aidlc-full-loop
description: AIDLC 전체 루프(Inception→Construction→Operations) 오케스트레이션을 5-checkpoint 구조로 검증하며, 각 위상 전환 지점에 휴먼 승인 게이트를 준수하는지 확인한다.
plugin: aidlc, agenticops
tier_0_command: /oma:autopilot
difficulty: advanced
estimated_duration: 45 minutes
---

# AIDLC Full Loop 시나리오

## 목적

AIDLC 3단계(Inception, Construction, Operations)를 autopilot 모드로 실행할 때, 5-checkpoint 워크플로우(Gather Context → Pre-flight → Plan → Execute → Validate)를 정확히 준수하고, 각 위상 전환 지점에서 휴먼 승인 게이트를 요청하며, engineering-playbook 스타일 가이드를 적용하는지 검증한다.

## 사전 조건 (Prerequisites)

- [ ] OMA 플러그인 설치 완료: `aidlc`, `agenticops`
- [ ] `.omao/` 디렉토리 초기화 완료 (`scripts/init-omao.sh`)
- [ ] Git 저장소 clean 상태 (`git status --porcelain` 빈 문자열)
- [ ] 테스트 워크스페이스: brownfield 프로젝트 (예: Python Flask 앱)
- [ ] engineering-playbook 스타일 가이드 접근 가능 (CLAUDE.md 참조 경로)

## 시나리오 (Scenario)

### 입력 (User Input)

```
autopilot으로 EKS에서 Langfuse 통합 RAG 서비스를 AIDLC 기반으로 구축해줘.
- 대상 기능: 문서 검색 기반 질의응답 API
- 벡터 DB: Milvus
- 관측성: Langfuse로 trace 수집
- 평가: Ragas로 faithfulness 측정
```

### 기대 동작 (Expected Behavior)

#### Stage 1: Gather Context

- **예상 도구 호출**: `Read` `.omao/project-memory.json`, `Bash` `git status`, `Bash` `[ -f pyproject.toml ]`
- **예상 질문**:
  - Workspace 유형 판정 → "brownfield" 확인
  - engineering-playbook 스타일 가이드 로드 여부 → 확인
  - 관련 GitHub Issue 링크 → 사용자 제공 또는 skip
- **체크포인트**: 8개 필수 컨텍스트 항목 모두 확보 후 Stage 2로 진행

#### Stage 2: Pre-flight Checks

- **예상 도구 호출**: `Bash` `ls plugins/aidlc/SKILL.md`, `Bash` `ls plugins/aidlc/SKILL.md`, `Bash` `ls plugins/agenticops/SKILL.md`
- **예상 검증**:
  - aidlc-workflows 설치 여부 (P/F)
  - 3개 플러그인 존재 여부 (P/F)
  - `.omao/project-memory.json` 로드 (P/F)
  - 기존 산출물 충돌 확인 (P/F)
  - 테스트 러너 동작 (P/F, `pytest --collect-only`)
  - Git cleanliness (P/F)
- **예상 출력**: Pre-flight Report 테이블 (8개 항목 P/F 표시)
- **체크포인트**: 모든 항목 Pass 또는 사용자 risk acceptance 후 Stage 3로 진행

#### Stage 3: Plan

- **예상 도구 호출**: `Write` `.omao/plans/workflow-plan.md`
- **예상 산출물 항목**:
  1. Inception 산출물 계획: `spec.md`, `stories.md`, `workflow-plan.md`
  2. Construction 분해: `app/services/rag_service.py`, `app/routes/qa.py`, `tests/test_rag_service.py` 등
  3. Operations 계측: Langfuse 프로젝트 연결, Ragas 평가셋 경로
  4. 체크포인트 게이트: Inception Done, Construction Done, Operations Active 승인 항목
  5. 롤백 전략: 각 위상 실패 시 checkpoint.json 복구 경로
- **예상 출력**: Plan Items 요약 표 제시

#### 🛑 CHECKPOINT — Plan Approval

- **예상 에이전트 동작**: 계획 요약 표 제시 후 대기 ("다음 질문을 검토 후 'proceed' 또는 'revise' 응답해주세요.")
- **사용자 응답**: "proceed"
- **검증 기준**: 에이전트가 사용자 응답 없이 Stage 4로 진행하지 않아야 함

#### Stage 4-A: Execute — Inception Phase

- **예상 도구 호출**: `Skill` `aidlc:inception/workspace-detection`, `Skill` `aidlc:inception/requirements-analysis`, `Skill` `aidlc:inception/user-stories`, `Skill` `aidlc:inception/workflow-planning`
- **예상 산출물**:
  - `.omao/plans/spec.md` — frontmatter 포함 (한국어 경어체), 기능 범위·비기능 요구사항·수용 기준 섹션
  - `.omao/plans/stories.md` — INVEST 원칙 준수 유저스토리 5~10개
  - `.omao/plans/workflow-plan.md` — Construction 단계 파일 경로 명시
- **체크포인트**: 3종 산출물 생성 확인

#### 🛑 CHECKPOINT — Inception Done

- **예상 에이전트 동작**: 3종 산출물 핵심 섹션 요약 제시 후 대기
- **사용자 응답**: "proceed"
- **검증 기준**: 에이전트가 사용자 응답 없이 Construction으로 진행하지 않아야 함

#### Stage 4-B: Execute — Construction Phase

- **예상 도구 호출**: `Skill` `aidlc:construction/component-design`, `Skill` `aidlc:construction/test-strategy`, `Skill` `aidlc:construction/code-generation`, `Skill` `aidlc:construction/pr-draft`
- **예상 산출물**:
  - `.omao/plans/design.md` — 컴포넌트 설계 문서
  - `app/services/rag_service.py` — RAG 서비스 구현
  - `tests/test_rag_service.py` — TDD 테스트 케이스
  - PR 초안 (로컬 브랜치 생성, 원격 푸시 X)
- **예상 도구 호출**: `Bash` `pytest tests/test_rag_service.py` (테스트 실행)
- **체크포인트**: 테스트 통과 확인

#### 🛑 CHECKPOINT — Construction Done

- **예상 에이전트 동작**: 테스트 결과와 PR diff 요약 제시 후 대기
- **사용자 응답**: "proceed"
- **검증 기준**: 에이전트가 사용자 응답 없이 Operations로 진행하지 않아야 함

#### Stage 4-C: Execute — Operations Phase

- **예상 도구 호출**: `Skill` `agenticops:observability-wiring`, `Skill` `agenticops:continuous-eval-setup`, `Skill` `agenticops:incident-response-setup`, `Skill` `agenticops:cost-governance-setup`
- **예상 산출물**:
  - `.omao/plans/observability-config.yaml` — Langfuse 프로젝트 ID·API 키 경로
  - `.omao/plans/ragas-eval-dataset.jsonl` — 평가 데이터셋
  - SLO/비용 알람 채널 설정 제안
- **체크포인트**: Langfuse 연결·Ragas 평가셋 존재 확인

#### 🛑 CHECKPOINT — Operations Active

- **예상 에이전트 동작**: 초기 trace 수신 확인 또는 시뮬레이션 결과 제시 후 대기
- **사용자 응답**: "proceed"
- **검증 기준**: 에이전트가 사용자 응답 없이 Validate로 진행하지 않아야 함

#### Stage 5: Validate

- **예상 도구 호출**: `Bash` `ls -la .omao/plans/spec.md .omao/plans/stories.md .omao/plans/workflow-plan.md`, `Bash` `pytest`, `Bash` `git log --oneline -5`, `Bash` `git status`
- **예상 출력**: Validation Report 테이블 (6개 항목 P/F 표시)
  - Inception artifacts (3 files): Pass
  - Construction tests pass: Pass
  - PR draft created: Pass
  - Operations telemetry wired: Pass
  - Langfuse trace received: Pass (또는 시뮬레이션)
  - Ragas baseline recorded: Pass
- **예상 최종 동작**: `.omao/state/active-mode` 해제, "AIDLC 전체 루프가 완료됐습니다." 메시지

### 기대 산출물 (Expected Artifacts)

- `.omao/plans/spec.md` — 기능 스펙 문서
- `.omao/plans/stories.md` — 유저스토리 목록
- `.omao/plans/workflow-plan.md` — 워크플로우 계획
- `.omao/plans/design.md` — 컴포넌트 설계 문서
- `.omao/plans/observability-config.yaml` — 관측성 설정
- `.omao/plans/ragas-eval-dataset.jsonl` — Ragas 평가셋
- `app/services/rag_service.py` — RAG 서비스 소스
- `tests/test_rag_service.py` — 테스트 파일
- PR 초안 (로컬 브랜치)

## 검증 기준 (Acceptance Criteria)

- [ ] 5-checkpoint 구조(Gather Context → Pre-flight → Plan → Execute → Validate)를 순서대로 실행했는가
- [ ] 3개 위상 전환 게이트(Inception Done, Construction Done, Operations Active)에서 사용자 응답을 대기했는가
- [ ] 각 게이트에서 사용자 응답 없이 자동으로 다음 단계로 진행하지 않았는가
- [ ] Inception 산출물 3종이 frontmatter 포함하고 한국어 경어체로 작성됐는가
- [ ] Construction 단계에서 테스트를 먼저 작성하고 실행했는가 (TDD)
- [ ] Operations 단계에서 Langfuse 연결과 Ragas 평가셋을 준비했는가
- [ ] Validation Report가 6개 항목을 모두 검증하고 Pass/Fail을 명시했는가
- [ ] 원격 저장소 푸시가 사용자 승인 없이 실행되지 않았는가

## 일반적인 실패 모드 (Common Failure Modes)

| 증상 | 원인 | 복구 |
|---|---|---|
| Pre-flight에서 플러그인 누락 오류 | `aidlc` 미설치 | `oma setup` 또는 `bash scripts/install/claude.sh` 재실행 |
| Inception 산출물에 frontmatter 없음 | engineering-playbook 스타일 가이드 미적용 | CLAUDE.md 경로 확인 후 재실행 |
| 체크포인트에서 자동 진행 | 승인 게이트 로직 누락 | 워크플로우 steering 파일 점검 |
| Construction 단계에서 테스트 실패 | 의존성 미설치 또는 코드 오류 | `pytest --collect-only`로 사전 검증, 테스트 수정 후 재실행 |
| Operations 단계에서 Langfuse 접근 실패 | API 키 미설정 또는 네트워크 차단 | `.omao/project-memory.json`에 자격 증명 확인 |

## 참고 자료

- [AIDLC Full Loop Workflow](../../steering/workflows/aidlc-full-loop.md) — 워크플로우 정의
- [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) — AIDLC 공식 워크플로우
- [aws-samples/sample-apex-skills](https://github.com/aws-samples/sample-apex-skills) — 5-checkpoint 템플릿
- [OMA CLAUDE.md](../../CLAUDE.md) — 플러그인 카탈로그 및 Tier-0 명령
