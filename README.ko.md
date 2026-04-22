# oh-my-aidlcops

**AIDLC × AgenticOps** — AI 기반 개발 라이프사이클(AIDLC)을 에이전트 기반 운영 자동화로 완성하는 플러그인 마켓플레이스입니다.

[English README](./README.md) · [문서](./docs/) · [플러그인](./plugins/) · [Steering](./steering/)

---

## OMA 란

`oh-my-aidlcops`(OMA)는 [oh-my-claudecode](https://github.com/Atom-oh/oh-my-claudecode)(OMC)의 형제 프로젝트입니다. OMC가 범용 Claude Code 워크플로우를 오케스트레이션한다면, OMA는 **AIDLC 루프**(Inception → Construction → Operations)에 특화됩니다.

핵심 명제: AIDLC는 운영까지 에이전트 자동화되었을 때 비로소 완성됩니다. OMA는 AWS 공식 [AIDLC workflows](https://github.com/awslabs/aidlc-workflows)에 **AgenticOps** 레이어(자기개선 피드백 루프, 자율 배포, 지속 평가, 인시던트 대응, 비용 거버넌스)를 결합하여 라이프사이클이 사람 개입 없이 스스로 닫히도록 구성합니다.

## 대상 사용자

- AWS EKS 위에 에이전틱 AI를 구축하는 플랫폼 엔지니어
- 설계·구축을 넘어 **운영** 단계까지 AIDLC로 커버하고자 하는 LLM/에이전트 운영 팀
- Claude Code 또는 Kiro를 사용하며, 스킬을 직접 만드는 대신 드롭인 마켓플레이스를 선호하는 사용자

## 플러그인

| 플러그인 | 역할 | 예시 스킬 |
|---|---|---|
| **`agentic-platform`** | EKS 위 Agentic AI Platform 구축·운영 | `agentic-eks-bootstrap`, `vllm-serving-setup`, `inference-gateway-routing`, `langfuse-observability`, `gpu-resource-management`, `ai-gateway-guardrails` |
| **`agenticops`** | 에이전트 기반 운영 자동화 | `self-improving-loop`, `autopilot-deploy`, `incident-response`, `continuous-eval`, `cost-governance` |
| **`aidlc-inception`** | AIDLC Phase 1 확장 | `workspace-detection`, `requirements-analysis`, `user-stories`, `workflow-planning` |
| **`aidlc-construction`** | AIDLC Phase 2 확장 | `component-design`, `code-generation`, `test-strategy` |

## Tier-0 워크플로우

OMA는 OMC의 Tier-0 패턴을 계승합니다. 한 번 호출하면 체크포인트에서만 사용자 승인을 받고 이후는 자율 실행합니다.

| 커맨드 | 목적 |
|---|---|
| `/oma:autopilot` | AIDLC 전체 루프 자율 실행 |
| `/oma:aidlc-loop` | 단일 feature AIDLC 1회전 |
| `/oma:agenticops` | 운영 모드(continuous-eval + incident-response + cost-governance 동시 구동) |
| `/oma:self-improving` | 피드백 루프(Langfuse 트레이스 → skill·prompt 개선 PR) |
| `/oma:platform-bootstrap` | EKS 위 Agentic AI Platform 5단계 체크포인트 구축 |

전체 커맨드는 [CLAUDE.md](./CLAUDE.md)를 참조합니다.

## 설치

### Claude Code (네이티브 마켓플레이스)

```bash
claude
> /plugin marketplace add https://github.com/devfloor9/oh-my-aidlcops
> /plugin install agentic-platform agenticops aidlc-inception aidlc-construction
```

### Claude Code (수동 설치)

```bash
git clone https://github.com/devfloor9/oh-my-aidlcops
bash oh-my-aidlcops/scripts/install-claude.sh
```

### Kiro

```bash
git clone https://github.com/devfloor9/oh-my-aidlcops
bash oh-my-aidlcops/scripts/install-kiro.sh
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
    └─▶ aidlc-construction  (Phase 2)
    │
    ▼
Skill 실행, AWS Hosted MCP 호출
    │
    ├─▶ eks, cloudwatch, prometheus, aws-iac, ...
    │
    ▼
체크포인트 — 사용자 승인
    │
    ▼
운영 단계는 자율 진행
    │
    └─▶ self-improving-loop가 개선을 Construction으로 피드백
```

## 재사용 자산

OMA는 AWS·커뮤니티 기존 작업 위에 쌓아 올리며, 재발명을 피합니다.

| 출처 | 라이선스 | OMA의 활용 방식 |
|---|---|---|
| [awslabs/agent-plugins](https://github.com/awslabs/agent-plugins) | Apache-2.0 | `plugin`·`skill-frontmatter`·`mcp`·`marketplace` JSON 스키마 채택 |
| [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) | MIT-0 | AIDLC core로 사용. OMA는 `*.opt-in.md` 확장만 기여 |
| [awslabs/mcp](https://github.com/awslabs/mcp) | Apache-2.0 | 11개 hosted MCP 서버를 `uvx` stdio로 참조 |
| [aws-samples/sample-apex-skills](https://github.com/aws-samples/sample-apex-skills) | MIT-0 | 5단계 체크포인트 워크플로우 템플릿 패턴 |
| [Atom-oh/oh-my-cloud-skills](https://github.com/Atom-oh/oh-my-cloud-skills) | MIT | eval 스크립트 패턴, Kiro 변환 참고 |
| [oh-my-claudecode](https://github.com/Atom-oh/oh-my-claudecode) | — | Tier-0 오케스트레이션 철학 및 `.omc/` 상태 관리 계승 |

전체 attribution은 [NOTICE](./NOTICE)에 있습니다.

## 라이선스

Apache-2.0. [LICENSE](./LICENSE) 참조.

## 기여

OMA는 Phase 1 MVP 단계입니다. Issue·PR 환영합니다 — 특히 skill 품질, MCP 커버리지, Kiro 호환성 테스트 영역을 우선 검토합니다.
