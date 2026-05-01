# PRIORITY: This extension activates MANDATORY checks for Korean technical documentation style

이 확장은 AIDLC Inception 산출물(`requirements.md`, `user-stories.md`,
`workflow-plan.md`) 에 engineering-playbook Documentation Style Guide 를 강제합니다.
opt-in 이 승인된 경우에만 적용됩니다.

## When to Load

다음 조건 중 하나 이상이 성립하면 확장을 로드합니다.

- 산출물의 기본 언어가 한국어로 선언된 경우(프로젝트 메타 또는 사용자 옵트인)
- `workspace-report.md` 에 한글 README / 문서가 다수 포함된 경우
- 사용자가 Requirements Analysis 단계에서 `korean-docs-style` 옵트인을 명시적으로 선택

비한국어 산출물만 생성하는 프로젝트에서는 로드하지 않습니다.

## MANDATORY: Voice & Tone

- **경어체 유지** — 모든 본문/설명/캡션은 `-합니다`, `-입니다` 로 종결합니다.
- **1인칭 금지** — `저는`, `제가`, `우리는`, `우리가 만들어봅시다` 등 사용 금지.
- **감정 표현 금지** — `놀랍게도`, `정말`, `매우 쉽게` 등 주관적 수식어 배제.
- **사실 기반 단정형** — 추측은 `~로 예상됩니다`, `~일 가능성이 있습니다` 로 명시 구분.
- **능동태 우선** — 행위자보다 동작이 중요할 때만 수동태 허용.

## MANDATORY: Frontmatter 필수 필드

모든 산출물 Markdown 은 다음 frontmatter 를 포함해야 합니다.

```yaml
---
title: 문서 제목
description: 한 문장 요약 (80~160자)
created: YYYY-MM-DD
last_update:
  date: YYYY-MM-DD
  author: <담당자>
reading_time: <정수 분>
tags:
  - aidlc
  - inception
  - scope:design
---
```

필수 필드 누락 또는 형식 불일치는 블로킹 결함입니다.

## MANDATORY: 참고 자료 섹션

모든 문서 말미에 `## 참고 자료` 섹션이 존재해야 하며, 다음 최소 구성 요건을 충족해야
합니다.

- 공식 문서(`### 공식 문서`) 최소 2개
- 관련 문서(`### 관련 문서` 또는 `### 관련 문서 (내부)`) 최소 2개
- 각 항목은 `- [제목](URL) — 한 줄 설명` 형식
- 내부 문서 링크는 상대 경로(`../`, `./`) 만 허용, 절대 경로(`/docs/...`) 금지

## MANDATORY: 구조 제약

- H1(`#`) 본문 사용 금지 — frontmatter `title` 로 대체합니다.
- H2/H3 위주 사용, H4 는 예외적으로만 허용합니다.
- 헤딩은 명사구 권장(`## 아키텍처`), 질문형 금지(`## 아키텍처는 어떻게 생겼나?`).
- 표는 3열 이상 속성 비교 시 사용합니다.
- 코드 블록은 언어 태그 필수(` ```bash `, ` ```yaml `, ` ```python `).

## Blocking Findings

- **FINDING-KD-001**: 1인칭 표현 감지(`저는`, `제가`, `우리는`, `우리가`)
- **FINDING-KD-002**: frontmatter 필수 필드(title / description / created / last_update.date / reading_time / tags) 누락
- **FINDING-KD-003**: `## 참고 자료` 섹션 누락 또는 공식/관련 문서 최소 개수 미달
- **FINDING-KD-004**: 본문 H1 사용
- **FINDING-KD-005**: 코드 블록 언어 태그 누락

## Integration with core-workflow.md

- `core-workflow.md` 의 Content Validation 규칙 위에 위 MANDATORY 블록을 추가로 적용합니다.
- compliance summary 에 `Voice`, `Frontmatter`, `References`, `Structure` 4개 축으로
  준수 여부를 보고합니다.
- 블로킹 결함이 존재하면 stage 완료를 차단하고, 결함별 수정안을 `audit.md` 에
  기록합니다.

## Rule Details Loading

opt-in 승인 후 로드할 상세 규칙 파일 경로(존재 순서대로 첫 매치 사용):

1. `.aidlc/aidlc-rules/aws-aidlc-rule-details/extensions/korean-docs-style.md`
2. `.aidlc-rule-details/extensions/korean-docs-style.md`
3. `.kiro/aws-aidlc-rule-details/extensions/korean-docs-style.md`
4. `.amazonq/aws-aidlc-rule-details/extensions/korean-docs-style.md`

상세 규칙 파일이 없으면 본 opt-in 파일이 정의한 MANDATORY 블록을 최소 기준으로
사용합니다. 참고 원본은 engineering-playbook `CLAUDE.md` 의 Documentation Style
Guide 입니다.
