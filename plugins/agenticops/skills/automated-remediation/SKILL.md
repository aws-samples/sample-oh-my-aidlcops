---
name: automated-remediation
description: 알려진 장애 패턴에 대해 사전 정의된 Runbook 기반 자동 복구를 실행한다. RCA 결과 또는 incident-response의 가설을 입력으로 받아 매칭되는 remediation playbook을 선택하고, 복구 전/후 상태를 검증하며, 실패 시 에스컬레이션한다. SEV2/3만 자동 복구 대상이며 SEV1은 사람 전용이다.
argument-hint: "[incident-id or runbook-name]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus,mcp__eks"
ontology:
  consumes: [Incident]
  references: [Deployment]
---

## When to Use

- `root-cause-analysis`가 근본 원인을 식별하고 알려진 패턴과 매칭될 때
- `incident-response`가 SEV2/3 인시던트를 분류하고 runbook이 존재할 때
- `anomaly-detection`이 이전에 자동 복구로 해결된 패턴을 재탐지할 때
- 사용자가 명시적으로 특정 runbook 실행을 요청할 때

사용 제외:

- **SEV1 인시던트** — 사람만 remediation 실행 가능 (본 skill은 진단 보조만)
- 매칭되는 runbook이 없는 미지의 장애 패턴
- 복구 대상 리소스에 대한 write 권한이 없는 경우

## Prerequisites

- **Runbook 저장소**: `.omao/plans/runbooks/` 에 패턴별 `${pattern-name}.yaml` 형식.
- **awslabs.eks-mcp-server==0.1.28** — EKS 클러스터 상태 조회 전용 (`@latest` 금지, PyPI 버전 pin 필수). Write 작업(Pod 삭제, eviction, scale 변경)은 EKS MCP가 아닌 `kubectl` Bash 명령으로 실행하며, EKS MCP는 read-only 기본값을 유지합니다.
- **awslabs.cloudwatch-mcp-server==0.0.25** — 복구 전/후 메트릭 비교.
- **awslabs.prometheus-mcp-server==0.2.15** — 복구 검증 메트릭 조회.
- `incident-response` 상태 파일 접근 (`.omao/state/incident/`).
- `root-cause-analysis` 보고서 접근 (RCA 결과 기반 runbook 매칭).

## Runbook 구조

```yaml
# .omao/plans/runbooks/pod-crashloop.yaml
name: pod-crashloop
description: "Pod CrashLoopBackOff 자동 복구"
version: "1.0.0"
match_conditions:
  - symptom: "CrashLoopBackOff"
  - k8s_event: "BackOff"
  - metric: "kube_pod_container_status_waiting_reason"
    value: "CrashLoopBackOff"
severity_scope: [SEV2, SEV3]
steps:
  - name: "Collect pod logs"
    action: kubectl_logs
    params:
      tail_lines: 100
    timeout_sec: 30
  - name: "Check resource limits"
    action: kubectl_describe
    verify: "OOMKilled not in events"
  - name: "Delete and recreate pod"
    action: kubectl_delete_pod
    params:
      grace_period: 30
  - name: "Verify recovery"
    action: wait_for_ready
    params:
      timeout_sec: 120
      check_interval_sec: 10
rollback:
  action: scale_previous_revision
  params:
    revision: "previous"
max_retries: 2
cooldown_minutes: 15
escalation_on_failure: SEV2
tags: [kubernetes, pod, crashloop]
```

```yaml
# .omao/plans/runbooks/canary-rollback.yaml
name: canary-rollback
description: "Canary 배포 실패 시 이전 버전으로 롤백"
version: "1.0.0"
match_conditions:
  - rca_category: "deployment"
  - symptom: "canary_gate_failure"
  - metric: "agent_request_errors_total"
    condition: "rate > 2x baseline"
severity_scope: [SEV2, SEV3]
steps:
  - name: "Identify current canary revision"
    action: kubectl_get_revision
    params:
      resource: "deployment"
  - name: "Scale down canary"
    action: kubectl_scale
    params:
      replicas: 0
      target: "canary"
  - name: "Verify stable version healthy"
    action: wait_for_ready
    params:
      target: "stable"
      timeout_sec: 60
  - name: "Update ArgoCD application"
    action: argocd_rollback
    params:
      revision: "previous"
  - name: "Verify rollback complete"
    action: wait_for_ready
    params:
      timeout_sec: 180
rollback:
  action: manual_escalation
  reason: "Rollback itself failed"
max_retries: 1
cooldown_minutes: 30
escalation_on_failure: SEV1
tags: [deployment, canary, rollback]
```

```yaml
# .omao/plans/runbooks/memory-pressure.yaml
name: memory-pressure
description: "Node memory pressure 자동 대응"
version: "1.0.0"
match_conditions:
  - symptom: "MemoryPressure"
  - k8s_event: "EvictionThresholdMet"
  - metric: "node_memory_MemAvailable_bytes"
    condition: "< 10%"
severity_scope: [SEV2, SEV3]
steps:
  - name: "Identify memory-heavy pods"
    action: kubectl_top_pods
    params:
      sort_by: memory
      limit: 10
  - name: "Evict non-critical pods"
    action: kubectl_evict
    params:
      priority_class_below: "high-priority"
      max_evictions: 3
  - name: "Verify memory recovered"
    action: check_metric
    params:
      metric: "node_memory_MemAvailable_bytes"
      condition: "> 20%"
      timeout_sec: 120
rollback:
  action: cordon_and_drain
  params:
    node: "affected"
max_retries: 2
cooldown_minutes: 10
escalation_on_failure: SEV2
tags: [kubernetes, node, memory]
```

## 안전 장치

| 장치 | 설명 |
|------|------|
| **SEV1 차단** | SEV1 인시던트는 절대 자동 복구하지 않음. 시도 시 OPERATIONS-06 blocking finding |
| **Retry 제한** | runbook별 `max_retries` 초과 시 자동 에스컬레이션 |
| **Cooldown** | 동일 runbook 재실행 간 최소 대기 시간 (`cooldown_minutes`) |
| **Blast radius 제한** | 동시에 영향받는 Pod/서비스 수 상한 (기본 3) |
| **Rollback 필수** | 모든 runbook에 `rollback` 절차 정의 필수. 미정의 시 OPERATIONS-08 |
| **Human override** | 자동 복구 중 사람이 `/stop-remediation` 으로 즉시 중단 가능 |
| **Deploy freeze 연동** | `autopilot-deploy` freeze 상태에서는 배포 관련 복구만 허용 |

## 실행 흐름

### Step 1: Runbook Matching

인시던트의 증상/RCA 결과를 기반으로 적합한 runbook을 선택합니다.

```python
import os
import yaml
import json
from glob import glob
from datetime import datetime, timedelta
from dataclasses import dataclass, field

@dataclass
class RunbookMatch:
    runbook: dict
    match_score: float
    matched_conditions: list[str]

def match_runbook(incident: dict, runbooks_dir: str = ".omao/plans/runbooks") -> RunbookMatch | None:
    """인시던트 증상과 매칭되는 runbook 검색.
    
    매칭 우선순위:
    1. rca_category 정확 매칭 (score 1.0)
    2. symptom 키워드 매칭 (score 0.8)
    3. metric condition 매칭 (score 0.6)
    4. k8s_event 매칭 (score 0.7)
    """
    symptom = incident.get("symptom", "")
    rca_category = incident.get("rca_category", "")
    severity = incident.get("severity", "SEV3")
    k8s_events = incident.get("k8s_events", [])
    
    best_match = None
    best_score = 0.0
    
    for runbook_file in glob(f"{runbooks_dir}/*.yaml"):
        with open(runbook_file) as f:
            runbook = yaml.safe_load(f)
        
        # Severity scope 확인
        if severity not in runbook.get("severity_scope", []):
            continue
        
        score = 0.0
        matched = []
        
        for condition in runbook.get("match_conditions", []):
            if condition.get("rca_category") and condition["rca_category"] == rca_category:
                score = max(score, 1.0)
                matched.append(f"rca_category={rca_category}")
            
            if condition.get("symptom") and condition["symptom"].lower() in symptom.lower():
                score = max(score, 0.8)
                matched.append(f"symptom contains '{condition['symptom']}'")
            
            if condition.get("k8s_event"):
                for event in k8s_events:
                    if condition["k8s_event"] in event:
                        score = max(score, 0.7)
                        matched.append(f"k8s_event={condition['k8s_event']}")
        
        if score > best_score:
            best_score = score
            best_match = RunbookMatch(
                runbook=runbook,
                match_score=score,
                matched_conditions=matched,
            )
    
    return best_match if best_match and best_match.match_score >= 0.6 else None
```

### Step 2: Pre-flight Validation

복구 실행 전 안전 조건을 검증합니다.

```python
@dataclass
class PreflightResult:
    passed: bool
    checks: dict[str, bool]
    block_reason: str | None = None

def preflight_check(incident: dict, runbook: dict) -> PreflightResult:
    """복구 실행 전 안전 조건 검증.
    
    모든 조건이 통과해야 복구를 실행합니다.
    하나라도 실패하면 사유를 명시하고 중단합니다.
    """
    checks = {}
    
    # 1. SEV1 차단
    checks["severity_not_sev1"] = incident.get("severity") != "SEV1"
    
    # 2. Severity scope 확인
    checks["severity_in_scope"] = incident.get("severity") in runbook.get("severity_scope", [])
    
    # 3. 활성 SEV1 없음 (SEV1 진행 중이면 모든 자동 복구 중단)
    checks["no_active_sev1"] = not has_active_sev1()
    
    # 4. 배포 진행 중 아님 (배포 관련 runbook 제외)
    if "deployment" not in runbook.get("tags", []):
        checks["deploy_not_in_progress"] = not is_deploy_active()
    else:
        checks["deploy_not_in_progress"] = True
    
    # 5. Retry 예산 확인
    retry_count = get_retry_count(incident["id"], runbook["name"])
    checks["retry_budget_available"] = retry_count < runbook.get("max_retries", 2)
    
    # 6. Cooldown 확인
    checks["cooldown_elapsed"] = is_cooldown_elapsed(
        incident["id"], runbook["name"], runbook.get("cooldown_minutes", 15)
    )
    
    # 7. Rollback 정의 확인
    checks["rollback_defined"] = "rollback" in runbook and runbook["rollback"] is not None
    
    passed = all(checks.values())
    block_reason = None
    if not passed:
        failed = [k for k, v in checks.items() if not v]
        block_reason = f"Pre-flight failed: {', '.join(failed)}"
    
    return PreflightResult(passed=passed, checks=checks, block_reason=block_reason)


def has_active_sev1() -> bool:
    """활성 SEV1 인시던트 존재 여부."""
    incident_dir = ".omao/state/incident"
    if not os.path.exists(incident_dir):
        return False
    for d in os.listdir(incident_dir):
        if d.startswith("sev1-"):
            result_file = os.path.join(incident_dir, d, "result.json")
            if not os.path.exists(result_file):
                return True  # 결과 없음 = 아직 진행 중
    return False


def is_deploy_active() -> bool:
    """autopilot-deploy 진행 중 여부."""
    state_file = ".omao/state/autopilot-deploy/current.json"
    if not os.path.exists(state_file):
        return False
    with open(state_file) as f:
        state = json.load(f)
    return state.get("status") == "in_progress"


def get_retry_count(incident_id: str, runbook_name: str) -> int:
    """동일 인시던트+runbook 조합의 재시도 횟수."""
    exec_dir = f".omao/state/remediation/{incident_id}"
    if not os.path.exists(exec_dir):
        return 0
    count = 0
    for f in os.listdir(exec_dir):
        if f.startswith(runbook_name) and f.endswith(".json"):
            count += 1
    return count


def is_cooldown_elapsed(incident_id: str, runbook_name: str, 
                        cooldown_minutes: int) -> bool:
    """마지막 실행 이후 cooldown 경과 여부."""
    exec_dir = f".omao/state/remediation/{incident_id}"
    if not os.path.exists(exec_dir):
        return True
    
    latest_time = None
    for f in sorted(os.listdir(exec_dir), reverse=True):
        if f.startswith(runbook_name):
            filepath = os.path.join(exec_dir, f)
            with open(filepath) as fh:
                data = json.load(fh)
            latest_time = datetime.fromisoformat(data.get("completed_at", "").replace("Z", "+00:00"))
            break
    
    if latest_time is None:
        return True
    
    elapsed = datetime.utcnow() - latest_time.replace(tzinfo=None)
    return elapsed > timedelta(minutes=cooldown_minutes)
```

### Step 3: Execute Remediation Steps

Runbook의 각 step을 순차 실행하며 중간 검증을 수행합니다.

```python
@dataclass
class StepResult:
    step_name: str
    action: str
    status: str  # success, failed, skipped
    output: str
    duration_sec: float
    timestamp: str

@dataclass
class RemediationExecution:
    incident_id: str
    runbook_name: str
    started_at: str
    steps: list[StepResult] = field(default_factory=list)
    status: str = "in_progress"  # in_progress, success, failed, rolled_back
    completed_at: str | None = None

def execute_remediation(incident: dict, runbook: dict) -> RemediationExecution:
    """Runbook의 각 step을 순차 실행."""
    execution = RemediationExecution(
        incident_id=incident["id"],
        runbook_name=runbook["name"],
        started_at=datetime.utcnow().isoformat() + "Z",
    )
    
    # Pre-snapshot 저장
    pre_snapshot = capture_metrics_snapshot(incident)
    save_snapshot(incident["id"], "pre-snapshot.json", pre_snapshot)
    
    for step in runbook["steps"]:
        step_start = datetime.utcnow()
        
        try:
            output = execute_step(step, incident)
            
            # Step 내 verify 조건 확인
            if "verify" in step:
                if not verify_condition(step["verify"], output):
                    raise Exception(f"Verification failed: {step['verify']}")
            
            result = StepResult(
                step_name=step["name"],
                action=step["action"],
                status="success",
                output=output,
                duration_sec=(datetime.utcnow() - step_start).total_seconds(),
                timestamp=datetime.utcnow().isoformat() + "Z",
            )
        except Exception as e:
            result = StepResult(
                step_name=step["name"],
                action=step["action"],
                status="failed",
                output=str(e),
                duration_sec=(datetime.utcnow() - step_start).total_seconds(),
                timestamp=datetime.utcnow().isoformat() + "Z",
            )
            execution.steps.append(result)
            execution.status = "failed"
            break
        
        execution.steps.append(result)
    
    if execution.status != "failed":
        execution.status = "success"
    
    execution.completed_at = datetime.utcnow().isoformat() + "Z"
    return execution


def execute_step(step: dict, incident: dict) -> str:
    """개별 step 실행. action 타입에 따라 분기."""
    action = step["action"]
    params = step.get("params", {})
    timeout = step.get("timeout_sec", 60)
    
    if action == "kubectl_get_revision":
        # kubectl rollout history deployment/...
        return f"Current revision identified for {params.get('resource', 'deployment')}"
    
    elif action == "kubectl_logs":
        # mcp__eks__get_pod_logs(...)
        return f"Collected {params.get('tail_lines', 100)} lines of logs"
    
    elif action == "kubectl_describe":
        # mcp__eks__manage_k8s_resource(operation='read', ...)
        return "Pod description retrieved"
    
    elif action == "kubectl_delete_pod":
        # mcp__eks__manage_k8s_resource(operation='delete', ...)
        return f"Pod deleted with grace period {params.get('grace_period', 30)}s"
    
    elif action == "kubectl_scale":
        # mcp__eks__manage_k8s_resource(operation='patch', ...)
        return f"Scaled to {params.get('replicas')} replicas"
    
    elif action == "wait_for_ready":
        # Poll pod status until ready or timeout
        return f"Pod ready within {timeout}s"
    
    elif action == "kubectl_top_pods":
        # mcp__eks__list_k8s_resources + metrics
        return "Top pods by memory retrieved"
    
    elif action == "kubectl_evict":
        # mcp__eks__manage_k8s_resource(operation='create', kind='Eviction')
        return f"Evicted {params.get('max_evictions', 1)} pods"
    
    elif action == "check_metric":
        # mcp__prometheus__query or mcp__cloudwatch__get_metric_data
        return f"Metric check: {params.get('condition')}"
    
    elif action == "argocd_rollback":
        # kubectl patch application ...
        return f"ArgoCD rollback to {params.get('revision', 'previous')}"
    
    else:
        raise ValueError(f"Unknown action: {action}")
```

### Step 4: Post-Remediation Verification

복구 후 메트릭이 정상 범위로 복귀했는지 확인합니다.

```python
def verify_recovery(incident: dict, execution: RemediationExecution,
                    wait_sec: int = 120) -> dict:
    """복구 후 정상 상태 복귀 확인.
    
    Pre-snapshot과 비교하여 메트릭이 정상 범위로 돌아왔는지 검증합니다.
    """
    import time
    time.sleep(min(wait_sec, 30))  # 최소 30초 대기
    
    # Post-snapshot 캡처
    post_snapshot = capture_metrics_snapshot(incident)
    save_snapshot(incident["id"], "post-snapshot.json", post_snapshot)
    
    # Pre-snapshot 로드
    pre_snapshot = load_snapshot(incident["id"], "pre-snapshot.json")
    
    # 비교
    recovery_checks = []
    for metric_name in pre_snapshot:
        pre_val = pre_snapshot[metric_name]
        post_val = post_snapshot.get(metric_name)
        
        if post_val is None:
            recovery_checks.append({"metric": metric_name, "status": "unknown"})
            continue
        
        # 정상 범위 판정: baseline 로드
        baseline = load_baseline(metric_name)
        if baseline:
            is_normal = baseline["lower_bound"] <= post_val <= baseline["upper_bound"]
        else:
            # Baseline 없으면 pre 대비 개선 여부로 판단
            is_normal = abs(post_val) <= abs(pre_val)
        
        recovery_checks.append({
            "metric": metric_name,
            "pre_value": pre_val,
            "post_value": post_val,
            "within_baseline": is_normal,
            "status": "recovered" if is_normal else "not_recovered",
        })
    
    all_recovered = all(c["status"] == "recovered" for c in recovery_checks if c["status"] != "unknown")
    
    return {
        "recovered": all_recovered,
        "checks": recovery_checks,
        "verification_time": datetime.utcnow().isoformat() + "Z",
    }


def capture_metrics_snapshot(incident: dict) -> dict:
    """현재 시점의 관련 메트릭 스냅샷 캡처."""
    target = incident.get("target_service", "unknown")
    snapshot = {}
    
    # Prometheus 메트릭
    # error_rate = mcp__prometheus__query(f'rate(agent_request_errors_total{{service="{target}"}}[5m])')
    # latency = mcp__prometheus__query(f'histogram_quantile(0.99, ...)')
    
    snapshot["error_rate"] = 0.0  # placeholder
    snapshot["p99_latency_ms"] = 0.0
    snapshot["pod_ready_count"] = 0
    
    return snapshot
```

### Step 5: Rollback (실패 시)

복구 실패 시 rollback 절차를 실행합니다.

```python
def execute_rollback(incident: dict, runbook: dict, 
                     execution: RemediationExecution) -> dict:
    """복구 실패 시 rollback 실행."""
    rollback_config = runbook.get("rollback", {})
    
    if not rollback_config:
        return {"status": "no_rollback_defined", "escalated": True}
    
    action = rollback_config.get("action")
    params = rollback_config.get("params", {})
    
    try:
        if action == "scale_previous_revision":
            # kubectl rollout undo deployment/...
            output = "Rolled back to previous revision"
        elif action == "cordon_and_drain":
            # kubectl cordon + drain
            output = "Node cordoned and drained"
        elif action == "manual_escalation":
            reason = rollback_config.get("reason", "Rollback requires manual intervention")
            return {"status": "escalated", "reason": reason}
        else:
            output = f"Executed rollback action: {action}"
        
        execution.status = "rolled_back"
        return {"status": "rolled_back", "output": output}
    
    except Exception as e:
        return {"status": "rollback_failed", "error": str(e), "escalated": True}
```

### Step 6: Result Recording & Feedback

실행 결과를 기록하고 후속 조치를 트리거합니다.

```python
def record_result(execution: RemediationExecution, 
                  verification: dict, incident: dict, runbook: dict):
    """실행 결과 기록 및 후속 조치 트리거."""
    result_dir = f".omao/state/remediation/{execution.incident_id}"
    os.makedirs(result_dir, exist_ok=True)
    
    result = {
        "incident_id": execution.incident_id,
        "runbook_name": execution.runbook_name,
        "started_at": execution.started_at,
        "completed_at": execution.completed_at,
        "status": execution.status,
        "steps": [vars(s) for s in execution.steps],
        "verification": verification,
    }
    
    timestamp = execution.started_at.replace(":", "-").replace(".", "-")
    result_file = os.path.join(result_dir, f"{execution.runbook_name}-{timestamp}.json")
    with open(result_file, "w") as f:
        json.dump(result, f, indent=2)
    
    # 후속 조치
    if execution.status == "success" and verification.get("recovered"):
        # 성공: effectiveness 통계 업데이트
        update_effectiveness(runbook["name"], success=True)
    
    elif execution.status == "failed":
        # 실패: 에스컬레이션
        escalation_severity = runbook.get("escalation_on_failure", "SEV2")
        trigger_escalation(incident, escalation_severity, execution)
        update_effectiveness(runbook["name"], success=False)
    
    # self-improving-loop에 피드백
    if execution.status == "failed":
        notify_self_improving(execution)


def update_effectiveness(runbook_name: str, success: bool):
    """Runbook 성공률 통계 업데이트."""
    stats_file = ".omao/plans/runbooks/effectiveness.yaml"
    
    if os.path.exists(stats_file):
        with open(stats_file) as f:
            stats = yaml.safe_load(f) or {"runbooks": {}}
    else:
        stats = {"runbooks": {}}
    
    if runbook_name not in stats["runbooks"]:
        stats["runbooks"][runbook_name] = {"total": 0, "success": 0, "failure": 0}
    
    stats["runbooks"][runbook_name]["total"] += 1
    if success:
        stats["runbooks"][runbook_name]["success"] += 1
    else:
        stats["runbooks"][runbook_name]["failure"] += 1
    
    # 성공률 계산
    total = stats["runbooks"][runbook_name]["total"]
    succ = stats["runbooks"][runbook_name]["success"]
    stats["runbooks"][runbook_name]["success_rate"] = round(succ / total, 3) if total > 0 else 0
    
    with open(stats_file, "w") as f:
        yaml.dump(stats, f, default_flow_style=False)
```

## 상태 관리

- `.omao/state/remediation/${incident-id}/` — 복구 실행 상태
  - `${runbook-name}-${timestamp}.json` — 실행 결과
  - `pre-snapshot.json` — 복구 전 메트릭 스냅샷
  - `post-snapshot.json` — 복구 후 메트릭 스냅샷
- `.omao/plans/runbooks/` — Runbook 정의
- `.omao/plans/runbooks/effectiveness.yaml` — Runbook별 성공률 통계

## Example Inputs/Outputs

**Input**: `/automated-remediation sev2-20260508-1405`

**Output (success)**:

```
[14:07:00Z] Starting automated remediation for: sev2-20260508-1405
[14:07:00Z] Loading incident state...
             Severity: SEV2
             Symptom: CrashLoopBackOff on rag-qa-agent-7f8b9c-x4k2p
             RCA category: deployment

[14:07:01Z] Step 1: Runbook Matching
             Match: pod-crashloop (score=0.80)
             Matched conditions: symptom contains 'CrashLoopBackOff', k8s_event=BackOff

[14:07:01Z] Step 2: Pre-flight Validation
             ✓ severity_not_sev1: true
             ✓ severity_in_scope: true (SEV2 in [SEV2, SEV3])
             ✓ no_active_sev1: true
             ✓ deploy_not_in_progress: true
             ✓ retry_budget_available: true (0/2 used)
             ✓ cooldown_elapsed: true (no previous execution)
             ✓ rollback_defined: true
             Pre-flight: PASS

[14:07:02Z] Step 3: Executing Remediation
             Pre-snapshot captured: error_rate=0.15, p99=890ms, pods_ready=2/3
             
             [1/4] Collect pod logs → SUCCESS (2.1s)
                   Found: "OOMKilled" in recent events
             [2/4] Check resource limits → SUCCESS (1.5s)
                   Memory limit: 512Mi, actual usage peak: 498Mi
             [3/4] Delete and recreate pod → SUCCESS (32s)
                   Pod rag-qa-agent-7f8b9c-x4k2p deleted, new pod scheduling...
             [4/4] Verify recovery → SUCCESS (45s)
                   New pod rag-qa-agent-7f8b9c-m9n3q Running and Ready

[14:08:25Z] Step 4: Post-Remediation Verification
             Post-snapshot: error_rate=0.01, p99=380ms, pods_ready=3/3
             Recovery checks:
               error_rate    : 0.15 → 0.01 (within baseline) ✓
               p99_latency   : 890ms → 380ms (within baseline) ✓
               pod_ready     : 2/3 → 3/3 ✓
             Verdict: RECOVERED

[14:08:25Z] Result: SUCCESS
             Duration: 85s
             Effectiveness updated: pod-crashloop success_rate=0.875 (7/8)
```

**Output (failure + rollback)**:

```
[14:07:00Z] Starting automated remediation for: sev2-20260508-1520
[14:07:01Z] Match: canary-rollback (score=1.00)

[14:07:02Z] Step 3: Executing Remediation
             [1/5] Identify current canary revision → SUCCESS
             [2/5] Scale down canary → SUCCESS
             [3/5] Verify stable version healthy → FAILED (timeout after 60s)
                   Error: stable pods not reaching Ready state

[14:08:05Z] Remediation FAILED at step 3/5
[14:08:05Z] Executing rollback: manual_escalation
             Reason: "Rollback itself failed"
[14:08:05Z] Escalating to SEV1 — both canary and stable unhealthy
[14:08:05Z] Effectiveness updated: canary-rollback success_rate=0.667 (4/6)
```

**Output (SEV1 blocked)**:

```
[14:07:00Z] Starting automated remediation for: sev1-20260508-1400
[14:07:00Z] Step 2: Pre-flight Validation
             ✗ severity_not_sev1: FALSE
             Pre-flight: BLOCKED
             Reason: SEV1 incidents require human remediation.
             Action: No automated remediation executed. Human responder in control.
```

## 기존 스킬 연동

| 연동 대상 | 방향 | 설명 |
|-----------|------|------|
| `incident-response` | ← 입력 | SEV2/3 인시던트 및 가설을 입력으로 수신 |
| `root-cause-analysis` | ← 입력 | RCA 결과 기반 runbook 매칭 |
| `anomaly-detection` | ← 입력 | 재발 패턴 탐지 시 자동 복구 트리거 |
| `self-improving-loop` | → 출력 | 복구 실패 패턴을 runbook 개선 신호로 전달 |
| `autopilot-deploy` | ↔ 양방향 | 배포 중 복구 차단 / 복구 후 배포 재개 신호 |
| `audit-trail` | → 출력 | 모든 복구 실행을 감사 로그에 기록 |
| `slo-management` | ← 입력 | SLO 위반 인시던트의 자동 복구 요청 수신 |

## 참고 자료

### 공식 문서

- [AWS Systems Manager Automation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation.html) — 자동 복구 참고
- [Kubernetes — Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/) — Pod 상태 관리
- [AWS FIS (Fault Injection Service)](https://docs.aws.amazon.com/fis/latest/userguide/) — 장애 주입 테스트

### 기술 블로그

- [Google SRE — Automating Away Toil](https://sre.google/sre-book/eliminating-toil/) — 자동화 원칙
- [PagerDuty — Automated Diagnostics](https://www.pagerduty.com/platform/automation/diagnostics/) — 자동 진단 패턴

### 관련 문서 (내부)

- [incident-response skill](../incident-response/SKILL.md) — 인시던트 소스
- [root-cause-analysis skill](../root-cause-analysis/SKILL.md) — RCA 결과 소스
- [anomaly-detection skill](../anomaly-detection/SKILL.md) — 재발 패턴 트리거
- [self-improving-loop skill](../self-improving-loop/SKILL.md) — 실패 피드백 수신자
