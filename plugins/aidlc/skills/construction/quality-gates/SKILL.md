---
name: quality-gates
description: AIDLC 각 phase 종료 시점에 필수 gate 체크리스트를 강제한다. Inception gate는 요구사항·사용자 스토리·워크플로우 계획 서명을, Construction gate는 설계·코드·테스트 전수 통과와 risk-discovery PASS를, Operations gate는 continuous-eval 24시간 green과 cost-governance budget OK를 요구한다. 미통과 시 `.omao/state/gates/<phase>.json`에 blocked 상태를 기록하고 다음 phase 진입을 차단한다.
argument-hint: "[phase: inception|construction|operations]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Bash,Grep"
---

## 언제 사용하나요

다음 상황에서 본 skill을 실행합니다.

- AIDLC phase 종료 시점에 다음 phase 진입 가능 여부를 판정해야 할 때
- CI 파이프라인·PR 머지 조건으로 phase gate 상태를 자동 확인해야 할 때
- 배포·rollback 의사결정 시 현재 gate 상태를 감사 증빙으로 제시해야 할 때

다음 상황에서는 사용하지 않습니다.

- 단일 skill 내부의 기술적 검증 — 각 skill의 산출물 체크리스트로 수행.
- 개인 학습·탐색 목적의 실험 — phase gate는 프로덕션 배포 경로 전용.

## 전제 조건

- `.omao/state/gates/` 디렉토리 쓰기 권한. 본 skill이 phase별 gate 상태를 JSON으로 기록합니다.
- 검증 대상 phase가 `inception`·`construction`·`operations` 중 하나.
- 각 phase의 전제 산출물(requirements·design·runbook 등)이 정해진 경로에 존재.
- Kiro 레포 MIT-0 `audit-rules.md`와 quality-gates 원칙을 반영하여 OMA 경어체 phase boundary 강제로 재구성.

## Anti-Skip 원칙

본 skill은 gate 미통과 시 다음 phase 진입을 **절대 허용하지 않습니다**. 예외 승인은 의사결정자 서명이 포함된 waiver 문서(`.omao/state/gates/waivers/<phase>-<timestamp>.md`)가 별도로 존재하는 경우에만 유효합니다.

```bash
PHASE="${1:?usage: quality-gates <inception|construction|operations>}"
STATE_DIR=".omao/state/gates"
mkdir -p "$STATE_DIR/waivers"
```

## 실행 절차

### Step 1: Phase별 체크리스트 로딩

Phase에 해당하는 필수 체크 항목을 로딩합니다.

#### Inception Gate

| 체크 항목 | 검증 방법 | 필수 여부 |
|-----------|----------|----------|
| `.omao/plans/<slug>/project-info.md` 존재 | 파일 존재 확인 | 필수 |
| `requirements.md` REQ-ID ≥ 3 | Grep 패턴 `REQ-\d{3}` | 필수 |
| `user-stories.md` 스토리마다 수락 기준 포함 | Grep `Acceptance:` | 필수 |
| `workflow-plan.md` 컴포넌트 호출 순서 기술 | Mermaid 또는 표 존재 | 필수 |
| 의사결정자 서명 | Sign-off 테이블에 이름·일시 기재 | 필수 |

#### Construction Gate

| 체크 항목 | 검증 방법 | 필수 여부 |
|-----------|----------|----------|
| `.omao/plans/construction/design.md` 8개 섹션 완결 | Grep 섹션 헤딩 | 필수 |
| 코드 커버리지 ≥ 80% | 테스트 리포트 파싱 | 필수 |
| 테스트 전수 통과 | CI 결과 `all passed` | 필수 |
| risk-discovery BLOCK = 0 | `.omao/state/risk-checkpoints/<slug>-*.md` 판정 | 필수 |
| 설계 리뷰어 승인 | `audit-trail` 로그에 approval 이벤트 | 필수 |

#### Operations Gate

| 체크 항목 | 검증 방법 | 필수 여부 |
|-----------|----------|----------|
| continuous-eval 24시간 green | Langfuse score ≥ 임계 | 필수 |
| cost-governance budget OK | 월간 예상 지출 ≤ 상한 | 필수 |
| runbook 문서화 완료 | `.omao/plans/ops/runbook.md` 존재 | 필수 |
| on-call rotation 지정 | PagerDuty·Slack 채널 설정 | 필수 |
| incident-response 리허설 수행 | game-day 로그 존재 | 권장 |

### Step 2: 체크리스트 검증 실행

각 항목을 자동 또는 반자동으로 검증합니다.

```bash
SLUG="${SLUG:?set SLUG env var}"
PHASE="$1"
RESULT_FILE="$STATE_DIR/${PHASE}.json"
FAILURES=()

case "$PHASE" in
  inception)
    test -f ".omao/plans/${SLUG}/project-info.md" || FAILURES+=("project-info.md missing")
    test -f ".omao/plans/${SLUG}/requirements.md" || FAILURES+=("requirements.md missing")
    test -f ".omao/plans/${SLUG}/user-stories.md" || FAILURES+=("user-stories.md missing")
    test -f ".omao/plans/${SLUG}/workflow-plan.md" || FAILURES+=("workflow-plan.md missing")
    ;;
  construction)
    test -f ".omao/plans/construction/design.md" || FAILURES+=("design.md missing")
    RISK_FILE=$(ls -t .omao/state/risk-checkpoints/${SLUG}-*.md 2>/dev/null | head -1)
    test -n "$RISK_FILE" || FAILURES+=("risk-discovery report missing")
    grep -q "BLOCK" "$RISK_FILE" 2>/dev/null && FAILURES+=("risk-discovery BLOCK detected")
    ;;
  operations)
    test -f ".omao/plans/ops/runbook.md" || FAILURES+=("runbook.md missing")
    ;;
  *)
    echo "unknown phase: $PHASE"; exit 2
    ;;
esac
```

### Step 3: Gate 상태 기록

검증 결과를 JSON으로 기록합니다.

```json
{
  "phase": "construction",
  "slug": "rag-qa",
  "timestamp": "2026-04-21T09:15:00Z",
  "status": "passed|blocked",
  "checks": {
    "design.md": "pass",
    "test_coverage": "pass",
    "risk_discovery": "pass"
  },
  "blockers": [],
  "waiver_ref": null,
  "next_phase_allowed": true
}
```

저장 경로: `.omao/state/gates/<phase>.json`

### Step 4: 하류 skill·CI 차단 연동

Gate가 `blocked` 상태면 다음을 수행합니다.

1. `.omao/state/gates/<phase>.json`의 `next_phase_allowed`를 `false`로 기록
2. 하류 skill(`code-generation`, `autopilot-deploy` 등)은 본 파일을 사전 확인하고 `blocked` 상태면 즉시 종료
3. `audit-trail` skill에 이벤트를 전달하여 감사 로그에 기록

### Step 5: Waiver 예외 처리

예외 승인은 다음 모든 조건을 충족해야 유효합니다.

- `.omao/state/gates/waivers/<phase>-<timestamp>.md` 파일 존재
- 의사결정자 실명·ISO 일시·사유 기재
- 유효 기간(TTL) 명시, 기본 7일 이하
- 본 파일은 재실행 시 자동 검증되며 TTL 만료 시 waiver 무효화

```yaml
---
phase: construction
waived_by: "홍길동 (CTO)"
issued_at: "2026-04-21T10:00:00Z"
expires_at: "2026-04-28T10:00:00Z"
reason: "risk-discovery category 11 BLOCK은 의존성 업그레이드 PR(#1234)로 48시간 내 해결 예정"
blockers_waived:
  - "dependency CVE-2026-1234"
---
```

## 산출물 체크리스트

본 skill 실행 종료 직전 다음을 자동 검증합니다.

- [ ] `.omao/state/gates/<phase>.json` 생성됨
- [ ] `status` 필드가 `passed` 또는 `blocked`
- [ ] `blockers` 배열이 실제 미통과 항목과 일치
- [ ] Waiver 존재 시 TTL·의사결정자 서명 검증 완료
- [ ] `audit-trail`에 gate 판정 이벤트 기록

## 좋은 예시 vs 나쁜 예시

**Good** — Construction gate가 risk-discovery BLOCK을 감지하여 진입 차단.

```json
{
  "phase": "construction",
  "status": "blocked",
  "blockers": ["risk-discovery category 2 (Security) BLOCK: plaintext secret in configmap"],
  "next_phase_allowed": false
}
```

**Bad** — 체크리스트 없이 수동 판정으로 skip.

> "리뷰어가 구두로 OK했으니 다음 단계 진행합니다." — 감사 증빙 부재, 재현 불가.

## 참고 자료

### 공식 문서

- [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) — AIDLC 공식 phase 정의
- [aws-samples/sample-ai-driven-modernization-with-kiro — audit-rules](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro/blob/main/.kiro/steering/audit-rules.md) — MIT-0 기반 감사 원칙
- [Google SRE Book — Release Engineering](https://sre.google/sre-book/release-engineering/) — release gate 이론적 배경

### 관련 문서 (내부)

- `../risk-discovery/SKILL.md` — Construction gate의 핵심 입력 제공자
- `../../aidlc-inception/skills/requirements-analysis/SKILL.md` — Inception gate의 입력 생성자
- `../../agenticops/skills/continuous-eval/SKILL.md` — Operations gate의 품질 지표 공급자
- `../../agenticops/skills/cost-governance/SKILL.md` — Operations gate의 비용 판정 공급자
- `../../agenticops/skills/audit-trail/SKILL.md` — gate 판정 이벤트 감사 로그 기록자
