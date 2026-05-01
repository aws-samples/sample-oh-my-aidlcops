---
title: Project Information — <slug>
slug: <slug>
created: YYYY-MM-DD
last_update:
  date: YYYY-MM-DD
  author: TBD
tags:
  - aidlc
  - inception
  - intake
  - scope:nav
---

## 1. 배경 (Background)

현재 시스템·업무 프로세스의 상태를 사실 기반 단정형으로 기술합니다. 측정된 지표(응답 지연, 에러율, 비용, 사용자 만족도)를 포함합니다.

- 현재 상태:
- 관측된 문제:
- 문제의 영향 범위(사용자 수, 매출, SLO 위반 빈도):

## 2. 목표 (Objectives)

3개월·6개월·12개월 단위 성공 목표를 분리하여 기술합니다. 각 목표는 측정 가능한 지표를 포함합니다.

- Short-term (~3 months):
- Mid-term (~6 months):
- Long-term (~12 months):

## 3. 제약 (Constraints)

예산·마감·기술 스택·규제·조직 제약을 분리하여 기술합니다.

- 예산 상한:
- 마감(법적·비즈니스):
- 기술 스택(언어·런타임·클라우드):
- 규제 요구사항(ISMS-P, SOC2, GDPR, HIPAA 등):
- 조직 제약(팀 규모, 기술 역량):

## 4. 이해관계자 (Stakeholders)

의사결정자·사용자·리뷰어·운영자를 역할·이름·연락 수단으로 기술합니다.

| 역할 | 이름 | 책임 | 승인 권한 | 연락 수단 |
|------|------|------|-----------|-----------|
| 의사결정자 | | | Yes / No | |
| 사용자 대표 | | | Yes / No | |
| 설계 리뷰어 | | | Yes / No | |
| 운영 담당자 | | | Yes / No | |

## 5. 타임라인 (Timeline)

Phase 단위 마일스톤을 ISO 날짜로 기술합니다. 각 Phase는 종료 조건(exit criteria)을 포함합니다.

| Phase | 시작 | 종료 | 산출물 | 종료 조건 |
|-------|------|------|--------|-----------|
| Inception | | | requirements.md, user-stories.md, workflow-plan.md | 이해관계자 서명 |
| Construction | | | design.md, code, tests | 테스트 전수 통과 + risk-discovery PASS |
| Operations | | | runbook, dashboards | continuous-eval 24h green |

## 6. 성공 기준 (Success Criteria)

측정 가능한 KPI·SLO·비용 목표를 기술합니다. 각 기준은 측정 방법·데이터 출처를 명시합니다.

| 카테고리 | 지표 | 목표 값 | 측정 방법 | 데이터 출처 |
|----------|------|---------|-----------|-------------|
| 성능 | p95 응답 지연 | < X초 | 1분 단위 집계 | Prometheus / Langfuse |
| 품질 | faithfulness | ≥ X.XX | 주간 Ragas 평가 | continuous-eval |
| 비용 | 월간 인프라 비용 | < $X | 월말 청구서 | AWS Cost Explorer |
| 안전 | PII leakage | 0건 | 자동 스캔 | Guardrails |

## 금지 표현 체크리스트

다음 표현이 발견되면 구체 수치·이름으로 재작성합니다.

- [ ] "빠르게", "쉽게", "편리하게", "가능하면", "적절히"
- [ ] 수치 없는 "개선한다"
- [ ] 역할 없이 이름만 나열된 이해관계자
- [ ] ISO 형식이 아닌 날짜("다음 분기쯤")
