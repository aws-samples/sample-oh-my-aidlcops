---
id: doctor
title: Doctor (oma doctor)
sidebar_position: 10
---

# Doctor — `oma doctor`

12 개의 환경 probe 를 실행해 설치와 런타임 환경이 AIDLC / AgenticOps 작업을
지원할 준비가 되었는지 점검합니다.

## 실행

```bash
oma doctor            # 사람이 읽는 표 형식
oma doctor --json     # CI 용 JSON 스키마 리포트
oma doctor --project /path/to/project   # 현재 디렉터리가 아닌 대상 점검
```

## Exit codes

| Code | 의미 |
|---|---|
| 0 | 모든 probe pass (skip 허용) |
| 1 | 최소 1 개 이상의 warn, fail 없음 |
| 2 | 최소 1 개 이상의 fail |

## Probe 목록

| id | 라벨 | 기본 심각도 | 설명 |
|---|---|---|---|
| `bash-version` | Bash >= 4 | fail | macOS 기본 bash 3.2 거부 |
| `jq-installed` | jq installed | fail | 모든 JSON 병합 경로의 의존성 |
| `git-installed` | git installed | fail | clone install & upgrade |
| `python3-installed` | python3 installed | warn | DSL compile / profile validate 에 필요 |
| `uvx-installed` | uvx installed (for MCP) | warn | MCP 서버 런처 |
| `claude-cli` | Claude CLI | skip | 미설치면 skip — Kiro 단독 구성 허용 |
| `kiro-cli` | Kiro CLI | skip | 동일 |
| `claude-settings` | Claude settings.json has OMA hooks | warn | 훅 미등록 시 trigger 비활성 |
| `mcp-pin-integrity` | MCP server versions pinned | fail | `.mcp.json` 전체가 `==X.Y.Z` 인지 |
| `aws-credentials` | AWS credentials | warn | `aws sts get-caller-identity` 성공 여부 |
| `profile-valid` | `.omao/profile.yaml` valid | warn/fail | 스키마 위반 시 fail |
| `ontology-valid` | `.omao/ontology/` valid | fail | 씨드 온톨로지 JSON Schema 검증 |

## JSON 리포트 스키마

`--json` 출력은 [`schemas/doctor/report.schema.json`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/schemas/doctor/report.schema.json) 을 따릅니다.

```jsonc
{
  "version": "1",
  "oma_version": "0.2.0-preview.1",
  "generated_at": "2026-04-30T02:05:11Z",
  "summary": { "pass": 11, "warn": 1, "fail": 0, "skipped": 0 },
  "probes": [
    { "id": "bash-version", "status": "pass", "message": "bash 5.2" },
    { "id": "aws-credentials", "status": "warn", "message": "aws sts get-caller-identity failed", "remediation": "Run `aws configure sso`." },
    ...
  ]
}
```

## CI 에서 사용

```yaml
- name: oma doctor
  run: oma doctor --json > doctor.json
- name: Fail on critical doctor issues
  run: |
    jq -e '.summary.fail == 0' doctor.json
```

`warn` 은 CI 를 fail 시키지 않는 것이 기본값입니다. 엄격 모드가 필요하면
`.summary.warn == 0` 도 assert 하세요.
