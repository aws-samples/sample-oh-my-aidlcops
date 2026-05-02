# sample-oh-my-aidlcops

**AIDLC × AgenticOps** — AI 기반 개발 라이프사이클(AIDLC)을 에이전트 기반 운영 자동화로 완성하는 플러그인 마켓플레이스입니다.

[English README](./README.md) · [문서](./docs/) · [플러그인](./plugins/) · [Steering](./steering/) · [릴리스](https://aws-samples.github.io/sample-oh-my-aidlcops/releases) · [References](./REFERENCES.md)

---

## v0.3 의 신규 기능

`v0.3.0-preview.1` 은 OMA 의 온톨로지·하네스 레이어를 호환성을 유지한 채
엔터프라이즈 수준으로 확장한 릴리스입니다.

- **두 개의 신규 온톨로지 엔티티** — `Spec` 과 `ADR` (Draft 2020-12) 추가로
  Phase 1(Inception) → Construction 산출물 traceability 체인이 닫힙니다.
- **기존 6 개 스키마의 엔터프라이즈 필드 확장** — `approval_chain`,
  `risk_exceptions`, `owasp_llm_top10_id`, `nist_ai_rmf_subcategory`,
  `compliance_refs[]`, `trace_id` / `span_id` (OTel), `cost_center_owner` 등
  전부 optional 이라 기존 fixture 는 그대로 통과합니다.
- **하네스 DSL v2** — 선택적 `workflows` (DAG), `telemetry`
  (OpenTelemetry Collector), `policies` (OPA/Rego), `metadata.labels` 블록.
  `version: 1` 파일은 변경 없이 계속 컴파일됩니다.
- **`oma doctor --enterprise`** — 8 가지 probe 실행 (ontology-2020-12,
  slsa-digest, risk-classification, audit-jsonl, dsl-version, policies-rego,
  plugin-dsl, mcp-pinned).
- **`oma compile --strict-enterprise`** — opt-in 게이트: DSL v2 만 허용,
  `approval_chain` 비어 있지 않아야 함, `Deployment.artifact` object
  형태 + `sha256` digest, 모든 Risk 가 OWASP 또는 NIST 로 분류되어야 함.
- **`oma validate <entity.yaml>`** — 8 가지 온톨로지 엔티티에 대해 스키마
  검증과 OPA 평가를 실행. `opa` 미설치 시 graceful fallback.
- **`oma run-workflow`** — DSL v2 워크플로우를 topo-sort 하여 실행 순서
  출력 (stub; 실제 호출 계층은 후속 릴리스에서 추가).
- **감사 이벤트 JSON-L 로 전환** — `python -m tools.oma_audit.append` 가
  `schemas/audit/event.schema.json` 스키마로 검증한 뒤
  `.omao/audit.jsonl` 에 append 합니다.

전체 내역은 [CHANGELOG.md](./CHANGELOG.md) 와
[릴리스 페이지](https://aws-samples.github.io/sample-oh-my-aidlcops/releases) 에
있습니다.

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
| **`ai-infra`** | EKS 위 Agentic AI Platform 구축·운영 | `agentic-eks-bootstrap`, `vllm-serving-setup`, `inference-gateway-routing`, `langfuse-observability`, `gpu-resource-management`, `ai-gateway-guardrails` |
| **`agenticops`** | 에이전트 기반 운영 자동화 | `self-improving-loop`, `autopilot-deploy`, `incident-response`, `continuous-eval`, `cost-governance`, `audit-trail` |
| **`aidlc`** | AIDLC Phase 1 확장 | `structured-intake`, `requirements-analysis`, `user-stories`, `workflow-planning` |
| **`aidlc`** | AIDLC Phase 2 확장 | `component-design`, `code-generation`, `test-strategy`, `risk-discovery`, `quality-gates` |
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

### ⚡ 원클릭 설치 (Tech Preview — 권장)

`install.sh` 가 release tarball 을 `~/.oma` 에 전개하고 `~/.local/bin/oma` 에
심링크를 만듭니다. 이후 `oma setup` 이 프로젝트 프로파일을 기록하고 씨드
온톨로지를 렌더한 뒤 플러그인 설치와 `oma doctor` 까지 한 번에 수행합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/aws-samples/sample-oh-my-aidlcops/v0.3.0-preview.1/install.sh | bash
cd my-project
oma setup
oma doctor
```

상세 동작 (무엇을 기록하는가, 12 probe 의 의미, 런타임에서 온톨로지·DSL 이
어떻게 강제되는가) 은 [Easy Button 문서](https://aws-samples.github.io/sample-oh-my-aidlcops/docs/easy-button)
를 참조하세요.

> **Tech Preview 고지** — `v0.3.0-preview.1` 은 ontology 8 개 엔티티와
> DSL v2 를 stable 로 간주합니다. CLI UX 일부와 doctor 리포트 구조는 GA
> 이전에 변경될 수 있습니다. [Support Policy](https://aws-samples.github.io/sample-oh-my-aidlcops/docs/support-policy) 를
> 확인하세요.

### Claude Code (네이티브 마켓플레이스 — Claude Code 2.0+)

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

> `/plugin install` 은 한 번에 하나의 플러그인 id 만 받습니다. 위 6 줄을
> 붙여넣으면 Claude Code 가 순차적으로 처리합니다. 쉘 한 줄로 스크립팅하고
> 싶다면 `claude <<'EOF' ... EOF` 히어독 사용.

### Claude Code (수동 스크립트 — 레거시 / MCP-only)

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash sample-oh-my-aidlcops/scripts/install/claude.sh
```

> 수동 스크립트는 `~/.claude/plugins/` 심링크를 만들고 `settings.json` 에
> MCP 서버·훅을 병합합니다. **Claude Code 2.0+ 에서는 이것만으로
> `/plugin list` 에 플러그인이 등록되지 않습니다.** 레거시 1.x 환경, 오프라인
> CI, 또는 마켓플레이스 등록 없이 MCP 만 연결하고 싶을 때만 사용하세요.

### Kiro

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash sample-oh-my-aidlcops/scripts/install/kiro.sh
```

### 사용자 프로젝트에 `.omao/` 초기화

```bash
cd <작업-프로젝트>
bash <oma-경로>/scripts/init-omao.sh
```

### AIDLC 확장 적용 (opt-in)

```bash
bash scripts/install/aidlc-extensions.sh
# awslabs/aidlc-workflows를 ~/.aidlc에 clone하고 OMA opt-in 확장을 심링크합니다.
```

### 빠른 시작 — v0.3 엔터프라이즈 플래그

`oma setup` 이후 Day 1 에 실행해 볼 만한 커맨드 네 가지입니다.

```bash
# 1. Diagnostic 전용 — 8 probe, 파일을 변경하지 않음
oma doctor --enterprise
# → [doctor:enterprise] 8 probes OK (0 warnings)

# 2. 엄격 게이트 — DSL v1 / 비어 있는 approval_chain /
#    레거시 문자열 artifact / 분류 없는 Risk 를 거부
oma compile --strict-enterprise
# → compiled ai-infra: plugins/ai-infra/.mcp.json ...

# 3. 온톨로지 엔티티 검증 (Spec / ADR / Deployment / Incident /
#    Budget / Risk / Agent / Skill). policies 선언 시 OPA 호출
oma validate path/to/deployment.yaml
# → [oma validate] path/to/deployment.yaml: schema OK

# 4. DSL v2 워크플로우 실행 순서 출력 (stub: 실제 invocation 미포함)
oma run-workflow ai-infra platform-bootstrap
# → execution order: preflight -> provision -> verify
```

v0.2 에서 v0.3 으로의 이전은 플래그 하나 차이입니다. 모든 신규 필드가
optional 이고, `--strict-enterprise` 를 켤 때만 강제됩니다. 단계별 도입
체크리스트는
[Enterprise readiness](https://aws-samples.github.io/sample-oh-my-aidlcops/docs/enterprise-readiness)
를 참고하세요.

### 컴플라이언스 프레임워크

OMA 는 온톨로지 엔티티를 네 가지 권위 있는 표준에 정렬하여 감사 대화에
임의 어휘 없이 대응할 수 있도록 합니다.

| 프레임워크 | OMA 내 위치 | 문서 |
|---|---|---|
| [Model Context Protocol v1.0](https://modelcontextprotocol.io) | `Agent.mcp_uri` (canonical MCP URI) | [Foundation](https://aws-samples.github.io/sample-oh-my-aidlcops/docs/ontology) |
| [SLSA v1.1 Provenance](https://slsa.dev/spec/v1.1/) | `Deployment.artifact.{digest,provenance_uri,signing}` | [SLSA provenance](https://aws-samples.github.io/sample-oh-my-aidlcops/docs/compliance/slsa-provenance) |
| [NIST AI RMF (AI 100-1)](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.100-1.pdf) | `Risk.nist_ai_rmf_subcategory`, `AuditEvent.compliance.nist_ai_rmf` | [NIST AI RMF mapping](https://aws-samples.github.io/sample-oh-my-aidlcops/docs/compliance/nist-ai-rmf) |
| [OWASP Top 10 for LLM Apps](https://owasp.org/www-project-top-10-for-large-language-model-applications/) | `Risk.owasp_llm_top10_id` (LLM01..LLM10) | [OWASP LLM Top 10 mapping](https://aws-samples.github.io/sample-oh-my-aidlcops/docs/compliance/owasp-llm-top10) |

OpenTelemetry(traces/metrics/logs)와 FinOps Framework 의 cost category 는
각각 DSL v2 `telemetry` 섹션과 `Budget` 엔티티로 편입됩니다.

### 마음에 드셨다면 Star 한 번

도움이 되셨다면 [GitHub 리포지터리](https://github.com/aws-samples/sample-oh-my-aidlcops)
에 ⭐ 를 남겨주시면 유지보수 우선순위 산정과 릴리스 알림 전달에 도움이
됩니다. **선택 사항** 이며 Star 여부에 따라 CLI 동작이 달라지지 않습니다.

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
    ├─▶ ai-infra    (구축)
    ├─▶ agenticops          (운영)
    ├─▶ aidlc     (Phase 1)
    ├─▶ aidlc  (Phase 2)
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

## 기반 레이어: 온톨로지 + 하네스 DSL

모든 OMA 플러그인은 두 개의 공유 레이어 위에서 동작합니다.

1. **온톨로지** (`ontology/`, `schemas/ontology/`) — 모든 플러그인과 스킬이
   합의하는 여섯 개의 도메인 개념을 JSON Schema로 정의합니다: `Agent`,
   `Skill`, `Deployment`, `Incident`, `Budget`, `Risk`. Construction→Operations
   핸드오프는 더 이상 산문 기술이 아닌, 검증된 `Deployment` 문서로 전달됩니다.
   [ontology/README.md](./ontology/README.md), [ontology/glossary.md](./ontology/glossary.md)
   를 참조하세요.
2. **하네스 DSL** (`schemas/harness/dsl.schema.json`, `tools/oma_compile/`) —
   플러그인마다 하나의 `<plugin>.oma.yaml` 이 agent, MCP 서버, hook, trigger의
   단일 소스입니다. `python -m tools.oma_compile` 명령이 이를 Claude Code와
   Kiro가 그대로 소비하는 `.mcp.json` 및 `kiro-agents/*.agent.json` 으로
   변환하므로 마켓플레이스 설치 흐름은 변경되지 않습니다.

```
<plugin>.oma.yaml  ──(oma-compile)──▶  .mcp.json
                                   ▶  kiro-agents/<agent>.agent.json
                                   ▶  .omao/triggers.json  (플러그인 전체 merge)
```

CI(`.github/workflows/oma-foundation.yml`)는 모든 스키마 fixture를 검증하고
`oma-compile --check` 로 DSL 소스와 커밋된 네이티브 파일 간 drift를 차단합니다.

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

전체 attribution 은 [NOTICE](./NOTICE) 에, 외부 스펙·프레임워크·런타임
도구를 포함한 레퍼런스 카탈로그는 [REFERENCES.md](./REFERENCES.md) 에
있습니다.

## 라이선스

MIT No Attribution (MIT-0). [LICENSE](./LICENSE) 참조.

## 기여

OMA 는 Tech Preview (`v0.3.0-preview.1`) 단계입니다. 4 가지 working
agreement (영문 전용 artifact, AI attribution 금지, CLAUDE.md 로컬 유지,
작업 단위 커밋) 와 PR/브랜치 네이밍 가이드는
[CONTRIBUTING.md](./CONTRIBUTING.md) 에, Amazon Open Source Code of
Conduct 는 [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) 를 참조하세요. 특히
skill 품질, MCP 커버리지, Kiro 호환성 테스트 영역 기여를 환영합니다.

보안 이슈는 공개 GitHub issue로 신고하지 **마시고**, AWS [vulnerability reporting](https://aws.amazon.com/security/vulnerability-reporting/) 절차를 따라 주세요.
