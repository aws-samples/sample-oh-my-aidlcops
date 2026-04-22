# aidlc-construction — AIDLC Phase 2 Plugin

`aidlc-construction`은 oh-my-aidlcops(OMA) 마켓플레이스의 **BUILD** 플러그인입니다. AIDLC 3-phase lifecycle(Inception → **Construction** → Operations) 중 [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows)의 Construction 단계를 agentic 시스템 전용 opt-in 확장으로 보강합니다.

## 철학: Design Once, Generate Safely, Test Against Non-Determinism

Construction 단계에서는 Inception이 생성한 요구사항·유저 스토리·워크플로우 계획을 실행 가능한 코드와 테스트로 변환합니다. Agentic 시스템은 비결정적 출력과 외부 LLM 의존성을 갖기 때문에 일반 SaaS의 Construction과 구분되는 세 가지 규율이 필요합니다.

- **Design**: 컴포넌트 경계·인터페이스 계약·데이터 모델을 먼저 문서화하고 검토합니다. 코드 생성 전에 설계 리뷰를 통과해야 합니다.
- **Generate**: Agent가 스캐폴딩·템플릿 기반 코드 생성을 수행하되 모든 변경은 사람 승인 gate를 통과한 뒤에야 main에 머지됩니다.
- **Test**: LLM 호출을 unit test에서 차단(mock)하고, golden dataset 기반 eval suite와 property-based test로 비결정성을 제어합니다.

## 3 Skills — 구성과 상호작용

본 플러그인은 Construction 단계를 3개 skill로 분할합니다. 순서는 다음과 같습니다.

| Skill | 역할 | 모델 | 선행 조건 |
|-------|------|------|----------|
| [`component-design`](./skills/component-design/SKILL.md) | 컴포넌트 경계·인터페이스·데이터 모델 설계, `design.md` 산출 | `claude-opus-4-7` | Inception artifacts (requirements, user-stories, workflow-plan) |
| [`code-generation`](./skills/code-generation/SKILL.md) | 스캐폴딩·템플릿 기반 코드 생성, 사람 승인 gate | `claude-sonnet-4-6` | `design.md` 승인 완료 |
| [`test-strategy`](./skills/test-strategy/SKILL.md) | Agentic TDD — LLM mock, golden eval, property-based test | `claude-opus-4-7` | `design.md` 승인 완료, 테스트 프레임워크 설치 |

실행 시퀀스:

```
component-design  →  code-generation  →  test-strategy
     (설계)             (구현)              (검증)
```

`test-strategy`는 `code-generation`과 병렬로 수행 가능하지만, TDD 원칙에 따라 **테스트를 먼저 작성**한 뒤 구현을 진행하는 경로를 권장합니다. 즉 `component-design → test-strategy → code-generation` 순서도 허용됩니다.

## Skill 조합 원칙

- `component-design`은 반드시 `.omao/plans/construction/design.md`를 생성합니다. 후속 skill은 이 파일을 단일 진실원(single source of truth)으로 참조합니다.
- `code-generation`은 `design.md`의 인터페이스 계약을 위반하는 코드를 생성하지 않습니다. 위반 탐지 시 즉시 중단하고 설계 수정을 요청합니다.
- `test-strategy`의 golden dataset은 Inception 단계의 user-stories.md에 있는 수락 기준(acceptance criteria)을 최소 공통 분모로 포함합니다. Golden 샘플은 최소 5건 이상입니다.
- 모든 생성된 코드는 사람 승인 gate를 통과한 뒤에만 main에 머지됩니다. Auto-merge는 금지됩니다.

## Construction Phase 활성화

본 플러그인은 `aidlc-rule-details/extensions/tdd-for-agentic.opt-in.md`를 제공합니다. awslabs/aidlc-workflows의 core-workflow.md가 Construction stage의 Extensions Loading 단계에서 이 opt-in 파일을 자동으로 로드합니다. 사용자가 opt-in을 선택하면 agentic 시스템 전용 TDD 규칙이 활성화되고, 위 3개 skill이 해당 단계의 sub-phase(Design → Generate → Test) 자동화를 담당합니다.

Construction 단계는 Inception 단계가 완료된 이후에만 활성화됩니다. Inception artifact(`aidlc-docs/inception/requirements.md`, `aidlc-docs/inception/user-stories.md`, `aidlc-docs/inception/workflow-plan.md`)가 존재하지 않으면 opt-in 프롬프트는 표시되지 않습니다.

## Inception 아티팩트 의존성

본 플러그인은 `aidlc-inception` 플러그인이 생성한 다음 파일을 입력으로 요구합니다. 하나라도 누락되면 `component-design` skill은 실행을 거부합니다.

| 경로 | 제공자 | 본 플러그인의 소비 방식 |
|------|--------|-----------------------|
| `aidlc-docs/inception/requirements.md` | aidlc-inception | 컴포넌트 경계 도출 시 참조 |
| `aidlc-docs/inception/user-stories.md` | aidlc-inception | Golden dataset 수락 기준 추출 |
| `aidlc-docs/inception/workflow-plan.md` | aidlc-inception | 컴포넌트 간 호출 순서 반영 |

## Agentic 시스템 전용 Construction 규칙

일반 SaaS Construction과 구분되는 본 플러그인의 추가 규칙:

1. **LLM 호출 격리** — Unit test는 실제 LLM을 호출하지 않습니다. `anthropic.Anthropic` / `openai.OpenAI` 클라이언트는 반드시 mock 또는 VCR-style cassette로 대체합니다.
2. **Eval suite 필수** — `tests/eval/` 디렉토리에 golden dataset 최소 5건과 자동 평가 스크립트가 존재해야 합니다.
3. **비결정성 제어** — 출력이 LLM의 자유 서술인 경우 property-based test(`hypothesis` 라이브러리 등)로 불변식(invariant)을 검증합니다.
4. **롤백 경로** — 코드 생성 직전 현재 main의 해당 파일을 `.omao/plans/construction/rollback/`에 보관합니다. Eval regression 발생 시 즉시 복원합니다.

## MCP 의존성

본 플러그인의 skill들은 AWS hosted MCP 서버를 런타임 데이터 레이어로 사용합니다. 커스텀 MCP는 구현하지 않습니다.

- `awslabs.aws-documentation-mcp-server@latest` — Boto3/AWS SDK 사용법 조회
- `awslabs.eks-mcp-server@latest` — 컴포넌트가 EKS에 배포될 경우 리소스 프로비저닝 참조
- `awslabs.cloudwatch-mcp-server@latest` — 테스트 실행 로그 수집

## 상태 관리

본 플러그인이 생성·참조하는 상태 파일은 OMA 표준 `.omao/` 디렉토리를 따릅니다.

- `.omao/plans/construction/design.md` — 컴포넌트 설계 산출물
- `.omao/plans/construction/code-plan.md` — 코드 생성 단계별 계획
- `.omao/plans/construction/test-plan.md` — 테스트 전략 문서
- `.omao/plans/construction/rollback/` — 코드 생성 직전 main 스냅샷
- `.omao/state/construction/` — 각 skill 실행 체크포인트
- `aidlc-docs/construction/` — Construction 단계 공식 아티팩트 (awslabs/aidlc-workflows 호환 경로)

## 참고 자료

- [OMA Marketplace](../../CLAUDE.md) — 상위 플러그인 카탈로그
- [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) — Core workflow (Construction stage 확장 대상)
- [aidlc-inception plugin](../aidlc-inception/CLAUDE.md) — 본 플러그인의 입력 아티팩트 제공자
- [agenticops plugin](../agenticops/CLAUDE.md) — Construction 완료 후 Operations 자동화 연계
- [pytest documentation](https://docs.pytest.org/) — 단위·통합 테스트 프레임워크
- [hypothesis documentation](https://hypothesis.readthedocs.io/) — Property-based testing 라이브러리
