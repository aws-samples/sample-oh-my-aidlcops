---
title: Getting Started
description: OMA 5분 Quickstart. 마켓플레이스 설치부터 첫 번째 /oma:autopilot 실행과 체크포인트 승인까지 전체 흐름을 최단 경로로 설명합니다.
sidebar_position: 2
---

본 문서는 `oh-my-aidlcops`(OMA)를 처음 사용하는 사용자를 위한 5분 Quickstart입니다. Claude Code 환경을 전제로 설명하지만, Kiro 환경도 흐름은 동일합니다(커맨드 대신 `.kiro/skills/` 심링크를 통해 호출). Kiro 전용 절차는 [Kiro Setup](./kiro-setup.md)을 참조합니다.

## 사전 요구사항

| 항목 | 버전 | 비고 |
|---|---|---|
| Claude Code CLI | 최신 stable | `claude --version` |
| jq | 1.6+ | 설치 스크립트가 JSON 병합에 사용 |
| bash | 4+ | macOS 기본 bash 3.2는 `brew install bash` 권장 |
| AWS 자격 증명 | — | `ai-infra` 워크플로우에서 EKS·CloudWatch·S3 접근 필요 |
| (선택) Kubernetes CLI | kubectl v1.32+ | `platform-bootstrap` 실행 시 |

## ⚡ `oma` CLI 설치 (선택, AgenticOps 용)

OMA 에는 **세 개의 서로 다른 설치 스크립트**가 있고 각각 역할이 다릅니다.
아래 표를 먼저 이해하면 혼란을 피할 수 있습니다.

| 스크립트 | 어디에 영향? | Claude Code 2.0+ 에서 필수? |
|---|---|---|
| **`install.sh`** (remote one-liner) | `~/.oma/` 에 CLI 설치, `~/.local/bin/oma` 심링크. **`~/.claude/` 는 안 건드림** | 선택 — `oma` CLI 쓰려면 필요 |
| **`oma setup`** | 프로젝트의 `.omao/profile.yaml`·씨드 온톨로지 기록. 내부적으로 `install/claude.sh` 도 호출해 `settings.json` 에 MCP·훅 병합 | 선택 — AgenticOps 쓸 때만 필요 |
| **`scripts/install/claude.sh`** | `~/.claude/plugins/` 심링크 + `settings.json` 에 MCP·훅 병합 (Claude Code 1.x 경로) | ❌ **단독으론 `/plugin list` 에 안 보임** |
| **`/plugin marketplace add` + `install`** | Claude Code 네이티브 플러그인 등록 (`~/.claude/installed_plugins.json` 업데이트) | ✅ **필수** |

즉, Claude Code 2.0+ 사용자는 **네이티브 마켓플레이스 경로(아래 1단계)** 가
필수이고, `oma setup` 은 **AgenticOps 기능을 쓸 때만** 추가로 실행합니다.

```bash
# OMA CLI 설치 (AgenticOps 쓸 계획이면)
curl -fsSL https://raw.githubusercontent.com/aws-samples/sample-oh-my-aidlcops/v0.2.0-preview.1/install.sh | bash
cd my-project
oma setup      # .omao/profile.yaml + 씨드 온톨로지 생성
oma doctor     # 환경 점검
```

> 기본값 그대로 설치하려면 모든 질문에서 ENTER 를 눌러 넘어가면 됩니다.
> CI 에서는 `OMA_NON_INTERACTIVE=1` 과 env flag 로 비대화식 설치가 가능합니다.
> `oma setup` 이 실패해도 아래 "1단계 · 마켓플레이스 등록" 은 독립적으로 진행 가능합니다.

### AWS 자격 증명은 별도 설정이 필요합니다

`oma setup` 이 묻는 AWS account id·region 은 **프로젝트의 의도를 적는 메타데이터**
입니다. 실제 AWS API 호출 권한은 다음 중 하나로 **별도로** 구성되어 있어야 합니다.

```bash
aws configure                  # 정적 access key 방식
aws configure sso              # SSO / IAM Identity Center
export AWS_PROFILE=my-profile  # 이미 있는 프로필 재사용
```

`oma setup` 종료 시 `aws sts get-caller-identity` 로 현재 쉘의 크리덴셜이
profile.yaml 에 기록한 account id 와 일치하는지 자동 확인하고 불일치/미설정 시
경고합니다. `oma doctor` 의 `AWS credentials` probe 에서도 동일하게 검증됩니다.

## 1단계 · 마켓플레이스 등록 (30초)

Claude Code **2.0 이상**에서는 네이티브 마켓플레이스 경로가 **유일한 공식 설치
방법**입니다. Claude Code 를 실행한 뒤 아래 명령을 순서대로 입력합니다.

```bash
claude
```

Claude Code 세션 안에서:

```text
/plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
/plugin install ai-infra@oh-my-aidlcops
/plugin install agenticops@oh-my-aidlcops
/plugin install aidlc@oh-my-aidlcops
/plugin install aidlc@oh-my-aidlcops
/plugin install modernization@oh-my-aidlcops
/plugin list
```

:::info 여러 플러그인을 한 번에 설치하고 싶다면
Claude Code `/plugin install` 자체는 한 번에 하나의 플러그인만 받습니다
(공백 구분 여러 인자 **미지원**). 위처럼 5줄을 붙여넣으면 Claude Code 가
순차적으로 각 줄을 실행해 줍니다. 혹은 쉘에서 한 번에 다섯 세션을 띄우고
싶다면 아래처럼 here-doc 을 사용할 수도 있습니다.

```bash
claude <<'EOF'
/plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
/plugin install ai-infra@oh-my-aidlcops
/plugin install agenticops@oh-my-aidlcops
/plugin install aidlc@oh-my-aidlcops
/plugin install aidlc@oh-my-aidlcops
/plugin install modernization@oh-my-aidlcops
/plugin list
EOF
```
:::

`/plugin list` 결과에 5 개 플러그인이 전부 `enabled` 로 보이면 성공입니다.

```text
ai-infra      v0.2.0-preview.1  enabled
agenticops            v0.2.0-preview.1  enabled
aidlc       v0.2.0-preview.1  enabled
aidlc    v0.2.0-preview.1  enabled
modernization         v0.2.0-preview.1  enabled
```

:::caution `bash scripts/install/claude.sh` 단독 실행은 동작하지 않습니다
OMA 설치 스크립트(`install/claude.sh`)는 `~/.claude/plugins/` 에 심링크만
생성합니다. 이는 Claude Code 1.x 구조였고, **Claude Code 2.0+** 는
`~/.claude/installed_plugins.json` 를 단일 기준(ground truth)으로 사용합니다.
따라서 스크립트 단독 실행으로는 `/plugin list` 에 플러그인이 나타나지
않습니다. 반드시 위의 네이티브 마켓플레이스 경로를 이용하세요.

설치 스크립트는 향후 Claude Code 1.x 레거시 환경 혹은 MCP·hook 동기화용
보조 도구로만 사용됩니다.
:::

수동 설치 상세는 [Claude Code Setup](./claude-code-setup.md)을 참조합니다.

## 2단계 · 프로젝트 초기화 (10초)

OMA 는 프로젝트별 상태를 `.omao/` 디렉터리에 보관합니다. **`oma setup` 을 실행했다면
이 단계는 이미 완료된 상태이므로 건너뛰셔도 됩니다** (setup 이 내부적으로 `.omao/` 를
초기화합니다).

`oma setup` 없이 `.omao/` 만 빠르게 만들고 싶다면:

```bash
cd <your-project>
oma init           # .omao/ 만 scaffold (wizard 없음)
```

> OMA 설치 경로(`~/.oma`) 를 기억할 필요가 없습니다. `oma init` 이 알아서 경로를
> 찾아갑니다. 확인이 필요하면 `oma where` 로 설치 루트를 볼 수 있습니다.

생성되는 구조는 다음과 같습니다.

```
.omao/
├── plans/                # AIDLC 산출물 (spec, design, ADR, user stories)
├── state/                # 세션 체크포인트, 활성 Tier-0 모드
├── notepad.md            # 작업 메모
├── triggers.json         # 키워드 트리거 카탈로그 (SessionStart 훅이 읽음)
└── project-memory.json   # 프로젝트별 영속 컨텍스트
```

`.omao/`는 harness-agnostic 하므로 Claude Code와 Kiro가 같은 파일을 공유합니다.

## 3단계 · 첫 Tier-0 실행 (2분)

가장 가벼운 워크플로우인 `/oma:aidlc-loop`로 시작합니다. 단일 feature의 AIDLC 1회전을 수행합니다.

```bash
> /oma:aidlc-loop "사용자 인증 로그에 이상 패턴 감지 룰을 추가하라"
```

에이전트는 다음 순서로 진행합니다.

1. **Inception** — `.omao/plans/` 안에 `spec.md`, `user-stories.md`를 생성합니다.
2. **Checkpoint 1** — 요구사항 검토를 위한 승인 프롬프트가 나타납니다. 내용을 확인하고 `approve` 또는 `revise` 응답합니다.
3. **Construction** — 승인 후 `design.md`, `adr-<topic>.md`, 테스트 전략, 구현 diff를 차례로 생성합니다.
4. **Checkpoint 2** — 설계·구현 리뷰 체크포인트. 여기서도 승인·수정이 가능합니다.
5. **Operations 설정** — 배포 후 지속 모니터링을 위해 `agenticops` 플러그인이 Langfuse 트레이스 훅을 등록합니다.

## 4단계 · 체크포인트 구조 이해 (1분)

OMA의 체크포인트는 [aws-samples/sample-apex-skills](https://github.com/aws-samples/sample-apex-skills)의 5단계 템플릿을 따릅니다.

```mermaid
flowchart LR
    G["1. Gather Context"] --> P["2. Pre-flight"]
    P --> PL["3. Plan"]
    PL --> E["4. Execute"]
    E --> V["5. Validate"]
    V -.실패 시.-> PL
```

각 단계는 `.omao/state/checkpoint-<n>.json`에 결과를 저장합니다. 중단 후 재개가 가능하며, 롤백은 `.omao/state/` 스냅샷을 복원하는 방식으로 수행합니다.

## 5단계 · 자율 실행 모드 전환 (1분)

단일 회전이 아닌 전체 루프 자동화를 원한다면 `/oma:autopilot`을 사용합니다.

```bash
> /oma:autopilot "신규 API 엔드포인트 /v1/events/anomaly 를 기획부터 운영까지 끝까지 완성하라"
```

`autopilot`은 Inception·Construction·Operations를 연속 실행하며, 체크포인트에서만 사용자 승인을 요구합니다. 운영 단계에서는 `continuous-eval`·`incident-response`·`cost-governance` 세 스킬이 백그라운드로 활성화됩니다.

중단하려면 언제든 다음을 호출합니다.

```bash
> /oma:cancel
```

## 결과 확인

Quickstart 완료 후 다음 산출물이 생성됩니다.

- `.omao/plans/spec.md` — 요구사항 명세
- `.omao/plans/design.md` — 컴포넌트 설계
- `.omao/plans/adr-*.md` — 아키텍처 결정 기록
- 소스 코드 변경사항 (feature branch에 커밋)
- `.omao/state/session-<id>/` — 세션 로그·체크포인트 결과

## 트러블슈팅 요약

| 증상 | 원인 | 해결 |
|---|---|---|
| `/plugin marketplace add` 실패 | Claude Code 버전 미지원 | `claude --version` 후 업그레이드 |
| `jq: command not found` | jq 미설치 | `brew install jq` / `apt install jq` |
| `/oma:*` 커맨드 미노출 | `~/.claude/commands/oma/` 심링크 실패 | `bash scripts/install/claude.sh` 재실행 |
| MCP 서버 연결 실패 | `uvx` 미설치 또는 네트워크 이슈 | `pipx install uv` 후 재시도 |
| Checkpoint가 무한 대기 | 훅 등록 누락 | [Claude Code Setup](./claude-code-setup.md)의 훅 섹션 참조 |

더 상세한 트러블슈팅은 [Claude Code Setup](./claude-code-setup.md)의 해당 섹션을 참조합니다.

## 다음 단계

- [Easy Button](./easy-button.md) — `oma setup` 1 회 실행으로 완료되는 설치·프로파일·씨드 온톨로지 흐름
- [Profile](./profile.md) · [Doctor](./doctor.md) — 프로젝트 설정과 환경 점검 참고
- [Ontology](./ontology.md) · [Harness DSL](./harness-dsl.md) — 런타임 강제화되는 도메인 계약과 DSL
- [Philosophy](./philosophy-aidlc-meets-agenticops.md) — OMA 설계 명제 이해
- [Tier-0 Workflows](./tier-0-workflows.md) — 9개 Tier-0 커맨드 심화 학습
- [Keyword Triggers](./keyword-triggers.md) — 키워드 기반 자동 커맨드 호출 설정
- [Support Policy](./support-policy.md) · [Telemetry](./telemetry.md) — Tech Preview 지원 범위

## 참고 자료

### 공식 문서
- [Claude Code Plugins](https://docs.anthropic.com/claude/docs/claude-code-plugins) — Claude Code 플러그인 공식 가이드
- [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) — AIDLC core workflow 저장소

### OMA 내부 문서
- [Introduction](./intro.md) — OMA 개요와 플러그인 카탈로그
- [Claude Code Setup](./claude-code-setup.md) — 수동 설치와 훅 설정
- [Tier-0 Workflows](./tier-0-workflows.md) — 커맨드 상세 레퍼런스
