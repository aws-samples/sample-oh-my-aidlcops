---
title: Kiro Setup
description: Kiro 에이전트 하네스에 OMA를 설치하는 경로. install-kiro.sh의 심링크 구조, kiro.meta.yaml 사이드카, Claude Code와의 상태 공유 방식을 다룹니다.
sidebar_position: 5
---

본 문서는 Kiro 하네스에서 `oh-my-aidlcops`(OMA)를 설치·구성하는 방법을 설명합니다. OMA는 Claude Code와 Kiro를 동일한 스킬·상태 기반으로 지원하며, 두 하네스는 프로젝트 루트의 `.omao/` 디렉터리를 공유합니다.

## Kiro 하네스란

Kiro는 Claude Code와 다른 **skills-first 에이전트 하네스**입니다. 주요 차이점은 다음과 같습니다.

| 측면 | Claude Code | Kiro |
|---|---|---|
| 플러그인 단위 | `plugin/` 디렉터리 | 스킬 단위 flat 배포 |
| 스킬 위치 | `~/.claude/plugins/<plugin>/skills/<skill>/` | `~/.kiro/skills/<plugin>/<skill>/` |
| 커맨드 시스템 | `/slash-command` | 스킬 직접 호출 |
| Steering | Claude Code가 자동 주입 | `.kiro/steering/` 디렉터리 기반 |
| 트리거 힌트 | `settings.json` 훅 | `kiro.meta.yaml` 사이드카 |

OMA는 이 차이를 `install-kiro.sh`에서 흡수하며, 동일한 `plugins/<plugin>/skills/<skill>/SKILL.md` 소스를 두 하네스에 공유 노출합니다.

## 사전 요구사항

| 도구 | 버전 | 설치 |
|---|---|---|
| Kiro 런타임 | 최신 stable | [Kiro 공식 가이드](https://kiro.dev) |
| bash | 4+ | `brew install bash` (macOS) |
| jq | 1.6+ | `brew install jq` / `apt install jq` |
| git | 2.30+ | 시스템 기본값 |
| uv / uvx | latest | `pipx install uv` (MCP 서버용) |

## 설치

Kiro는 네이티브 마켓플레이스 경로를 제공하지 않으므로 수동 설치만 지원합니다.

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
cd oh-my-aidlcops
bash scripts/install-kiro.sh
```

스크립트 실행 후 기대되는 출력은 다음과 같습니다.

```
[install-kiro] OMA repo : /.../oh-my-aidlcops
[install-kiro] KIRO_HOME: /home/user/.kiro
[install-kiro] OMA_OWNER: aws-samples
[install-kiro] skill linked: agentic-platform/vllm-serving-setup
[install-kiro] skill linked: agenticops/self-improving-loop
...
[install-kiro] steering linked: /home/user/.kiro/steering

Installation complete.
    skills linked         : 23
    kiro.meta.yaml found  : 7
```

## 심링크 구조

설치가 끝나면 Kiro 홈 디렉터리에 다음 구조가 생성됩니다.

```
~/.kiro/
├── skills/
│   ├── agentic-platform/
│   │   ├── agentic-eks-bootstrap       -> <repo>/plugins/agentic-platform/skills/agentic-eks-bootstrap
│   │   ├── vllm-serving-setup          -> <repo>/plugins/agentic-platform/skills/vllm-serving-setup
│   │   ├── inference-gateway-routing   -> ...
│   │   └── ...
│   ├── agenticops/
│   │   ├── self-improving-loop         -> ...
│   │   ├── autopilot-deploy            -> ...
│   │   ├── incident-response           -> ...
│   │   ├── continuous-eval             -> ...
│   │   └── cost-governance             -> ...
│   ├── aidlc-inception/
│   └── aidlc-construction/
├── steering                             -> <repo>/steering
├── guides/                              # NEW: 단계별 가이드 (플러그인별 디렉터리)
│   └── agentic-platform/                -> <repo>/plugins/agentic-platform/guides
├── agents/                              # NEW: Kiro 에이전트 설정
│   └── agentic-platform.agent.json      -> <repo>/plugins/agentic-platform/kiro-agents/agentic-platform.agent.json
└── settings/                            # NEW: CLI 설정
    └── cli.json                         # 기본 템플릿 (사용자 편집 가능)
```

각 심링크는 OMA 리포지터리의 원본 디렉터리를 가리킵니다. 따라서 `git pull`로 리포지터리를 업데이트하면 Kiro가 즉시 최신 스킬을 사용합니다.

### idempotency

`install-kiro.sh`는 idempotent입니다. 재실행 시 기존 심링크의 타겟이 올바르면 유지하고, 오염된 링크만 새로 생성합니다. 실제 파일이 심링크 자리에 있으면 **덮어쓰지 않고 경고만 출력**합니다.

```
[install-kiro][warn] refusing to replace non-symlink: /home/user/.kiro/skills/my-skill
```

## kiro.meta.yaml 사이드카

Claude Code의 `SKILL.md` frontmatter는 Kiro가 그대로 해석하지 못하는 필드를 일부 포함합니다. 일부 스킬은 Kiro 전용 메타데이터를 `kiro.meta.yaml` 사이드카 파일로 제공하며, 설치 스크립트는 이를 감지하면 로그를 출력합니다.

```
[install-kiro] skill linked: agentic-platform/vllm-serving-setup
[install-kiro]   kiro.meta.yaml sidecar detected for agentic-platform/vllm-serving-setup
```

사이드카 파일 예시 구조:

```yaml
# kiro.meta.yaml
kiro:
  trigger_keywords:
    - "vllm"
    - "model serving"
    - "PagedAttention"
  context_files:
    - SKILL.md
    - reference/vllm-config.yaml
  mcp_required:
    - eks-mcp-server
    - aws-pricing-mcp-server
  phase: operations
  approval_required: true
```

Kiro는 이 메타데이터를 읽어 다음을 수행합니다.

- **trigger_keywords** — 자연어 요청에서 매칭 시 스킬을 우선 제안
- **context_files** — 스킬 실행 시 함께 로드할 추가 파일
- **mcp_required** — 실행 전 필수 MCP 서버 연결 확인
- **phase** — Inception / Construction / Operations 단계 분류
- **approval_required** — 체크포인트 승인 필요 여부

사이드카가 없는 스킬은 `SKILL.md` frontmatter만으로 동작합니다.

## Full Kiro Layout Support

OMA는 AWS Kiro 모더나이제이션 샘플에서 사용하는 전체 디렉터리 레이아웃을 지원합니다. 설치 스크립트는 다음 5개 디렉터리를 자동으로 구성합니다.

### 1. skills/ — 실행 가능한 스킬

모든 플러그인의 `skills/` 하위 디렉터리를 `~/.kiro/skills/<plugin>/<skill>/` 형태로 심링크합니다. 각 스킬은 `SKILL.md` + 선택적 `kiro.meta.yaml` 사이드카로 구성됩니다.

### 2. steering/ — 전역 오리엔테이션

`steering/` 디렉터리를 `~/.kiro/steering/`에 심링크합니다.

```
steering/
├── oma-hub.md              # OMA 전역 오리엔테이션
├── commands/
│   └── oma/                # /oma:* 슬래시 커맨드 정의 (Claude Code용)
└── workflows/              # 5-checkpoint 워크플로우 템플릿
```

Kiro는 `commands/oma/`를 슬래시 커맨드로 해석하지 않지만, 파일 내용을 스킬 orchestration 참고 자료로 활용합니다. `workflows/` 디렉터리의 5-체크포인트 템플릿은 두 하네스에서 동일하게 동작합니다.

### 3. guides/ — 단계별 안전 가이드 (Stage-Gated)

플러그인의 `guides/` 디렉터리를 `~/.kiro/guides/<plugin>/` 형태로 심링크합니다. guides는 워크플로우 단계별로 로드되는 안전 기준 문서(safety-critical content)입니다.

```
~/.kiro/guides/
└── agentic-platform/       -> <repo>/plugins/agentic-platform/guides
    ├── aws-practices/      # AWS Well-Architected 기반 가이드
    ├── common/             # 공통 안전 기준
    └── stages/             # 단계별 체크포인트 가이드
        ├── stage-1-analysis.md
        ├── stage-2-requirements.md
        └── ...
```

Kiro는 워크플로우 컨텍스트에 따라 해당 단계의 가이드를 자동으로 로드합니다. 예를 들어 `stage-2-requirements` 단계에서는 `stages/stage-2-requirements.md`가 context로 주입됩니다.

### 4. agents/ — Kiro 에이전트 프로필

플러그인의 `kiro-agents/*.json` 파일을 `~/.kiro/agents/` 디렉터리로 심링크합니다. 각 에이전트 프로필은 다음을 정의합니다.

- **MCP 서버 구성(MCP Server Configuration)** — 필요한 MCP 서버 목록과 환경 변수
- **자동 승인 규칙(Auto-approval Rules)** — 읽기 전용 / 파일 쓰기 / bash 명령 승인 정책
- **리소스 로딩(Resource Loading)** — 에이전트 시작 시 로드할 steering 파일 및 스킬 경로

예시: `agentic-platform.agent.json`

```json
{
  "name": "agentic-platform",
  "description": "Agentic AI Platform architect for EKS + vLLM + Inference Gateway + Langfuse on AWS.",
  "mcpServers": {
    "awslabs.eks-mcp-server": { "command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"] },
    "awslabs.aws-documentation-mcp-server": { ... }
  },
  "autoApprove": {
    "readOnly": true
  }
}
```

Kiro 런타임에서 `@agentic-platform` 형태로 해당 프로필을 활성화할 수 있습니다.

### 5. settings/ — CLI 기본 설정

`scripts/kiro-cli.template.json` 템플릿을 `~/.kiro/settings/cli.json`으로 복사합니다 (기존 파일이 없는 경우에만). 이 파일은 Kiro CLI의 기본 동작을 정의합니다.

```json
{
  "defaultModel": "claude-sonnet-4-6",
  "autoApprove": {
    "readOnly": true,
    "fileWrites": false,
    "bashCommands": false
  },
  "steering": {
    "alwaysLoad": ["oma-hub.md"]
  }
}
```

설치 후 사용자가 직접 편집해 기본 모델, 자동 승인 정책, 항상 로드할 steering 파일을 조정할 수 있습니다.

## 프로젝트 초기화

Claude Code와 동일하게 작업 프로젝트에서 `.omao/`를 초기화합니다.

```bash
cd <your-project>
bash <oma-repo>/scripts/init-omao.sh
```

`.omao/`는 harness-agnostic 이므로 같은 프로젝트에서 Claude Code와 Kiro를 병행 사용해도 상태가 동기화됩니다. 예를 들어 Kiro에서 시작한 AIDLC 루프를 Claude Code에서 이어받아 체크포인트 승인을 처리할 수 있습니다.

## AIDLC 확장 적용 (opt-in)

Kiro에서도 awslabs/aidlc-workflows 확장을 적용할 수 있습니다.

```bash
bash scripts/install-aidlc.sh
```

스크립트는 `awslabs/aidlc-workflows`를 `~/.aidlc`에 clone하고 OMA의 `*.opt-in.md` 확장을 심링크합니다. Kiro는 `~/.aidlc`를 스킬 컨텍스트로 자동 로드하지는 않으므로, 스킬 호출 시 명시적으로 참조하거나 프로젝트의 `.omao/plans/` 디렉터리에 복사해야 합니다.

## 환경 변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `OMA_OWNER` | `aws-samples` | GitHub 소유자 |
| `KIRO_HOME` | `$HOME/.kiro` | Kiro 설치 디렉터리 |

CI 환경이나 다중 사용자 장비에서 `KIRO_HOME`을 재지정해 격리된 설치를 만들 수 있습니다.

```bash
KIRO_HOME=/opt/kiro-ci bash scripts/install-kiro.sh
```

## 설치 검증

```bash
# 1. 스킬 디렉터리 확인
ls ~/.kiro/skills/
# agentic-platform/  agenticops/  aidlc-inception/  aidlc-construction/

# 2. 각 플러그인 스킬 개수
for p in agentic-platform agenticops aidlc-inception aidlc-construction; do
    echo "$p: $(ls ~/.kiro/skills/$p/ 2>/dev/null | wc -l) skills"
done

# 3. Steering 심링크 확인
ls -la ~/.kiro/steering
# symbolic link to <repo>/steering 이어야 합니다.
```

Kiro 런타임에서 스킬을 호출해 정상 동작을 확인합니다.

```
> agenticops/self-improving-loop 트레이스를 분석해 개선 PR을 작성하라
```

## 트러블슈팅

### 스킬이 Kiro에 표시되지 않음

`~/.kiro/skills/` 하위에 심링크가 생성되었는지 확인합니다.

```bash
find ~/.kiro/skills/ -maxdepth 2 -type l | head
```

심링크가 깨졌다면 재설치합니다.

```bash
rm -rf ~/.kiro/skills/agentic-platform ~/.kiro/skills/agenticops \
       ~/.kiro/skills/aidlc-inception ~/.kiro/skills/aidlc-construction
bash <oma-repo>/scripts/install-kiro.sh
```

### `refusing to replace non-symlink` 경고

기존에 Kiro 스킬 디렉터리에 실제 파일이 존재하는 경우입니다. 해당 파일을 백업·제거 후 재설치합니다.

```bash
mv ~/.kiro/skills/<conflicting-skill> ~/.kiro/skills/<conflicting-skill>.bak
bash <oma-repo>/scripts/install-kiro.sh
```

### kiro.meta.yaml이 반영되지 않음

Kiro 버전에 따라 사이드카 필드 지원이 다릅니다. 다음을 확인합니다.

```bash
# 사이드카 파일 존재 확인
find ~/.kiro/skills/ -name 'kiro.meta.yaml' | head

# Kiro 런타임 로그에서 사이드카 로드 확인 (Kiro 문서 참조)
```

지원되지 않는 필드는 무시되며, 스킬 기본 동작에는 영향이 없습니다.

### Claude Code와 Kiro 간 상태 불일치

두 하네스가 같은 `.omao/`를 공유하므로 원칙적으로 동기화됩니다. 불일치가 발생하면 파일 시스템 동기화 문제(예: NFS, 네트워크 드라이브)일 가능성이 높습니다.

```bash
# 파일 시스템이 로컬인지 확인
df -T .omao/
# 네트워크 드라이브라면 로컬 디스크로 이동 권장
```

### MCP 서버 연결 실패

Kiro 런타임이 `uvx` 경로를 찾지 못하는 경우가 있습니다. Kiro 설정에서 `PATH`에 uv 설치 경로(`~/.local/bin` 또는 `~/.cargo/bin`)를 추가합니다.

## Kiro 전용 고려사항

### 트리거 키워드 기반 호출

Kiro는 `kiro.meta.yaml`의 `trigger_keywords`를 기반으로 자연어 입력을 스킬에 자동 매칭합니다. Claude Code의 [Keyword Triggers](./keyword-triggers.md) 훅 기반 구조와 유사하지만, Kiro 내부 엔진이 처리합니다.

### 체크포인트 승인 UX

Kiro는 체크포인트를 대화창 내 인라인 프롬프트로 표시합니다. 승인·거부는 `approve` / `reject` / `revise <comment>` 중 하나를 입력합니다. Claude Code와 입력 형식이 같으므로 학습 비용이 거의 없습니다.

### 로그 수집

Kiro는 실행 로그를 `~/.kiro/logs/`에 저장합니다. OMA는 이 로그를 별도로 수집하지 않지만, 문제 신고 시 해당 디렉터리를 첨부해야 재현이 가능합니다.

## 제거

```bash
# 스킬 심링크 제거
rm -rf ~/.kiro/skills/agentic-platform ~/.kiro/skills/agenticops \
       ~/.kiro/skills/aidlc-inception ~/.kiro/skills/aidlc-construction

# Steering 심링크 제거
rm ~/.kiro/steering

# (선택) 프로젝트 상태 제거
rm -rf <your-project>/.omao/
```

## 참고 자료

### 공식 문서
- [Kiro 공식 가이드](https://kiro.dev) — Kiro 런타임 설치와 설정
- [awslabs/mcp](https://github.com/awslabs/mcp) — Kiro에서 사용하는 MCP 서버 목록

### OMA 내부 문서
- [Introduction](./intro.md) — OMA 개요
- [Getting Started](./getting-started.md) — 5분 Quickstart (Claude Code 기준, 흐름 동일)
- [Claude Code Setup](./claude-code-setup.md) — 자매 하네스 설치
- [Tier-0 Workflows](./tier-0-workflows.md) — 설치 후 실행할 워크플로우
