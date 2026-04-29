# sample-oh-my-aidlcops

**AIDLC × AgenticOps** — AI 기반 개발 라이프사이클(AIDLC)을 에이전트 기반 운영 자동화로 완성하는 플러그인 마켓플레이스입니다.

[English README](./README.md) · [문서](./docs/) · [플러그인](./plugins/) · [Steering](./steering/)

---

## OMA 란

`oh-my-aidlcops`(OMA)는 [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)(OMC)의 형제 프로젝트입니다. OMC가 범용 Claude Code 워크플로우를 오케스트레이션한다면, OMA는 **AIDLC 루프**(Inception → Construction → Operations)에 특화됩니다.

핵심 명제: AIDLC는 운영까지 에이전트 자동화되었을 때 비로소 완성됩니다. OMA는 AWS 공식 [AIDLC workflows](https://github.com/awslabs/aidlc-workflows)에 **AgenticOps** 레이어(자기개선 피드백 루프, 자율 배포, 지속 평가, 인시던트 대응, 비용 거버넌스)를 결합하여 라이프사이클이 사람 개입 없이 스스로 닫히도록 구성합니다.

## 대상 사용자

- AWS EKS 위에 에이전틱 AI를 구축하는 플랫폼 엔지니어
- 설계·구축을 넘어 **운영** 단계까지 AIDLC로 커버하고자 하는 LLM/에이전트 운영 팀
- 6R 기반 반복 가능한 모더나이제이션 워크플로우로 레거시 워크로드를 AWS로 이전하려는 팀
- Claude Code 또는 Kiro를 사용하며, 스킬을 직접 만드는 대신 드롭인 마켓플레이스를 선호하는 사용자

## 플러그인

| 플러그인 | 역할 | 예시 스킬 |
|---|---|---|
| **`agentic-platform`** | EKS 위 Agentic AI Platform 구축·운영 | `agentic-eks-bootstrap`, `vllm-serving-setup`, `inference-gateway-routing`, `langfuse-observability`, `gpu-resource-management`, `ai-gateway-guardrails` |
| **`agenticops`** | 에이전트 기반 운영 자동화 | `self-improving-loop`, `autopilot-deploy`, `incident-response`, `continuous-eval`, `cost-governance`, `audit-trail` |
| **`aidlc-inception`** | AIDLC Phase 1 확장 | `structured-intake`, `requirements-analysis`, `user-stories`, `workflow-planning` |
| **`aidlc-construction`** | AIDLC Phase 2 확장 | `component-design`, `code-generation`, `test-strategy`, `risk-discovery`, `quality-gates` |
| **`modernization`** | 레거시 워크로드 AWS 이전 (6R 전략) | `workload-assessment`, `modernization-strategy`, `to-be-architecture`, `containerization`, `cutover-planning` |

## Tier-0 워크플로우

OMA는 OMC의 Tier-0 패턴을 계승합니다. 한 번 호출하면 체크포인트에서만 사용자 승인을 받고 이후는 자율 실행합니다.

| 커맨드 | 목적 |
|---|---|
| `/oma:autopilot` | AIDLC 전체 루프 자율 실행 (Inception → Construction → Operations) |
| `/oma:aidlc-loop` | 단일 feature AIDLC 1회전 |
| `/oma:agenticops` | 운영 모드(continuous-eval + incident-response + cost-governance 동시 구동) |
| `/oma:self-improving` | 피드백 루프(Langfuse 트레이스 → skill·prompt 개선 PR) |
| `/oma:platform-bootstrap` | EKS 위 Agentic AI Platform 5단계 체크포인트 구축 |
| `/oma:modernize` | 레거시 워크로드 모더나이제이션 (6R 의사결정 → cutover) |
| `/oma:review` | AIDLC 산출물 리뷰 (ADR, 명세, 설계, PR) |
| `/oma:cancel` | 진행 중인 Tier-0 모드 종료 |

## 설치

### Claude Code (네이티브 마켓플레이스)

```bash
claude
> /plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
> /plugin install agentic-platform agenticops aidlc-inception aidlc-construction modernization
```

### Claude Code (수동 설치)

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash sample-oh-my-aidlcops/scripts/install-claude.sh
```

### Kiro

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash sample-oh-my-aidlcops/scripts/install-kiro.sh
```

### 사용자 프로젝트에 `.omao/` 초기화

```bash
cd <작업-프로젝트>
bash <oma-경로>/scripts/init-omao.sh
```

### AIDLC 확장 적용 (opt-in)

```bash
bash scripts/install-aidlc.sh
# awslabs/aidlc-workflows를 ~/.aidlc에 clone하고 OMA opt-in 확장을 심링크합니다.
```

## 아키텍처

```
사용자 요청
    │
    ▼
Tier-0 트리거 ── 키워드 매칭? ──▶ /oma:<workflow>
    │
    ▼
플러그인 디스패치
    │
    ├─▶ agentic-platform    (구축)
    ├─▶ agenticops          (운영)
    ├─▶ aidlc-inception     (Phase 1)
    ├─▶ aidlc-construction  (Phase 2)
    └─▶ modernization       (레거시 → AWS)
    │
    ▼
Skill 실행, AWS Hosted MCP 호출
    │
    ├─▶ eks, cloudwatch, prometheus, aws-iac, cost-explorer, ...
    │
    ▼
체크포인트 — 사용자 승인
    │
    ▼
운영 단계는 자율 진행
    │
    └─▶ self-improving-loop이 개선을 Construction으로 피드백
```

## 보안 기본 설정

본 리포지토리는 보수적인 기본값으로 배포됩니다. 프로덕션 사용 전 아래 항목을 확인하세요.

- **MCP 서버 버전 pin** — 모든 `.mcp.json`과 `kiro-agents/*.agent.json`에서 awslabs MCP 서버를 정확한 PyPI 버전으로 pin합니다. `@latest`는 어디에도 사용하지 않으므로, 손상된 상류 릴리스가 AWS 자격 증명과 함께 조용히 당겨지지 않습니다.
- **EKS MCP는 기본 read-only** — 번들된 Kiro agent 프로필은 `awslabs.eks-mcp-server`에 `--allow-write`나 `--allow-sensitive-data-access`를 **전달하지 않습니다**. EKS 리소스 변경이 필요할 때만 명시적으로 추가하고 감사 기록을 남기세요.
- **최소 권한 IAM** — `langfuse-observability` 스킬은 Langfuse 버킷 ARN으로 scope한 customer-managed policy를 사용합니다. AWS managed `AmazonS3FullAccess`(`s3:*` account-wide)는 스킬 본문의 "Bad Example" 블록으로 명시적으로 거부합니다.
- **`budget.yaml` 표현식 샌드박싱** — `cost-governance` 스킬은 `rule["when"]`을 [`simpleeval`](https://pypi.org/project/simpleeval/)(AST walker, builtins·callable 0개)로 평가합니다. 사용자 편집 가능한 파일에 Python `eval()`을 사용하면 왜 RCE 벡터가 되는지 Bad Example로 명시했습니다.
- **세션 상태는 로컬 전용** — `.omao/state/`, `.omao/plans/`, `.omao/logs/`, `.omao/notepad.md`, `.omao/project-memory.json`은 gitignore됩니다. `audit-trail`이 프롬프트를 verbatim 저장(PII, 승인자 신원, SOC2 retention 포함)하므로 절대 커밋되지 않아야 합니다.
- **Hook은 진짜 JSON encoder 요구** — `hooks/session-start.sh`는 `jq`(`python3` / `python` 순 폴백)를 사용하며, 셸 문자열 보간 기반 JSON은 방출하지 않고 실패 시 non-zero exit합니다. 조작된 상태 파일로 세션 컨텍스트에 key를 inject하는 벡터를 차단합니다.

## 재사용 자산

OMA는 AWS·커뮤니티 기존 작업 위에 쌓아 올리며, 재발명을 피합니다.

| 출처 | 라이선스 | OMA의 활용 방식 |
|---|---|---|
| [awslabs/agent-plugins](https://github.com/awslabs/agent-plugins) | Apache-2.0 | `plugin`·`skill-frontmatter`·`mcp`·`marketplace` JSON 스키마 채택 |
| [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) | MIT-0 | AIDLC core로 사용. OMA는 `*.opt-in.md` 확장만 기여 |
| [awslabs/mcp](https://github.com/awslabs/mcp) | Apache-2.0 | 11개 hosted MCP 서버를 `uvx` stdio로 참조 |
| [aws-samples/sample-apex-skills](https://github.com/aws-samples/sample-apex-skills) | MIT-0 | 5단계 체크포인트 워크플로우 템플릿 패턴 |
| [aws-samples/sample-ai-driven-modernization-with-kiro](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro) | MIT-0 | risk-discovery, audit-trail, quality-gates, 6R 전략 방법론 |
| [Atom-oh/oh-my-cloud-skills](https://github.com/Atom-oh/oh-my-cloud-skills) | MIT | eval 스크립트 패턴, Kiro 변환 참고 |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | — | Tier-0 오케스트레이션 철학 및 `.omc/` 상태 관리 계승 |

전체 attribution은 [NOTICE](./NOTICE)에 있습니다.

## 라이선스

MIT No Attribution (MIT-0). [LICENSE](./LICENSE) 참조.

## 기여

OMA는 Phase 1 MVP 단계입니다. 버그 리포트·PR 절차는 [CONTRIBUTING.md](./CONTRIBUTING.md), Amazon Open Source Code of Conduct는 [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)를 참조하세요. 특히 skill 품질, MCP 커버리지, Kiro 호환성 테스트 영역 기여를 환영합니다.

보안 이슈는 공개 GitHub issue로 신고하지 **마시고**, AWS [vulnerability reporting](https://aws.amazon.com/security/vulnerability-reporting/) 절차를 따라 주세요.
