---
name: automated-remediation
description: 알려진 장애 패턴에 대해 사전 정의된 Runbook 기반 자동 복구를 실행한다. RCA 결과 또는 incident-response의 가설을 입력으로 받아 매칭되는 remediation playbook을 선택하고, 복구 전/후 상태를 검증하며, 실패 시 에스컬레이션한다. SEV2/3만 자동 복구 대상이며 SEV1은 사람 전용이다.
argument-hint: "[incident-id or runbook-name]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus,mcp__eks"
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
- **awslabs.eks-mcp-server** — Pod restart, scale-out 등 K8s 조작.
- **awslabs.cloudwatch-mcp-server==0.0.25** — 복구 전/후 메트릭 비교.
- `incident-response` 상태 파일 접근 (`.omao/state/incident/`).
- `root-cause-analysis` 보고서 접근 (RCA 결과 기반 runbook 매칭).

## Runbook 구조

```yaml
# .omao/plans/runbooks/pod-crashloop.yaml
name: pod-crashloop
description: "Pod CrashLoopBackOff 자동 복구"
match_conditions:
  - symptom: "CrashLoopBackOff"
  - metric: "kube_pod_container_status_waiting_reason"
    value: "CrashLoopBackOff"
severity_scope: [SEV2, SEV3]
steps:
  - name: "Collect pod logs"
    action: kubectl_logs
    params:
      tail_lines: 100
  - name: "Check resource limits"
    action: kubectl_describe
    verify: "OOMKilled not in events"
  - name: "Restart pod"
    action: kubectl_delete_pod
    params:
      grace_period: 30
  - name: "Verify recovery"
    action: wait_for_ready
    params:
      timeout_sec: 120
rollback:
  action: scale_previous_revision
max_retries: 2
escalation_on_failure: SEV2
```

## 실행 흐름

### Step 1: Runbook Matching

인시던트의 증상/RCA 결과를 기반으로 적합한 runbook을 선택합니다.

```python
def match_runbook(incident: dict, runbooks_dir: str) -> dict | None:
    """인시던트 증상과 매칭되는 runbook 검색."""
    symptom = incident.get("symptom", "")
    rca_category = incident.get("rca_category", "")
    
    for runbook_file in glob(f"{runbooks_dir}/*.yaml"):
        runbook = yaml.safe_load(open(runbook_file))
        for condition in runbook["match_conditions"]:
            if condition.get("symptom") and condition["symptom"] in symptom:
                return runbook
            if condition.get("rca_category") == rca_category:
                return runbook
    return None
```

### Step 2: Pre-flight Validation

복구 실행 전 안전 조건을 검증합니다.

```python
def preflight_check(incident: dict, runbook: dict) -> dict:
    """복구 실행 전 안전 조건 검증."""
    checks = {
        "severity_in_scope": incident["severity"] in runbook["severity_scope"],
        "no_active_sev1": not has_active_sev1(),
        "deploy_not_in_progress": not is_deploy_active(),
        "retry_budget_available": get_retry_count(incident["id"]) < runbook["max_retries"],
    }
    return {
        "pass": all(checks.values()),
        "checks": checks,
    }
```

### Step 3: Execute Remediation Steps

Runbook의 각 step을 순차 실행하며 중간 검증을 수행합니다.

### Step 4: Post-Remediation Verification

복구 후 메트릭이 정상 범위로 복귀했는지 확인합니다.

```python
def verify_recovery(incident: dict, timeout_sec: int = 300) -> dict:
    """복구 후 정상 상태 복귀 확인."""
    # 복구 전 메트릭 스냅샷과 비교
    pre_metrics = load_pre_remediation_snapshot(incident["id"])
    post_metrics = fetch_current_metrics(incident["target"])
    
    return {
        "recovered": is_within_baseline(post_metrics),
        "metrics_comparison": compare(pre_metrics, post_metrics),
        "verification_time": datetime.utcnow().isoformat() + "Z",
    }
```

### Step 5: Feedback Loop

복구 성공/실패 결과를 학습하여 runbook을 개선합니다.

## 안전 장치

| 장치 | 설명 |
|------|------|
| **SEV1 차단** | SEV1 인시던트는 절대 자동 복구하지 않음 |
| **Retry 제한** | runbook별 max_retries 초과 시 에스컬레이션 |
| **Blast radius 제한** | 동시에 영향받는 Pod/서비스 수 상한 (기본 3) |
| **Rollback 필수** | 모든 runbook에 rollback 절차 정의 필수 |
| **Human override** | 자동 복구 중 사람이 `/stop-remediation` 으로 즉시 중단 가능 |

## 상태 관리

- `.omao/state/remediation/${incident-id}/` — 복구 실행 상태
  - `execution.jsonl` — step별 실행 로그
  - `pre-snapshot.json` — 복구 전 메트릭 스냅샷
  - `post-snapshot.json` — 복구 후 메트릭 스냅샷
  - `result.json` — 최종 결과 (success/failure/escalated)
- `.omao/plans/runbooks/` — Runbook 정의
- `.omao/plans/runbooks/effectiveness.yaml` — Runbook별 성공률 통계

## 기존 스킬 연동

| 연동 대상 | 방향 | 설명 |
|-----------|------|------|
| `incident-response` | ← 입력 | SEV2/3 인시던트 및 가설을 입력으로 수신 |
| `root-cause-analysis` | ← 입력 | RCA 결과 기반 runbook 매칭 |
| `anomaly-detection` | ← 입력 | 재발 패턴 탐지 시 자동 복구 트리거 |
| `self-improving-loop` | → 출력 | 복구 실패 패턴을 runbook 개선 신호로 전달 |
| `autopilot-deploy` | ↔ 양방향 | 배포 중 복구 차단 / 복구 후 배포 재개 신호 |
| `audit-trail` | → 출력 | 모든 복구 실행을 감사 로그에 기록 |

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
