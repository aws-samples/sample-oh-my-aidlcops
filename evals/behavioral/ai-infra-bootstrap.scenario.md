---
name: agentic-platform-bootstrap
description: EKS 클러스터에 Agentic AI Platform 스택(Karpenter, GPU Operator, vLLM, kgateway, Langfuse)을 5-checkpoint로 부트스트랩하고 샘플 추론·trace 검증까지 완료한다.
plugin: agentic-platform
tier_0_command: /oma:platform-bootstrap
difficulty: advanced
estimated_duration: 60 minutes
---

# Agentic Platform Bootstrap 시나리오

## 목적

신규 EKS 클러스터에 Agentic AI Platform 스택을 5-checkpoint 워크플로우(Gather Context → Pre-flight → Plan → Execute → Validate)로 부트스트랩하며, GPU 노드 자동 프로비저닝, 모델 서빙 엔진(vLLM), Inference Gateway(kgateway), 관측성(Langfuse)이 정상 동작하고, 샘플 추론 요청이 Langfuse trace로 수신되는지 검증한다.

## 사전 조건 (Prerequisites)

- [ ] AWS 계정 및 자격 증명 설정 완료 (`aws sts get-caller-identity` 성공)
- [ ] IAM 권한: EKS, EC2, IAM, VPC, Route53, ACM 필요 권한 보유
- [ ] Helm v3.x 설치 (`helm version` 확인)
- [ ] kubectl 설치 및 기본 클러스터 접근 가능 (또는 신규 생성 계획)
- [ ] OMA 플러그인 설치: `agentic-platform`
- [ ] MCP 서버 접근 가능: `mcp__eks`, `mcp__aws-pricing`, `mcp__aws-documentation`
- [ ] Security Group 정책 준수: 0.0.0.0/0 인바운드 금지 (CLAUDE.md 규정)

## 시나리오 (Scenario)

### 입력 (User Input)

```
/oma:platform-bootstrap — us-east-1 리전, 목표 모델 Llama-3 70B, 예상 QPS 50
```

### 기대 동작 (Expected Behavior)

#### Stage 1: Gather Context

- **예상 도구 호출**: `Bash` `aws ec2 describe-instance-type-offerings --filters "Name=instance-type,Values=p5*,g6*" --region us-east-1`, MCP 호출 `mcp__aws-pricing` (p5/g6 시간당 비용 조회)
- **예상 질문**:
  - 대상 AWS 리전 → "us-east-1" (입력에서 명시)
  - 기존 EKS 클러스터 여부 → 사용자 응답 (예: "신규 생성")
  - GPU 인스턴스 가용성 → mcp__eks 자동 조회
  - 타겟 모델 → "Llama-3 70B" (입력에서 명시)
  - 예상 QPS → 50 (입력에서 명시)
  - Langfuse self-hosted 여부 → 사용자 응답 (예: "self-hosted")
  - IaC 선호 → 사용자 응답 (예: "Terraform")
  - 네트워크 모델 → 퍼블릭 SG 금지 확인
- **체크포인트**: 8개 필수 컨텍스트 항목 확보 후 Stage 2로 진행

#### Stage 2: Pre-flight Checks

- **예상 도구 호출**: `Bash` `aws iam get-user`, `Bash` `helm version`, `Bash` `kubectl version --client`
- **예상 검증**:
  - IAM 권한 (P/F): EKS, EC2, IAM, VPC 권한 확인
  - 서비스 쿼타 (P/F): p5/g6 인스턴스 쿼타, mcp__aws-pricing 조회
  - KubeConfig 접근 (P/F): 신규 클러스터면 skip
  - Helm v3.x (P/F): `helm version` 출력 검증
  - Security Group 정책 (P/F): 0.0.0.0/0 인바운드 금지 재확인
  - 도메인·ACM 인증서 (P/F): 사용자 제공 또는 kubectl port-forward 대안 제시
  - Langfuse 접근 (P/F): self-hosted 배포 계획 확인
  - Terraform 상태 저장소 (P/F): S3+DynamoDB backend 계획
- **예상 출력**: Pre-flight Report 테이블 (8개 항목 P/F 표시)
- **체크포인트**: 모든 항목 Pass 또는 risk acceptance 후 Stage 3로 진행

#### Stage 3: Plan

- **예상 도구 호출**: `Write` `.omao/plans/platform-bootstrap-plan.md`
- **예상 계획 항목**:
  1. EKS 클러스터 스펙: K8s 1.32+, managed control plane log, addon 목록
  2. 노드풀 설계:
     - 시스템 노드풀: m6i.large × 3 (AZ 분산)
     - GPU 노드풀: Llama-3 70B → p5.48xlarge (A100 80GB) 또는 g6.12xlarge 선택
     - Karpenter NodePool 매니페스트
  3. Helm 차트 순서: Karpenter → GPU Operator → vLLM → kgateway → Langfuse
  4. 네트워킹: ALB + Cognito/OIDC 인증, Route53 레코드, ACM TLS
  5. 관측성 계측: OTel collector, Langfuse API key 배포
  6. 롤백 계획: 각 단계별 실패 시 되돌릴 지점
- **예상 출력**: Terraform plan 요약 (또는 eksctl 설정), Helm release matrix, 예상 비용 (시간당·월간)

#### 🛑 CHECKPOINT — Plan Approval

- **예상 에이전트 동작**: Terraform plan + Helm matrix + 비용 요약 제시 후 대기 ("다음 계획을 검토 후 'proceed' 또는 'revise' 응답해주세요.")
- **사용자 응답**: "proceed"
- **검증 기준**:
  - 노드풀 사이즈가 Llama-3 70B 요구사항(최소 A100 80GB) 충족
  - 퍼블릭 SG 오픈 없음 (0.0.0.0/0 금지)
  - Helm 차트 버전이 2026.04 기준 안정 버전 (Karpenter v1.2+, vLLM v0.18+, kgateway v2.0+)
  - 에이전트가 사용자 응답 없이 Execute로 진행하지 않음

#### Stage 4: Execute

- **예상 순서**: EKS Cluster → Karpenter → GPU Operator → vLLM → kgateway → Langfuse

##### 4-1. EKS Cluster
- **예상 도구 호출**: `Bash` `terraform apply -target=module.eks` (사용자 승인 후)
- **검증 명령**: `Bash` `aws eks describe-cluster --name <name> --query 'cluster.status'` → ACTIVE
- **체크포인트**: 시스템 노드 Ready 확인

##### 4-2. Karpenter
- **예상 도구 호출**: `Bash` `helm install karpenter oci://public.ecr.aws/karpenter/karpenter --version v1.2.x --namespace karpenter --create-namespace -f karpenter-values.yaml`
- **검증 명령**: `Bash` `kubectl get pods -n karpenter`, `Bash` `kubectl get nodepool`
- **체크포인트**: Karpenter Pod Running, NodePool CRD 적용

##### 4-3. NVIDIA GPU Operator
- **예상 도구 호출**: `Bash` `helm install gpu-operator nvidia/gpu-operator --namespace gpu-operator --create-namespace -f gpu-operator-values.yaml`
- **검증 명령**: `Bash` `kubectl get pods -n gpu-operator`, `Bash` `kubectl describe node <gpu-node> | grep nvidia.com/gpu`
- **체크포인트**: DCGM DaemonSet Running, GPU Allocatable 확인

##### 4-4. vLLM Serving
- **예상 도구 호출**: `Bash` `helm install vllm-runtime <vllm-chart> --namespace inference --create-namespace -f vllm-values.yaml`
- **검증 명령**: `Bash` `kubectl get pods -n inference`, `Bash` `curl http://<vllm-service>:8000/v1/models`
- **체크포인트**: vLLM Pod Running, `/v1/models` 응답 확인

##### 4-5. kgateway Inference Gateway
- **예상 도구 호출**: `Bash` `helm install kgateway oci://<registry>/kgateway --version v2.0.x --namespace gateway-system --create-namespace -f kgateway-values.yaml`, `Bash` `kubectl apply -f httproute-vllm.yaml`
- **검증 명령**: `Bash` `kubectl get httproute -n gateway-system`, `Bash` `kubectl get svc -n gateway-system`
- **체크포인트**: HTTPRoute Accepted, ALB DNS 응답

##### 4-6. Langfuse Observability
- **예상 도구 호출**: `Bash` `helm install langfuse langfuse/langfuse --namespace observability --create-namespace -f langfuse-values.yaml`
- **검증 명령**: `Bash` `kubectl get pods -n observability`, `Bash` `curl https://<langfuse-ui>`
- **체크포인트**: Langfuse Web UI 접속, API key 발급

#### 🛑 CHECKPOINT — Install Complete

- **예상 에이전트 동작**: 6개 구성요소 Helm release 상태 + endpoint 나열 후 대기
- **사용자 응답**: "proceed"
- **검증 기준**:
  - 6개 Helm release 모두 deployed 상태
  - GPU 노드가 Karpenter를 통해 자동 프로비저닝됨
  - Inference Gateway endpoint가 ALB + 인증 경유로 도달 가능
  - Langfuse UI 접속 및 API key 발급 완료

#### Stage 5: Validate

- **예상 도구 호출**: `Bash` `kubectl get pods -A --field-selector 'status.phase!=Running,status.phase!=Succeeded'`, `Bash` `curl -X POST https://<gateway-host>/v1/chat/completions -H "Authorization: Bearer <token>" -d '{"model":"llama-3-70b","messages":[{"role":"user","content":"ping"}]}'`
- **예상 검증**:
  - All pods running (P/F)
  - Karpenter scales GPU node (P/F)
  - GPU Operator DCGM metrics (P/F)
  - vLLM /v1/models responds (P/F)
  - Gateway HTTPRoute Accepted (P/F)
  - Sample inference succeeded (P/F): 응답 200, completion 텍스트 수신
  - Langfuse trace received (P/F): Langfuse Web UI에서 trace 존재 확인
- **예상 출력**: Validation Report 테이블 (7개 항목 P/F 표시)
- **예상 최종 동작**: OVERALL Pass → "플랫폼 부트스트랩 완료. 다음 단계로 /oma:agenticops를 호출해 운영 자동화 모드를 활성화할 수 있습니다."

### 기대 산출물 (Expected Artifacts)

- `.omao/plans/platform-bootstrap-plan.md` — Terraform plan + Helm matrix
- Terraform 상태 파일 (S3 backend)
- Helm release 6개: karpenter, gpu-operator, vllm-runtime, kgateway, langfuse
- Kubernetes 매니페스트: NodePool, HTTPRoute, ExternalSecrets (또는 SealedSecrets)
- 샘플 추론 응답 로그
- Langfuse trace 스크린샷 또는 API 조회 결과

## 검증 기준 (Acceptance Criteria)

- [ ] 5-checkpoint 구조(Gather Context → Pre-flight → Plan → Execute → Validate)를 순서대로 실행했는가
- [ ] Pre-flight에서 Security Group 정책(0.0.0.0/0 금지)을 검증했는가
- [ ] Plan Approval 체크포인트에서 사용자 응답을 대기했는가
- [ ] GPU 노드풀 사이즈가 Llama-3 70B 요구사항(A100 80GB 또는 동급)을 충족했는가
- [ ] Helm 차트 설치 순서(Karpenter → GPU Operator → vLLM → kgateway → Langfuse)를 준수했는가
- [ ] vLLM 버전이 v0.18+ (PagedAttention v2 지원)인가
- [ ] kgateway 버전이 v2.0+ (Cascade routing 지원)인가
- [ ] Langfuse 버전이 v3.x (self-hosted OSS)인가
- [ ] 샘플 추론 요청이 성공하고 Langfuse trace로 수신됐는가
- [ ] 네트워킹이 ALB + 인증(Cognito/OIDC) 경유로 설정됐는가 (퍼블릭 SG 오픈 없음)

## 일반적인 실패 모드 (Common Failure Modes)

| 증상 | 원인 | 복구 |
|---|---|---|
| Pre-flight IAM 권한 실패 | EKS, EC2, IAM 권한 부족 | IAM 정책 추가 후 재실행 |
| Pre-flight 서비스 쿼타 실패 | p5/g6 인스턴스 쿼타 부족 | AWS Support에 쿼타 증가 요청 |
| Karpenter 설치 실패 | KubeConfig 접근 불가 또는 IAM OIDC 미구성 | `aws eks update-kubeconfig`, eksctl IAM OIDC 재구성 |
| GPU Operator DCGM 미동작 | GPU 노드 프로비저닝 지연 | Karpenter NodePool 재확인, Provisioner 로그 점검 |
| vLLM /v1/models 미응답 | OOM 또는 모델 로드 실패 | GPU 메모리 확인, vLLM 로그 점검 (`kubectl logs -n inference`) |
| kgateway HTTPRoute Rejected | CRD 미설치 또는 Gateway API 버전 불일치 | `kubectl get crd httproutes.gateway.networking.k8s.io`, Gateway API v1 재설치 |
| Langfuse trace 미수신 | OTel collector 미구성 또는 API key 누락 | OTel DaemonSet 재확인, Langfuse API key 배포 확인 |

## 참고 자료

- [Platform Bootstrap Workflow](../../steering/workflows/platform-bootstrap.md) — 워크플로우 정의
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) — EKS 기본 개념
- [Karpenter Documentation](https://karpenter.sh/docs/) — 오토스케일러 공식 문서
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html) — GPU 운영자
- [vLLM Documentation](https://docs.vllm.ai/) — 고성능 추론 서빙
- [kgateway Project](https://kgateway.dev/) — Inference Gateway
- [Langfuse Self-hosting Guide](https://langfuse.com/self-hosting) — LLM 관측성
- [OMA CLAUDE.md](../../CLAUDE.md) — 플러그인 카탈로그
