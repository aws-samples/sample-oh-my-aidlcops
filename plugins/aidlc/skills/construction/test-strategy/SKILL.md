---
name: test-strategy
description: Agentic 시스템을 위한 TDD 전략을 수립한다. LLM 클라이언트 mock(VCR-style), golden dataset 기반 eval(최소 5건), hypothesis 기반 property-based test로 비결정성을 제어한다. `.omao/plans/construction/test-plan.md`를 산출하며 code-generation과 병렬 실행 가능하다.
argument-hint: "[component or unit name]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Write,Edit,Grep,Glob,Bash"
---

## 언제 사용하나요

다음 상황에서 본 skill을 실행합니다.

- `component-design` 승인 직후 TDD 기반으로 테스트를 먼저 작성하는 단계
- `code-generation`이 구현을 완료한 뒤 회귀 테스트·eval suite를 강화하는 단계
- 프로덕션 regression이 관측되어 재현 테스트(regression test)를 추가해야 할 때
- Golden dataset 갱신이 필요하거나 property-based invariant를 추가 정의할 때

다음 상황에서는 사용하지 않습니다.

- 실제 LLM 호출을 수행하는 E2E 스모크 테스트 — 본 skill의 대상은 mock·local·property-based·eval 4가지 계층이며, 실물 호출은 별도 CI job에 위임합니다.
- UI·시각 회귀 테스트 — Playwright·Storybook 영역은 본 skill 범위 외입니다.

## 전제 조건

- `.omao/plans/construction/design.md` 존재 및 승인 완료.
- Python의 경우 `pytest`, `pytest-anyio`, `hypothesis` 최신 안정 버전 설치.
- LLM mock 라이브러리 — `anthropic`/`openai` SDK의 mock 기능 또는 `vcrpy` 카세트 레코딩 준비.
- `.omao/plans/construction/test-plan.md` 쓰기 권한.
- Golden dataset 작성을 위한 도메인 샘플 최소 5건 수집 가능.

## 실행 절차

### Step 1: 테스트 계층 매핑

Agentic 시스템은 4개 계층으로 테스트를 분리합니다.

| 계층 | 대상 | 도구 | LLM 호출 |
|------|------|------|---------|
| Unit | Tool·Memory·Gateway의 결정적 함수 | pytest | 금지(mock 필수) |
| Contract | 인터페이스 서명·예외 계약 | pytest + typing | 금지 |
| Property | 비결정적 출력의 불변식 | hypothesis | 제한적 허용(mock 권장) |
| Eval | Golden dataset 기반 품질 측정 | pytest + ragas 또는 custom | 허용(오프라인 cassette) |

### Step 2: LLM Mock 전략 선택

세 가지 방식 중 하나를 선택합니다.

- **Stub** — `unittest.mock.MagicMock`으로 응답 고정. 가장 빠르며 CI 부담 없음.
- **VCR cassette** — `vcrpy`로 실제 응답을 1회 녹화 후 반복 재생. 실제 API 스키마와 일치하는 응답 보장.
- **Local model proxy** — 소형 모델(예: Qwen3-0.5B)을 로컬에서 띄워 mock 대용. 비결정성 유지하되 비용 없음.

예시 — `anthropic.Anthropic` 클라이언트 mock:

```python
import pytest
from unittest.mock import MagicMock
from src.agents import QaAgent

@pytest.fixture
def mock_anthropic(monkeypatch):
    fake = MagicMock()
    fake.messages.create.return_value = MagicMock(
        content=[MagicMock(text="mocked answer")],
    )
    monkeypatch.setattr("src.agents.Anthropic", lambda *a, **kw: fake)
    return fake

def test_qa_agent_returns_mocked_answer(mock_anthropic):
    agent = QaAgent()
    assert agent.answer("hi") == "mocked answer"
```

### Step 3: Golden Dataset 작성 (최소 5건)

`tests/eval/golden/${component}.jsonl`에 최소 5건의 샘플을 작성합니다. 각 샘플은 다음 필드를 포함합니다.

```json
{
  "id": "gold-001",
  "input": "What is vLLM?",
  "expected_contains": ["PagedAttention", "KV cache"],
  "expected_excludes": ["internal_ip", "api_key"],
  "max_tokens": 256,
  "acceptance_criteria_ref": "US-042"
}
```

필드 설명:

- `expected_contains` — 반드시 포함되어야 할 키워드 리스트
- `expected_excludes` — 출력에 나타나서는 안 될 토큰(PII, 내부 주소)
- `acceptance_criteria_ref` — Inception 단계 user-stories.md의 수락 기준 ID

샘플 작성은 도메인 전문가가 검토합니다. 5건은 최소 임계이며 production agent는 100건 이상을 권장합니다.

### Step 4: Property-Based Test 정의

LLM 출력의 불변식을 `hypothesis`로 검증합니다. 예: 입력 길이에 관계없이 출력이 `max_tokens` 이내, 출력에 PII 패턴이 포함되지 않음.

```python
from hypothesis import given, strategies as st
from src.agents import SummaryAgent

@given(st.text(min_size=10, max_size=2000))
def test_summary_never_contains_email(input_text):
    agent = SummaryAgent(llm=MockedLLM())
    result = agent.summarize(input_text)
    assert "@" not in result, "summary leaked email-like token"
```

불변식 카테고리(최소 3개 권장):

1. **길이 제약** — 출력 토큰 수가 설정한 상한 이내
2. **금지 토큰 부재** — PII·비밀·내부 식별자가 출력에 없음
3. **스키마 일치** — JSON 출력 시 지정한 schema를 항상 만족

### Step 5: Eval Suite 자동화

`tests/eval/run.py`를 작성하여 golden dataset을 순회하며 평가합니다.

```python
import json, pathlib, sys

def evaluate(component: str) -> dict:
    passes, fails = 0, []
    golden = pathlib.Path(f"tests/eval/golden/{component}.jsonl").read_text().splitlines()
    for line in golden:
        case = json.loads(line)
        output = call_component_with_mock(case["input"])
        ok = all(k in output for k in case["expected_contains"]) and not any(k in output for k in case["expected_excludes"])
        if ok:
            passes += 1
        else:
            fails.append({"id": case["id"], "output": output})
    return {"total": passes + len(fails), "pass": passes, "fails": fails}

if __name__ == "__main__":
    result = evaluate(sys.argv[1])
    json.dump(result, sys.stdout, indent=2)
    sys.exit(0 if not result["fails"] else 1)
```

CI에서 `python tests/eval/run.py ${component}` 를 호출하고 실패 시 빌드를 차단합니다.

### Step 6: Rollback 경로 정의

Eval regression 발생 시 복원 절차를 `test-plan.md`에 명시합니다.

1. `.omao/plans/construction/rollback/${STAMP}/` 에서 마지막 통과 커밋의 파일을 복원
2. `git checkout main -- ${affected_path}` 로 main 상태로 되돌림
3. Eval 재실행으로 baseline 복귀 확인
4. `aidlc-docs/audit.md`에 rollback 사유와 타임스탬프 기록

### Step 7: test-plan.md 산출

`.omao/plans/construction/test-plan.md`를 다음 구조로 작성합니다.

1. Scope — 대상 컴포넌트, 테스트 계층별 책임
2. Mock Strategy — 선택한 방식(Stub / VCR / Local proxy) 및 근거
3. Golden Dataset — 샘플 수, 수용 기준 매핑
4. Property Invariants — 3개 이상의 불변식 정의
5. Eval Thresholds — 통과 기준(예: pass rate ≥ 90%)
6. Rollback Plan — 회귀 발생 시 복원 절차
7. CI Integration — 어떤 job에서 어떤 레벨이 실행되는지

## Good Example vs Bad Example

**Good** — Unit test는 LLM을 호출하지 않고 mock으로 고정됩니다.

```python
def test_tool_unit(mock_anthropic):
    assert RetrievalTool().search("x", 3)[0].score > 0
```

**Bad** — Unit test가 실제 API를 호출하여 비결정적이고 비용이 발생합니다.

```python
def test_agent():
    agent = Agent(api_key=os.environ["ANTHROPIC_API_KEY"])
    assert "answer" in agent.ask("hi")  # 실제 호출
```

**Good** — Golden dataset 5건이 모두 user-story 수락 기준 ID와 연결되어 있습니다.

**Bad** — Golden dataset이 3건이고 출처가 불명확합니다.

**Good** — Property-based test가 출력 길이·금지 토큰·스키마 3축을 검증합니다.

**Bad** — 결정적 예제 한 건만 assert로 검증하여 edge case를 놓칩니다.

## 산출물 체크리스트

본 skill 실행 종료 직전 다음을 자동 검증합니다.

- [ ] `.omao/plans/construction/test-plan.md` 존재
- [ ] `tests/eval/golden/${component}.jsonl` 최소 5건
- [ ] Unit test가 실제 LLM 호출 없이 통과(`grep -r "anthropic.Anthropic()" tests/unit/`가 비어 있음)
- [ ] Property-based test 최소 3개 invariant 정의
- [ ] `tests/eval/run.py` 또는 동등한 entry point 실행 가능
- [ ] Rollback plan이 test-plan.md에 명시됨

## 참고 자료

### 공식 문서

- [pytest Documentation](https://docs.pytest.org/) — 테스트 러너 공식 문서
- [hypothesis Documentation](https://hypothesis.readthedocs.io/) — Property-based testing
- [vcrpy Documentation](https://vcrpy.readthedocs.io/) — HTTP cassette 라이브러리
- [Anthropic Python SDK — testing](https://github.com/anthropics/anthropic-sdk-python) — SDK mock 레퍼런스

### 기술 블로그

- [Property-based testing for ML (Hypothesis)](https://hypothesis.works/articles/property-based-testing-for-ml/) — 비결정성 제어 패턴
- [Ragas — Metrics overview](https://docs.ragas.io/en/stable/concepts/metrics/overview.html) — Eval 지표 설계

### 관련 문서 (내부)

- [component-design skill](../component-design/SKILL.md) — 본 skill의 입력(design.md) 제공자
- [code-generation skill](../code-generation/SKILL.md) — 본 skill의 병렬 구현자
- [tdd-for-agentic opt-in](../../aidlc-rule-details/extensions/tdd-for-agentic.opt-in.md) — Construction 테스트 규칙
