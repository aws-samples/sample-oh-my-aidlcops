---
title: vLLM 성능 튜닝 — PagedAttention v2, Chunked Prefill, Multi-LoRA, KV 캐시 사이징
description: vLLM v0.18.2 프로덕션 배포를 위한 성능 튜닝 레퍼런스. 메모리 사이징 공식, 병렬화 전략, FP8 KV Cache, 벤치마크 지표와 튜닝 체크리스트를 다룹니다.
created: 2026-04-21
last_update:
  date: 2026-04-21
  author: devfloor9
reading_time: 18
tags:
  - vllm
  - paged-attention
  - chunked-prefill
  - multi-lora
  - kv-cache
  - fp8
  - performance
  - scope:impl
---

## 개요

본 문서는 vLLM v0.18.2 를 EKS 프로덕션 환경에서 운영할 때 필요한 성능 튜닝 지침을 제공합니다. PagedAttention v2 내부 구조, Chunked Prefill 동작 원리, Multi-LoRA 배포, KV 캐시 메모리 사이징 공식과 벤치마크 방법을 포괄합니다. `vllm-serving-setup` 스킬과 `gpu-resource-management` 스킬이 본 문서를 공유 참조합니다.

## 배경

전통적 LLM 서빙 엔진은 KV 캐시를 정적으로 할당하여 60-80% 메모리 낭비가 발생했고, 정적 배칭은 GPU idle time 이 길었습니다. vLLM 은 가상 메모리 관리에 영감을 받은 **PagedAttention** 과 iteration 수준의 **Continuous Batching** 으로 처리량을 최대 24배 개선했습니다. v0.18.x 부터 V1 엔진이 도입되어 Chunked Prefill, FP8 KV Cache, Prefix Caching 이 기본 활성 옵션으로 포함되었습니다.

## PagedAttention v2 내부 구조

PagedAttention 은 KV 캐시를 고정 크기 블록(block)으로 분할하여 비연속적으로 저장합니다. 각 요청은 논리적 순서를 block table 로 유지하고, 실제 물리 메모리는 할당 가능한 block 을 재활용합니다.

- **블록 크기**: 기본 16 token. V1 에서 32 까지 확장 가능
- **블록 공유**: Prefix Caching 활성 시 동일 시스템 프롬프트를 공유하는 요청은 같은 block 을 가리킴
- **Swap**: GPU 메모리 부족 시 CPU swap area 로 이동, 재개 시 복원
- **Preemption**: 낮은 우선순위 요청은 일시 중단 후 재실행 (V1 에서 재개 지원)

PagedAttention v2 의 주요 개선 사항:
- Attention 커널 최적화로 FP8 KV Cache 와 결합 시 추가 15-25% throughput 개선
- FlashAttention 3 통합 (H100/H200)
- 더 세밀한 memory pool 관리로 fragmentation 감소

## Continuous Batching 동작

정적 배칭은 fixed batch size 만큼 요청을 모은 후 처리합니다. vLLM 의 연속 배칭은 **iteration 수준 스케줄러**가 매 token 생성마다 다음 작업을 선택합니다.

- 완료된 요청은 즉시 제거 → GPU 즉시 여유 확보
- 새 요청은 대기 없이 합류 → 평균 대기 시간 감소
- `--max-num-seqs` 로 동시 실행 상한, `--max-num-batched-tokens` 으로 토큰 batch 상한 제어

## Chunked Prefill

Prefill(첫 토큰 생성) 단계는 계산 집약적(compute-bound), Decode(이후 토큰 생성)는 메모리 집약적(memory-bound) 입니다. 두 단계를 같은 배치에 섞으면 compute 와 memory 가 동시 포화되어 GPU 활용률이 최대화됩니다.

- 긴 컨텍스트(예: 32K 입력) 요청이 혼재할 때 효과 큼
- 활성화: `--enable-chunked-prefill`
- V1 엔진 기본 `True`, 비활성화는 특별한 사유가 있을 때만
- p99 latency 는 다소 증가할 수 있으나 throughput 은 20-40% 개선

## FP8 KV Cache

KV 캐시를 BF16(2 bytes/element) → FP8(1 byte/element) 로 저장하면 동일 GPU 에 2배의 컨텍스트 또는 2배의 동시 요청을 담을 수 있습니다.

- 활성화: `--kv-cache-dtype=fp8`
- 품질 저하: 대부분 모델에서 0.1-0.3% 이내 (측정 필수)
- H100/H200/MI300X 에서 하드웨어 가속, A100 은 소프트웨어 에뮬레이션으로 이득 제한적
- 정확도 민감 작업(코드 실행, 수학)은 영향 검증 후 적용

## Prefix Caching

공통 시스템 프롬프트·RAG 컨텍스트가 반복되는 워크로드에서 prefix 를 재사용하면 prefill 비용을 크게 절감합니다.

- 활성화: `--enable-prefix-caching`
- 캐시 히트율은 Prometheus `vllm_cache_hit_rate` 로 관측
- 다수 고객이 같은 system prompt 를 사용하는 SaaS Agent 에서 400% 이상 개선 사례

## Multi-LoRA

하나의 base 모델 위에 수십 개의 LoRA adapter 를 hot-swap 방식으로 로드하여 멀티 도메인·멀티 고객을 단일 Pod 로 서빙합니다.

- 활성화: `--enable-lora --max-loras=16 --max-lora-rank=32`
- adapter 는 S3/HF Hub 에서 lazy load, IRSA 로 권한 관리
- GPU 메모리 추가 소비: adapter 당 수십 MB ~ 수백 MB (rank 에 비례)
- HTTPRoute 에서 `model=base-model+adapter-id` 형식으로 adapter 지정

## 병렬화 전략

### Tensor Parallelism (TP)
- 레이어 내 파라미터를 GPU 간 분할
- 단일 노드 내 2/4/8 GPU 구성에 최적
- NCCL 통신 최소화 위해 동일 PCIe 스위치 내 GPU 배치

### Pipeline Parallelism (PP)
- 레이어 그룹을 노드 간 분산
- TP=8 이후 추가 확장 시 PP 도입
- micro-batch 로 파이프라인 버블 감소

### Expert Parallelism (EP)
- MoE 모델 전용, expert 를 GPU 간 분산
- DeepSeek-V3, Qwen3-MoE, Mixtral 등에서 필수

### Data Parallelism (DP)
- replica 복제, HPA + KEDA 와 결합
- stateless 하므로 scale-out 간단

## GPU 메모리 사이징 공식

```
총 GPU 메모리 = 모델 가중치 + 비torch 메모리 (~2GB)
              + PyTorch 활성화 피크 (~10-20GB)
              + KV 캐시 (배치 크기 × 시퀀스 길이 × 2 × n_layers × d_head × n_heads × bytes_per_element)
```

예시 (Llama 3.3 70B BF16, 배치 256, 시퀀스 8192):
- 가중치: 140GB
- 활성화: ~20GB
- KV 캐시: ~40GB
- 합계: ~200GB → TP=4 (GPU당 50GB)

FP8 KV Cache 적용 시 KV 캐시 20GB 로 축소, TP=2 로도 가능.

## 벤치마크

```bash
python benchmarks/benchmark_serving.py \
  --backend vllm \
  --model meta-llama/Llama-3.3-70B-Instruct \
  --dataset-name sharegpt \
  --num-prompts 500 \
  --request-rate 20
```

측정 지표:
- **TTFT** (Time To First Token): p50 < 500ms, p95 < 1.5s 권장
- **TPOT** (Time Per Output Token): p50 < 50ms
- **Throughput**: tokens/sec
- **Goodput**: SLA 를 만족한 요청만 카운트
- GPU 활용률: DCGM `DCGM_FI_DEV_GPU_UTIL` > 70% 지속 목표

## 튜닝 체크리스트

1. `--gpu-memory-utilization` 는 0.88-0.92 범위에서 조정, OOM 여유 확보
2. `--max-num-seqs` 와 `--max-num-batched-tokens` 를 워크로드별로 스윕
3. `--enable-chunked-prefill`, `--enable-prefix-caching` 기본 활성
4. `--kv-cache-dtype=fp8` 는 품질 측정 후 적용
5. Multi-LoRA 사용 시 `--max-loras` 를 실제 동시 adapter 수보다 1.5배 여유
6. TP 구성은 GPU NVLink 토폴로지와 일치
7. Spot Interruption 대응: `terminationGracePeriodSeconds: 60`, readiness 재검증
8. Prometheus scrape 간격 15s, alert 기준 TTFT p95 > 3s

## 일반적인 오류와 대응

| 증상 | 원인 | 대응 |
|-------|------|------|
| CUDA OOM | memory-utilization 과다 | 0.85 로 하향, `max-model-len` 감소, FP8 KV Cache 활성 |
| 낮은 throughput | Chunked Prefill off | `--enable-chunked-prefill` 추가 |
| Prefix 캐시 hit 낮음 | system prompt 변동 | 프롬프트 구조 표준화, 앞부분 고정 |
| LoRA 로드 실패 | `--enable-lora` 누락 | Helm extraArgs 확인, adapter 경로 점검 |
| NCCL timeout | 네트워크 지연 | `NCCL_DEBUG=INFO`, placement group 검토, TP 그룹 동일 노드 배치 |

## 참고 자료

### 공식 문서
- [vLLM Documentation](https://docs.vllm.ai/) — CLI 옵션·배포 가이드
- [vLLM Production Stack](https://github.com/vllm-project/production-stack) — Helm 차트 레퍼런스
- [NVIDIA NCCL Troubleshooting](https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/troubleshooting.html)

### 논문 / 기술 블로그
- [PagedAttention (SOSP 2023)](https://arxiv.org/abs/2309.06180) — 원 논문
- [FlashAttention 3](https://arxiv.org/abs/2407.08608) — H100 지원 attention 커널
- [Chunked Prefill 설계](https://blog.vllm.ai/2024/09/05/perf-update.html) — vLLM 공식 블로그

### 관련 문서 (내부)
- [vllm-serving-setup Skill](../skills/vllm-serving-setup/SKILL.md)
- [gpu-resource-management Skill](../skills/gpu-resource-management/SKILL.md)
- [engineering-playbook: vLLM 모델 서빙](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/model-serving/inference-frameworks/vllm-model-serving.md)
