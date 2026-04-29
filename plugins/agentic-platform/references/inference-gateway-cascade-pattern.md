---
title: Inference Gateway Cascade / Semantic Router 패턴
description: 2-Tier 게이트웨이 아키텍처, Cascade Routing (Haiku→Sonnet→Opus), Semantic Router (intent-based) 설계 원칙과 비용·지연 트레이드오프, Bifrost/LiteLLM 구성 예시를 다룹니다.
created: 2026-04-21
last_update:
  date: 2026-04-21
  author: aws-samples
reading_time: 16
tags:
  - inference-gateway
  - kgateway
  - bifrost
  - litellm
  - cascade-routing
  - semantic-router
  - cost-optimization
  - scope:impl
---

## 개요

본 문서는 Inference Gateway 레이어에서 모델 선택을 자동화하는 세 가지 패턴(Cascade / Semantic Router / Hybrid)의 설계 원칙을 정리합니다. `inference-gateway-routing` 스킬과 `inference-gateway-operator` 에이전트가 본 문서를 참조합니다.

## 배경

LLM 플랫폼은 다양한 모델(경량 / 중형 / 대형) 과 다수 프로바이더(Bedrock, OpenAI, Anthropic, self-hosted)를 함께 운용합니다. 모든 요청을 대형 모델로 처리하면 비용이 폭증하고, 경량 모델로만 처리하면 품질 실패율이 높아집니다. **요청 특성에 따라 적절한 모델을 자동 선택**하는 게이트웨이 레이어가 필요한 이유입니다.

## 2-Tier Gateway 아키텍처

| 계층 | 역할 | 구현체 |
|------|------|--------|
| L1 Ingress | 네트워크 트래픽, TLS, mTLS, Rate Limit | kgateway v2.0+ (Kubernetes Gateway API) |
| L2-A Inference | 모델 선택, Cascade, Semantic Cache | Bifrost v1.x / LiteLLM v1.60+ |
| L2-B Data Plane | MCP/A2A 세션, Tool 라우팅 | agentgateway |

관심사 분리의 핵심 원칙:
- L1 은 모델을 **알지 못합니다**. 네트워크 규칙만 적용합니다
- L2-A 는 요청 내용을 분석해 모델을 **선택**합니다
- L2-B 는 stateful 세션을 **유지**합니다

## Cascade Routing

Cascade 는 **가벼운 모델부터 순차 시도**하고, confidence 가 낮거나 실패 시 더 강력한 모델로 승격합니다.

### 동작 원리
1. 요청 수신 → 경량 모델(예: Haiku) 호출
2. 응답의 품질 점수(logprobs, classifier score, 또는 regex) 확인
3. 임계값 미달 → 중형 모델(예: Sonnet) 재호출
4. 다시 미달 → 최종 모델(예: Opus)

### 장점
- 간단한 질의(FAQ, 분류, 포맷 변환)는 경량 모델로 처리 → 비용 60-80% 절감
- 복잡한 reasoning 은 자동 승격 → 품질 유지

### 단점
- 복잡한 질의가 두세 번 호출되어 latency 증가
- 품질 판단 로직 설계가 까다로움

### Bifrost 설정 예시
```yaml
cascade:
  enabled: true
  chain:
    - provider: anthropic
      model: claude-haiku-4-5
      confidence_threshold: 0.85
    - provider: anthropic
      model: claude-sonnet-4-6
      confidence_threshold: 0.80
    - provider: anthropic
      model: claude-opus-4-7
  fallback_on:
    - http_5xx
    - timeout
    - low_confidence
```

### 적용 권장 상황
- 질의가 난이도 분포가 넓음 (예: 고객 상담)
- 비용 민감도 > 지연 민감도

## Semantic Router

Semantic Router 는 **임베딩 기반 intent 분류**로 도메인별 최적 모델을 선택합니다.

### 동작 원리
1. 요청 내용을 경량 임베딩 모델(BGE-M3 small, 512 dim)로 벡터화
2. 미리 정의된 intent class (code / reasoning / creative / summarize 등) 중심 벡터와 cosine 유사도 계산
3. 최대 유사도 intent 에 지정된 모델로 라우팅

### 장점
- 첫 호출에서 적절한 모델 도달 → 낮은 p95 latency
- 도메인 전용 모델(Qwen3-Coder for code, DeepSeek-V3 for reasoning) 강점 활용
- intent 별 비용 예측 가능

### 단점
- intent 정의·임베딩 데이터셋 유지 비용
- 임베딩 모델 별도 운영 필요

### 설정 예시 (vllm-semantic-router)
```yaml
routes:
  - name: code
    centroid_file: s3://embeds/code-centroid.npy
    model: qwen3-coder-32b
  - name: reasoning
    centroid_file: s3://embeds/reasoning-centroid.npy
    model: deepseek-v3-671b
  - name: creative
    model: claude-opus-4-7
  - name: default
    model: claude-sonnet-4-6
embedding:
  model: bge-m3-small
  cache:
    backend: redis
    ttl: 3600
```

### 적용 권장 상황
- 도메인이 명확히 분리됨
- 지연 민감도 > 비용 민감도

## Hybrid 패턴

Cascade 와 Semantic Router 를 결합하면 장점을 모두 취할 수 있습니다.

- 1단계: Semantic Router 로 초기 모델 선택
- 2단계: 해당 모델이 실패하거나 confidence 낮으면 Cascade fallback

### 설정 예시
```yaml
router:
  primary: semantic
  fallback: cascade
  cascadeChain: [claude-sonnet-4-6, claude-opus-4-7]
```

## Semantic Caching

동일·유사 질의에 대해 이전 응답을 재활용하면 GPU 호출을 제거할 수 있습니다.

- Bifrost 내장 / GPTCache 사이드카
- Redis 기반 벡터 검색 (faiss-lite / qdrant)
- TTL + invalidation rule 필수 (모델 버전 변경 시 cache flush)
- Hit rate 20-40% 가 일반적 FAQ 도메인

## 비용·지연 트레이드오프

| 패턴 | 비용 | p50 지연 | p95 지연 | 운영 복잡도 |
|------|------|----------|----------|-------------|
| 단일 대형 모델 | 높음 | 중간 | 중간 | 낮음 |
| Cascade | 낮음 | 낮음 | 높음(최악 3-hop) | 중간 |
| Semantic Router | 중간 | 낮음 | 낮음 | 높음 |
| Hybrid | 낮음-중간 | 낮음 | 중간 | 가장 높음 |
| Semantic Cache 추가 | 최저 | 매우 낮음 | 매우 낮음 | 중간 |

## 관측성

- 모든 요청에 `x-oma-route-decision` 헤더 추가 → Langfuse span attribute
- Prometheus 메트릭
  - `route_decision_total{route="cascade",step="haiku"}`
  - `route_fallback_total{from="haiku",to="sonnet",reason="low_confidence"}`
  - `semantic_cache_hit_total`
- Langfuse 대시보드에서 route decision 별 cost/latency 분포 시각화

## 보안 고려사항

- Cascade fallback 시 민감한 시스템 프롬프트가 외부 provider 로 송신되지 않도록 provider 분리
- Semantic Router 의 임베딩 캐시에 PII 가 저장되지 않도록 pre-PII-redact
- Tool Allow-list 는 L2-A 의 route decision 과 별개로 적용

## 참고 자료

### 공식 문서
- [kgateway Documentation](https://kgateway.dev/docs/) — GatewayClass, HTTPRoute
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/) — 표준 스펙
- [Bifrost GitHub](https://github.com/maximhq/bifrost)
- [LiteLLM Documentation](https://docs.litellm.ai/)

### 논문 / 기술 블로그
- [FrugalGPT](https://arxiv.org/abs/2305.05176) — Cascade Routing 원전
- [Semantic Router (Aurelio AI)](https://github.com/aurelio-labs/semantic-router) — 오픈소스 구현

### 관련 문서 (내부)
- [inference-gateway-routing Skill](../skills/inference-gateway-routing/SKILL.md)
- [inference-gateway-operator Agent](../agents/inference-gateway-operator.md)
- engineering-playbook: 라우팅 전략 (community resource)
- engineering-playbook: Cascade 튜닝 (community resource)
