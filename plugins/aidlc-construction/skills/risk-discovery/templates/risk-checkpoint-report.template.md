---
title: Risk Checkpoint Report — <slug>
slug: <slug>
created: YYYY-MM-DD
last_update:
  date: YYYY-MM-DD
  author: TBD
tags:
  - aidlc
  - construction
  - risk
  - scope:ops
---

## 실행 메타데이터

| 항목 | 값 |
|------|----|
| 대상 slug | |
| 입력 문서 | `.omao/plans/<slug>/project-info.md`, `requirements.md`, `.omao/plans/construction/design.md` |
| 실행 시각 (ISO 8601) | |
| 실행자 | |
| 총 카테고리 수 | 12 |
| PASS / WARN / BLOCK | X / Y / Z |

## 카테고리별 판정

각 카테고리는 PASS / WARN / BLOCK 중 하나의 판정을 받습니다. BLOCK 1건 이상 시 Construction 진입 차단.

### 1. 비즈니스 연속성 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 2. 보안 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 3. 외부 통합 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 4. 데이터 일관성 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 5. 비용 함정 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 6. 성능 회귀 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 7. 규제·컴플라이언스 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 8. 가용성·SLA — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 9. 장애 전파 반경 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 10. 운영 복잡도 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 11. 의존성 취약점 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

### 12. 롤백 가능성 — [PASS / WARN / BLOCK]

- 증거 인용:
- 위험 설명:
- 권장 조치:

## 종합 판정

| 판정 | 카테고리 수 | 카테고리 목록 |
|------|------------|---------------|
| PASS | | |
| WARN | | |
| BLOCK | | |

## 다음 phase 진입 조건

- BLOCK = 0 → Construction 진입 가능
- BLOCK ≥ 1 → `quality-gates` skill이 `.omao/state/gates/construction.json`을 `blocked` 상태로 기록, 진입 차단
- WARN ≥ 3 → 설계 리뷰어 2차 승인 필요
