---
id: easy-button
title: Easy Button — 3-command install
sidebar_position: 1.5
---

# Easy Button — 3-command install

:::caution Tech Preview
`oma setup` / `oma doctor` 은 **Tech Preview** 입니다 (`v0.2.0-preview.1`).
`profile.yaml` v1 만 stable 로 간주하며, 나머지 표면은 GA 전까지 변경될 수
있습니다. 상세는 [Support Policy](./support-policy.md) 를 참조하세요.
:::

OMA 는 "AIDLC × AgenticOps 이지버튼" 을 목표로 합니다. 설치부터 첫 워크플로우
실행까지 **세 줄**로 끝납니다.

```bash
# 1. 원격 설치 — 릴리스 tarball 다운로드 후 ~/.oma 에 설치, ~/.local/bin/oma 심링크
curl -fsSL https://raw.githubusercontent.com/aws-samples/sample-oh-my-aidlcops/v0.2.0-preview.1/install.sh | bash

# 2. 프로젝트 디렉터리에서 세팅 — 프로파일 생성, 씨드 온톨로지, 플러그인 설치
cd my-project
oma setup

# 3. 환경 점검 — 프로파일/훅/MCP/온톨로지/AWS 크리덴셜 12 probe
oma doctor
```

## `oma setup` 이 하는 일

1. **Preflight** — `jq`, `git`, `python3`, `uvx`, Claude CLI, Kiro CLI 가용성 확인.
2. **Profile wizard** — 7개 질문 (Harness / AWS 계정 / Region / 환경 / AIDLC 진입
   phase / Approval mode / 월 예산 / Observability). 기본값 답변은 ENTER 로만
   넘어갈 수 있도록 전부 준비됨.
3. **`.omao/profile.yaml` 기록 + 즉시 검증** — 스키마 위반 시 die. 잘못된 프로파일로
   설치 완료가 되지 않도록 강제.
4. **Seed ontology 렌더** — `templates/ontology/` 를 프로파일 값으로 치환하여
   `.omao/ontology/{budgets,deployments,risks}/*.json` 생성, **각각 JSON Schema
   검증 통과**.
5. **Harness install** — `scripts/install/claude.sh` 또는 `kiro.sh` 호출. 둘 다
   선택하면 `both`.
6. **DSL compile** — `plugins/*/*.oma.yaml` 이 있으면 `python3 -m tools.oma_compile --all`
   실행, `.mcp.json` / `kiro-agents/*.agent.json` 재생성.
7. **Doctor 요약** — 12 probe 실행, pretty 출력. 실패 0 / 경고 N 을 종합.

### 비대화식 실행 (CI)

```bash
OMA_NON_INTERACTIVE=1 \
  OMA_HARNESS=claude-code \
  OMA_AWS_ACCOUNT=123456789012 \
  OMA_AWS_REGION=ap-northeast-2 \
  OMA_AWS_ENV=sandbox \
  OMA_AIDLC_PHASE=inception \
  OMA_APPROVAL_MODE=interactive \
  OMA_BUDGET_USD=200 \
  OMA_OBSERVABILITY=langfuse-managed \
  oma setup --non-interactive --skip-doctor
```

## Ontology + Harness 는 상위 규칙

`oma` 로 설치된 프로젝트에서는 온톨로지(Agent / Skill / Deployment / Incident /
Budget / Risk) 와 하네스 DSL 이 **모든 플러그인보다 우선하는 top-level rules**
로 동작합니다. 구체 규칙은 [Ontology + Harness Mandate](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/steering/workflows/ontology-harness-mandate.md)
에 정의되어 있습니다.

집행 경로:

| 시점 | 컴포넌트 | 하는 일 |
|---|---|---|
| 세션 시작 | `hooks/session-start.sh` | `.omao/ontology/` 스캔 → Budget / Incident / Deployment 상태 주입 |
| 사용자 프롬프트 | `hooks/user-prompt-submit.sh` | Budget 80% 초과 시 `[MAGIC KEYWORD: OMA_BUDGET_WARN]` 삽입 |
| on-demand | `oma doctor` | Profile / Ontology / Harness drift 점검 |
| PR 시점 | `.github/workflows/oma-foundation.yml` | `oma compile --check` 로 DSL↔네이티브 drift 차단 |

## 다음 단계

- [Profile 레퍼런스](./profile.md)
- [Doctor 레퍼런스](./doctor.md)
- [Ontology 개요](./ontology.md)
- [Harness DSL](./harness-dsl.md)
- [Tier-0 Workflows](./tier-0-workflows.md)
