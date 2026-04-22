---
name: inference-gateway-routing
description: "Configure kgateway v2.0+ as L1 and Bifrost v1.x or LiteLLM v1.60+ as L2 for a 2-Tier Inference Gateway on EKS. Apply Cascade Routing (Haiku→Sonnet→Opus fallback), Semantic Router (intent-based model pick), and HTTPRoute with OTel trace propagation to Langfuse."
argument-hint: "[routing pattern, providers, target cost/SLO]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Bash,Grep,Glob,mcp__eks,mcp__aws-documentation,mcp__prometheus"
---

## When to Use

- vLLM + 외부 LLM(Bedrock/OpenAI/Anthropic) 을 단일 엔드포인트로 통합할 때
- 비용 절감을 위해 Cascade Routing (경량 모델 우선 → 실패 시 강력 모델) 이 필요할 때
- 의도 분류 기반 Semantic Router 로 모델 자동 선택을 원할 때
- 다중 tenant / multi-project 격리가 필요할 때

## When NOT to Use

- 단일 모델·단일 프로바이더 → vLLM OpenAI 호환 엔드포인트 직결로 충분
- MCP/A2A stateful 세션만 처리 → `agentgateway` 전용 구성 사용
- ingress 수준 TLS 만 필요 → 일반 ALB Ingress 로 충분

## Preconditions

- EKS 클러스터에 Kubernetes Gateway API CRD 설치 (`gateway-api` v1.1+)
- `kgateway-system` namespace 또는 전용 namespace 준비
- Langfuse / OTel Collector 가 배포되어 있음
- 각 LLM provider API Key 가 Secrets Manager 에 저장

## Procedure

### Step 1. Gateway API CRD 설치
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
kubectl get crd | grep gateway.networking.k8s.io
```

### Step 2. kgateway v2.0 설치 (L1)
```bash
helm repo add kgateway https://kgateway.dev/helm
helm install kgateway kgateway/kgateway \
  --namespace kgateway-system --create-namespace \
  --version 2.0.0 \
  --set gatewayClass.name=kgateway \
  --set controller.metrics.enabled=true
```

### Step 3. Gateway 리소스 생성
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: llm-gateway
  namespace: kgateway-system
spec:
  gatewayClassName: kgateway
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: llm-tls-cert
```

### Step 4. Bifrost v1.x (L2) 배포
```bash
helm install bifrost maximhq/bifrost \
  --namespace inference \
  --version 1.0.0 \
  --set providers.openai.apiKeyFrom=secret/openai \
  --set providers.anthropic.apiKeyFrom=secret/anthropic \
  --set providers.bedrock.region=ap-northeast-2 \
  --set cascade.enabled=true \
  --set semanticCache.enabled=true
```

### Step 5. Cascade 또는 Semantic Router 정책 정의
- **Cascade 예시**: `anthropic.claude-haiku-4-5 → anthropic.claude-sonnet-4-6 → anthropic.claude-opus-4-7` 순 fallback
- **Semantic Router 예시**: 임베딩 BGE-M3 로 intent 분류 → `code` → Qwen3-Coder, `reasoning` → DeepSeek-V3
- `references/inference-gateway-cascade-pattern.md` 참조

### Step 6. HTTPRoute 바인딩
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: llm-cascade
  namespace: inference
spec:
  parentRefs:
    - name: llm-gateway
      namespace: kgateway-system
  hostnames: ["llm.example.com"]
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /v1/chat/completions
      backendRefs:
        - name: bifrost
          port: 8080
      timeouts:
        request: 60s
```

### Step 7. OTel Trace 검증
- Bifrost → OTel Collector → Langfuse 경로 확인
- `langfuse.com` 대시보드에서 trace 수신 여부 확인
- 누락 시 `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME` 환경 변수 재점검

## Good Examples

- 2-Tier: kgateway(L1) + Bifrost(L2) + vLLM(backend) — 관심사 명확 분리
- Cascade: Haiku 우선, 실패 코드 5xx 또는 정책 confidence 기반 fallback
- Semantic Router: intent embedding → 도메인 모델 선택, p95 latency 20% 개선 사례

## Bad Examples (금지)

- 단일 Gateway 에 L1+L2 역할 혼재 → 각 레이어 최적화 불가
- API Key 를 HTTPRoute annotation 에 평문 저장 → Secrets 참조 필수
- Retry 없는 Cascade → 하나의 provider 장애로 전체 중단
- OTel Collector 미설정 → 트레이스 블랙홀

## References

- [Inference Gateway 라우팅 전략](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/reference-architecture/inference-gateway/routing-strategy.md)
- [Cascade Routing 튜닝](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/reference-architecture/inference-gateway/cascade-routing-tuning.md)
- [Inference Gateway 배포 가이드](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/reference-architecture/inference-gateway/setup/)
- [kgateway 공식 문서](https://kgateway.dev/docs/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Bifrost](https://github.com/maximhq/bifrost)
- [LiteLLM](https://docs.litellm.ai/)
- 플러그인 내부: `../../references/inference-gateway-cascade-pattern.md`
