---
name: vllm-serving-setup
description: "Design, deploy, and tune vLLM v0.18.2 inference serving on EKS with PagedAttention v2, Multi-LoRA, FP8 KV Cache, Chunked Prefill, and Continuous Batching. Produces Helm values.yaml, PodMonitor, HPA, and kubectl validation steps for production agentic workloads."
argument-hint: "[model name, target QPS/latency, GPU budget]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Bash,Grep,Glob,mcp__eks,mcp__aws-documentation,mcp__aws-pricing,mcp__cloudwatch,mcp__prometheus"
---

## When to Use

- 특정 모델(예: Llama 3.3 70B, Qwen3 32B, DeepSeek-V3)을 vLLM 으로 EKS 에 배포할 때
- 기존 vLLM 배포의 처리량·지연을 튜닝할 때
- Multi-LoRA 어댑터를 하나의 base 모델에 올릴 때
- FP8 KV Cache, Chunked Prefill 등 v0.18.2 신기능을 활성화할 때

## When NOT to Use

- 분산 추론(Disaggregated Prefill/Decode)이 필요한 대규모 트래픽 → `llm-d` 스킬 사용 권장
- 사전 학습(training) 파이프라인 → SageMaker / KubeRay / SkyPilot 영역
- MoE 전용 최적화가 필요한 경우 → Expert Parallel 전용 설정 참조

## Preconditions

- EKS 클러스터에 GPU NodePool, GPU Operator, DCGM 이 정상 동작 (`agentic-eks-bootstrap` 완료)
- Hugging Face 액세스 토큰(Secrets Manager 저장) 또는 S3 모델 가중치 복사 완료
- Prometheus + OTel Collector 가 배포되어 있음

## Procedure

### Step 1. GPU 메모리 사이징
```
필요 GPU 메모리 = 모델 가중치 + 비torch 메모리
                  + PyTorch 활성화 피크 메모리
                  + (배치당 KV 캐시 × 배치 크기)
```
- Llama 3.3 70B FP16 → 가중치 140GB + KV 캐시 ~40GB + 오버헤드 20GB ≈ 200GB
- 단일 H100 80GB 불가 → TP=4 (GPU당 50GB)
- INT4 양자화 시 35GB → 단일 A100 80GB 또는 H100 가능

### Step 2. 병렬화 전략 선정
- TP (Tensor Parallel): 동일 노드 내 GPU 간 layer 파라미터 분산
- PP (Pipeline Parallel): 레이어 그룹을 노드 간 분산 (멀티 노드)
- EP (Expert Parallel): MoE 모델 전용
- DP (Data Parallel): replica 확장, HPA 와 결합

### Step 3. Helm values 작성
```yaml
model:
  name: meta-llama/Llama-3.3-70B-Instruct
  dtype: bfloat16
vllm:
  image: vllm/vllm-openai:v0.18.2
  extraArgs:
    - --tensor-parallel-size=4
    - --gpu-memory-utilization=0.92
    - --max-model-len=32768
    - --enable-chunked-prefill
    - --enable-prefix-caching
    - --kv-cache-dtype=fp8
    - --enable-lora
    - --max-loras=8
    - --otlp-traces-endpoint=http://otel-collector.observability.svc:4317
resources:
  limits:
    nvidia.com/gpu: 4
nodeSelector:
  karpenter.sh/nodepool: gpu-inference-pool
tolerations:
  - key: nvidia.com/gpu
    operator: Exists
```

### Step 4. 배포 및 검증
```bash
helm upgrade --install vllm-llama3 vllm-project/vllm \
  --namespace inference --create-namespace \
  -f values.yaml --version 0.18.2

kubectl -n inference rollout status deployment/vllm-llama3 --timeout=10m
kubectl -n inference port-forward svc/vllm-llama3 8000:8000 &
curl -s http://localhost:8000/v1/models | jq
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"meta-llama/Llama-3.3-70B-Instruct","messages":[{"role":"user","content":"hello"}]}'
```

### Step 5. HPA + PodMonitor
- HPA: `vllm:num_requests_running` 또는 `DCGM_FI_DEV_GPU_UTIL` 기반
- PodMonitor: `/metrics` 엔드포인트 (prometheus_client)
- Langfuse 로 OTel trace 전송되는지 확인

### Step 6. 벤치마크
```bash
python benchmarks/benchmark_serving.py \
  --backend vllm \
  --model meta-llama/Llama-3.3-70B-Instruct \
  --num-prompts 200 \
  --request-rate 10
```
- p50/p95/p99 latency, throughput (tokens/s), GPU util 캡처

## Good Examples

- Llama 3.3 70B: TP=4, FP8 KV Cache, Chunked Prefill on → 30% throughput 개선
- Qwen3 32B: TP=2, Prefix Caching 활성 → code 벤치마크 400%+ 개선
- Multi-LoRA 16개: 단일 base + 어댑터 hot swap, 고객별 tenant 분리

## Bad Examples (금지)

- `gpu-memory-utilization=0.98` — OOM 위험, 0.92 이하 권장
- `--max-model-len` 임의 축소 없이 긴 프롬프트 허용 → KV 캐시 폭주
- TP 설정이 GPU 개수와 불일치 (예: TP=4 인데 request 3 GPU) — 부팅 실패
- vLLM v0.6.x 구버전 사용 — Chunked Prefill, FP8 KV 미지원

## References

- vLLM 모델 서빙 (community resource)
- llm-d 분산 추론 (community resource)
- [vLLM 공식 문서](https://docs.vllm.ai/)
- [vLLM Production Stack](https://github.com/vllm-project/production-stack)
- [PagedAttention SOSP 2023](https://arxiv.org/abs/2309.06180)
- 플러그인 내부: `../../references/vllm-performance-tuning.md`
