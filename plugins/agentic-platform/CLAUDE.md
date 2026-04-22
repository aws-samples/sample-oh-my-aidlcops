# agentic-platform — Build the Agentic AI Platform on AWS EKS

이 플러그인은 AIDLC Construction 단계에서 **Agentic AI 플랫폼을 EKS 위에 구축**하는 데 사용합니다.
vLLM, Inference Gateway(kgateway + Bifrost/LiteLLM), Langfuse, Kagent, GPU 인프라(Karpenter + DRA)를 다룹니다.

운영(BUILD → OPERATE) 관점에서는 `agenticops` 플러그인이 이 플랫폼 위에서 동작합니다.

## 역할 요약

- **대상 단계**: AIDLC Phase 2 (Construction) — 플랫폼 자산 구축
- **커버리지**: GPU 노드 풀, 모델 서빙, 게이트웨이 라우팅, 관측성, Guardrails
- **참조 지식**: engineering-playbook `docs/agentic-ai-platform/` (링크 우선, 복사 금지)

## Agents

| Agent | 모델 | 역할 |
|-------|------|------|
| `platform-architect` | opus | SageMaker vs AgentCore vs EKS 결정, 플랫폼 컴포넌트 라이트사이징 |
| `vllm-deployer` | sonnet | vLLM Helm values, PagedAttention v2, Multi-LoRA, KV 캐시 튜닝 |
| `inference-gateway-operator` | sonnet | kgateway v2.0+ 설치, HTTPRoute, Cascade/Semantic Router 구성 |
| `langfuse-observer` | sonnet | Langfuse v3 self-hosted 설치, 트레이스 분석, 비용 추적 |

`agents/` 디렉터리의 각 `.md`는 해당 에이전트의 의사결정 트리, 자주 쓰는 커맨드, Error→Solution 매핑을 담습니다.

## Skills (사용자가 `/` 로 호출 가능)

| Skill | 트리거 시점 |
|-------|------------|
| `agentic-eks-bootstrap` | EKS 클러스터를 Agentic AI 용도로 신규 구성할 때 |
| `vllm-serving-setup` | 특정 모델을 vLLM으로 EKS에 배포할 때 |
| `inference-gateway-routing` | kgateway + Bifrost/LiteLLM 라우팅 패턴을 구성할 때 |
| `langfuse-observability` | OTel 기반 관측성 파이프라인을 Langfuse로 연동할 때 |
| `gpu-resource-management` | GPU NodePool, KEDA 스케일링, MIG/DRA 파티셔닝을 설계할 때 |
| `ai-gateway-guardrails` | PII 마스킹, Prompt Injection 방어, 정책 집행이 필요할 때 |

각 skill의 SKILL.md는 "When to Use / When NOT to Use / 절차 / 예시 / 참고 자료" 섹션을 따릅니다.

## References

심화 문서는 `references/` 에 위치하며 여러 skill 이 공유합니다:

- `vllm-performance-tuning.md` — PagedAttention v2, Chunked Prefill, Multi-LoRA, KV 캐시 사이징 벤치마크
- `inference-gateway-cascade-pattern.md` — 2-Tier, Cascade, Semantic Router 전략 비교
- `langfuse-self-hosted-setup.md` — PostgreSQL + ClickHouse + Redis + S3 기반 자체 호스팅 절차

## Commands

- `/oma:platform-bootstrap` — 5-체크포인트 부트스트랩 (Gather Context → Pre-flight → Plan → Execute → Validate)
- `/oma:platform-review` — 기존 플랫폼 배포의 GPU 사이징, 관측성 커버리지, Guardrails, 비용 이상 검토

## MCP Servers

`.mcp.json` 에 AWS Hosted MCP 11종(awslabs) 이 등록되어 있습니다.
주요 활용 매핑:

- `eks` — 클러스터 조회, Addon 관리, kubectl wrapper
- `aws-documentation` / `aws-knowledge` — 공식 문서·서비스 한도 조회
- `aws-pricing` — GPU 인스턴스 비용 분석
- `bedrock-agentcore` / `bedrock-kb-retrieval` — 하이브리드 플랫폼에서 Bedrock 연계
- `sagemaker-ai` — 학습·배치 추론 파이프라인 연동
- `cloudwatch` / `prometheus` — 메트릭·로그 분석
- `aws-iac` — Terraform/CDK 리소스 생성
- `well-architected-security` — 아키텍처 보안 검토

## 사용 원칙

1. **지식 소스 단일화** — 모든 개념 설명은 engineering-playbook GitHub 링크로 통합합니다.
   - 기본 URL: `https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/`
2. **버전 고정** — vLLM v0.18.2, Kubernetes 1.32+, Karpenter v1.2+, kgateway v2.0+, Langfuse v3.x, LiteLLM v1.60+, llm-d v0.5+, Bifrost v1.x (2026-04 기준).
3. **보안 제약** — Security Group `0.0.0.0/0` 오픈 금지. ALB/NLB + Cognito/OIDC/mTLS 경유 필수.
4. **언어** — 코드·설정은 영어, 본문은 한국어 경어체. 1인칭·감탄사 금지.
5. **에이전트 경로** — 복잡도 높은 설계 판단은 `platform-architect` (opus) 에 위임하고, 실행 단계는 전문 에이전트(sonnet)가 담당합니다.

## 참고 문서 (내부)

- `/home/ubuntu/workspace/oh-my-aidlcops/CLAUDE.md` — OMA 전체 철학과 Tier-0 워크플로우
- `/home/ubuntu/workspace/oh-my-aidlcops/.claude-plugin/marketplace.json` — 플러그인 메타데이터
- `/home/ubuntu/workspace/oh-my-aidlcops/schemas/` — plugin/skill/mcp 스키마 정의
