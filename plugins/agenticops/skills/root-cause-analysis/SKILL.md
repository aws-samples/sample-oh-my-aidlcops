---
name: root-cause-analysis
description: 인시던트 발생 시 관련 메트릭·로그·이벤트·변경 이력을 자동 수집하고 인과 관계를 추론하여 근본 원인을 식별한다. 타임라인 기반 이벤트 상관관계 분석, 변경-장애 매핑, 의존성 그래프 탐색을 수행하며 RCA 보고서를 자동 생성한다.
argument-hint: "[incident-id or symptom description]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus,mcp__eks"
ontology:
  consumes: [Incident]
  references: [Deployment, Agent]
---

## When to Use

- `incident-response`가 SEV1~3 인시던트를 분류한 직후, 근본 원인 분석이 필요할 때
- `anomaly-detection`이 Critical anomaly를 탐지하고 원인 추적이 필요할 때
- Post-mortem 작성을 위해 인시던트의 인과 관계를 체계적으로 정리할 때
- 반복 발생하는 인시던트의 공통 원인 패턴을 식별할 때

사용 제외:

- 원인이 명확한 단순 장애 (예: 인증서 만료, 디스크 풀) — runbook 직접 실행
- 진단 데이터가 전혀 없는 환경 (MCP 데이터 레이어 부재)
- `incident-response`의 Step 3~4 (Hypothesis + Diagnostic)로 이미 원인이 확정된 경우

## Prerequisites

- **awslabs.cloudwatch-mcp-server==0.0.25** — 로그/메트릭 조회.
- **awslabs.prometheus-mcp-server==0.2.15** — 시계열 쿼리.
- **awslabs.eks-mcp-server==0.1.28** — EKS 클러스터 이벤트/리소스 조회 (`@latest` 금지, PyPI 버전 pin 필수).
- `incident-response`가 생성한 인시던트 상태 파일 (`.omao/state/incident/`).
- 변경 이력 소스: Git log, ArgoCD sync history, CloudTrail.
- 서비스 의존성 맵: `.omao/plans/observability/dependency-map.yaml`.
- 과거 RCA 패턴 DB: `.omao/plans/observability/rca-patterns.yaml` (학습 결과 축적).

## 서비스 의존성 맵 정의

```yaml
# .omao/plans/observability/dependency-map.yaml
services:
  rag-qa-agent:
    type: agent
    namespace: production
    dependencies:
      - name: milvus
        type: vector-db
        protocol: grpc
        port: 19530
        health_check: "milvus_health_status"
      - name: bedrock
        type: llm-provider
        protocol: https
        endpoint: "bedrock-runtime.ap-northeast-2.amazonaws.com"
        health_check: "aws_bedrock_invocation_errors"
      - name: redis
        type: cache
        protocol: tcp
        port: 6379
        health_check: "redis_up"
      - name: postgres
        type: database
        protocol: tcp
        port: 5432
        health_check: "pg_up"

  milvus:
    type: vector-db
    namespace: milvus
    dependencies:
      - name: minio
        type: object-storage
        protocol: http
        port: 9000

  code-reviewer-agent:
    type: agent
    namespace: production
    dependencies:
      - name: bedrock
        type: llm-provider
      - name: github-api
        type: external-api
        protocol: https
```

## RCA 방법론: 5-Why + Evidence Chain

### Phase 1: Evidence Collection (자동)

인시던트 시점 ±30분의 데이터를 다차원으로 자동 수집합니다.

```python
import json
import os
from datetime import datetime, timedelta
from dataclasses import dataclass, field

@dataclass
class EvidenceWindow:
    incident_time: datetime
    start: datetime
    end: datetime
    
    @classmethod
    def from_incident(cls, incident_time: str, buffer_minutes: int = 30):
        t = datetime.fromisoformat(incident_time.replace("Z", "+00:00"))
        return cls(
            incident_time=t,
            start=t - timedelta(minutes=buffer_minutes),
            end=t + timedelta(minutes=buffer_minutes),
        )

@dataclass
class Evidence:
    source: str
    timestamp: str
    description: str
    severity: str = "info"
    raw_data: dict = field(default_factory=dict)

def collect_evidence(incident_id: str, window: EvidenceWindow) -> dict[str, list[Evidence]]:
    """인시던트 관련 증거를 다차원으로 수집.
    
    수집 소스:
    1. CloudWatch Metrics — 관련 메트릭 시계열
    2. CloudWatch Logs — 에러 로그
    3. EKS Events — Pod/Node 이벤트
    4. Git/ArgoCD — 변경 이력
    5. CloudTrail — AWS API 호출 이력
    """
    evidence = {
        "metrics": collect_metrics_evidence(window),
        "logs": collect_log_evidence(window),
        "k8s_events": collect_k8s_events(window),
        "changes": collect_change_history(window),
        "cloudtrail": collect_cloudtrail_events(window),
    }
    
    # 증거 저장
    evidence_dir = f".omao/state/incident/{incident_id}/evidence"
    os.makedirs(evidence_dir, exist_ok=True)
    for source, items in evidence.items():
        with open(os.path.join(evidence_dir, f"{source}.json"), "w") as f:
            json.dump([vars(e) for e in items], f, indent=2, default=str)
    
    return evidence


def collect_metrics_evidence(window: EvidenceWindow) -> list[Evidence]:
    """CloudWatch + Prometheus 메트릭에서 이상 구간 추출."""
    evidence = []
    
    # Prometheus: 에러율 급증 구간
    # mcp__prometheus__query_range(
    #   query='rate(agent_request_errors_total[5m])',
    #   start=window.start.timestamp(),
    #   end=window.end.timestamp(),
    #   step=60
    # )
    
    # CloudWatch: 관련 알람 상태 변경
    # mcp__cloudwatch__describe_alarm_history(
    #   alarm_name=...,
    #   start_date=window.start.isoformat(),
    #   end_date=window.end.isoformat()
    # )
    
    return evidence


def collect_log_evidence(window: EvidenceWindow) -> list[Evidence]:
    """CloudWatch Logs에서 에러/경고 로그 추출."""
    evidence = []
    
    # mcp__cloudwatch__filter_log_events(
    #   log_group='/aws/eks/production/containers',
    #   start_time=int(window.start.timestamp() * 1000),
    #   end_time=int(window.end.timestamp() * 1000),
    #   filter_pattern='?ERROR ?FATAL ?Exception ?Traceback'
    # )
    
    return evidence


def collect_k8s_events(window: EvidenceWindow) -> list[Evidence]:
    """EKS 클러스터 이벤트 수집 (Pod restart, OOM, scheduling 실패 등)."""
    evidence = []
    
    # mcp__eks__get_k8s_events(
    #   cluster_name='production',
    #   kind='Pod',
    #   namespace='production'
    # )
    
    return evidence


def collect_change_history(window: EvidenceWindow) -> list[Evidence]:
    """변경 이력 수집 (Git, ArgoCD, CloudTrail)."""
    evidence = []
    
    # Git: 최근 커밋/배포
    # git log --after=window.start --before=window.end --oneline
    
    # ArgoCD: sync history
    # kubectl get applications -n argocd -o json
    
    return evidence


def collect_cloudtrail_events(window: EvidenceWindow) -> list[Evidence]:
    """CloudTrail에서 인프라 변경 이벤트 수집."""
    evidence = []
    
    # aws cloudtrail lookup-events \
    #   --start-time window.start \
    #   --end-time window.end \
    #   --lookup-attributes AttributeKey=EventSource,AttributeValue=eks.amazonaws.com
    
    return evidence
```

### Phase 2: Timeline Reconstruction

수집된 이벤트를 시간순으로 정렬하여 인과 관계 후보를 식별합니다.

```python
@dataclass
class TimelineEvent:
    timestamp: datetime
    source: str
    description: str
    severity: str
    is_change: bool = False
    is_symptom: bool = False

def build_timeline(evidence: dict[str, list[Evidence]], 
                   incident_time: datetime) -> list[TimelineEvent]:
    """모든 증거를 단일 타임라인으로 병합하고 인과 관계 후보를 마킹."""
    events = []
    
    for source, items in evidence.items():
        for item in items:
            ts = datetime.fromisoformat(item.timestamp.replace("Z", "+00:00"))
            event = TimelineEvent(
                timestamp=ts,
                source=source,
                description=item.description,
                severity=item.severity,
                is_change=(source in ("changes", "cloudtrail")),
                is_symptom=(item.severity in ("critical", "warning") and ts >= incident_time),
            )
            events.append(event)
    
    # 시간순 정렬
    events.sort(key=lambda e: e.timestamp)
    
    return events


def identify_causal_candidates(timeline: list[TimelineEvent],
                               incident_time: datetime) -> list[dict]:
    """타임라인에서 인과 관계 후보 식별.
    
    규칙:
    1. 장애 시점 이전의 변경 이벤트 → 원인 후보
    2. 시간적 근접도가 높을수록 상관 점수 높음
    3. 동일 소스의 연속 이벤트는 그룹핑
    """
    candidates = []
    
    for event in timeline:
        if not event.is_change:
            continue
        if event.timestamp >= incident_time:
            continue
        
        time_delta_sec = (incident_time - event.timestamp).total_seconds()
        
        # 시간 근접도 점수 (1시간 이내 = 높음, 24시간 이내 = 중간)
        if time_delta_sec < 3600:
            proximity_score = 0.9
        elif time_delta_sec < 14400:  # 4시간
            proximity_score = 0.6
        elif time_delta_sec < 86400:  # 24시간
            proximity_score = 0.3
        else:
            proximity_score = 0.1
        
        candidates.append({
            "event": event,
            "time_before_incident_sec": time_delta_sec,
            "proximity_score": proximity_score,
            "source": event.source,
        })
    
    return sorted(candidates, key=lambda x: -x["proximity_score"])
```

### Phase 3: Change-Incident Correlation

장애 시점 이전 변경 이력과의 상관관계를 심층 분석합니다.

```python
@dataclass
class CorrelationResult:
    change_event: TimelineEvent
    correlation_score: float  # 0.0 ~ 1.0
    evidence_chain: list[str]
    confidence: str  # high, medium, low

def correlate_changes(candidates: list[dict], 
                      symptoms: list[TimelineEvent],
                      dependency_map: dict) -> list[CorrelationResult]:
    """변경 이벤트와 증상 간 상관관계 분석.
    
    상관 점수 계산:
    - 시간 근접도 (40%)
    - 영향 범위 일치 (30%) — 변경 대상과 장애 서비스의 의존성 관계
    - 유사 패턴 이력 (30%) — 과거 RCA에서 동일 변경→장애 패턴 존재 여부
    """
    results = []
    
    for candidate in candidates:
        event = candidate["event"]
        
        # 영향 범위 일치 점수
        scope_score = calculate_scope_match(event, symptoms, dependency_map)
        
        # 유사 패턴 이력 점수
        pattern_score = check_historical_patterns(event, symptoms)
        
        # 종합 점수
        total_score = (
            candidate["proximity_score"] * 0.4 +
            scope_score * 0.3 +
            pattern_score * 0.3
        )
        
        # 증거 체인 구성
        evidence_chain = build_evidence_chain(event, symptoms)
        
        # 신뢰도 분류
        if total_score >= 0.7:
            confidence = "high"
        elif total_score >= 0.4:
            confidence = "medium"
        else:
            confidence = "low"
        
        results.append(CorrelationResult(
            change_event=event,
            correlation_score=total_score,
            evidence_chain=evidence_chain,
            confidence=confidence,
        ))
    
    return sorted(results, key=lambda r: -r.correlation_score)


def calculate_scope_match(change: TimelineEvent, symptoms: list[TimelineEvent],
                          dependency_map: dict) -> float:
    """변경 대상과 장애 서비스 간 의존성 관계 점수."""
    # 직접 의존: 1.0, 간접 의존(1-hop): 0.6, 무관: 0.1
    return 0.5  # placeholder


def check_historical_patterns(change: TimelineEvent, 
                              symptoms: list[TimelineEvent]) -> float:
    """과거 RCA 패턴 DB에서 유사 패턴 검색."""
    patterns_file = ".omao/plans/observability/rca-patterns.yaml"
    if not os.path.exists(patterns_file):
        return 0.0
    
    # 패턴 매칭 로직
    return 0.0  # 초기에는 패턴 없음


def build_evidence_chain(change: TimelineEvent, 
                         symptoms: list[TimelineEvent]) -> list[str]:
    """변경 → 증상 간 인과 관계 체인 구성."""
    chain = [
        f"[{change.timestamp.isoformat()}Z] Change: {change.description}",
    ]
    for symptom in symptoms[:3]:  # 상위 3개 증상
        chain.append(f"[{symptom.timestamp.isoformat()}Z] Symptom: {symptom.description}")
    return chain
```

### Phase 4: Dependency Graph Traversal

장애 서비스의 upstream/downstream 의존성을 탐색하여 전파 경로를 추적합니다.

```python
import yaml

def traverse_dependencies(affected_service: str, 
                          dependency_map_file: str,
                          direction: str = "both") -> dict:
    """의존성 그래프를 탐색하여 장애 전파 경로 추적.
    
    Args:
        affected_service: 장애가 발생한 서비스명
        dependency_map_file: 의존성 맵 파일 경로
        direction: upstream, downstream, both
    
    Returns:
        전파 경로 및 영향 범위
    """
    with open(dependency_map_file) as f:
        dep_map = yaml.safe_load(f)
    
    services = dep_map.get("services", {})
    
    # Upstream: 이 서비스가 의존하는 서비스들
    upstream = []
    if direction in ("upstream", "both"):
        svc = services.get(affected_service, {})
        for dep in svc.get("dependencies", []):
            upstream.append({
                "name": dep["name"],
                "type": dep["type"],
                "health_check": dep.get("health_check"),
            })
    
    # Downstream: 이 서비스에 의존하는 서비스들
    downstream = []
    if direction in ("downstream", "both"):
        for svc_name, svc_config in services.items():
            if svc_name == affected_service:
                continue
            for dep in svc_config.get("dependencies", []):
                if dep["name"] == affected_service:
                    downstream.append({
                        "name": svc_name,
                        "type": svc_config.get("type"),
                    })
    
    return {
        "affected_service": affected_service,
        "upstream_dependencies": upstream,
        "downstream_impact": downstream,
        "total_blast_radius": 1 + len(downstream),
    }
```

### Phase 5: RCA Report Generation

분석 결과를 구조화된 보고서로 생성합니다.

```python
@dataclass
class RCAReport:
    incident_id: str
    root_cause: str
    confidence: str
    category: str
    timeline: list[TimelineEvent]
    evidence_chain: list[str]
    contributing_factors: list[str]
    recommendations: list[dict]
    blast_radius: dict

def generate_rca_report(incident_id: str, 
                        correlations: list[CorrelationResult],
                        timeline: list[TimelineEvent],
                        dependency_result: dict) -> str:
    """RCA 보고서를 마크다운으로 생성."""
    
    top_cause = correlations[0] if correlations else None
    
    report = f"""# RCA Report — {incident_id}

## Summary
- **Root Cause**: {top_cause.change_event.description if top_cause else "Undetermined"}
- **Confidence**: {top_cause.confidence if top_cause else "low"}
- **Category**: {categorize_root_cause(top_cause)}
- **Correlation Score**: {top_cause.correlation_score:.2f if top_cause else "N/A"}

## Timeline

| Timestamp | Source | Event | Type |
|-----------|--------|-------|------|
"""
    for event in timeline[:20]:  # 상위 20개 이벤트
        event_type = "🔄 Change" if event.is_change else ("⚠️ Symptom" if event.is_symptom else "ℹ️ Info")
        report += f"| {event.timestamp.strftime('%Y-%m-%d %H:%M:%S')}Z | {event.source} | {event.description} | {event_type} |\n"
    
    report += f"""
## Evidence Chain

"""
    if top_cause:
        for i, step in enumerate(top_cause.evidence_chain, 1):
            report += f"{i}. {step}\n"
    
    report += f"""
## Blast Radius

- **Affected Service**: {dependency_result['affected_service']}
- **Upstream Dependencies**: {len(dependency_result['upstream_dependencies'])}
- **Downstream Impact**: {len(dependency_result['downstream_impact'])} services
"""
    for ds in dependency_result["downstream_impact"]:
        report += f"  - `{ds['name']}` ({ds['type']})\n"
    
    report += f"""
## Contributing Factors

"""
    for corr in correlations[1:4]:  # 2~4위 후보
        report += f"- [{corr.confidence}] {corr.change_event.description} (score: {corr.correlation_score:.2f})\n"
    
    report += f"""
## Recommendations

- [ ] **단기 조치**: {"Rollback " + top_cause.change_event.description if top_cause else "Manual investigation required"}
- [ ] **중기 조치**: Add monitoring for similar change patterns
- [ ] **장기 조치**: Update dependency-map and add pre-deploy validation
"""
    
    # 보고서 저장
    report_path = f".omao/state/incident/{incident_id}/rca-report.md"
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w") as f:
        f.write(report)
    
    return report


def categorize_root_cause(correlation: CorrelationResult | None) -> str:
    """근본 원인 카테고리 분류."""
    if not correlation:
        return "unknown"
    
    source = correlation.change_event.source
    desc = correlation.change_event.description.lower()
    
    if source == "changes" and ("deploy" in desc or "release" in desc):
        return "deployment"
    elif source == "cloudtrail" and ("security" in desc or "iam" in desc):
        return "configuration"
    elif source == "k8s_events" and ("node" in desc or "resource" in desc):
        return "infrastructure"
    elif "dependency" in desc or "upstream" in desc:
        return "dependency"
    else:
        return "other"
```

### Phase 6: Pattern Learning

RCA 결과를 패턴 DB에 축적하여 향후 분석 정확도를 높입니다.

```python
def update_rca_patterns(incident_id: str, rca_report: RCAReport):
    """RCA 결과를 패턴 DB에 축적."""
    patterns_file = ".omao/plans/observability/rca-patterns.yaml"
    
    if os.path.exists(patterns_file):
        with open(patterns_file) as f:
            patterns = yaml.safe_load(f) or {"patterns": []}
    else:
        patterns = {"patterns": []}
    
    new_pattern = {
        "id": f"pattern-{len(patterns['patterns']) + 1}",
        "incident_id": incident_id,
        "root_cause_category": rca_report.category,
        "change_signature": rca_report.root_cause,
        "symptoms": [e.description for e in rca_report.timeline if e.is_symptom][:5],
        "confidence": rca_report.confidence,
        "created_at": datetime.utcnow().isoformat() + "Z",
    }
    
    patterns["patterns"].append(new_pattern)
    
    with open(patterns_file, "w") as f:
        yaml.dump(patterns, f, default_flow_style=False, allow_unicode=True)
```

## 상태 관리

- `.omao/state/incident/${id}/rca-report.md` — RCA 보고서
- `.omao/state/incident/${id}/evidence/` — 수집된 증거 raw 데이터
  - `metrics.json` — 메트릭 증거
  - `logs.json` — 로그 증거
  - `k8s_events.json` — K8s 이벤트
  - `changes.json` — 변경 이력
  - `cloudtrail.json` — CloudTrail 이벤트
- `.omao/state/incident/${id}/timeline.jsonl` — 재구성된 타임라인
- `.omao/plans/observability/rca-patterns.yaml` — 반복 패턴 학습 결과
- `.omao/plans/observability/dependency-map.yaml` — 서비스 의존성 맵

## Example Inputs/Outputs

**Input**: `/root-cause-analysis sev2-20260508-1405`

**Output**:

```
[14:06:00Z] Starting RCA for incident: sev2-20260508-1405
[14:06:00Z] Incident time: 2026-05-08T14:05:00Z
[14:06:00Z] Evidence window: 13:35:00Z — 14:35:00Z (±30min)

[14:06:01Z] Phase 1: Evidence Collection
             Metrics    : 4 time series collected (Error Rate, P99 Latency, Bedrock Latency, Token Usage)
             Logs       : 23 error entries found
             K8s Events : 5 events (2 Warning, 3 Normal)
             Changes    : 3 events (1 deploy, 1 ConfigMap update, 1 HPA change)
             CloudTrail : 2 events (ModifyTargetGroup, UpdateService)

[14:06:03Z] Phase 2: Timeline Reconstruction
             Total events: 37
             Change events (pre-incident): 3
             Symptom events: 8

[14:06:04Z] Phase 3: Change-Incident Correlation
             Candidate 1: [13:52Z] Deploy rag-qa-agent:v2.3.1 → score=0.82 (HIGH)
               - Proximity: 13min before incident (0.9)
               - Scope: direct match — same service (1.0)
               - Pattern: similar deploy→latency pattern seen in pattern-3 (0.6)
             Candidate 2: [13:45Z] ConfigMap update: prompt-templates → score=0.54 (MEDIUM)
             Candidate 3: [12:30Z] HPA maxReplicas 10→8 → score=0.31 (LOW)

[14:06:05Z] Phase 4: Dependency Graph Traversal
             Affected: rag-qa-agent
             Upstream: milvus (healthy), bedrock (healthy), redis (healthy)
             Downstream: 2 services impacted (api-gateway, slack-bot)

[14:06:06Z] Phase 5: RCA Report Generated
             Root Cause: Deploy rag-qa-agent:v2.3.1 (confidence: HIGH)
             Category: deployment
             Blast Radius: 3 services

[14:06:06Z] Phase 6: Pattern DB Updated (pattern-7)

[14:06:06Z] Report saved: .omao/state/incident/sev2-20260508-1405/rca-report.md
[14:06:06Z] Next action: automated-remediation (runbook match available: rollback-canary)
```

**Input**: `/root-cause-analysis sev3-20260508-0300 --postmortem`

**Output (undetermined)**:

```
[03:15:00Z] Starting RCA for incident: sev3-20260508-0300
[03:15:05Z] Phase 3: Change-Incident Correlation
             No change events found in ±30min window.
             Expanding window to ±2 hours...
             Candidate 1: [01:15Z] AWS maintenance event (ap-northeast-2a) → score=0.45 (MEDIUM)

[03:15:07Z] Root Cause: [UNDETERMINED — medium confidence]
             Best candidate: AWS maintenance event (score=0.45)
             Recommendation: Check AWS Health Dashboard, expand evidence window to ±6h

[03:15:07Z] Report saved with status: NEEDS_HUMAN_REVIEW
```

## 기존 스킬 연동

| 연동 대상 | 방향 | 설명 |
|-----------|------|------|
| `incident-response` | ← 입력 | 인시던트 분류 결과 및 가설을 입력으로 수신 |
| `anomaly-detection` | ← 입력 | Critical anomaly 이벤트를 RCA 트리거로 수신 |
| `automated-remediation` | → 출력 | RCA 완료 + 알려진 패턴 → remediation 트리거 |
| `self-improving-loop` | → 출력 | RCA 결과가 "prompt 품질"이면 개선 루프 트리거 |
| `audit-trail` | → 출력 | RCA 과정 전체를 감사 로그에 기록 |
| `slo-management` | ← 입력 | SLO 위반 인시던트의 RCA 요청 수신 |

## 참고 자료

### 공식 문서

- [AWS CloudTrail](https://docs.aws.amazon.com/cloudtrail/latest/userguide/) — 변경 이력 추적
- [Amazon DevOps Guru](https://docs.aws.amazon.com/devops-guru/latest/userguide/) — ML 기반 이상 탐지 참고
- [Kubernetes Events](https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/) — 클러스터 이벤트
- [AWS Health API](https://docs.aws.amazon.com/health/latest/APIReference/) — AWS 서비스 상태

### 기술 블로그

- [Google SRE — Effective Troubleshooting](https://sre.google/sre-book/effective-troubleshooting/) — 체계적 진단 방법론
- [Meta — Root Cause Analysis at Scale](https://engineering.fb.com/2023/11/28/production-engineering/root-cause-analysis/) — 대규모 RCA 자동화

### 관련 문서 (내부)

- [incident-response skill](../incident-response/SKILL.md) — RCA 트리거 소스
- [anomaly-detection skill](../anomaly-detection/SKILL.md) — anomaly 이벤트 소스
- [automated-remediation skill](../automated-remediation/SKILL.md) — RCA→복구 연결
- [self-improving-loop skill](../self-improving-loop/SKILL.md) — RCA→개선 연결
