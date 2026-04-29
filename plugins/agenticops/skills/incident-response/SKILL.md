---
name: incident-response
description: CloudWatch/Prometheus 알람을 수신하여 severity 분류, runbook 조회, hypothesis 생성, 진단 MCP 쿼리, 사람 승인 기반 remediation 수행까지 자동화한다. SEV1은 즉시 on-call 호출, SEV2/3은 agent가 drafted response를 준비한 뒤 사람 승인 후 실행한다.
argument-hint: "[alarm-id or incident context]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus"
---

## When to Use

- CloudWatch Alarm 또는 Prometheus AlertManager가 임계 초과 알람을 발송했을 때
- `autopilot-deploy`의 circuit breaker가 trip하여 rollback이 실행된 직후
- `continuous-eval` regression gate 실패가 연속 2회 발생했을 때
- 사용자가 명시적으로 `/incident-response <alarm-id>`를 호출하여 근본 원인 분석을 요청했을 때

사용 제외:

- 단순 retry로 복구 가능한 일시 오류 (circuit breaker 자체 복원)
- 진단 데이터가 없는 legacy 환경 (MCP 데이터 레이어 부재 시 수동 runbook으로 대체)

## Prerequisites

- **CloudWatch Alarms** + **Prometheus AlertManager** 알람 소스 설정.
- **awslabs.cloudwatch-mcp-server==0.0.25**, **awslabs.prometheus-mcp-server==0.2.15** MCP 접근 (`@latest` 금지, PyPI 버전 pin 필수).
- Runbook 저장소: `.omao/plans/runbooks/` 에 `${symptom}.md` 형식으로 보관.
- PagerDuty / Opsgenie / Slack 등 on-call 라우팅 통합 (SEV1 자동 호출용).
- `autopilot-deploy`의 상태 파일 (`.omao/state/autopilot-deploy/`) 접근 권한 — 배포 freeze에 사용.

## Severity 분류 기준

수신 알람은 즉시 다음 기준으로 분류됩니다.

| Severity | 기준 | 사람 개입 |
|----------|------|----------|
| **SEV1** | Toxicity/PII leakage 양성, 데이터 유출, 프로덕션 전체 장애, 30% 이상 트래픽 에러 | 즉시 on-call page. Agent는 진단만 수행하고 remediation은 실행하지 않음. |
| **SEV2** | 서비스 부분 장애, P99 latency 2× 이상 증가, circuit breaker trip, 특정 region 장애 | Agent가 drafted response 준비 → 사람 승인 후 실행. |
| **SEV3** | 품질 regression (faithfulness -5pp 등), 비용 급증, 단일 agent 에러율 증가 | Agent가 drafted response 준비 → 사람 승인 후 실행. |
| **SEV4** | 경고성 (log volume 증가, token 사용량 15% 증가 등) | Agent가 리포트만 생성하고 주간 리뷰 큐에 적재. |

## 5-Step Response Playbook

### Step 1: Receive & Classify

알람 수신 시 payload를 파싱하여 severity를 확정합니다.

```bash
ALARM_ID="$1"
ALARM=$(aws cloudwatch describe-alarms --alarm-names "$ALARM_ID" --query 'MetricAlarms[0]' --output json)

# Or via MCP
# mcp__cloudwatch__get_alarm --name "$ALARM_ID"

SEVERITY=$(jq -r '.Tags[] | select(.Key=="severity") | .Value' <<< "$ALARM")
```

Severity가 확정되지 않으면 기본값 SEV3으로 처리하고 사람 확인을 요청합니다.

### Step 2: Runbook Lookup

Symptom 키워드 기반으로 `.omao/plans/runbooks/` 에서 대응 runbook을 검색합니다.

```bash
SYMPTOM=$(jq -r '.AlarmDescription' <<< "$ALARM" | sed 's/[^a-z0-9-]/-/g')
RUNBOOK=$(ls .omao/plans/runbooks/*.md | grep -i "$SYMPTOM" | head -1)

if [ -z "$RUNBOOK" ]; then
  echo "No matching runbook. Proceeding with generic diagnostic flow."
fi
```

Runbook이 존재하면 해당 단계를 따르고 없으면 Step 3 generic diagnostic flow로 진행합니다.

### Step 3: Hypothesis Generation

Runbook의 "Possible Causes" 또는 generic 규칙 기반으로 3~5개 가설을 생성합니다. 각 가설은 진단 가능한 MCP 쿼리와 pair로 매핑되어야 합니다.

```json
{
  "hypotheses": [
    {
      "id": "H1",
      "claim": "Retrieval index outdated after 2026-04-20 reindex job",
      "diagnostic_query": "cloudwatch: /aws/lambda/reindex-job last 24h",
      "confidence_prior": 0.4
    },
    {
      "id": "H2",
      "claim": "New model version v2.3.1 introduced context window truncation",
      "diagnostic_query": "prometheus: agent_context_truncation_total{version='v2.3.1'}",
      "confidence_prior": 0.3
    },
    {
      "id": "H3",
      "claim": "Vector DB (Milvus) slow query due to compaction backlog",
      "diagnostic_query": "prometheus: milvus_compaction_queue_length",
      "confidence_prior": 0.3
    }
  ]
}
```

### Step 4: Diagnostic MCP Queries

각 가설에 대응하는 MCP 쿼리를 병렬 실행합니다.

```bash
# Hypothesis H1: reindex job health
mcp__cloudwatch__filter_log_events \
  --log-group /aws/lambda/reindex-job \
  --start-time $(date -u -d '-24 hours' +%s)000 \
  --filter-pattern "ERROR"

# Hypothesis H2: context truncation
mcp__prometheus__query_range \
  --query 'rate(agent_context_truncation_total{version="v2.3.1"}[5m])' \
  --start "$(date -u -d '-6 hours' +%s)" \
  --end "$(date -u +%s)"

# Hypothesis H3: Milvus compaction
mcp__prometheus__query \
  --query 'milvus_compaction_queue_length'
```

결과를 바탕으로 각 가설의 posterior confidence를 업데이트합니다. 최고 confidence 가설을 root cause 후보로 확정합니다.

### Step 5: Remediation — Drafted Response + Human Approval

SEV2/3의 경우 remediation 명령어를 `.omao/state/incident/${id}/remediation.sh` 에 drafted 파일로 생성합니다. 자동 실행하지 않습니다.

```bash
cat > .omao/state/incident/sev2-20260421-1023/remediation.sh <<'EOF'
#!/bin/bash
# Proposed remediation for SEV2 incident
# Root cause: Milvus compaction backlog (H3 confidence 0.82)
# Reviewer: please approve before execution

kubectl -n milvus exec milvus-proxy-0 -- milvus-cli \
  --command "compact -collection=agent_kb"

# Verify
kubectl -n milvus exec milvus-proxy-0 -- milvus-cli \
  --command "describe -collection=agent_kb" | grep "compaction_state"
EOF

echo "Drafted remediation at .omao/state/incident/sev2-20260421-1023/remediation.sh"
echo "Approve via: gh issue comment <issue-id> --body '/approve-remediation'"
```

SEV1의 경우:

```bash
# Page on-call immediately
curl -X POST "$PAGERDUTY_INCIDENT_URL" \
  -H "Authorization: Token token=$PD_TOKEN" \
  -d "$(jq -n --arg id "$ALARM_ID" --arg desc "$SEVERITY $SYMPTOM" \
    '{incident:{type:"incident",title:$desc,service:{id:"PXXXXX",type:"service_reference"},urgency:"high"}}')"

# Freeze autopilot-deploy
echo '{"circuit_breaker_status":"tripped","reason":"SEV1 incident"}' \
  > .omao/state/autopilot-deploy/freeze.json
```

## 상태 관리

모든 incident는 `.omao/state/incident/${severity}-${timestamp}/` 디렉토리에 기록됩니다.

- `timeline.jsonl` — 각 step 시작/완료 타임스탬프
- `hypotheses.json` — 생성된 가설과 posterior confidence
- `diagnostic-results/` — MCP 쿼리 결과 raw
- `remediation.sh` — drafted 복구 명령 (SEV2/3)
- `postmortem-draft.md` — 사건 종료 후 자동 생성되는 post-mortem 초안

## Example Inputs/Outputs

**Input**: `/incident-response rag-qa-error-rate-spike`

**Output (SEV2)**:

```
[12:35Z] Received alarm: rag-qa-error-rate-spike
[12:35Z] Severity: SEV2 (error rate 2.1× baseline for 5m)
[12:35Z] Runbook match: .omao/plans/runbooks/rag-qa-error-spike.md
[12:36Z] Generated 3 hypotheses
[12:38Z] Diagnostic MCP queries complete
[12:38Z] Root cause candidate: H3 (Milvus compaction backlog, confidence=0.82)
[12:39Z] Drafted remediation at .omao/state/incident/sev2-20260421-1235/remediation.sh
[12:39Z] AWAITING HUMAN APPROVAL. autopilot-deploy frozen.
```

**Output (SEV1)**:

```
[14:02Z] Received alarm: pii-leak-detected
[14:02Z] Severity: SEV1 (PII token found in agent response)
[14:02Z] On-call paged: PagerDuty incident P-A1B2C3
[14:02Z] autopilot-deploy frozen for all agents
[14:02Z] Agent diagnosis continuing; no remediation will be auto-drafted for SEV1
[14:05Z] Diagnostic complete: see .omao/state/incident/sev1-20260421-1402/
[14:05Z] Human responder in control. Agent awaiting /release-sev1 command.
```

## 참고 자료

### 공식 문서

- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html) — 알람 정의
- [Prometheus AlertManager](https://prometheus.io/docs/alerting/latest/alertmanager/) — 알람 라우팅
- [awslabs/mcp — cloudwatch-mcp-server](https://github.com/awslabs/mcp/tree/main/src/cloudwatch-mcp-server) — CloudWatch MCP
- [PagerDuty Events API v2](https://developer.pagerduty.com/docs/events-api-v2/overview/) — on-call 라우팅

### 기술 블로그

- [Google SRE Book — Managing Incidents](https://sre.google/sre-book/managing-incidents/) — Incident command 원칙
- [Incident.io — Hypothesis-driven debugging](https://incident.io/blog/hypothesis-driven-debugging) — 가설 기반 진단 패턴

### 관련 문서 (내부)

- [autopilot-deploy skill](../autopilot-deploy/SKILL.md) — SEV1 발생 시 freeze 대상
- [continuous-eval skill](../continuous-eval/SKILL.md) — Regression gate 연속 실패 시 본 skill 호출
- [self-improving-loop skill](../self-improving-loop/SKILL.md) — SEV2/3 root cause가 "prompt 품질"인 경우 후속 skill
