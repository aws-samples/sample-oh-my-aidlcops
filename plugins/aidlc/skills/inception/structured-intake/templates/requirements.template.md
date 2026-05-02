---
title: Requirements — <slug>
slug: <slug>
created: YYYY-MM-DD
last_update:
  date: YYYY-MM-DD
  author: TBD
tags:
  - aidlc
  - inception
  - requirements
  - scope:design
---

## 문서 목적

본 문서는 `project-info.md`에서 수집된 배경·목표·제약을 입력으로 받아 REQ-ID 형식의 요구사항 초안을 제공합니다. 후속 `requirements-analysis` skill이 각 REQ를 정제하고 수락 기준(Acceptance Criteria)을 강화합니다.

## Functional Requirements

| REQ-ID | 설명 | 우선순위 (P0/P1/P2) | 의존성 | 수락 기준 초안 |
|--------|------|---------------------|--------|----------------|
| REQ-001 | | P0 | - | |
| REQ-002 | | P1 | REQ-001 | |
| REQ-003 | | P2 | - | |

## Non-Functional Requirements

| REQ-ID | 카테고리 | 설명 | 목표 값 | 측정 방법 |
|--------|----------|------|---------|-----------|
| REQ-NF-001 | 성능 | p95 응답 지연 | < X초 | Prometheus |
| REQ-NF-002 | 비용 | 1K 요청당 비용 | < $X | 월말 청구 로그 |
| REQ-NF-003 | 보안 | PII leakage | 0건 | Guardrails 스캔 |
| REQ-NF-004 | 관측성 | trace coverage | 100% | Langfuse |
| REQ-NF-005 | 규제 | 로그 보존 | ≥ X일 | 보존 정책 설정 |

## Traceability (후속 skill이 채움)

| REQ-ID | User Story | Workflow Step | Component | Test Case |
|--------|-----------|---------------|-----------|-----------|
| REQ-001 | TBD | TBD | TBD | TBD |

## 작성 원칙

- 각 REQ는 **검증 가능한** 수락 기준 1개 이상 포함.
- 주관적 표현("빠르게", "쉽게") 금지. 수치·조건으로 치환.
- Functional과 Non-Functional을 절대 혼재시키지 않음.
- P0(필수)·P1(중요)·P2(선택) 우선순위는 이해관계자 합의 후 확정.
- 의존성(Dependencies) 컬럼에 다른 REQ-ID를 기재하여 순서 제약을 명시.

## 서명 (Sign-off)

| 역할 | 이름 | 일시 | 서명 |
|------|------|------|------|
| 의사결정자 | | | |
| 설계 리뷰어 | | | |
| 운영 담당자 | | | |
