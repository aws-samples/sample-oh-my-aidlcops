---
name: audit-trail
description: 모든 사용자 발화·agent 행동·phase 전환·gate 판정을 ISO 8601 타임스탬프와 함께 감사 로그에 기록한다. 사용자 입력은 축약·요약 없이 verbatim blockquote로 보존하며, SOC2·ISMS-P 감사 요구사항에 매핑되는 보존 정책(30·90·365일)을 프로젝트별로 선택한다. 모든 AIDLC skill이 호출 가능한 공통 감사 계층을 제공한다.
argument-hint: "[session-id or slug]"
user-invocable: true
model: claude-haiku-4-5
allowed-tools: "Read,Write,Bash"
---

## 언제 사용하나요

다음 상황에서 본 skill을 실행합니다.

- Stage·Phase 시작/종료 시점에 감사 이벤트를 기록해야 할 때
- 사용자가 원본 프롬프트·수락/거부 결정·방향 전환을 입력한 시점
- 파일 생성/수정, 명령 실행, 에러 발생/해결, 질문·응답, 승인 요청/결과가 발생한 시점
- 테스트 skip 이유·gate waiver 발급 등 예외 사유를 기록해야 할 때

다음 상황에서는 사용하지 않습니다.

- 일회성 개인 탐색 세션 — 감사 로그가 불필요합니다.
- 로컬 dev 환경의 temp 파일 조작 — 프로덕션 경로와 분리하여 기록 제외.

## 전제 조건

- `.omao/state/audit/` 디렉토리 쓰기 권한. 본 skill이 세션별 로그 파일을 생성합니다.
- 세션 ID 또는 프로젝트 slug 확정. 로그 파일은 `<session-id>.md` 네이밍을 사용합니다.
- Kiro 레포 MIT-0 `audit-rules.md`의 verbatim 기록 원칙을 준수. 사용자 입력을 축약·요약·재구성하지 않습니다.

## 핵심 원칙

### 1. Verbatim 기록 (MANDATORY)

사용자 입력은 **원문 그대로** blockquote로 기록합니다. 요약·의역·키워드 추출·재구성을 금지합니다.

```markdown
- **User Prompt (verbatim)**:
  > 사용자가 입력한 원본 텍스트 그대로. 오타·비문·감정 표현 보존.
```

### 2. ISO 8601 타임스탬프

모든 이벤트는 `[YYYY-MM-DDTHH:MM:SSZ]` (UTC) 형식을 사용합니다. 로컬 시간대·비표준 형식 금지.

```bash
timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
```

### 3. 불변 로그 (Append-Only)

감사 로그는 추가 전용입니다. 수정·삭제 필요 시 **보정 이벤트(correction event)** 를 새로 추가합니다.

```markdown
### [2026-04-21T10:15:00Z] Correction — 2026-04-21T09:30:00Z 이벤트 수정
- 사유: 원본 기록의 파일 경로 오기
- 원본 항목: (링크)
- 정정 내용:
```

### 4. 보존 정책 (Retention)

프로젝트 단위로 보존 기간을 선택합니다.

| 보존 기간 | 대상 프로젝트 | 규제 근거 |
|-----------|---------------|-----------|
| 30일 | 내부 실험·PoC | 운영 정책 |
| 90일 | 일반 프로덕션 | SOC2 CC7.2 |
| 365일 | 규제 대상(금융·의료) | ISMS-P 2.9.4, PCI DSS 10.7 |

보존 기간 설정은 `.omao/state/audit/<session-id>.config.yaml`에 기록합니다.

## 실행 절차

### Step 1: 세션 초기화

세션 시작 시 감사 로그 파일과 설정을 생성합니다.

```bash
SESSION_ID="${1:?usage: audit-trail <session-id>}"
AUDIT_DIR=".omao/state/audit"
mkdir -p "$AUDIT_DIR"
LOG_FILE="$AUDIT_DIR/${SESSION_ID}.md"
CONFIG_FILE="$AUDIT_DIR/${SESSION_ID}.config.yaml"

if [ ! -f "$LOG_FILE" ]; then
  cat > "$LOG_FILE" <<EOF
# Audit Log — ${SESSION_ID}

Session initialized: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
fi

if [ ! -f "$CONFIG_FILE" ]; then
  cat > "$CONFIG_FILE" <<EOF
session_id: ${SESSION_ID}
retention_days: 90
created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
compliance:
  - SOC2
EOF
fi
```

### Step 2: 이벤트 기록

본 skill의 공통 이벤트 타입은 다음과 같습니다.

- `stage-start` / `stage-end`
- `user-prompt` (verbatim)
- `user-answer` (verbatim)
- `ai-action`
- `ai-decision`
- `file-created` / `file-modified`
- `command-executed`
- `error` / `error-resolved`
- `approval-requested` / `approval-granted` / `approval-rejected`
- `gate-evaluation`
- `test-skipped`
- `waiver-issued`

각 이벤트는 `templates/audit-log.template.md`의 형식을 따릅니다.

### Step 3: 검증 루틴

세션 종료 시 다음 불변식을 검증합니다.

- [ ] 모든 사용자 입력이 `> ` blockquote로 기록되었는가
- [ ] 모든 이벤트가 ISO 8601 타임스탬프를 포함하는가
- [ ] 로그 파일이 추가 전용으로 유지되었는가(diff로 검증)
- [ ] retention_days 설정이 프로젝트 규제 요구를 만족하는가

### Step 4: 주기적 정리 (Retention 만료)

보존 기간을 초과한 로그를 자동 아카이브하거나 삭제합니다.

```bash
find .omao/state/audit -name "*.config.yaml" | while read cfg; do
  retention=$(grep "^retention_days:" "$cfg" | awk '{print $2}')
  created=$(grep "^created:" "$cfg" | awk '{print $2}')
  # 유통기한 초과 시 아카이브 디렉토리로 이동 (삭제는 추가 승인 필요)
done
```

## SOC2 / ISMS-P 매핑

| 요구사항 | 본 skill의 기여 |
|----------|----------------|
| SOC2 CC7.2 (Monitoring) | 모든 사용자·agent 이벤트 타임스탬프 기록 |
| SOC2 CC6.1 (Logical Access) | 승인 요청/결과 verbatim 보존 |
| ISMS-P 2.9.4 (로그 관리) | 365일 보존 옵션 + 불변성 검증 |
| ISMS-P 2.10.9 (침해사고 대응) | error·error-resolved 이벤트 추적 |
| PCI DSS 10.7 | 1년 보존 + 첫 90일 즉시 조회 가능 |

## 산출물 체크리스트

본 skill 실행 종료 직전 다음을 자동 검증합니다.

- [ ] `.omao/state/audit/<session-id>.md` 존재 및 최소 1개 이벤트 기록
- [ ] `.omao/state/audit/<session-id>.config.yaml` retention_days 명시
- [ ] 모든 이벤트 타임스탬프가 UTC·ISO 8601 형식
- [ ] 사용자 입력 항목이 모두 blockquote로 보존
- [ ] 로그 파일이 git-ignored 또는 별도 secure 저장소로 분리

## 좋은 예시 vs 나쁜 예시

**Good** — 사용자 입력을 원문 그대로 보존합니다.

```markdown
### [2026-04-21T09:45:12Z] User Prompt
- **User Prompt (verbatim)**:
  > 일단 빠르게 배포 진행해주시고, 모니터링은 내일 붙이면 될거같아요. 암튼 오늘내로 나가야합니다.
- **AI Judgment**: 사용자 요청은 quality gate 우회 신호이므로 waiver 없이 진행 불가.
- **Next Action**: waiver 요청 템플릿 제시.
```

**Bad** — 사용자 입력을 요약·의역합니다.

```markdown
- 사용자가 빠른 배포를 요청함. 모니터링은 나중에 추가 예정. (❌ 원문 소실)
```

**Good** — 타임스탬프가 UTC·ISO 8601.

```markdown
### [2026-04-21T09:45:12Z] File Created
```

**Bad** — 타임스탬프가 로컬 시간대·비표준.

```markdown
### [4/21 오후 6:45] 파일 생성 (❌ UTC 아님, ISO 아님)
```

## 참고 자료

### 공식 문서

- [aws-samples/sample-ai-driven-modernization-with-kiro — audit-rules](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro/blob/main/.kiro/steering/audit-rules.md) — MIT-0 원본 감사 원칙
- [AWS Artifact — SOC2 Compliance](https://aws.amazon.com/compliance/soc-faqs/) — SOC2 CC7.2 요구사항
- [NIST SP 800-92 — Log Management](https://csrc.nist.gov/publications/detail/sp/800-92/final) — 로그 보존·무결성 가이드
- [ISO 8601 Date and Time Format](https://www.iso.org/iso-8601-date-and-time-format.html) — 타임스탬프 표준

### 관련 문서 (내부)

- `../../aidlc-construction/skills/quality-gates/SKILL.md` — gate 판정 이벤트를 본 skill로 기록
- `../../aidlc-construction/skills/risk-discovery/SKILL.md` — risk 판정 결과를 감사 로그에 push
- `../../aidlc-inception/skills/structured-intake/SKILL.md` — 사용자 intake 응답을 verbatim 보존
- `../incident-response/SKILL.md` — SEV 이벤트를 본 skill로 기록
