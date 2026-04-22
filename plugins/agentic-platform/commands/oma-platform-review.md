---
name: oma-platform-review
description: "기존 Agentic AI 플랫폼 배포를 리뷰하여 GPU 사이징, 관측성 커버리지, Guardrails, 비용 이상, 보안 취약점을 점검합니다. 진단 리포트와 개선 제안을 `.omao/state/platform-review-<date>.md` 에 저장합니다."
argument-hint: "[cluster-name] [optional: --scope=gpu|observability|guardrails|cost|security|all]"
---

## 명령 동작

`/oma:platform-review` 는 `platform-architect` (opus) 가 기존 배포를 분석하고 개선점을 제안합니다. 실제 변경은 수행하지 않으며, 변경은 사용자가 승인한 뒤 `/oma:platform-bootstrap --resume` 또는 개별 스킬로 반영합니다.

## 점검 영역

### 1. GPU 사이징
- Karpenter NodePool 구성, consolidation 정책 적정성
- 실제 GPU 활용률(DCGM_FI_DEV_GPU_UTIL) 대비 인스턴스 타입 적합도
- Spot / On-Demand 비율이 SLA 와 맞는가
- DRA / MIG 파티셔닝 활용 가능 여부
- KEDA scale-to-zero 적용 가능 워크로드 식별

### 2. 관측성 커버리지
- Langfuse 스팬 커버리지: Ingress → Gateway → vLLM → Tool → Response 전체 포함 여부
- OTel Collector 파이프라인 누수(drop) 발생 여부
- Prometheus 메트릭 기준 TTFT p95, error rate, queue depth
- 알림 규칙 적정성: Slack/PagerDuty 경로 존재
- 프롬프트 버저닝 사용 여부, 평가(Ragas) 연결

### 3. Guardrails
- OWASP LLM Top 10 대응 현황 매핑
- Input Guard (PII redact, Injection detect), Output Guard (PII scrub, Toxicity)
- Tool Allow-list 존재 여부, `*` 허용 금지
- Audit Log 수집 여부 (Langfuse + CloudTrail)
- 한국 금융·의료 규제 매핑 (ISMS-P, 전자금융감독규정)

### 4. 비용 이상
- 일/월 토큰 비용 추세, 비정상 스파이크 탐지
- Cascade / Semantic Router 도입으로 절감 가능량 추정
- Spot 인스턴스 interruption 비용 영향
- RDS/ClickHouse/Redis over-provisioning 여부
- S3 Lifecycle 적용 여부

### 5. 보안
- Security Group `0.0.0.0/0` 규칙 여부 (필수 차단)
- IRSA 권한 최소화, 과도한 권한 탐지
- mTLS, JWT, API Key rotation 정책
- External Secrets Operator 로 Secrets 관리 여부
- `mcp__well-architected-security` 로 SEC-01~SEC-11 자동 점검

## 절차

1. `--scope` 인자로 점검 범위 결정 (기본 `all`)
2. MCP 를 통해 클러스터 상태 스냅샷 수집
3. 각 영역별 에이전트에게 서브 리포트 요청
   - GPU → `vllm-deployer` + `platform-architect`
   - 관측성 → `langfuse-observer`
   - Gateway/Guardrails → `inference-gateway-operator`
4. 통합 리포트 생성: 심각도(High/Medium/Low) 별 발견 사항과 해결 제안
5. 저장 경로: `.omao/state/platform-review-YYYYMMDD.md`

## 리포트 템플릿

```
# Platform Review - <date>
## Summary
- Overall Score: <A/B/C/D>
- High Severity: <n>
- Medium Severity: <n>

## GPU Sizing
- Finding: <...>
- Evidence: <metric or kubectl output>
- Recommendation: <...>

## Observability
...

## Guardrails
...

## Cost Anomalies
...

## Security
...

## Proposed Actions (Prioritized)
1. [HIGH] <action> — owner: <agent/skill>
2. [MED] <action> — owner: <agent/skill>
```

## 실패 시 행동

- MCP 접근 권한 부족 → IRSA Role 및 kubeconfig 재확인
- Langfuse 연결 실패 → VPC endpoint 또는 DNS 확인
- 대규모 로그 볼륨 → sampling rate 로 우선 분석

## 참고 자료

- [engineering-playbook: Well-Architected ML Lens 매핑](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/operations-mlops/governance/compliance-framework.md)
- `references/vllm-performance-tuning.md` — 성능 점검 체크리스트
- `references/inference-gateway-cascade-pattern.md` — 라우팅 최적화
- `references/langfuse-self-hosted-setup.md` — 관측성 점검 항목
