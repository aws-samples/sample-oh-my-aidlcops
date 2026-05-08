---
name: root-cause-analysis
description: 인시던트 발생 시 관련 메트릭·로그·이벤트·변경 이력을 자동 수집하고 인과 관계를 추론하여 근본 원인을 식별한다. 타임라인 기반 이벤트 상관관계 분석, 변경-장애 매핑, 의존성 그래프 탐색을 수행하며 RCA 보고서를 자동 생성한다.
argument-hint: "[incident-id or symptom description]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus,mcp__eks"
---

## When to Use

- `incident-response`가 SEV1~3 인시던트를 분류한 직후, 근본 원인 분석이 필요할 때
- `anomaly-detection`이 Critical anomaly를 탐지하고 원인 추적이 필요할 때
- Post-mortem 작성을 위해 인시던트의 인과 관계를 체계적으로 정리할 때
- 반복 발생하는 인시던트의 공통 원인 패턴을 식별할 때

사용 제외:

- 원인이 명확한 단순 장애 (예: 인증서 만료, 디스크 풀)
- 진단 데이터가 전혀 없는 환경 (MCP 데이터 레이어 부재)

## Prerequisites

- **awslabs.cloudwatch-mcp-server==0.0.25** — 로그/메트릭 조회.
- **awslabs.prometheus-mcp-server==0.2.15** — 시계열 쿼리.
- **awslabs.eks-mcp-server** — EKS 클러스터 이벤트/리소스 조회.
- `incident-response`가 생성한 인시던트 상태 파일 (`.omao/state/incident/`).
- 변경 이력 소스: Git log, ArgoCD sync history, CloudTrail.
- 서비스 의존성 맵: `.omao/plans/observability/dependency-map.yaml`.

## RCA 방법론: 5-Why + Evidence Chain

### Phase 1: Evidence Collection (자동)

인시던트 시점 ±30분의 데이터를 자동 수집합니다.

```python
from dataclasses import dataclass
from datetime import datetime, timedelta

@dataclass
class EvidenceWindow:
    incident_time: datetime
    start: datetime  # incident_time - 30min
    end: datetime    # incident_time + 30min

def collect_evidence(incident_id: str, window: EvidenceWindow) -> dict:
    """인시던트 관련 증거를 다차원으로 수집."""
    return {
        "metrics": fetch_metrics(window),        # CloudWatch + Prometheus
        "logs": fetch_logs(window),              # CloudWatch Logs
        "events": fetch_k8s_events(window),      # EKS events
        "changes": fetch_change_history(window), # Git + ArgoCD + CloudTrail
        "dependencies": load_dependency_map(),   # 서비스 의존성
    }
```

### Phase 2: Timeline Reconstruction

수집된 이벤트를 시간순으로 정렬하여 인과 관계 후보를 식별합니다.

```python
def build_timeline(evidence: dict) -> list[dict]:
    """모든 이벤트를 단일 타임라인으로 병합."""
    events = []
    for source, data in evidence.items():
        for item in data:
            events.append({
                "timestamp": item["timestamp"],
                "source": source,
                "description": item["description"],
                "severity": item.get("severity", "info"),
            })
    return sorted(events, key=lambda x: x["timestamp"])
```

### Phase 3: Change-Incident Correlation

장애 시점 이전 변경 이력과의 상관관계를 분석합니다.

```python
def correlate_changes(timeline: list, incident_time: datetime) -> list[dict]:
    """장애 시점 이전 변경 이벤트를 후보 원인으로 식별."""
    candidates = []
    for event in timeline:
        if event["source"] == "changes" and event["timestamp"] < incident_time:
            time_delta = (incident_time - event["timestamp"]).total_seconds()
            candidates.append({
                "change": event,
                "time_before_incident_sec": time_delta,
                "correlation_score": 1.0 / (1 + time_delta / 3600),  # 시간 근접도
            })
    return sorted(candidates, key=lambda x: -x["correlation_score"])
```

### Phase 4: Dependency Graph Traversal

장애 서비스의 upstream/downstream 의존성을 탐색하여 전파 경로를 추적합니다.

### Phase 5: RCA Report Generation

분석 결과를 구조화된 보고서로 생성합니다.

## RCA 보고서 구조

```markdown
# RCA Report — {incident-id}

## Summary
- **Root Cause**: {1문장 요약}
- **Confidence**: {high/medium/low}
- **Category**: {deployment|infrastructure|dependency|configuration|unknown}

## Timeline
| Timestamp | Source | Event |
|-----------|--------|-------|
| ... | ... | ... |

## Evidence Chain
1. {첫 번째 증거} → {인과 관계} → {두 번째 증거}
2. ...

## Contributing Factors
- ...

## Recommendations
- [ ] 단기 조치: ...
- [ ] 장기 조치: ...
```

## 상태 관리

- `.omao/state/incident/${id}/rca-report.md` — RCA 보고서
- `.omao/state/incident/${id}/evidence/` — 수집된 증거 raw 데이터
- `.omao/state/incident/${id}/timeline.jsonl` — 재구성된 타임라인
- `.omao/plans/observability/rca-patterns.yaml` — 반복 패턴 학습 결과

## 기존 스킬 연동

| 연동 대상 | 방향 | 설명 |
|-----------|------|------|
| `incident-response` | ← 입력 | 인시던트 분류 결과 및 가설을 입력으로 수신 |
| `anomaly-detection` | ← 입력 | Critical anomaly 이벤트를 RCA 트리거로 수신 |
| `self-improving-loop` | → 출력 | RCA 결과가 "prompt 품질"이면 개선 루프 트리거 |
| `automated-remediation` | → 출력 | RCA 완료 후 remediation 실행 트리거 |
| `audit-trail` | → 출력 | RCA 과정 전체를 감사 로그에 기록 |

## 참고 자료

### 공식 문서

- [AWS CloudTrail](https://docs.aws.amazon.com/cloudtrail/latest/userguide/) — 변경 이력 추적
- [Amazon DevOps Guru](https://docs.aws.amazon.com/devops-guru/latest/userguide/) — ML 기반 이상 탐지 참고
- [Kubernetes Events](https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/) — 클러스터 이벤트

### 기술 블로그

- [Google SRE — Effective Troubleshooting](https://sre.google/sre-book/effective-troubleshooting/) — 체계적 진단 방법론
- [Jepsen — Linearizability Testing](https://jepsen.io/) — 분산 시스템 장애 분석 참고

### 관련 문서 (내부)

- [incident-response skill](../incident-response/SKILL.md) — RCA 트리거 소스
- [anomaly-detection skill](../anomaly-detection/SKILL.md) — anomaly 이벤트 소스
- [self-improving-loop skill](../self-improving-loop/SKILL.md) — RCA→개선 연결
- [automated-remediation skill](../automated-remediation/SKILL.md) — RCA→복구 연결
