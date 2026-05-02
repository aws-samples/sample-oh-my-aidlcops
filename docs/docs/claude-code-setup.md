---
title: Claude Code Setup
description: Claude Code 환경에서 OMA를 설치하는 두 경로(네이티브 마켓플레이스·수동)와 settings.json MCP 병합·훅 등록 세부 동작, 일반적인 트러블슈팅을 다룹니다.
sidebar_position: 4
---

본 문서는 Claude Code CLI 환경에서 `oh-my-aidlcops`(OMA)를 설치·구성하는 두 경로를 설명합니다. 네이티브 마켓플레이스 경로가 기본이며, 수동 설치는 오프라인 환경·엔터프라이즈 정책 등으로 네이티브 경로를 사용할 수 없을 때 이용합니다.

## 사전 요구사항

| 도구 | 버전 | 설치 |
|---|---|---|
| Claude Code CLI | 최신 stable | [공식 설치 가이드](https://docs.anthropic.com/claude/docs/claude-code) |
| bash | 4+ | macOS는 `brew install bash` |
| jq | 1.6+ | `brew install jq` 또는 `apt install jq` |
| uv / uvx | latest | `pipx install uv` (MCP 서버 실행용) |
| git | 2.30+ | 시스템 기본값 대부분 가능 |

## 방법 1 · 네이티브 마켓플레이스 설치 (유일한 공식 경로)

Claude Code **2.0 이상** 에서는 네이티브 마켓플레이스만 `/plugin list` 에
플러그인을 노출합니다. 다른 경로(예: 수동 심링크)는 UI 에 반영되지 않습니다.

```bash
claude
```

Claude Code 세션 안에서 다음을 순서대로 입력(또는 통째로 붙여넣기):

```text
/plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
/plugin install ai-infra@oh-my-aidlcops
/plugin install agenticops@oh-my-aidlcops
/plugin install aidlc@oh-my-aidlcops
/plugin install aidlc@oh-my-aidlcops
/plugin install modernization@oh-my-aidlcops
/plugin list
```

쉘에서 한 번에 처리하고 싶다면 here-doc:

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

설치 확인:

```bash
> /plugin list
# ai-infra     0.2.0-preview.1   enabled
# agenticops           0.2.0-preview.1   enabled
# aidlc      0.2.0-preview.1   enabled
# aidlc   0.2.0-preview.1   enabled
# modernization        0.2.0-preview.1   enabled
```

이 경로는 Claude Code 가 내부적으로 `~/.claude/installed_plugins.json` 을
갱신하고, 각 플러그인의 `.mcp.json`·commands 를 자동으로 통합합니다.

## 방법 2 · 수동 스크립트 (레거시 / 보조)

:::caution Claude Code 2.0+ 에서는 이 경로만으로는 플러그인이 로드되지 않습니다
`scripts/install/claude.sh` 는 `~/.claude/plugins/` 에 심링크를 만들고
`~/.claude/settings.json` 에 MCP 서버·훅을 병합합니다. Claude Code 1.x 까지는
이것만으로 플러그인이 작동했지만, **Claude Code 2.0+** 는
`~/.claude/installed_plugins.json` 을 단일 기준으로 삼습니다. 스크립트를
직접 실행하고 끝내면 `/plugin list` 는 비어있는 채로 남습니다. 아래
"MCP·hook 만 필요한 경우" 시나리오에서만 유효합니다.
:::

`scripts/install/claude.sh` 는 다음 세 가지 시나리오에서 여전히 유용합니다.

1. **Claude Code 1.x 레거시 환경** — 구버전에서는 심링크 방식이 유일한 설치 경로였습니다.
2. **MCP/hook 만 선반영** — 마켓플레이스 등록 없이 `settings.json` 에 OMA MCP 서버 + 훅만 병합하고 싶을 때.
3. **오프라인 CI** — 네트워크가 차단된 환경에서 `/plugin marketplace add` 가 불가능할 때.

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
cd oh-my-aidlcops
bash scripts/install/claude.sh
```

스크립트가 수행하는 작업은 네 단계입니다(자세한 동작은 [install/claude.sh 소스](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/scripts/install/claude.sh)를 참조).

1. **플러그인 심링크** — `~/.claude/plugins/<plugin>/`에 각 플러그인 디렉터리를 심링크합니다.
2. **커맨드 심링크** — `steering/commands/oma/`를 `~/.claude/commands/oma/`로 심링크해 `/oma:*` 슬래시 커맨드를 노출합니다.
3. **MCP 서버 병합** — 각 플러그인의 `.mcp.json` 내 `mcpServers` 객체를 `~/.claude/settings.json`의 최상위 `mcpServers` 키에 비파괴적으로 병합합니다.
4. **훅 등록** — `hooks/user-prompt-submit.sh`와 `hooks/session-start.sh`를 `~/.claude/settings.json`의 `hooks` 섹션에 등록합니다.

스크립트는 **idempotent**합니다. 재실행 시 기존 심링크는 유지되고, 누락된 항목만 새로 생성·병합됩니다.

### 환경 변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `OMA_OWNER` | `aws-samples` | 마켓플레이스 GitHub 소유자 |
| `CLAUDE_HOME` | `$HOME/.claude` | Claude Code 설치 디렉터리 |

## settings.json 병합 상세

OMA의 설치 스크립트는 **기존 `settings.json`을 덮어쓰지 않습니다.** `jq`를 사용해 두 가지 섹션만 부분 병합합니다.

### `mcpServers` 병합 규칙

기존 키가 존재하면 보존하고, 새 키만 추가합니다.

```json
{
  "mcpServers": {
    "my-custom-server": { "command": "..." },
    "eks-mcp-server": { "command": "uvx", "args": ["awslabs.eks-mcp-server"] },
    "cloudwatch-mcp-server": { "command": "uvx", "args": ["awslabs.cloudwatch-mcp-server"] }
  }
}
```

위 예시에서 `my-custom-server`(기존 키)는 그대로 두고, OMA가 추가하는 11개 hosted MCP 서버는 신규 키로 들어갑니다. 키 충돌 시 **기존 값이 우선**합니다.

병합 대상 MCP 서버 목록은 [NOTICE](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/NOTICE) 섹션 3에 정의되어 있습니다.

### `hooks` 등록 규칙

`UserPromptSubmit`과 `SessionStart` 훅이 다음 구조로 추가됩니다.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "/path/to/oh-my-aidlcops/hooks/user-prompt-submit.sh" }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "/path/to/oh-my-aidlcops/hooks/session-start.sh" }
        ]
      }
    ]
  }
}
```

기존 훅은 유지됩니다. 설치 스크립트는 동일한 `command` 경로가 이미 등록되어 있는지 확인하고, 중복을 만들지 않습니다.

훅의 역할은 다음과 같습니다.

- **SessionStart** — `.omao/triggers.json`을 로드해 활성 Tier-0 모드를 감지하고, 세션 컨텍스트에 OMA 상태를 주입합니다.
- **UserPromptSubmit** — 사용자 입력에서 키워드 트리거를 감지해 매칭되는 `/oma:<workflow>` 커맨드를 제안합니다. 상세는 [Keyword Triggers](./keyword-triggers.md)를 참조합니다.

## 프로젝트 초기화

설치는 사용자 홈 디렉터리 기준으로 진행되지만, 실제 작업은 프로젝트 루트의 `.omao/` 에서 일어납니다. **`oma setup` 을 실행했다면 이 단계는 자동 수행** 되며 별도 호출은 필요 없습니다.

`oma setup` 없이 수동 초기화:

```bash
cd <your-project>
oma init
```

이 커맨드는 `.omao/plans/`, `.omao/state/`, `.omao/notepad.md`, `.omao/triggers.json`, `.omao/project-memory.json` 을 생성합니다. 설치 경로를 직접 알 필요는 없습니다 — 필요하면 `oma where` 로 확인.

`.omao/`는 **harness-agnostic**하므로 같은 프로젝트에서 Claude Code와 Kiro를 번갈아 사용해도 상태가 일관됩니다.

## AIDLC 확장 적용 (opt-in)

`aidlc`·`aidlc` 플러그인은 awslabs/aidlc-workflows의 opt-in 확장 구조를 따릅니다. 확장을 활성화하려면 다음을 실행합니다.

```bash
bash scripts/install/aidlc-extensions.sh
```

스크립트는 `awslabs/aidlc-workflows`를 `~/.aidlc`로 clone하고, OMA가 작성한 `*.opt-in.md` 파일을 해당 리포지터리의 extension 디렉터리에 심링크합니다. OMA는 core workflow 파일을 복사·수정하지 않으며, 확장 파일만 기여합니다(상세는 [NOTICE](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/NOTICE) 섹션 2 참조).

## 설치 검증

다음 세 커맨드가 모두 정상 동작해야 설치가 완료된 것입니다.

```bash
# 1. 플러그인 활성 상태 확인
> /plugin list

# 2. 슬래시 커맨드 자동완성 확인
> /oma:
# autopilot, aidlc-loop, inception, construction, agenticops, self-improving,
# platform-bootstrap, review, cancel 가 모두 보여야 합니다.

# 3. MCP 서버 연결 확인
> /mcp
# 11개 AWS hosted MCP 서버가 listed 되어야 합니다.
```

## 트러블슈팅

### `/plugin marketplace add` 실패

Claude Code 버전이 오래된 경우 발생합니다.

```bash
claude --version
# 최신 stable로 업그레이드: https://docs.anthropic.com/claude/docs/claude-code
```

### `jq: command not found`

설치 스크립트가 JSON 병합에 jq를 사용합니다.

```bash
# macOS
brew install jq
# Debian/Ubuntu
sudo apt-get install -y jq
```

### `/oma:*` 커맨드가 표시되지 않음

`~/.claude/commands/oma/` 심링크가 생성되지 않았을 가능성이 있습니다.

```bash
ls -la ~/.claude/commands/oma/
# stale 심링크라면 제거 후 재설치
rm ~/.claude/commands/oma
bash ~/.oma/scripts/install/claude.sh
```

### MCP 서버 연결 실패 (`uvx not found`)

AWS hosted MCP 서버는 `uvx` stdio로 실행됩니다.

```bash
pipx install uv
# 또는
curl -LsSf https://astral.sh/uv/install.sh | sh

# 설치 후
uvx --version
```

### 훅이 실행되지 않음

`~/.claude/settings.json`에 훅이 등록되었는지 확인합니다.

```bash
jq '.hooks' ~/.claude/settings.json
# UserPromptSubmit, SessionStart 두 이벤트가 있어야 합니다.
```

훅 파일에 실행 권한이 있는지도 확인합니다.

```bash
chmod +x ~/.oma/hooks/user-prompt-submit.sh
chmod +x ~/.oma/hooks/session-start.sh
```

### 체크포인트가 무한 대기

`.omao/state/` 디렉터리 권한 문제일 수 있습니다.

```bash
ls -la .omao/state/
# 쓰기 권한이 없다면
chmod -R u+w .omao/
```

### 플러그인을 제거하고 싶을 때

네이티브 마켓플레이스 설치:

```bash
> /plugin uninstall ai-infra agenticops aidlc
> /plugin marketplace remove oh-my-aidlcops
```

수동 설치는 심링크 제거 후 `settings.json`에서 해당 항목을 직접 삭제합니다.

```bash
rm ~/.claude/plugins/ai-infra ~/.claude/plugins/agenticops \
   ~/.claude/plugins/aidlc ~/.claude/plugins/aidlc
rm ~/.claude/commands/oma
# ~/.claude/settings.json의 mcpServers·hooks에서 OMA 항목 수동 정리
```

## 참고 자료

### 공식 문서
- [Claude Code CLI](https://docs.anthropic.com/claude/docs/claude-code) — Claude Code 공식 가이드
- [Claude Code Plugins](https://docs.anthropic.com/claude/docs/claude-code-plugins) — 플러그인 구조 표준
- [awslabs/mcp](https://github.com/awslabs/mcp) — 병합 대상 MCP 서버 카탈로그
- [jq Manual](https://jqlang.github.io/jq/manual/) — settings.json 직접 편집 시 참조

### OMA 내부 문서
- [Getting Started](./getting-started.md) — 5분 Quickstart
- [Kiro Setup](./kiro-setup.md) — Kiro 환경 설치
- [Keyword Triggers](./keyword-triggers.md) — 훅 기반 자동 커맨드 호출
- [Tier-0 Workflows](./tier-0-workflows.md) — 설치 후 실행할 커맨드 상세
