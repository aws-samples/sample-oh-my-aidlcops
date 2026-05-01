---
name: agentic-eks-bootstrap
description: "Bootstrap an AWS EKS cluster optimized for Agentic AI workloads — Karpenter v1.2+ GPU node pools, EKS Auto Mode, Kubernetes 1.32+ with DRA 1.35 GA, VPC CNI, GPU Operator, and baseline observability. Use when starting a new EKS cluster that will host vLLM, Inference Gateway, Langfuse, or Kagent."
argument-hint: "[cluster-name, region, expected GPU workload profile]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Bash,Grep,Glob,mcp__eks,mcp__aws-documentation,mcp__aws-iac,mcp__aws-pricing,mcp__well-architected-security"
---

## When to Use

- 신규 Agentic AI 플랫폼을 EKS 위에 구축하기 시작할 때
- 기존 EKS 클러스터를 GPU·Agent 워크로드용으로 재구성할 때
- `platform-architect` 가 "EKS 경로"를 확정한 이후 실제 클러스터 프로비저닝 단계

## When NOT to Use

- Bedrock AgentCore 또는 SageMaker Unified Studio 만 사용할 예정일 때 → 이 스킬은 불필요합니다
- 이미 Karpenter·GPU Operator 가 정상 동작하는 기존 클러스터 → `vllm-serving-setup` 으로 바로 진행
- PoC 수준의 로컬 k3d/kind 환경 → EKS 전용 기능(IRSA, Karpenter EC2 자동 프로비저닝)이 불필요

## Preconditions

- AWS CLI 및 `eksctl` v0.196+, `helm` v3.14+, `kubectl` v1.32+ 설치
- 관리자 IAM 권한 또는 EKS 클러스터 생성 가능한 Role
- 대상 리전에서 요구 GPU 인스턴스 쿼터 확인 (`p5`, `g6e`, `trn2`)

## Procedure

### Step 1. Platform 요구사항 수집
- 예상 동시 사용자/QPS, 모델 크기, SLA(지연) 값 확인
- 한국 금융권 규제 대상 여부(ISMS-P, 전자금융감독규정) 확인
- Private / Hybrid / Public 배포 스타일 결정

### Step 2. 클러스터 생성 (EKS Auto Mode 권장)
```bash
eksctl create cluster \
  --name agentic-prod \
  --region ap-northeast-2 \
  --version 1.32 \
  --auto-mode \
  --with-oidc \
  --zones ap-northeast-2a,ap-northeast-2c
```
- Auto Mode 는 Karpenter, EBS CSI, VPC CNI, CoreDNS 를 AWS 가 관리합니다
- 수동 관리를 원하면 `--node-type` 지정 + Karpenter 별도 설치

### Step 3. Karpenter GPU NodePool 생성
- `karpenter.sh/v1` API 사용, `capacity-type` 에 `on-demand` + `spot` 혼합
- `nvidia.com/gpu` taint 로 GPU 노드 격리
- `consolidation` 정책으로 idle GPU 자동 회수

### Step 4. NVIDIA GPU Operator 설치
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator --create-namespace \
  --version v24.6.2 \
  --set driver.enabled=true \
  --set toolkit.enabled=true \
  --set dcgmExporter.enabled=true
```
- Kubernetes 1.32+ 에서 DRA 1.35 GA 를 활용하려면 `--feature-gates=DynamicResourceAllocation=true`

### Step 5. 베이스라인 Addon
- AWS Load Balancer Controller (ALB/NLB)
- External Secrets Operator (IRSA + Secrets Manager)
- Prometheus Stack (kube-prometheus-stack)
- Fluent Bit → CloudWatch Logs
- Cert-Manager (ACME)

### Step 6. 보안 베이스라인
- `0.0.0.0/0` SG 오픈 금지, 내부 ALB + Cognito/OIDC 경유
- IRSA: Karpenter, GPU Operator, Langfuse 각각 전용 Role
- CIS EKS Benchmark 자동 스캔 (kube-bench)
- `well-architected-security` MCP 로 SEC-01~SEC-11 점검

### Step 7. 검증
```bash
kubectl get nodes -L karpenter.sh/nodepool,node.kubernetes.io/instance-type
kubectl -n gpu-operator get pods
kubectl get gatewayclass
kubectl get crd | grep -E 'nodepool|gpu|dra'
```

## Good Examples

- 프로덕션: `--version 1.32`, Auto Mode on, p5.48xlarge + g6e 혼합 NodePool, DCGM + Prometheus
- 하이브리드: Bedrock 매니지드 기본 + EKS burst pool (Spot 70% / On-Demand 30%)

## Bad Examples (금지)

- Security Group `0.0.0.0/0` inbound — 회사 정책 위반
- `--version 1.28` 이하 — DRA 미지원, EOL 임박
- Karpenter v0.x (legacy API) — v1 migration 필수
- GPU Operator 없이 nvidia-device-plugin 단독 사용 — DCGM 메트릭 부재

## References

- EKS GPU Node Strategy (community resource)
- GPU Resource Management (community resource)
- NVIDIA GPU Stack (community resource)
- [Karpenter v1 공식 문서](https://karpenter.sh/docs/)
- [EKS Auto Mode 공식 가이드](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [Kubernetes DRA](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/) — 1.35 GA
- 플러그인 내부: `../../references/vllm-performance-tuning.md` (GPU 메모리 사이징)
