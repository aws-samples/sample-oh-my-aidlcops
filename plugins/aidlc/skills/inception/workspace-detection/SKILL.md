---
name: workspace-detection
description: "Detect whether the workspace is greenfield (new project) or brownfield (existing codebase). For brownfield, trigger reverse-engineering to recover implicit requirements. Produces a workspace-report.md with detected stack, entry points, and recommended inception path."
argument-hint: "[target directory — defaults to cwd]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Glob,Bash"
---

## 언제 사용하나요

- AIDLC Inception 을 **시작하는 첫 단계**로서 워크스페이스 상태를 판별할 때
- 기존 레포에 기능을 추가하면서 암묵적인 도메인 컨텍스트를 파악해야 할 때
- greenfield 초기화 전에 빈 디렉터리인지 기존 자산이 남아있는지 확인할 때

## 언제 사용하지 않나요

- 이미 `.omao/plans/<slug>/workspace-report.md` 가 최신 상태로 존재할 때
- 단일 파일 리팩터링 등 워크스페이스 판별이 불필요한 작업
- IaC 전용 리포지토리에서 인프라 변경만 다룰 때

## 전제 조건

- 분석 대상 디렉터리에 대한 read 권한 보유
- `.omao/plans/` 디렉터리가 존재(없을 경우 생성)
- Git 리포지토리 여부는 선택사항 — 비Git 디렉터리도 지원

## 절차

### Step 1. 타깃 디렉터리 확정

인자로 받은 경로 또는 현재 작업 디렉터리를 타깃으로 설정합니다. 절대 경로로 변환한 뒤
존재 여부와 읽기 권한을 확인합니다.

### Step 2. Greenfield / Brownfield 판별

다음 시그널을 종합하여 판별합니다.

| 시그널 | Greenfield | Brownfield |
|--------|-----------|-----------|
| 소스 파일 수 | 10 미만 또는 scaffold 만 존재 | 소스 파일 50 이상 |
| Git 히스토리 | 0~3 commits | 10 이상 commits |
| 의존성 선언 | `package.json`/`pyproject.toml` 없음 또는 초기 스캐폴드 | 고정 버전의 의존성 다수 |
| 테스트 자산 | 테스트 파일 없음 | 테스트 디렉터리 존재 |
| 도메인 모델 | 명시된 엔터티 없음 | 모델/스키마 파일 존재 |

판별 결과는 `workspace_type: greenfield | brownfield | hybrid` 로 기록합니다.

### Step 3. 기술 스택 탐지

- 언어: `*.py`, `*.ts`, `*.go`, `*.java`, `*.rs` 등 확장자 빈도 집계
- 프레임워크: `package.json`, `pyproject.toml`, `go.mod`, `pom.xml` 파싱
- 인프라: `Dockerfile`, `helm/`, `terraform/`, `*.tf`, `k8s/`, `kustomization.yaml` 존재 여부
- AI/ML 스택: `requirements.txt` 에서 `vllm`, `transformers`, `langfuse`, `langchain` 탐지

### Step 4. 엔트리 포인트 목록

- CLI: `bin/`, `cmd/`, `main.py`
- API: `app.py`, `server.ts`, `api/` 라우트
- UI: `src/pages/`, `app/`, `public/`
- Worker: `workers/`, `consumers/`

### Step 5. 브라운필드 확장 — Reverse Engineering 트리거

`workspace_type == brownfield` 인 경우, 다음 산출물을 추가 수집합니다.

- 도메인 모델 요약(클래스/스키마 상위 20개)
- 외부 의존 서비스(AWS, 데이터베이스, 벡터 DB, 메시지 큐)
- 관측성 스택 존재 여부(OpenTelemetry, Langfuse, Prometheus)
- 보안 시그널(Secrets Manager, IRSA, OIDC)

결과는 `reverse-engineering-notes.md` 로 별도 저장하고, `workspace-report.md` 에서 링크합니다.

### Step 6. 산출물 생성

`.omao/plans/<slug>/workspace-report.md` 에 다음 섹션을 기록합니다.

```markdown
# Workspace Report
- workspace_type: brownfield
- primary_language: Python 3.11
- frameworks: [FastAPI, LangChain, vLLM client]
- entry_points: [app/main.py, workers/indexer.py]
- infrastructure: [Helm, Terraform]
- recommended_next: requirements-analysis (adaptive, complex)
```

### Step 7. 다음 스킬 연결

- greenfield + 단순 기능 → `requirements-analysis` (simple mode)
- greenfield + 복잡 기능 → `requirements-analysis` (structured mode)
- brownfield → `requirements-analysis` + `reverse-engineering-notes.md` 참조

## 좋은 예시

- Python FastAPI 레포 + 50개 소스 + OpenTelemetry 존재 → brownfield, structured
- 빈 디렉터리 + Git init 만 수행 → greenfield, simple
- 스캐폴드만 생성된 Next.js 레포(페이지 없음) → greenfield

## 나쁜 예시 (금지)

- 파일 수만으로 판단하여 `docs/` 위주 레포를 brownfield 로 잘못 분류
- `node_modules/` 를 소스 파일 수에 포함
- 산출물 저장 경로를 `/tmp/` 같은 휘발성 위치로 지정
- 브라운필드인데 reverse-engineering-notes 를 생략

## 참고 자료

### 공식 문서
- [awslabs/aidlc-workflows — core-workflow](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rules/core-workflow.md) — AIDLC 코어 워크플로우 정의
- [awslabs/aidlc-workflows — workspace-detection](https://github.com/awslabs/aidlc-workflows/blob/main/aidlc-rules/aws-aidlc-rule-details/inception/workspace-detection.md) — 원본 워크스페이스 탐지 규칙

### 관련 문서 (내부)
- `../../CLAUDE.md` — aidlc-inception 플러그인 개요
- `../requirements-analysis/SKILL.md` — 다음 단계 스킬
- `/home/ubuntu/workspace/oh-my-aidlcops/CLAUDE.md` — OMA 전체 철학
- `/home/ubuntu/workspace/oh-my-aidlcops/plugins/aidlc-construction/CLAUDE.md` — Phase 2 연결
