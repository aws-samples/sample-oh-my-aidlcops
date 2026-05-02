---
name: workflow-planning
description: "Strategic workflow planning for AIDLC Phase 1 close-out. Chooses sequential / parallel-units / iterative execution mode via a decision tree, maps stories to units, and defines checkpoint gates. Produces workflow-plan.md as the hand-off artifact to the aidlc plugin construction phase."
argument-hint: "[feature slug — same slug used in requirements-analysis and user-stories]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Write,Edit,Grep,Glob"
---

## 언제 사용하나요

- 요구사항과 스토리가 확정되어 **실행 모드** 를 결정해야 할 때
- 병렬 작업 가능성과 의존성 그래프를 정리해 Construction 단계로 전달할 때
- Checkpoint gate(휴먼 승인 지점) 을 정의해야 할 때

## 언제 사용하지 않나요

- 단일 스토리, 단일 커밋 수준 작업 — 오버헤드만 발생
- 이미 `aidlc` (construction) 이 진행 중인 피처의 재계획 — 해당 플러그인에서 수행
- 운영 장애 대응(AgenticOps 모드) — `agenticops` 플러그인 참조

## 전제 조건

- `.omao/plans/<slug>/requirements.md`, `user-stories.md` 존재(또는 스토리 생략 결정 로그)
- 팀 캘린더 또는 인력 가용성에 대한 개괄 정보
- Construction 단계에서 가능한 에이전트 카탈로그 확인 완료

## 절차

### Step 1. 실행 모드 결정 트리

```
    요구사항 간 엄격한 순서 의존성?
         ├── 예 → sequential
         └── 아니오
              ├── 스토리 ≥ 5 개 + 독립 Unit 분해 가능?
              │     ├── 예 → parallel-units
              │     └── 아니오
              └── 불확실성 높음(프로토타입·탐색) → iterative
```

- **sequential**: Step 1 → Step 2 → Step 3 선형. 결정 횟수 최소, 리스크 관리 단순.
- **parallel-units**: 독립 Unit N 개를 병렬. Unit 간 계약(인터페이스) 을 먼저 확정.
- **iterative**: 2주 스프린트 × 3회. 각 반복 끝에 재계획.

### Step 2. Unit 분해 (parallel-units 일 때)

- 각 Unit 은 1~2명의 에이전트/엔지니어가 2~5일 내 완료 가능
- Unit 간 의존성은 방향성 그래프로 표현
- 공유 자원(DB 스키마, API 계약) 은 Unit 0(공통 계약) 로 분리

### Step 3. Checkpoint Gate 설계

| Gate | 승인자 | 확인 항목 |
|------|--------|----------|
| G1 — Requirements Freeze | 프로덕트 오너 | REQ 목록, 비기능 요구, 우선순위 |
| G2 — Story Freeze | 테크 리드 | 스토리 완전성, Acceptance Criteria |
| G3 — Unit Contract Freeze | 아키텍트 | Unit 인터페이스, 데이터 계약 |
| G4 — Construction Kickoff | 엔지니어링 매니저 | 인력/예산, 리스크 완화안 |

### Step 4. 리스크 매트릭스

| 리스크 | 발생 확률 | 영향 | 완화 |
|--------|----------|------|------|
| GPU 쿼터 부족 | 중 | 고 | On-Demand → Spot 전환, 리전 이중화 |
| 모델 가중치 라이선스 제약 | 저 | 고 | 대체 모델 후보 2개 사전 확보 |
| Langfuse 자체 호스팅 운영 부담 | 중 | 중 | SaaS 대체 경로 문서화 |

### Step 5. 일정 초안(Indicative Timeline)

- sequential: 단계별 완료일 + 25% 버퍼
- parallel-units: Unit 별 시작/종료 + 통합 시점 명시
- iterative: 스프린트 목표(Goal) + 스프린트 리뷰 일자

### Step 6. Construction 핸드오프 입력 정의

다음 세 산출물을 `aidlc` (construction) 에 전달합니다.

1. `requirements.md` — 기능/비기능 요구, REQ-ID
2. `user-stories.md` — 스토리, AC, Traceability(생략된 경우 사유 로그)
3. `workflow-plan.md` — 실행 모드, Unit 분해, Gate, 리스크, 일정

### Step 7. 산출물 저장

- `.omao/plans/<slug>/workflow-plan.md` 저장
- frontmatter: `created`, `last_update.date`, `tags: [aidlc, inception, workflow-planning]`
- 상단에 실행 모드, Unit 수, Gate 수를 요약 표로 배치

## 좋은 예시

- parallel-units 5개 + 공통 계약 Unit 0, Gate 4개, 리스크 7개 + 완화안, 8주 일정
- iterative 3 스프린트, 각 스프린트 목표 1문장 + AC 3~5개

## 나쁜 예시 (금지)

- "일단 시작하고 필요하면 쪼개자" — Unit/Gate 미정의
- Gate 승인자 공백 — 의사결정 정체 유발
- 리스크를 "낮음/낮음/낮음" 으로 일괄 기재 — 실효성 없음
- sequential 과 parallel-units 특징을 섞어 서술 — 모드 명시 필요

## 참고 자료

### 공식 문서
- [awslabs/aidlc-workflows — workflow-planning](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rule-details/inception/workflow-planning.md) — 원본 워크플로우 계획 규칙
- [awslabs/aidlc-workflows — units-generation](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rule-details/inception/units-generation.md) — Unit 분해 원본 규칙

### 관련 문서 (내부)
- `../requirements-analysis/SKILL.md` — REQ-ID 소스
- `../user-stories/SKILL.md` — 스토리 소스
- `../../CLAUDE.md` — aidlc 플러그인 개요
- `/home/ubuntu/workspace/oh-my-aidlcops/plugins/aidlc/CLAUDE.md` — Phase 2 핸드오프 대상
- `/home/ubuntu/workspace/oh-my-aidlcops/CLAUDE.md` — OMA 전체 철학
