---
name: oma:platform-bootstrap
description: EKS 위에 Agentic AI Platform 스택(vLLM, Inference Gateway, Langfuse, Kagent)을 5-checkpoint 워크플로우로 구축한다. 리전·쿼터·GPU 가용성 확인부터 헬스체크·샘플 추론 검증까지 전 과정을 포함한다.
---
<objective>
Agentic AI Platform의 기반 인프라(EKS 클러스터, Karpenter, NVIDIA GPU Operator, vLLM 서빙, kgateway 기반 Inference Gateway, Langfuse 관측성)를 순서 보장된 5-checkpoint 방식으로 부트스트랩한다. 각 단계는 사람이 승인한 다음 다음으로 진행된다.
</objective>

<when_to_use>
- 신규 EKS 클러스터에 Agentic Platform 스택을 처음부터 구축할 때
- 기존 클러스터가 있더라도 Agentic 스택 구성요소 중 일부가 누락됐을 때(예: vLLM 또는 Langfuse 미설치)
- 리전·GPU 쿼터·IAM 등 사전 점검을 체계적으로 수행하고 기록으로 남기고 싶을 때
- 운영 자동화 활성화는 별도 명령(`/oma:agenticops`)을 사용한다. 이 명령은 **빌드 전용**이다
</when_to_use>

<execution_context>
@steering/workflows/platform-bootstrap.md
</execution_context>

<process>
`platform-bootstrap.md` 워크플로우를 그대로 실행하며, ai-infra 플러그인의 스킬을 순서대로 호출한다.

1. **Gather Context** — 대상 AWS 리전, 기존 EKS 클러스터, GPU 인스턴스 가용성 조회(`mcp__eks`, `mcp__aws-pricing`)
2. **Pre-flight Checks** — IAM 권한(EKS/EC2/VPC), 서비스 쿼터, KubeConfig 접근성, Helm v3.x 설치 확인
3. **Plan** — Terraform 또는 eksctl 매니페스트 생성, GPU 노드풀 사이징(모델 크기별), 네임스페이스·IRSA 설계
4. **Execute** — 의존성 순서로 설치
   - EKS 클러스터 → Karpenter → NVIDIA GPU Operator → vLLM → kgateway Inference Gateway → Langfuse
5. **Validate** — 각 컴포넌트 헬스체크, 샘플 추론 요청 성공, Langfuse trace 수신 확인

설치 순서는 의존성(GPU 드라이버→서빙 엔진→라우팅→관측성)에 의해 결정되므로 임의로 바꾸지 않는다. 실패 시 해당 체크포인트에서 중단하고 롤백 옵션을 제시한다.
</process>

<expected_stack_versions>
기준 시점 2026.04 — 플러그인 스킬이 별도로 관리하는 버전을 우선한다.
- Kubernetes: 1.32+ (DRA 1.35 GA)
- vLLM: v0.18+ 또는 v0.19.x
- kgateway: v2.0+
- Karpenter: v1.2+
- Langfuse: v3.x (self-hosted)
</expected_stack_versions>
