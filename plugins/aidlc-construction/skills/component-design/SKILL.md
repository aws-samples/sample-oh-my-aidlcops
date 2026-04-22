---
name: component-design
description: Inception 아티팩트(requirements, user-stories, workflow-plan)를 입력으로 받아 agentic 시스템의 컴포넌트 경계·인터페이스 계약·데이터 모델을 설계하고 `.omao/plans/construction/design.md`를 생성한다. Agent·Tool·Memory·Gateway 경계를 명확히 나누고 후속 code-generation·test-strategy skill의 단일 진실원 역할을 한다.
argument-hint: "[feature or unit name]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Grep,Glob,Bash"
license: Apache-2.0
---

## 언제 사용하나요

다음 상황에서 본 skill을 실행합니다.

- AIDLC Construction 단계 진입 직후 신규 feature·unit의 컴포넌트 설계가 필요할 때
- Inception이 생성한 requirements·user-stories가 모두 승인 완료된 상태에서 구현 진입을 준비할 때
- 기존 컴포넌트의 인터페이스 변경·데이터 모델 진화(schema migration)가 필요할 때
- Agent·Tool·Memory·Gateway 경계가 모호하여 팀 간 합의가 필요할 때

다음 상황에서는 사용하지 않습니다.

- Inception 아티팩트(requirements·user-stories·workflow-plan)가 아직 확정되지 않은 상태 — 먼저 `aidlc-inception` skill들로 상위 단계를 완료해야 합니다.
- 단순 버그 픽스·리팩토링 — 설계 문서 갱신이 필요 없는 변경은 `code-generation` skill로 직접 진행합니다.

## 전제 조건

- `aidlc-docs/inception/requirements.md` 존재 및 Inception stage가 `Completed` 상태.
- `aidlc-docs/inception/user-stories.md` 존재, 각 스토리에 수락 기준(acceptance criteria) 포함.
- `aidlc-docs/inception/workflow-plan.md` 존재, 컴포넌트 간 호출 순서와 데이터 흐름 기술.
- `.omao/plans/construction/` 디렉토리 쓰기 권한.
- 팀 내 최소 1명의 설계 리뷰어 지정(승인 gate 담당자).

## 실행 절차

### Step 1: Inception 아티팩트 로딩 및 범위 확정

Inception 산출물을 읽고 본 설계 세션의 범위를 확정합니다.

```bash
FEATURE="$1"  # 예: rag-qa-agent
test -f aidlc-docs/inception/requirements.md || { echo "missing requirements"; exit 1; }
test -f aidlc-docs/inception/user-stories.md || { echo "missing user-stories"; exit 1; }
test -f aidlc-docs/inception/workflow-plan.md || { echo "missing workflow-plan"; exit 1; }
mkdir -p .omao/plans/construction
```

범위 확정 항목: 대상 feature 이름, 포함 user stories 목록, 제외 항목(out-of-scope), 외부 시스템 경계.

### Step 2: 컴포넌트 경계 식별

Agentic 시스템의 4가지 표준 역할 축에 따라 컴포넌트를 분류합니다.

- **Agent** — LLM 호출과 결정 논리를 담당하는 컴포넌트
- **Tool** — Agent가 호출하는 결정적(deterministic) 함수 또는 외부 API 클라이언트
- **Memory** — 대화 이력·벡터 저장소·KV 캐시 등 상태 보관소
- **Gateway** — 라우팅·rate limit·guardrail을 수행하는 입출력 경계

각 컴포넌트의 책임·입력·출력·에러 경로를 표로 정리합니다.

### Step 3: 인터페이스 계약 작성

컴포넌트 간 호출은 타입 서명·에러 모델·멱등성(idempotency) 정책을 포함한 계약으로 명세합니다. Python의 경우 `Protocol` 또는 `dataclass`, TypeScript의 경우 `interface`를 사용합니다.

```python
from typing import Protocol, Sequence
from dataclasses import dataclass

@dataclass(frozen=True)
class RetrievalResult:
    doc_id: str
    score: float
    content: str

class RetrievalTool(Protocol):
    def search(self, query: str, top_k: int) -> Sequence[RetrievalResult]: ...
```

모든 인터페이스는 다음 4가지를 명시합니다: 입력 타입, 출력 타입, 예외 타입, 멱등성 여부.

### Step 4: 데이터 모델 정의

영속 데이터는 별도 섹션으로 스키마를 정의합니다. 벡터 DB·RDB·오브젝트 스토리지·캐시를 분리하여 기술합니다.

| 저장소 종류 | 기술 스택 권장 | 스키마 필수 항목 |
|------------|----------------|------------------|
| 벡터 DB | Milvus, pgvector | collection 이름, dimension, metric, partition 키 |
| RDB | PostgreSQL | 테이블명, PK, FK, 인덱스, 제약조건 |
| 오브젝트 스토리지 | S3 | bucket, prefix, 객체 lifecycle |
| 캐시 | Redis, ElastiCache | key 패턴, TTL, eviction 정책 |

### Step 5: `design.md` 산출물 작성

다음 섹션 순서로 `.omao/plans/construction/design.md`를 작성합니다.

1. Overview — 해결할 문제, 범위, 대상 사용자
2. Architecture Diagram — Mermaid sequenceDiagram 또는 flowchart
3. Components — Step 2의 경계 표
4. Interfaces — Step 3의 타입 계약 코드 블록
5. Data Model — Step 4의 저장소 스키마
6. Non-Functional Requirements — latency SLO, 비용 상한, 보안 요구사항
7. Risks and Mitigations — 비결정성·LLM 장애·데이터 노출 3대 리스크
8. Review Checklist — 설계 리뷰어가 승인 전에 확인할 체크리스트

### Step 6: 설계 리뷰 요청 및 승인 대기

`design.md` 작성 완료 후 리뷰어에게 검토를 요청합니다. 승인 방식은 PR 코멘트 또는 `aidlc-docs/audit.md` 기록입니다.

```bash
echo "[$(date -Iseconds)] design.md submitted for review" >> aidlc-docs/audit.md
```

리뷰어가 승인 전까지 `code-generation`·`test-strategy` skill 실행을 차단합니다.

## Good Example vs Bad Example

**Good** — 인터페이스가 타입·예외·멱등성을 모두 명시합니다.

```python
class LangfuseTracer(Protocol):
    def log_trace(self, trace_id: str, payload: dict) -> None:
        """멱등: 동일 trace_id 재호출 시 첫 호출만 저장. 네트워크 실패 시 LangfuseUnavailable 발생."""
```

**Bad** — 계약이 느슨하여 구현자가 자유 해석합니다.

```python
def log_trace(payload):
    # 어떤 타입? 실패 시 동작? 재호출 허용?
    ...
```

**Good** — Agent와 Tool 경계가 분리되어 있어 Tool만 독립적으로 unit test 가능합니다.

**Bad** — LLM 호출과 DB 조회가 한 함수에 혼재되어 mock 지점이 불분명합니다.

## 산출물 체크리스트

본 skill 실행 종료 직전 다음을 자동 검증합니다.

- [ ] `.omao/plans/construction/design.md` 존재
- [ ] 8개 섹션(Overview ~ Review Checklist) 모두 채워짐
- [ ] Mermaid 다이어그램 렌더링 가능
- [ ] 모든 인터페이스에 타입·예외·멱등성 명시
- [ ] 리뷰 요청이 `aidlc-docs/audit.md`에 기록됨

## 참고 자료

### 공식 문서

- [awslabs/aidlc-workflows — Construction stage](https://github.com/awslabs/aidlc-workflows/tree/main/aidlc-rules/aws-aidlc-rule-details/construction) — Construction 단계 공식 규약
- [Python typing.Protocol](https://docs.python.org/3/library/typing.html#typing.Protocol) — 구조적 서브타이핑
- [Mermaid sequenceDiagram](https://mermaid.js.org/syntax/sequenceDiagram.html) — 다이어그램 문법

### 관련 문서 (내부)

- [aidlc-inception plugin](../../../aidlc-inception/CLAUDE.md) — 입력 아티팩트 제공자
- [code-generation skill](../code-generation/SKILL.md) — 본 skill의 후속 실행자
- [test-strategy skill](../test-strategy/SKILL.md) — 본 skill의 병렬 소비자
