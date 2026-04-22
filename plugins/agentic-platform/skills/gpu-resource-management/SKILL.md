---
name: gpu-resource-management
description: "Design GPU orchestration on EKS using Karpenter v1.2+ NodePools, KEDA scale-to-zero, and DRA 1.35 GA for multi-instance GPU (MIG) partitioning. Right-size NodePool for p5/g6e/trn2 instance mix, spot/on-demand split, consolidation, and topology-aware scheduling."
argument-hint: "[workload profile — training/inference, GPU mix, QPS pattern]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Bash,Grep,Glob,mcp__eks,mcp__aws-pricing,mcp__aws-documentation,mcp__prometheus"
---

## When to Use

- GPU NodePool 설계 및 Karpenter v1.2+ consolidation 정책 조정이 필요할 때
- KEDA 로 scale-to-zero, HPA 로 Pod 수준 스케일링 정책을 수립할 때
- DRA 1.35 GA 로 MIG(Multi-Instance GPU) 파티셔닝을 적용할 때
- Spot vs On-Demand 비율, Reserved Instance vs Savings Plans 구성 검토

## When NOT to Use

- CPU-only 워크로드 — 본 스킬은 GPU 전용
- Managed 환경(SageMaker endpoints) 사용 중 — 별도 스킬
- GPU Operator 미설치 — `agentic-eks-bootstrap` 선행

## Preconditions

- EKS 1.32+, Kubernetes DRA 1.35 GA 활성(`--feature-gates=DynamicResourceAllocation=true`)
- Karpenter v1.2+, NVIDIA GPU Operator, DCGM Exporter, Prometheus 설치
- 대상 리전에서 p5/g6e/trn2 쿼터 확인 완료

## Procedure

### Step 1. NodePool 설계
```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu-inference-pool
spec:
  template:
    metadata:
      labels:
        node-type: gpu-inference
        workload: genai
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["p5.48xlarge", "g6e.12xlarge", "g6e.48xlarge"]
      taints:
        - key: nvidia.com/gpu
          value: "true"
          effect: NoSchedule
      nodeClassRef:
        name: default
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
  limits:
    nvidia.com/gpu: 64
```

### Step 2. Spot / On-Demand 비율 전략
- 추론 (inference): Spot 70% + On-Demand 30%, HPA min=1 유지
- 학습 (training): Savings Plans 또는 Capacity Blocks for ML
- Reserved Instance: 24/7 baseline 워크로드에만 적용

### Step 3. KEDA ScaledObject (Scale-to-Zero)
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: vllm-scaler
  namespace: inference
spec:
  scaleTargetRef:
    name: vllm-llama3
  minReplicaCount: 0
  maxReplicaCount: 8
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus.observability.svc:9090
        metricName: vllm_num_requests_running
        threshold: "4"
        query: sum(rate(vllm_num_requests_running[1m]))
```

### Step 4. DRA 1.35 GA - MIG 파티셔닝
- H100 80GB 를 `1g.10gb` × 7 로 분할하면 소형 모델 7개 동시 서빙
- `ResourceClaim` + `DeviceClass` 리소스로 Pod 에 동적 할당
```yaml
apiVersion: resource.k8s.io/v1beta1
kind: ResourceClaimTemplate
metadata:
  name: mig-1g10gb
spec:
  spec:
    devices:
      requests:
        - name: gpu
          deviceClassName: nvidia.com/mig-1g.10gb
```

### Step 5. Topology-Aware Routing
- NCCL 통신 최소화: 같은 AZ, 같은 placement group 내 TP 그룹 배치
- `topologySpreadConstraints` 로 AZ 분산 DP, 동일 노드 내 TP

### Step 6. 비용 관측 + 알림
- Prometheus: `DCGM_FI_DEV_GPU_UTIL`, `DCGM_FI_DEV_MEM_COPY_UTIL`
- KubeCost + AWS Cost Explorer 태그
- 알림: GPU util < 20% 30분 지속 시 Slack 알림, consolidation 검토

## Good Examples

- 추론 NodePool: p5 + g6e 혼합, Spot 70%, consolidation 30s, KEDA scale-to-zero
- MIG: H100 80GB → `1g.10gb` × 7 → 7B-14B 모델 7개 동시
- DRA 1.35 로 ResourceClaim 기반 fractional GPU 할당

## Bad Examples (금지)

- Karpenter v0.x legacy API (`provisioner.karpenter.sh`) — v1 migration 필수
- 단일 인스턴스 타입 제약 — 쿼터 부족 시 Pending 무한 대기
- GPU idle 상태 방치 — Spot 인스턴스로도 비용 누수
- MIG 없이 7B 모델 7개를 동일 GPU 에 공유 (device plugin time-slicing 의존) — latency 변동

## References

- [GPU Resource Management](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/model-serving/gpu-infrastructure/gpu-resource-management.md)
- [NVIDIA GPU Stack](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/model-serving/gpu-infrastructure/nvidia-gpu-stack.md)
- [AWS Neuron Stack](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/model-serving/gpu-infrastructure/aws-neuron-stack.md)
- [Karpenter 공식 문서](https://karpenter.sh/docs/)
- [KEDA 공식 문서](https://keda.sh/docs/)
- [Kubernetes DRA 1.35 GA](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/)
- [NVIDIA MIG 가이드](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/)
- 플러그인 내부: `../../references/vllm-performance-tuning.md`
