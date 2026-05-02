---
name: ai-gateway-guardrails
description: "Enforce Input/Output Guardrails at the LLM Gateway layer — PII redaction, Prompt Injection defense, Jailbreak detection, Toxicity filter, and Tool Allow-list. Integrates Bedrock Guardrails, NeMo Guardrails, Llama Guard 3, and regex/regex-ML policies on Bifrost/LiteLLM with Langfuse audit trail."
argument-hint: "[compliance scope — ISMS-P, finance, healthcare]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Bash,Grep,Glob,mcp__eks,mcp__aws-documentation,mcp__well-architected-security"
---

## When to Use

- 한국 금융권(전자금융감독규정·ISMS-P), 의료, 공공 등 규제 환경에 LLM 서비스를 배포할 때
- Prompt Injection / Jailbreak / PII 유출 / Tool Poisoning 위협을 방어해야 할 때
- Bedrock Guardrails, NeMo Guardrails, Llama Guard 3 중 선택 및 조합이 필요할 때
- Agent 가 외부 Tool 을 호출할 때 Allow-list 기반 정책이 필요할 때

## When NOT to Use

- 내부 PoC 로 위협 모델이 불필요 — Guardrail 오버헤드만 발생
- Bedrock 매니지드 모델만 호출하며 Bedrock Guardrails 기본 활성 — 추가 구성 불필요 (단, 로그는 필수)
- 내부 RAG 없이 단순 Q&A — regex 수준의 Input Guard 만 필요할 수 있음

## Preconditions

- Inference Gateway (Bifrost/LiteLLM) 가 이미 배포됨 (`inference-gateway-routing` 완료)
- Langfuse 가 audit log 를 수신 가능 (`langfuse-observability` 완료)
- PII 정책·차단 카테고리·Tool Allow-list 정의 문서 확보

## Procedure

### Step 1. 위협 모델 정의 (OWASP LLM Top 10 기반)
- LLM01 Prompt Injection (Direct/Indirect)
- LLM02 Sensitive Information Disclosure (PII, 영업비밀)
- LLM06 Excessive Agency (Tool 오용)
- LLM08 Vector & Embedding Weaknesses (RAG poisoning)

### Step 2. 다층 방어 (Defense in Depth)
```
User → Input Guard → Gateway Policy → Tool Allow-list → LLM → Output Guard → Response
                                                                     ↓
                                                                 Audit Log (Langfuse)
```
- Input Guard: PII redaction, Injection pattern, Jailbreak classifier
- Gateway Policy: AuthN/Z, Rate Limit, Tenant Isolation
- Tool Allow-list: MCP Server Registry, Scoped tokens
- Output Guard: PII scrub, Toxicity, Fact check
- Audit Log: 모든 단계에서 Langfuse + CloudTrail 기록

### Step 3. Bedrock Guardrails 연동 (매니지드)
```yaml
# Bifrost 설정
providers:
  bedrock:
    region: ap-northeast-2
    guardrails:
      - id: arn:aws:bedrock:ap-northeast-2:ACCOUNT:guardrail/PII-BLOCK
        version: "1"
      - id: arn:aws:bedrock:ap-northeast-2:ACCOUNT:guardrail/TOXICITY
        version: "1"
```

### Step 4. NeMo Guardrails (오픈소스 Flow)
```yaml
# config.yml
models:
  - type: main
    engine: openai
    model: gpt-4.1
rails:
  input:
    flows:
      - self check input
      - detect pii
  output:
    flows:
      - self check output
      - remove pii
      - fact checking
```

### Step 5. Llama Guard 3 (Output Classifier)
- Meta Llama Guard 3 8B 모델을 vLLM 별도 Pod 로 배포
- Bifrost output 훅에서 Llama Guard 3 call → unsafe 판정 시 재생성 또는 차단

### Step 6. Tool Allow-list (MCP)
```yaml
mcpAllowList:
  - name: aws-documentation
    scopes: ["read"]
  - name: eks
    scopes: ["read", "describe"]
  # deny all others
tokenPolicy:
  maxLifetimeSeconds: 900
  audience: ai-infra
```

### Step 7. Audit & 알림
- 모든 guard violation 은 Langfuse `scores` + `tags` 로 기록
- Prometheus 메트릭 `guardrail_violation_total{type="pii",decision="block"}`
- CloudWatch Logs + SIEM 연계 (Security Lake)
- Slack/PagerDuty 알림 기준: `guardrail_violation_rate > 5%/5m`

## Good Examples

- ISMS-P 대상 금융: Bedrock Guardrails(managed PII + Block) + NeMo Guardrails(자체 Policy) + Llama Guard 3(output)
- Coding Agent: Tool Allow-list 로 `shell_exec`, `network_request` 차단
- RAG: Indirect Injection 방어용 Llama Guard 3 + fact-check Flow

## Bad Examples (금지)

- Guardrails 없이 Tool-calling Agent 를 프로덕션 배포 → LLM06 즉시 위반
- 정규식 기반 PII 단독 → 한국 주민번호 변형 패턴 미탐지, ML classifier 병행 필수
- Audit log 미수집 → 규제 감사 시 근거 부재
- `allowed-tools: ["*"]` — 전체 허용 = 정책 없음

## References

- AI Gateway Guardrails (community resource)
- 컴플라이언스 프레임워크 (community resource)
- [Bedrock Guardrails 공식 문서](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html)
- [NeMo Guardrails](https://github.com/NVIDIA/NeMo-Guardrails)
- [Llama Guard 3 (Hugging Face)](https://huggingface.co/meta-llama/Llama-Guard-3-8B)
- [OWASP LLM Top 10 2025](https://genai.owasp.org/llm-top-10/)
- [ISMS-P 인증 기준](https://isms.kisa.or.kr/) — 한국 인터넷진흥원
