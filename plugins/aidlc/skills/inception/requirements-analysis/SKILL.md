---
name: requirements-analysis
description: "Adaptive-depth requirements analysis for AIDLC Inception. Simple features produce a 1-paragraph brief; complex features produce structured REQ-001/REQ-002 functional and non-functional requirements with acceptance criteria and traceability to user stories."
argument-hint: "[feature slug — e.g., semantic-router, gateway-guardrails]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Grep,Glob"
---

## 언제 사용하나요

- `workspace-detection` 산출물을 바탕으로 요구사항을 정리할 때
- 비즈니스 목표와 기술 제약을 Functional / Non-Functional 로 분리해야 할 때
- 기존 기능 확장 시, 변경된 범위의 요구사항만 선별적으로 갱신할 때

## 언제 사용하지 않나요

- 사용자 대면 플로우 묘사가 주 목적일 때 — `user-stories` 스킬 사용
- 구현 상세(API 스펙, DB 스키마) 를 작성할 때 — Phase 2 로 이동
- 단일 버그 수정처럼 요구사항이 자명한 작업

## 전제 조건

- `workspace-report.md` 존재 또는 범위가 명확한 기능 요청 문장 확보
- 목표 슬러그(`<feature-slug>`) 가 `.omao/plans/` 에 생성됨
- 비기능 요구사항(성능/비용/보안) 에 관여하는 이해관계자 확인

## 절차

### Step 1. 깊이 선택 (Adaptive Depth)

| 기준 | Simple | Structured |
|------|--------|-----------|
| 영향 범위 | 단일 컴포넌트 | 2개 이상 컴포넌트 |
| 예상 변경 파일 | 10 미만 | 10 이상 |
| 비기능 제약 | 없음 또는 미미 | 성능/비용/보안 조건 존재 |
| 이해관계자 | 단일 팀 | 다팀 협업 필요 |

결정 결과는 `depth: simple | structured` 로 기록합니다.

### Step 2. Simple Mode — 1-문단 Brief

"**무엇을 왜 바꾸며, 성공 판단 기준은 무엇인지**" 를 5~8 문장으로 서술합니다.
사용자 시나리오, 핵심 제약 1~2개, 검증 지표(예: "응답 지연 < 200ms") 를 포함합니다.

### Step 3. Structured Mode — REQ-ID 포맷

```markdown
# Requirements — semantic-router

## Functional Requirements
- **REQ-001**: 라우터는 프롬프트 임베딩 유사도 기반으로 모델을 선택합니다.
  - Acceptance: 동일 의미 프롬프트 100건에 대해 95% 이상 동일 모델 라우팅
- **REQ-002**: 라우터는 폴백 경로를 제공합니다.
  - Acceptance: 주 모델 오류율 5% 초과 시 30초 내 폴백 모델로 전환

## Non-Functional Requirements
- **REQ-NF-001** (성능): p95 라우팅 지연 < 20ms
- **REQ-NF-002** (비용): 1K 요청당 비용 < $0.003
- **REQ-NF-003** (보안): 프롬프트 원문은 디스크에 저장하지 않음

## Traceability
| REQ-ID | User Story | Workflow Step |
|--------|-----------|---------------|
| REQ-001 | US-01 | workflow-step-2 |
| REQ-002 | US-03 | workflow-step-4 |
```

### Step 4. 비기능 요구사항 체크리스트

- 성능: p50/p95/p99 지연, 처리량(QPS), 동시 사용자 수
- 비용: 월간 상한, 요청당 비용, 리전 최적화 여부
- 보안: 인증/인가, 데이터 분류, 전송/저장 암호화, PII 취급
- 관측성: 메트릭/로그/트레이스 스펙, SLO/SLI 정의
- 규제: ISMS-P, SOC2, HIPAA 등 도메인별 요구

### Step 5. 검증 기준(Acceptance Criteria)

- 각 REQ-ID 는 **검증 가능한 문장**을 최소 1개 포함합니다.
- 주관적 표현("빠르게", "쉽게") 을 금지하고 수치 또는 명시적 조건으로 기술합니다.

### Step 6. 산출물 저장

- `.omao/plans/<slug>/requirements.md` 저장
- frontmatter: `created`, `last_update.date`, `tags: [aidlc, inception, requirements]`
- 워크스페이스 리포트 링크 포함

### Step 7. 옵트인 확장 평가

- `agentic-platform.opt-in.md` — Agentic AI 도메인이면 필수 검증 활성
- `korean-docs-style.opt-in.md` — 산출물 문서 스타일 강제

## 좋은 예시

- Simple: "Inference Gateway 로그 필드에 `tenant_id` 를 추가합니다. 목적은 테넌트별 과금 분석이며 100% 의 요청 로그에 필드가 포함되어야 합니다."
- Structured: REQ-001 ~ REQ-005 + 비기능 3개 + Traceability 표

## 나쁜 예시 (금지)

- "성능을 개선한다" — 수치가 없어 검증 불가
- 기능/비기능 혼재 — 독립 섹션 필수
- Acceptance Criteria 누락 — 다운스트림 테스트 설계 불가
- 이해관계자 언급 없이 보안/규제 요구 생략

## 참고 자료

### 공식 문서
- [awslabs/aidlc-workflows — requirements-analysis](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rule-details/inception/requirements-analysis.md) — 원본 요구사항 분석 규칙
- [AWS Prescriptive Guidance — Functional Requirements](https://docs.aws.amazon.com/prescriptive-guidance/latest/software-requirements-specification/) — 요구사항 명세 가이드

### 관련 문서 (내부)
- `../workspace-detection/SKILL.md` — 선행 스킬
- `../user-stories/SKILL.md` — 후행 스킬(조건부)
- `../workflow-planning/SKILL.md` — 실행 단위 설계
- `../../aidlc-rule-details/extensions/agentic-platform.opt-in.md` — Agentic 도메인 확장
- `/home/ubuntu/workspace/oh-my-aidlcops/CLAUDE.md` — OMA 전체 철학
