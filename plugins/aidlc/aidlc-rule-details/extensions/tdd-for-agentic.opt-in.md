# PRIORITY: This extension activates MANDATORY checks for agentic-system Construction

**Extension**: AIDLC Construction — TDD for Agentic Systems (aidlc-construction)

## Opt-In Prompt

다음 질문은 이 확장이 로드되었을 때 Construction stage의 Extensions Loading 단계에 자동으로 포함됩니다.

```markdown
## Question: TDD for Agentic Systems
Should the Construction phase activate TDD-for-agentic rules (LLM mock enforcement, golden dataset, property-based tests)?

A) Yes — activate component-design, code-generation, and test-strategy skills with mandatory mock/golden/property rules (recommended for any agent invoking Anthropic/OpenAI/Bedrock in production)
B) No — use the default Construction flow without agentic-specific test rules (suitable for non-LLM SaaS projects)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```

---

## When to Load

본 확장은 다음 조건을 **모두** 만족할 때에만 Construction stage에서 활성화됩니다.

1. **Inception 완료 확인** — `aidlc-docs/inception/requirements.md`, `aidlc-docs/inception/user-stories.md`, `aidlc-docs/inception/workflow-plan.md` 존재 및 Inception stage가 `Completed` 상태.
2. **LLM 의존성 확인** — `requirements.md` 또는 `workflow-plan.md`에 `anthropic`, `openai`, `bedrock`, `langfuse`, `llm`, `agent` 키워드 중 하나 이상 등장.
3. **테스트 프레임워크 가용** — 대상 프로젝트의 언어 런타임에 `pytest`(Python) 또는 `vitest`/`jest`(TypeScript)가 설치되어 있거나 추가 가능.

세 조건을 모두 만족하면 본 opt-in 프롬프트를 Construction stage의 Extensions Loading 질문 목록에 삽입합니다.

## MANDATORY: LLM Mock Enforcement

**CRITICAL**: Construction 단계에서 생성되는 모든 unit test는 실제 LLM API를 호출하지 **않습니다**. 다음 패턴 중 하나를 필수로 적용합니다.

1. **Stub mock** — `unittest.mock.MagicMock` 또는 `pytest-mock`의 `mocker.patch`로 `anthropic.Anthropic`, `openai.OpenAI`, `boto3.client('bedrock-runtime')` 객체를 교체합니다.
2. **VCR cassette** — `vcrpy`(Python) 또는 `nock`(Node.js)으로 실제 응답을 1회 녹화 후 CI에서 반복 재생합니다. 카세트 파일은 `tests/fixtures/cassettes/` 경로에 저장하고 PII 필터를 통과한 payload만 커밋합니다.
3. **Local model proxy** — Qwen3-0.5B 등 소형 로컬 모델을 `localhost`에 띄워 API 호환 응답을 발급합니다.

CI에서 다음 정적 검사를 통과해야 합니다.

```bash
! grep -rE "anthropic\.Anthropic\(\)|openai\.OpenAI\(\)|boto3\.client\('bedrock" tests/unit/ tests/contract/
```

패턴이 감지되면 `code-generation` skill은 즉시 실행을 중단하고 `FINDING-TDD-01` 로 audit 로그에 기록합니다.

## MANDATORY: Golden Dataset (Minimum 5 Examples)

모든 agent·skill 컴포넌트는 `tests/eval/golden/${component}.jsonl`에 **최소 5건**의 golden sample을 보유해야 합니다.

각 sample은 다음 필드를 포함합니다.

- `id` — 고유 식별자(`gold-NNN`)
- `input` — 사용자 입력
- `expected_contains` — 반드시 포함될 토큰 리스트
- `expected_excludes` — 포함되어서는 안 될 토큰(PII, 내부 식별자)
- `acceptance_criteria_ref` — Inception 단계 `user-stories.md`의 수락 기준 ID

5건 미만이면 `test-strategy` skill이 실행 거부하고 `FINDING-TDD-02` 로 기록합니다. Production 승격 전까지 100건 이상 확장을 권장합니다.

## MANDATORY: Property-Based Tests (Minimum 3 Invariants)

LLM 출력은 비결정적이므로 결정적 assertion만으로는 회귀를 탐지할 수 없습니다. `hypothesis`(Python) 또는 `fast-check`(TypeScript)로 다음 3가지 범주의 invariant를 **반드시** 정의합니다.

1. **길이 제약** — 출력 토큰 수가 설정된 상한(`max_tokens`)을 초과하지 않음
2. **금지 토큰 부재** — PII 패턴(이메일, 전화번호, 주민번호 포맷), 비밀(`api_key`, `secret`), 내부 식별자가 출력에 없음
3. **스키마 일치** — JSON/structured output 모드일 때 지정된 schema를 항상 만족 (`jsonschema`로 검증)

3개 중 하나라도 누락되면 `FINDING-TDD-03` 으로 기록하고 PR을 Block합니다.

## MANDATORY: Rollback Path

모든 `code-generation` 실행은 수정 직전 상태를 `.omao/plans/construction/rollback/${STAMP}/`에 스냅샷합니다. Eval regression 발생 시 다음 절차를 즉시 수행합니다.

1. 스냅샷에서 해당 파일 복원
2. `tests/eval/run.py` 재실행으로 baseline 복귀 확인
3. `aidlc-docs/audit.md`에 rollback 사유·타임스탬프·regression metric 기록

Rollback 경로가 존재하지 않으면 `FINDING-TDD-04` 로 기록하고 머지를 차단합니다.

## Blocking Findings

다음 상황은 Construction 단계를 중단시키는 blocking finding으로 처리됩니다. 각 finding은 `aidlc-docs/audit.md`에 rule ID와 함께 기록됩니다.

- **FINDING-TDD-01**: Unit test에서 실제 LLM 클라이언트 호출 코드 감지 (`anthropic.Anthropic()`, `openai.OpenAI()`, `bedrock-runtime` 등)
- **FINDING-TDD-02**: Golden dataset 파일 부재 또는 샘플 5건 미만
- **FINDING-TDD-03**: Property-based invariant 3개 미만
- **FINDING-TDD-04**: 코드 생성 시 rollback 스냅샷 누락
- **FINDING-TDD-05**: Eval suite entry point 부재 (`tests/eval/run.py` 또는 `make eval` 타겟 없음)
- **FINDING-TDD-06**: PR이 auto-merge로 설정되어 사람 승인 gate 우회 시도

각 finding은 차단 수준(blocking / warning)과 해소 기준을 함께 기록합니다.

## Integration with core-workflow.md

본 확장은 awslabs/aidlc-workflows의 `aidlc-rules/aws-aidlc-rules/core-workflow.md`가 정의한 MANDATORY Extensions Loading 규칙에 따라 로드됩니다.

1. **Discovery** — core-workflow.md의 Construction Extensions Loading 단계에서 본 `tdd-for-agentic.opt-in.md`가 스캔됩니다.
2. **Conditional Prompt** — 상단 "When to Load"의 3개 사전 조건이 모두 충족될 때에만 opt-in 프롬프트가 Construction Extensions 질문 목록에 삽입됩니다.
3. **Rule Activation** — 사용자가 A(Yes)를 선택하면 `aidlc-docs/aidlc-state.md`의 `## Extension Configuration` 섹션에 `tdd-for-agentic: enabled` 가 기록됩니다.
4. **Skill Loading** — 본 확장이 활성화되면 `aidlc-construction` 플러그인의 3개 skill(component-design, code-generation, test-strategy)이 Construction 단계 실행 환경에 자동 등록됩니다.
5. **Rule Enforcement** — 각 skill은 본 문서의 MANDATORY 섹션을 자가 검증하며, blocking finding 발생 시 실행을 중단합니다.

## Integration with aidlc-construction Skills

본 확장이 활성화되면 다음 skill이 Construction 단계 실행 환경에 등록됩니다.

- `skills/component-design/SKILL.md` — Sub-Phase 1 Design (`design.md` 산출)
- `skills/code-generation/SKILL.md` — Sub-Phase 2 Generate (스캐폴딩·구현·Draft PR)
- `skills/test-strategy/SKILL.md` — Sub-Phase 3 Test (mock·golden·property·eval)

Skill 간 상호작용:

- `component-design` 완료 → `code-generation`·`test-strategy` 동시 가능
- `test-strategy`의 eval fail → `code-generation`의 rollback 트리거
- `code-generation`의 PR draft → 사람 승인 후 `test-strategy`의 full eval 실행

## References

- [aidlc-construction plugin — CLAUDE.md](../../CLAUDE.md) — 플러그인 전체 설명
- [awslabs/aidlc-workflows — core-workflow.md](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rules/core-workflow.md) — Extensions Loading 규약
- [awslabs/aidlc-workflows — construction](https://github.com/awslabs/aidlc-workflows/tree/main/aidlc-rules/aws-aidlc-rule-details/construction) — Construction 공식 규약
- [pytest Documentation](https://docs.pytest.org/) — Test runner
- [hypothesis Documentation](https://hypothesis.readthedocs.io/) — Property-based testing
- [vcrpy Documentation](https://vcrpy.readthedocs.io/) — HTTP cassette recorder
