---
id: profile
title: Profile (.omao/profile.yaml)
sidebar_position: 9
---

# Profile — `.omao/profile.yaml`

프로젝트당 한 개, `oma setup` 이 생성합니다. 이후 모든 hook, skill, 검증 도구가
이 파일을 **single source of truth** 로 참조합니다.

## 형식 (v1)

```yaml
version: 1
created_at: "2026-04-30T02:00:00Z"

harness:
  primary: claude-code        # claude-code | kiro
  secondary: null             # 또는 "kiro" / "claude-code"

aws:
  account_id: "123456789012"
  region: ap-northeast-2
  profile_name: default
  environment: sandbox        # sandbox | staging | prod

aidlc:
  entry_phase: inception      # inception | construction | operations
  strict_gates: false

approval:
  mode: interactive           # interactive | ci-auto-approve-safe | strict
  blast_radius_ceiling: single-account

budgets:
  default_monthly_usd: 200
  warn_at_pct: 80
  block_at_pct: 100

observability:
  mode: langfuse-managed      # langfuse-managed | langfuse-self-hosted | opentelemetry-only | none
  endpoint: null

star_confirmed: false
```

## 검증

- 스키마: [`schemas/profile/profile.schema.json`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/schemas/profile/profile.schema.json)
- `oma setup` 은 **항상** 쓰기 직후 `profile_validate` 를 호출 — 잘못된 프로파일
  상태로 설치가 완료되지 않습니다.
- `oma doctor` 의 `profile-valid` probe 가 세션 단위로 재검증.

## 필드별 효과

- `harness.primary/secondary` — 어느 설치 스크립트를 구동할지 결정.
- `aws.*` — seed 예산의 `scope_ref`, MCP 서버의 region 컨텍스트.
- `aidlc.entry_phase` — 첫 `/oma:autopilot` 이 진입할 phase.
- `approval.mode` — `ci-auto-approve-safe` 는 단일 namespace 이하 blast radius 에
  한해 자동 승인. 그 외는 human-in-the-loop.
- `approval.blast_radius_ceiling` — 초과 시 강제 human approval + secondary review.
- `budgets.*` — `.omao/ontology/budgets/default.json` 을 seed 하고, 동시에
  `user-prompt-submit.sh` 의 예산 경고 임계치를 지정.
- `observability.*` — Langfuse self-hosted 이면 `langfuse-observability` 스킬이
  endpoint 필드를 재사용.

## 수동 편집

- `oma setup` 재실행 없이도 편집 가능. 단 편집 후 `oma doctor` 로 재검증 필수.
- 값을 비우면 (`null`) 안전한 기본값을 사용할지, 에러를 낼지 필드마다 다릅니다.
  스키마의 `required` / `default` 절을 참조하세요.

## 기본값 선택 근거

- 월 예산 $200 — 단일 개발자가 Claude Code + Claude Sonnet 을 full-day 사용했을
  때의 실측 중앙값 근처. 팀 단위라면 상향 필요.
- `blast_radius_ceiling: single-account` — 기본적으로 cross-account 나 cross-region
  배포는 강제 승인 경로로 보내 사고 반경을 통제.
- `approval.mode: interactive` — 처음 도입 시 가장 안전. CI 에서만 `ci-auto-approve-safe`
  로 승격 권장.
