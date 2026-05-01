---
name: user-stories
description: "Conditionally generate user stories in As-a/I-want/So-that format only when changes are user-facing. Skips story generation for pure infrastructure or internal refactor work. Produces stories with acceptance criteria linked back to REQ-IDs."
argument-hint: "[feature slug — same slug used in requirements-analysis]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Grep,Glob"
---

## 언제 사용하나요

- `requirements-analysis` 산출물이 사용자 대면 기능을 포함할 때
- 여러 페르소나(관리자 / 운영자 / 최종 사용자) 관점의 가치 서술이 필요할 때
- Acceptance Criteria 를 기능 단위에서 스토리 단위로 확장할 때

## 언제 사용하지 않나요

- 내부 리팩터링, 빌드 파이프라인 변경, 인프라 설정만 바뀌는 경우
- 단일 외부 API 추가처럼 최종 사용자 시나리오 변화가 없는 작업
- 이미 승인된 스토리를 단순 복사하는 경우 — 기존 파일 참조

## 전제 조건

- `.omao/plans/<slug>/requirements.md` 존재
- 페르소나 목록 확정(최소 1개, 최대 5개 권장)
- Acceptance Criteria 작성 가능한 수준으로 기능이 분해됨

## 절차

### Step 1. 조건부 실행 판단

다음 질문에 모두 "예" 인 경우에만 스토리를 생성합니다.

1. 해당 변경이 외부 사용자 또는 내부 사용자의 화면/CLI/API 경험을 바꾸는가?
2. 변경된 경험에 대한 가치 서술(왜 필요한가) 이 요구사항만으로 충분히 드러나지 않는가?
3. Acceptance Criteria 가 요구사항 레벨보다 세밀하게 기술되어야 하는가?

모두 "아니오" 인 경우 스토리 생성을 스킵하고, `decision-log.md` 에 스킵 사유를 기록합니다.

### Step 2. 페르소나 정의

| 필드 | 예시 |
|------|------|
| 이름 | 플랫폼 운영자 / AI 서비스 개발자 / 최종 사용자 |
| 주요 목표 | 지연 감소, 비용 가시성, 개인정보 보호 |
| 권한 수준 | 읽기 / 쓰기 / 승인 |
| 주요 채널 | Web UI, CLI, API, Slack |

### Step 3. As-a / I-want / So-that 포맷

```markdown
### US-01 — Semantic Router 폴백 알림
- **As a** 플랫폼 운영자
- **I want** 라우터가 폴백 경로로 전환되는 순간 알림을 받기를
- **So that** 사용자 영향이 발생하기 전에 조치할 수 있습니다.

**Acceptance Criteria**
- [ ] 폴백 전환 이벤트가 Slack `#ai-platform-ops` 채널에 30초 내 게시됩니다.
- [ ] 알림은 트리거 REQ-ID(REQ-002) 와 트레이스 ID 링크를 포함합니다.
- [ ] 알림은 동일 원인 기준 15분간 중복 집계(deduplicate) 됩니다.

**Traceability**: REQ-001, REQ-002
```

### Step 4. 스토리 우선순위

- P0 (필수): 차단 요소, 규제 이슈, 데이터 정합성
- P1 (중요): 주요 사용 흐름, 대규모 사용자 영향
- P2 (선호): 편의성 개선, 보조 페르소나 요구
- 우선순위는 `requirements.md` 의 REQ-ID 중요도와 일관성 유지

### Step 5. 스토리 단위 크기 제어

- 각 스토리는 2~5일 구현 분량(MoSCoW 기준 "Should" 이상) 으로 제한합니다.
- 5일을 초과하면 하위 스토리로 분해하고 `US-01 → US-01a / US-01b` 형태로 번호를 부여합니다.

### Step 6. 산출물 저장

- `.omao/plans/<slug>/user-stories.md` 저장
- frontmatter: `created`, `last_update.date`, `tags: [aidlc, inception, user-stories]`
- 각 스토리에 Traceability 블록(REQ-ID 매핑) 필수

### Step 7. 다음 스킬 연결

- `workflow-planning` 에 각 스토리가 속할 Unit 을 전달합니다.
- 사용자 대면 요구가 없어 스토리를 생략한 경우, `decision-log.md` 만 남기고 건너뜁니다.

## 좋은 예시

- 3개 페르소나, 각 3~5 스토리, 모든 스토리에 REQ-ID 링크 + 체크리스트 형식 Acceptance Criteria
- 1개 P0 스토리(차단 요소) + 2개 P1 스토리(주요 흐름) + 1개 P2 스토리(편의성)

## 나쁜 예시 (금지)

- "사용자는 빠른 응답을 원한다" — 페르소나 없음, 가치 모호, 수치 부재
- REQ-ID 를 전혀 참조하지 않아 Traceability 깨짐
- 하나의 스토리에 5개 이상 AC 병합 — 독립 스토리로 분해 필요
- 내부 전용 변경에 스토리를 억지로 생성 — 스킵 사유 기록이 올바른 선택

## 참고 자료

### 공식 문서
- [awslabs/aidlc-workflows — user-stories](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rule-details/inception/user-stories.md) — 원본 사용자 스토리 규칙
- [Atlassian Agile — User Stories](https://www.atlassian.com/agile/project-management/user-stories) — As-a/I-want/So-that 표준

### 관련 문서 (내부)
- `../requirements-analysis/SKILL.md` — 선행 스킬(REQ-ID 소스)
- `../workflow-planning/SKILL.md` — 후행 스킬(Unit 매핑)
- `../../CLAUDE.md` — aidlc-inception 개요
- `/home/ubuntu/workspace/oh-my-aidlcops/CLAUDE.md` — OMA 전체 철학
