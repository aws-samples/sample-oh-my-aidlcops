---
name: langfuse-observability
description: "Self-host Langfuse v3.x on EKS (Web, API, Worker) with PostgreSQL, ClickHouse, Redis, and S3 backends. Wire an OpenTelemetry Collector pipeline that receives traces from vLLM, Bifrost/LiteLLM, and LangChain agents so token cost, latency, and quality scores are tracked end-to-end."
argument-hint: "[expected trace volume, multi-tenant requirement]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Bash,Grep,Glob,mcp__eks,mcp__aws-documentation,mcp__cloudwatch,mcp__prometheus"
---

## When to Use

- Agent / LLM 호출에 대한 end-to-end trace, token cost, quality 점수를 한곳에서 보고 싶을 때
- LangSmith SaaS 대신 self-hosted 관측성이 필요한 규제 환경
- 프롬프트 버저닝, 평가(Ragas), 데이터셋 기반 회귀 테스트가 필요할 때
- vLLM·Bifrost·LangChain·LangGraph 모두를 하나의 trace tree 로 연결해야 할 때

## When NOT to Use

- Cloud SaaS 로 충분 → Langfuse Cloud 사용
- 메트릭만 필요 (trace 불필요) → Prometheus + Grafana 단독
- OTel 표준과 호환되지 않는 legacy agent → OTel 마이그레이션 선행 필요

## Preconditions

- EKS 1.32+, IRSA 구성, S3 버킷 생성
- PostgreSQL, ClickHouse, Redis 를 in-cluster 또는 managed 로 배포할지 결정 (RDS, Aurora, ElastiCache 가능)
- OTel Collector 를 `observability` namespace 에 배포 예정

## Procedure

### Step 1. S3 버킷 + IRSA 생성
```bash
aws s3 mb s3://my-langfuse-blobs --region ap-northeast-2
eksctl create iamserviceaccount \
  --cluster agentic-prod \
  --namespace langfuse \
  --name langfuse \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
  --approve
```

### Step 2. Langfuse v3 Helm 배포
```bash
helm repo add langfuse https://langfuse.github.io/langfuse-k8s
helm upgrade --install langfuse langfuse/langfuse \
  --namespace langfuse --create-namespace \
  --version 1.3.0 \
  -f langfuse-values.yaml
```

`langfuse-values.yaml`:
```yaml
langfuse:
  image:
    tag: "3.162.0"
  web:
    replicas: 2
  worker:
    replicas: 2
postgresql:
  deploy: true
  auth:
    database: langfuse
clickhouse:
  deploy: true
  shards: 1
  replicas: 2
redis:
  deploy: true
  architecture: replication
s3:
  bucket: my-langfuse-blobs
  region: ap-northeast-2
  useIamRole: true
```

### Step 3. OTel Collector 파이프라인
```yaml
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }
processors:
  batch: {}
  attributes:
    actions:
      - key: service.namespace
        value: agentic
        action: insert
exporters:
  otlphttp/langfuse:
    endpoint: http://langfuse-web.langfuse.svc:3000/api/public/otel
    headers:
      Authorization: Basic ${env:LANGFUSE_API_BASIC}
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [otlphttp/langfuse]
```

### Step 4. vLLM / Bifrost 연결
```bash
kubectl -n inference set env deployment/vllm-llama3 \
  OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability.svc:4317 \
  OTEL_SERVICE_NAME=vllm-llama3

kubectl -n inference set env deployment/bifrost \
  OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability.svc:4317 \
  OTEL_SERVICE_NAME=bifrost
```

### Step 5. 검증
```bash
kubectl -n langfuse get pods
kubectl -n langfuse port-forward svc/langfuse-web 3000:3000
# 브라우저에서 http://localhost:3000 → Organization/Project 생성
# Settings → API Keys → OTel Basic 토큰 발급 → Collector 에 주입
```
- 샘플 요청 후 Langfuse Traces 탭에서 span tree 확인

### Step 6. 알림·대시보드
- Prometheus alert: `langfuse_worker_queue_depth > 10000`
- Langfuse Dashboards: token/day, error rate, p95 latency, cost by model
- Ragas 평가 결과를 Langfuse Scores 로 업로드

## Good Examples

- 프로덕션: PostgreSQL RDS Multi-AZ + ClickHouse 2-replica + Redis ElastiCache + S3
- PoC: in-cluster PG + ClickHouse single + Redis single (replicas=1)
- OTel attribute `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens` 주입으로 정확 cost

## Bad Examples (금지)

- ClickHouse 비활성 + 1M events/day 초과 → 대시보드 로딩 타임아웃
- OTel Collector 없이 SDK → Langfuse 직통 (retries·sampling 미지원)
- `disable-model-invocation` 모드에서 프롬프트 sanitize 누락 → PII 유출 위험
- Langfuse v2.x 구버전 → Prompt Experiments, ClickHouse 미지원

## References

- [Agent 모니터링 개요](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/operations-mlops/observability/agent-monitoring.md)
- [LLMOps Observability 도구 비교](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/operations-mlops/observability/llmops-observability.md)
- [모니터링 스택 구성 가이드](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/reference-architecture/integrations/monitoring-observability-setup.md)
- [Langfuse 공식 문서](https://langfuse.com/docs)
- [Langfuse Self-Host 가이드](https://langfuse.com/docs/deployment/self-host)
- [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)
- 플러그인 내부: `../../references/langfuse-self-hosted-setup.md`
