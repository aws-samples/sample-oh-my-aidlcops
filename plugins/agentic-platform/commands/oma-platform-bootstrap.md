---
name: oma-platform-bootstrap
description: "Agentic AI 플랫폼을 EKS 위에 5-체크포인트(Gather Context → Pre-flight → Plan → Execute → Validate) 로 부트스트랩합니다. 클러스터 생성, GPU NodePool, vLLM, Inference Gateway, Langfuse, Guardrails 를 순서대로 배포합니다."
argument-hint: "[cluster-name] [region] [model] [optional: --dry-run]"
---

## 명령 동작

`/oma:platform-bootstrap` 를 호출하면 `platform-architect` (opus) 가 세션을 주도하고, 각 단계마다 전문 에이전트에게 위임합니다. 사용자는 체크포인트마다 승인/거절만 합니다.

## 5-Checkpoint 워크플로우

### Checkpoint 1. Gather Context
- 대상 클러스터 이름, 리전, 서빙할 모델, 예상 QPS/SLA, 규제 범위 확인
- `mcp__aws-documentation` 으로 리전 별 GPU 쿼터 조회
- `mcp__aws-pricing` 으로 TCO 예비 추정
- 산출물: `.omao/plans/platform-bootstrap-context.md`

### Checkpoint 2. Pre-flight
- AWS CLI, eksctl v0.196+, helm v3.14+, kubectl v1.32+ 설치 확인
- IAM 권한·AWS Organization 한도 점검
- VPC/Subnet 구성 가용성 확인 (최소 2 AZ, Private Subnet)
- `mcp__well-architected-security` SEC-01~SEC-11 점검
- 실패 항목이 있으면 여기서 중단, 사용자 승인 후 재진행

### Checkpoint 3. Plan
- `platform-architect` 가 6-레이어 청사진 초안 작성
- NodePool 구성(인스턴스 타입, Spot 비율, consolidation 정책) 결정
- 배포 순서: EKS 생성 → Karpenter → GPU Operator → vLLM → kgateway + Bifrost → Langfuse → Guardrails
- 산출물: `.omao/plans/platform-bootstrap-plan.md`
- 사용자 승인 필수

### Checkpoint 4. Execute
다음 스킬을 순서대로 호출:
1. `/oma:agentic-eks-bootstrap` — EKS 클러스터, Karpenter, GPU Operator
2. `/oma:gpu-resource-management` — NodePool 최종 적용, KEDA
3. `/oma:vllm-serving-setup` — 지정 모델 배포
4. `/oma:inference-gateway-routing` — kgateway + Bifrost 구성
5. `/oma:langfuse-observability` — Langfuse + OTel Collector
6. `/oma:ai-gateway-guardrails` — Input/Output Guard, Tool Allow-list

각 단계는 독립 체크포인트이며 실패 시 rollback 전략 제안.

### Checkpoint 5. Validate
- `kubectl get pods -A` 전체 Ready 확인
- 테스트 요청: Bifrost 경유 vLLM 호출, Langfuse 에 trace 도달 확인
- Prometheus 메트릭: TTFT p95 < 1.5s, error rate < 1%
- Guardrail 시뮬레이션: PII 포함 요청이 차단되는지, Injection 샘플이 탐지되는지
- 산출물: `.omao/state/platform-bootstrap-validation.md`

## 재실행 / 롤백

- 각 체크포인트 종료 후 상태는 `.omao/state/` 에 저장
- `--resume` 플래그로 마지막 성공 체크포인트부터 재시작
- `--dry-run` 플래그는 실제 변경 없이 계획만 출력

## 실패 시 행동

- Pre-flight 실패 → 구성 요건 리스트와 함께 종료
- Execute 단계 실패 → 해당 스킬의 Error → Solution 매핑 참조
- Validate 실패 → 원인 분석 후 재실행 또는 롤백 제안

## 참고 자료

- 플러그인 CLAUDE.md: 사용 원칙과 Agent 목록
- `references/vllm-performance-tuning.md`: 성능 튜닝 체크리스트
- `references/inference-gateway-cascade-pattern.md`: 라우팅 패턴
- `references/langfuse-self-hosted-setup.md`: Langfuse 설치
- engineering-playbook 메인 (community resource)
