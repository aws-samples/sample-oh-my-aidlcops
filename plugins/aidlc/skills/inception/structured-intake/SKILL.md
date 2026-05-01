---
name: structured-intake
description: AIDLC Inception 시작 시 자유 형식 발화 대신 구조화된 템플릿으로 프로젝트 정보를 수집한다. project-info 템플릿과 requirements 템플릿을 순차 생성하여 후속 workspace-detection·requirements-analysis·user-stories skill이 소비할 단일 진실원을 제공한다.
argument-hint: "[project slug — e.g., rag-qa, inference-gateway]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Bash"
---

## 언제 사용하나요

다음 상황에서 본 skill을 실행합니다.

- AIDLC Inception을 신규 프로젝트·feature 단위로 시작할 때, 첫 발화가 자유 형식으로 들어온 경우 구조화된 템플릿으로 전환하는 진입점이 필요할 때
- 이해관계자·성공 기준·제약이 흩어져 있어 요구사항 분석(`requirements-analysis`) 전에 사실 관계를 정렬해야 할 때
- 고객·사내 다팀 워크숍에서 공통 입력 양식으로 프로젝트 배경을 수집할 때

다음 상황에서는 사용하지 않습니다.

- 단일 버그 픽스·문서 오타 수정 — 구조화된 intake가 과도합니다. `requirements-analysis` Simple 모드로 직행합니다.
- 이미 `project-info.md`가 승인된 상태에서 재실행 — 덮어쓰면 히스토리가 사라집니다. 변경은 별도 PR로 진행합니다.

## 전제 조건

- `.omao/plans/` 디렉토리 쓰기 권한. 본 skill이 `.omao/plans/<slug>/` 하위 산출물을 생성합니다.
- 프로젝트 slug(kebab-case) 결정. 이후 모든 AIDLC 아티팩트가 이 slug를 공유합니다.
- 의사결정 권한을 가진 이해관계자 최소 1명 식별(승인자, 예산 결정권자 등).
- Kiro 레포 MIT-0 라이선스의 `prompts/1-as-is-analysis`, `prompts/2-requirement-analysis` 구조를 참조하여 OMA 경어체로 한국어화된 템플릿 사용.

## 실행 절차

### Step 1: 템플릿 복사

본 skill 디렉토리의 템플릿 2개를 프로젝트 slug 하위로 복사합니다.

```bash
SLUG="${1:?usage: structured-intake <project-slug>}"
SKILL_DIR="$(dirname "$0")"  # or CLAUDE_PLUGIN_ROOT
TARGET=".omao/plans/${SLUG}"
mkdir -p "$TARGET"
test -f "$TARGET/project-info.md" && { echo "project-info.md already exists — edit via PR"; exit 1; }
cp "$SKILL_DIR/templates/project-info.template.md" "$TARGET/project-info.md"
cp "$SKILL_DIR/templates/requirements.template.md" "$TARGET/requirements.md"
```

템플릿 복사 후 frontmatter의 `created`, `last_update.date`를 오늘 날짜로 갱신합니다. `slug` 필드에 Step 입력 값을 채웁니다.

### Step 2: 사용자와 빈칸 채우기

`project-info.md`의 6개 섹션을 사용자와 대화하며 순서대로 채웁니다.

| 섹션 | 질문 예시 | 금지 표현 |
|------|----------|----------|
| 배경 | 어떤 문제를 해결하려고 합니까 | "편리하게", "쉽게" |
| 목표 | 3개월·6개월 단위 성공 기준은 무엇입니까 | 수치 없는 선언 |
| 제약 | 예산·마감·규제·기술 스택 제약이 있습니까 | "가능하면" |
| 이해관계자 | 의사결정자·사용자·리뷰어는 누구입니까 | 역할 없이 이름만 |
| 타임라인 | Phase 단위 마일스톤을 언제로 잡습니까 | "빠르게" |
| 성공 기준 | 측정 가능한 KPI·SLO는 무엇입니까 | 주관적 표현 |

각 섹션은 최소 3문장 이상으로 작성합니다. 사용자 응답이 모호하면 구체적인 수치·이름·날짜를 요구하는 재질문을 실시합니다.

### Step 3: requirements 템플릿 초안 생성

`project-info.md`가 완성되면 `requirements.md`의 REQ-ID 표에 기능·비기능 요구사항 3~5개를 초안으로 채웁니다. 이 초안은 후속 `requirements-analysis` skill이 정제할 입력입니다.

```bash
echo "[$(date -Iseconds)] structured-intake completed for ${SLUG}" \
  >> .omao/state/audit/${SLUG}.log 2>/dev/null || true
```

산출물 체크리스트:

- [ ] `.omao/plans/<slug>/project-info.md` 6개 섹션 모두 채워짐
- [ ] `.omao/plans/<slug>/requirements.md` REQ-ID 초안 3개 이상
- [ ] frontmatter `created`·`last_update.date`가 오늘 날짜
- [ ] 이해관계자 섹션에 의사결정자 최소 1명 실명

## 좋은 예시 vs 나쁜 예시

**Good** — 배경 섹션이 사실 기반 단정형으로 서술됩니다.

> "현재 RAG QA 시스템은 p95 응답 지연 4.2초이며, 2026 Q1 사용자 설문 결과 NPS -12점으로 관측되었습니다. 주 원인은 재랭킹 단계 부재로 분석됩니다."

**Bad** — 배경이 감정 표현·수사로 채워져 검증 불가합니다.

> "사용자들이 매우 답답해하고 있어서 정말 빠르게 개선해야 합니다."

**Good** — 성공 기준이 수치·측정 지표를 포함합니다.

> "p95 응답 지연 < 1.5초, faithfulness ≥ 0.88, 월간 인프라 비용 < $2,400 이하를 동시에 만족해야 합니다."

**Bad** — 성공 기준이 주관적입니다.

> "사용자가 만족할 만한 수준까지 성능을 높입니다."

## 참고 자료

### 공식 문서

- [awslabs/aidlc-workflows — Inception stage](https://github.com/awslabs/aidlc-workflows/tree/main/aidlc-rules/aws-aidlc-rule-details/inception) — AIDLC Inception 공식 규약
- [aws-samples/sample-ai-driven-modernization-with-kiro — prompts](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro/tree/main/prompts) — MIT-0 Kiro intake 프롬프트 원본

### 관련 문서 (내부)

- `../workspace-detection/SKILL.md` — intake 완료 후 코드베이스 스캔을 수행하는 후행 skill
- `../requirements-analysis/SKILL.md` — `requirements.md` 초안을 REQ-ID 구조로 정제
- `../user-stories/SKILL.md` — 성공 기준·이해관계자 정보를 소비
- `../../../aidlc-construction/skills/risk-discovery/SKILL.md` — Construction 진입 시 intake 산출물을 위험 탐지 입력으로 사용
