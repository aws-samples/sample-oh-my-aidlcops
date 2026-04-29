---
name: self-improving-loop
description: Langfuse production trace를 관찰하고 품질 regression·비용 이상·실패 패턴을 자동 분석한 뒤 prompt·skill 수정안을 PR draft 형태로 제안한다. Observe → Analyze → Propose → PR 4단계 루프를 실행하며 self-improving-agent-loop ADR의 자동화 경계(Rollout/Score/Filter까지만 자동, Train/Deploy는 사람 승인)를 강제한다.
argument-hint: "[which agent/skill to analyze?]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Grep,Bash,mcp__cloudwatch,mcp__prometheus"
license: Apache-2.0
---

## When to Use

다음 상황에서 본 skill을 실행합니다.

- 특정 agent/skill의 성능 regression이 관측되었고 원인 분석과 개선안 도출이 필요할 때
- 주간/격주 정기 품질 리뷰 cadence에서 trace 샘플 기반 지속 개선이 필요할 때
- `continuous-eval`이 faithfulness 5%p 하락 또는 user_feedback 부정 비율 임계 초과를 보고했을 때
- `incident-response`가 SEV2/3 이벤트의 root cause를 "prompt 품질" 또는 "도구 호출 누락"으로 분류했을 때

다음 상황에서는 사용하지 않습니다.

- 폐쇄형 관리 모델(Bedrock Claude/Nova, OpenAI GPT-4.1, Gemini 2.5 등)의 weight 개선 — weight 접근 불가. prompt/라우팅 개선만 가능.
- Train/Deploy 단계 자동 실행 — ADR에 따라 사람 승인 필수이며 본 skill은 제안(PR draft)까지만 담당합니다.

## Prerequisites

- **Langfuse v3.x** self-hosted 또는 cloud 인스턴스. 최소 30일 trace retention.
- **Prometheus** (AMP 또는 self-hosted) — latency, error_rate, token_usage 메트릭 수집.
- **CloudWatch Logs** — Agent 실행 로그, tool invocation 로그.
- **awslabs.cloudwatch-mcp-server==0.0.25**, **awslabs.prometheus-mcp-server==0.2.15** MCP 서버가 설정된 상태 (공급망 보안을 위해 `@latest` 대신 PyPI 버전 pin 필수).
- Git 저장소에 대한 write 권한 (PR draft 생성을 위함).
- 개선 대상 agent/skill의 baseline 평가 점수가 `continuous-eval`로 최근 24시간 내 생성되어 있어야 합니다.

## 4-Stage Loop

본 skill은 engineering-playbook의 `self-improving-agent-loop.md` 5-Stage 설계에서 **Rollout·Score·Filter** 3단계를 자동화하고, Train/Deploy 2단계는 PR 승인·사람 트리거로 분리합니다. 즉 skill 내부 루프는 4단계입니다.

### Stage 1: Observe — Langfuse trace 수집

개선 대상 agent/skill의 최근 trace를 시간·품질·비용 차원으로 그룹화합니다.

```bash
LANGFUSE_HOST="${LANGFUSE_HOST:-http://langfuse.svc.cluster.local}"
TARGET_AGENT="$1"   # 예: rag-qa-agent, code-reviewer-skill
WINDOW_HOURS="${WINDOW_HOURS:-168}"  # 기본 7일

curl -s -u "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" \
  "$LANGFUSE_HOST/api/public/traces?name=$TARGET_AGENT&from=$(date -u -d "-${WINDOW_HOURS} hours" +%Y-%m-%dT%H:%M:%SZ)&limit=500" \
  | jq -c '.data[]' \
  > .omao/plans/self-improving/traces-raw.jsonl
```

수집 항목은 trace ID, 프롬프트, 응답, reward_score, user_feedback, latency, tool_invocations, token_count입니다. Reward가 낮은 trace(< 0.5)와 user_feedback이 부정인 trace를 우선 분석 대상으로 flag합니다.

### Stage 2: Analyze — Regression 패턴 탐지

수집한 trace를 품질·비용·안전 3축으로 분석합니다.

- **품질 축**: `continuous-eval`의 Ragas 결과(faithfulness, answer relevance, context precision)를 동일 기간 baseline과 비교합니다. 5%p 이상 하락한 지표를 regression으로 분류합니다.
- **비용 축**: Prometheus에서 `rate(agent_token_total[1h])`를 쿼리하여 토큰 사용량 급증을 확인합니다.
- **안전 축**: Langfuse score 중 `toxicity`, `pii_leakage` 값이 한 건이라도 양성으로 라벨된 trace를 격리합니다.

분석 결과는 다음 구조의 리포트로 저장합니다.

```json
{
  "target": "rag-qa-agent",
  "window": "2026-04-14T00:00:00Z/2026-04-21T00:00:00Z",
  "regressions": [
    {
      "dimension": "faithfulness",
      "baseline": 0.87,
      "current": 0.79,
      "delta_pp": -8.0,
      "affected_trace_ids": ["tr_abc", "tr_def", "..."],
      "hypothesized_cause": "system_prompt revision on 2026-04-16 removed citation instruction"
    }
  ]
}
```

저장 경로: `.omao/plans/self-improving/report-${target}-${timestamp}.json`

### Stage 3: Propose — Prompt/Skill 수정안 생성

Regression 원인 가설에 대응하는 수정안을 생성합니다. 모든 수정안은 `diff` 형식으로 작성하여 사람이 검토할 수 있도록 합니다.

```diff
--- a/skills/rag-qa-agent/SKILL.md
+++ b/skills/rag-qa-agent/SKILL.md
@@ -42,7 +42,11 @@
 ## Instructions
 
 You are a RAG QA agent. Retrieve relevant context and answer the user's question.
-Always respond concisely.
+Always respond concisely and include inline citations in the form [source:doc-id]
+for every claim grounded in retrieved context. If no retrieved context supports
+a claim, state "I cannot verify this from available sources" instead of speculating.
+
+Never output PII tokens (email, SSN, phone) even if present in retrieved context.
```

수정안 생성 원칙:

1. **최소 변경** — regression 원인 한 가지에 대응하는 가장 작은 변경부터 제안합니다.
2. **측정 가능성** — 수정안이 통과해야 할 Ragas 임계값(예: `faithfulness ≥ 0.87`)을 PR body에 명시합니다.
3. **롤백 경로** — 수정 전 원본을 `.omao/plans/self-improving/rollback/` 에 보관합니다.
4. **사람 승인 필수** — 본 skill은 PR을 draft 상태로만 생성하며 머지는 수행하지 않습니다.

### Stage 4: PR — Draft Pull Request 생성

GitHub CLI로 PR draft를 생성합니다.

```bash
BRANCH="self-improving/${TARGET_AGENT}-$(date +%Y%m%d-%H%M)"
git checkout -b "$BRANCH"
git add skills/rag-qa-agent/SKILL.md
git commit -m "improve($TARGET_AGENT): restore citation instruction + block PII leakage"

gh pr create --draft \
  --title "improve($TARGET_AGENT): address faithfulness -8.0pp regression" \
  --body "$(cat <<'EOF'
## Self-Improving Loop Proposal

**Target**: `rag-qa-agent`
**Window**: 2026-04-14 .. 2026-04-21
**Detected Regression**: faithfulness 0.87 → 0.79 (-8.0pp)

### Evidence
- Affected traces: 47 traces, avg reward 0.42 (baseline 0.78)
- Langfuse query: see `.omao/plans/self-improving/report-rag-qa-agent-20260421.json`

### Hypothesized Cause
System prompt revision on 2026-04-16 removed the "include inline citations" instruction.

### Proposed Fix
Restore citation instruction + add explicit PII blocking clause.

### Acceptance Criteria
- [ ] `continuous-eval` faithfulness ≥ 0.87 on golden dataset
- [ ] No PII leakage detected in 48h canary (5% traffic)
- [ ] user_feedback positive rate ≥ baseline (0.71)

### Rollback
`.omao/plans/self-improving/rollback/rag-qa-agent-20260421.md` holds the pre-change content.

### ADR Compliance
Per ADR Self-Improving Loop §2, this proposal does NOT trigger model retraining. Merge of this PR results in prompt-only change; no weight update. `continuous-eval` will verify on next scheduled run.
EOF
)"
```

## Example Inputs/Outputs

**Input**: `self-improving-loop rag-qa-agent`

**Output**:

1. `.omao/plans/self-improving/traces-raw.jsonl` — 최근 7일 trace 500건
2. `.omao/plans/self-improving/report-rag-qa-agent-20260421.json` — regression 분석
3. Draft PR: `improve(rag-qa-agent): address faithfulness -8.0pp regression`

**실패 케이스**:

- Langfuse 접근 불가 → `.omao/state/self-improving/error-langfuse.log`에 원인 기록, skill 종료.
- Regression 미검출 → "no regression detected" 리포트만 생성하고 PR 미생성.
- Target agent가 self-hosted가 아닌 관리형 모델(Claude/Nova 등) → ADR §1 위반으로 즉시 중단하고 "managed model — prompt-only improvement required" 안내.

## ADR 경계 준수 체크리스트

본 skill 실행 종료 직전 다음을 자동 검증합니다. 하나라도 실패 시 PR 생성을 중단합니다.

- [ ] Target이 self-hosted 모델인가 (Qwen3 / Llama 4 / GLM-5 계열)
- [ ] 제안이 prompt/skill 수정에 국한되는가 (weight 업데이트 제안 없음)
- [ ] 학습 데이터 사용 제안이 있다면 PII / Consent / 지역 / 기밀 4-gate 통과 trace만 참조하는가
- [ ] Rollback 경로가 `.omao/plans/self-improving/rollback/`에 저장되었는가
- [ ] PR 상태가 `draft`이며 자동 머지 설정이 없는가

## 참고 자료

### 공식 문서

- [Langfuse OpenTelemetry](https://langfuse.com/docs/opentelemetry) — Production trace standard
- [Ragas Documentation](https://docs.ragas.io/) — 품질 지표 정의
- [GitHub CLI gh pr create](https://cli.github.com/manual/gh_pr_create) — PR draft 생성 레퍼런스

### 기술 블로그

- [LMSYS RouteLLM](https://lmsys.org/blog/2024-07-01-routellm/) — Regression 분석 패턴
- [Langfuse — Production observability for LLM apps](https://langfuse.com/blog) — trace 기반 품질 개선 사례

### 관련 문서 (내부)

- [ADR: Self-Improving Loop](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/design-architecture/advanced-patterns/adr-self-improving-loop.md) — 운영 원칙
- [Self-Improving Agent Loop 설계](https://github.com/devfloor9/engineering-playbook/blob/main/docs/agentic-ai-platform/design-architecture/advanced-patterns/self-improving-agent-loop.md) — 5-Stage 아키텍처
- [continuous-eval skill](../continuous-eval/SKILL.md) — Regression signal 제공자
- [autopilot-deploy skill](../autopilot-deploy/SKILL.md) — PR 머지 후 canary rollout 실행자
- [incident-response skill](../incident-response/SKILL.md) — 품질 regression을 SEV2/3로 격상하는 upstream
