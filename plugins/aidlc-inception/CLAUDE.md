# aidlc-inception — AIDLC Phase 1 Opt-In Extensions

이 플러그인은 AIDLC(AI-Driven Development Lifecycle) **Phase 1 — Inception** 단계를
담당합니다. 목적은 "**무엇을(WHAT) 왜(WHY) 만드는가**"를 확정하는 것이며,
구현 상세(HOW)는 `aidlc-construction` 플러그인이 이어받습니다.

## 스코프

- 대상 단계: AIDLC Phase 1 (Inception)
- 커버리지: Workspace Detection → Requirements Analysis → User Stories → Workflow Planning
- 철학: **opt-in 확장만 기여**. 코어 워크플로우는 `awslabs/aidlc-workflows` 를 그대로 사용합니다.

## 의존성

본 플러그인은 단독으로 완결되지 않으며, `awslabs/aidlc-workflows` 리포지토리가
선행 설치되어 있어야 합니다.

```bash
bash scripts/install-aidlc.sh
```

설치 후 다음 경로 중 하나에서 `core-workflow.md` 를 찾을 수 있습니다:

- `.aidlc/aidlc-rules/aws-aidlc-rule-details/` (AI 셋업)
- `.aidlc-rule-details/` (Cursor / Claude Code)
- `.kiro/aws-aidlc-rule-details/` (Kiro IDE)
- `.amazonq/aws-aidlc-rule-details/` (Amazon Q)

OMA 의 opt-in 확장은 `aidlc-rule-details/extensions/` 에 위치하며, 설치 시
위 경로의 `extensions/` 하위에 심볼릭 링크 또는 복사본으로 배치됩니다.

## 실행 순서 (Inception Sequence)

```
1. workspace-detection
   └─ greenfield / brownfield 판별 → brownfield 이면 reverse-engineering 트리거
2. requirements-analysis
   └─ 적응형 깊이(Adaptive Depth). 단순 기능은 1문단, 복잡 기능은 REQ-ID 포맷
3. user-stories
   └─ 사용자 대면 변경에만 조건부 생성. As-a / I-want / So-that 포맷
4. workflow-planning
   └─ sequential / parallel-units / iterative 중 의사결정 트리로 선택
```

각 단계는 독립된 스킬로 제공되며, 사용자는 필요한 스킬만 선택적으로 호출할 수
있습니다(opt-in). 모든 스킬은 `user-invocable: true` 이므로 `/` 메뉴에서 직접 실행
가능합니다.

## Skills

| Skill | 모델 | 트리거 시점 |
|-------|------|------------|
| `workspace-detection` | sonnet | 신규 프로젝트 또는 기존 코드베이스 확장 판단 필요 시 |
| `requirements-analysis` | sonnet | 기능 요구사항을 Functional / Non-Functional 로 정리할 때 |
| `user-stories` | sonnet | 사용자 대면 가치가 있는 변경에 대해 스토리를 작성할 때 |
| `workflow-planning` | opus | 대규모 변경의 실행 순서와 단위(Unit) 를 설계할 때 |

스킬 본문은 한국어 경어체, 헤딩은 명사구로 통일합니다. 1인칭 표현은 금지합니다.

## Extensions (opt-in)

`aidlc-rule-details/extensions/` 하위의 opt-in 확장은 Requirements Analysis 단계에서
사용자 승인을 받은 경우에만 규칙 파일이 로드됩니다.

- `agentic-platform.opt-in.md` — Agentic AI 도메인 검증(GPU, Langfuse, Inference Gateway, Guardrails)
- `korean-docs-style.opt-in.md` — 한국어 기술 문서 스타일 가이드 강제(경어체, frontmatter, 참고 자료 섹션)

## 다음 단계 연결

Phase 1 산출물(`requirements.md`, `user-stories.md`, `workflow-plan.md`) 은
`.omao/plans/` 에 저장되며, `aidlc-construction` 플러그인이 이 산출물을 입력으로
받아 Phase 2(컴포넌트 설계 → 코드 생성 → 테스트 전략) 을 수행합니다.

## 사용 원칙

1. **opt-in 우선** — 사용자가 명시적으로 선택한 스킬/확장만 활성화합니다.
2. **아티팩트 저장 경로 고정** — `.omao/plans/<slug>/` 아래에 단계별 산출물을 저장합니다.
3. **지식 소스 단일화** — 상세 설명은 engineering-playbook 링크를 우선합니다.
4. **언어** — 산출물 본문은 한국어 경어체, 식별자(REQ-ID, Story-ID) 는 영문 대문자 + 숫자.
5. **버전 고정 참조** — awslabs/aidlc-workflows 는 `scripts/install-aidlc.sh` 가 설치한 SHA 기준.

## 참고 문서 (내부)

- `/home/ubuntu/workspace/oh-my-aidlcops/CLAUDE.md` — OMA 전체 철학, Tier-0 워크플로우
- `/home/ubuntu/workspace/oh-my-aidlcops/.claude-plugin/marketplace.json` — 플러그인 메타데이터
- `/home/ubuntu/workspace/oh-my-aidlcops/schemas/plugin.schema.json` — plugin 스키마
- `/home/ubuntu/workspace/oh-my-aidlcops/schemas/skill-frontmatter.schema.json` — SKILL frontmatter 스키마
- `/home/ubuntu/workspace/oh-my-aidlcops/plugins/aidlc-construction/CLAUDE.md` — Phase 2 플러그인
- `/home/ubuntu/workspace/oh-my-aidlcops/plugins/agentic-platform/CLAUDE.md` — Agentic 플랫폼 구축 플러그인
