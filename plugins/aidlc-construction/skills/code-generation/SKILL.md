---
name: code-generation
description: 승인된 design.md를 기반으로 스캐폴딩·인터페이스·데이터 모델·구현 코드를 단계별로 생성하고 모든 변경을 사람 승인 gate에 제출한다. 템플릿 기반 생성·롤백 스냅샷·계약 위반 감지로 안전성을 확보하며 auto-merge는 금지된다.
argument-hint: "[unit or component name]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Grep,Glob,Bash"
license: Apache-2.0
---

## 언제 사용하나요

다음 상황에서 본 skill을 실행합니다.

- `component-design` skill이 생성한 `design.md`가 리뷰어 승인을 받은 직후
- 기존 컴포넌트에 새 기능을 추가하는 코드 생성이 필요할 때 (설계 변경분은 `component-design`으로 재작성)
- `test-strategy` skill이 먼저 작성한 실패 테스트를 통과시키는 구현 단계(TDD 흐름)

다음 상황에서는 사용하지 않습니다.

- `design.md`가 아직 승인되지 않은 상태 — 승인 전 코드 생성은 계약 위반을 유발합니다.
- 프로덕션 핫픽스 — 설계 문서 갱신 없이 긴급 수정이 필요한 경우 팀 규약에 따라 직접 패치 후 사후 문서화합니다.
- 대규모 리팩토링(컴포넌트 경계 변경) — 먼저 `component-design`으로 설계 재작성이 필요합니다.

## 전제 조건

- `.omao/plans/construction/design.md` 존재 및 리뷰어 승인 기록(`aidlc-docs/audit.md`) 완료.
- 대상 코드 베이스의 주 언어 런타임 설치(Python 3.11+ 또는 Node.js 20+ 등).
- 린터·포매터 설정 파일 존재(`pyproject.toml`, `ruff.toml`, `.eslintrc` 등).
- Git 저장소 clean 상태 — uncommitted 변경이 있으면 실행 거부.
- `.omao/plans/construction/rollback/` 디렉토리 쓰기 권한.

## 실행 절차

### Step 1: design.md 계약 파싱

`design.md`의 Interfaces 섹션에서 타입 서명과 예외 계약을 추출하여 체크리스트로 변환합니다.

```bash
DESIGN=.omao/plans/construction/design.md
test -f "$DESIGN" || { echo "design.md missing"; exit 1; }
grep -qE "^## Interfaces" "$DESIGN" || { echo "Interfaces section missing"; exit 1; }
```

각 인터페이스에 대해 다음을 태스크 리스트로 기록합니다: 서명, 예외, 멱등성, 호출자, 호출 대상.

### Step 2: 코드 생성 계획 작성

`.omao/plans/construction/code-plan.md`를 작성합니다. 다음 단계로 분할합니다.

1. Project Structure Setup — 디렉토리·패키지·의존성 추가
2. Interface Stubs — Protocol·interface 파일 생성 (구현 없음)
3. Data Model — Pydantic·SQLAlchemy·Prisma 스키마
4. Tool Implementations — 결정적 컴포넌트 먼저 구현
5. Agent Implementation — LLM 호출 포함 컴포넌트 구현
6. Gateway Integration — 라우팅·guardrail 연결
7. Documentation — README·docstring·OpenAPI

각 단계는 별도 커밋으로 분리하여 리뷰 단위를 작게 유지합니다.

### Step 3: 롤백 스냅샷 생성

코드 수정 대상 파일을 현재 상태 그대로 `.omao/plans/construction/rollback/`에 보관합니다.

```bash
STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p ".omao/plans/construction/rollback/${STAMP}"
git diff --name-only main -- . | xargs -I{} sh -c 'mkdir -p ".omao/plans/construction/rollback/${STAMP}/$(dirname {})" && cp {} ".omao/plans/construction/rollback/${STAMP}/{}"'
```

롤백 경로는 eval regression 또는 리뷰 반려 시 즉시 복원에 사용합니다.

### Step 4: 스캐폴딩 및 템플릿 기반 생성

정형화된 코드(Pydantic 모델, API 핸들러 뼈대, 테스트 스텁)는 템플릿으로 생성합니다. 자유 서술이 필요한 로직(프롬프트 구성, 복잡한 제어 흐름)은 설계 문서 근거를 명시적으로 참조하여 작성합니다.

템플릿 예시 — Tool 구현 스텁:

```python
# src/tools/retrieval.py
from typing import Sequence
from src.contracts import RetrievalTool, RetrievalResult

class MilvusRetrievalTool(RetrievalTool):
    def __init__(self, collection: str) -> None:
        self._collection = collection

    def search(self, query: str, top_k: int) -> Sequence[RetrievalResult]:
        raise NotImplementedError("implement in Step 4.2")
```

### Step 5: 계약 위반 자동 검증

생성 완료 후 다음 정적 검증을 수행합니다. 하나라도 실패하면 해당 커밋을 되돌립니다.

- 타입 검사 — `mypy --strict` 또는 `tsc --noEmit`
- 린트 — `ruff check` 또는 `eslint`
- 포맷 — `ruff format --check` 또는 `prettier --check`
- 인터페이스 일치 — design.md의 Protocol 서명과 실제 구현 서명 diff 없음

```bash
ruff check . && ruff format --check . && mypy --strict src/
```

### Step 6: 사람 승인 gate 제출

변경 사항을 feature branch에 커밋하고 PR을 Draft로 생성합니다. **main에 직접 푸시하거나 auto-merge를 설정하지 않습니다.**

```bash
BRANCH="construction/${UNIT}-$(date +%Y%m%d-%H%M)"
git checkout -b "$BRANCH"
git add .
git commit -m "feat(${UNIT}): scaffold interfaces and data model per design.md"
gh pr create --draft \
  --title "feat(${UNIT}): Construction implementation" \
  --body "Implements design.md §2 §3. Rollback at .omao/plans/construction/rollback/${STAMP}/"
```

리뷰어 승인 없이 머지되지 않도록 repository의 branch protection 설정을 사용합니다.

### Step 7: Eval 연동 준비

`test-strategy` skill이 eval suite를 실행할 수 있도록 entry point를 노출합니다. `tests/eval/run.py` 또는 Makefile target(`make eval`)이 존재해야 합니다. 존재하지 않으면 stub을 생성하고 `test-strategy` skill로 실행을 위임합니다.

## Good Example vs Bad Example

**Good** — 결정적 Tool을 먼저 구현하여 독립 unit test가 가능합니다.

```python
class DeterministicHashTool:
    def compute(self, text: str) -> str:
        return hashlib.sha256(text.encode()).hexdigest()
```

**Bad** — LLM 호출이 Tool 내부에 숨겨져 mock 지점이 불명확합니다.

```python
class SummaryTool:
    def run(self, text: str) -> str:
        return anthropic.Anthropic().messages.create(...)  # LLM 호출 직접 매립
```

**Good** — PR이 Draft 상태이고 설계 근거가 본문에 명시되어 있습니다.

**Bad** — main에 직접 푸시했으며 설계 문서 링크가 없습니다.

## 산출물 체크리스트

본 skill 실행 종료 직전 다음을 자동 검증합니다.

- [ ] `.omao/plans/construction/code-plan.md` 존재
- [ ] `.omao/plans/construction/rollback/${STAMP}/` 스냅샷 생성
- [ ] 타입 검사·린트·포맷 통과
- [ ] design.md Interfaces와 구현 서명 일치
- [ ] PR이 Draft 상태로 생성, main 직접 푸시 없음
- [ ] `aidlc-docs/audit.md`에 제출 기록

## 참고 자료

### 공식 문서

- [awslabs/aidlc-workflows — code-generation.md](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rule-details/construction/code-generation.md) — Construction code generation 규약
- [pytest Documentation](https://docs.pytest.org/) — 테스트 프레임워크
- [ruff Documentation](https://docs.astral.sh/ruff/) — Python 린터·포매터
- [GitHub CLI gh pr create](https://cli.github.com/manual/gh_pr_create) — Draft PR 생성

### 관련 문서 (내부)

- [component-design skill](../component-design/SKILL.md) — 본 skill의 선행 실행자
- [test-strategy skill](../test-strategy/SKILL.md) — 본 skill의 병렬 검증자
- [tdd-for-agentic opt-in](../../aidlc-rule-details/extensions/tdd-for-agentic.opt-in.md) — Construction 테스트 규칙
