---
name: modernization-strategy
description: "Decide the 6R modernization pattern — Rehost / Replatform / Refactor / Repurchase / Retire / Retain — using a decision tree and cost/time/risk matrix. Produces a defensible strategy-decision.md that justifies the selected pattern with quantitative evidence. Use after workload-assessment and before to-be-architecture."
argument-hint: "[assessment-report-path, constraints (budget|deadline|risk-tolerance)]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Grep,Glob,Bash,WebFetch,mcp__aws-documentation,mcp__aws-pricing"
---

## 언제 사용하나요

- `workload-assessment` 가 생성한 `assessment-report.md` 가 존재하고 6R 패턴 결정이 필요할 때
- 기존 현대화 경로가 예산·일정 변경으로 재평가되어야 할 때
- 단일 워크로드의 세부 컴포넌트별로 서로 다른 6R 을 적용할지 판단할 때
- Rehost 로 시작해서 Refactor 로 진화하는 점진적(iterative) 경로 설계가 필요할 때

## 언제 사용하지 않나요

- `assessment-report.md` 가 아직 존재하지 않을 때 — 선행 skill 먼저 수행
- 단순 EC2 인스턴스 재배치 — 6R 평가 overhead 가 불필요
- 경영진이 이미 전략을 확정한 경우 — 이 skill 은 검증 도구로만 제한적 사용

## 전제 조건

- `.omao/plans/modernization/assessment-report.md` 가 `readiness_score`, `five_lenses`, `compliance` 필드를 포함
- AWS Pricing MCP 접근 가능 (6R 별 cost 추정)
- 예산 상한, 일정 제약, 리스크 허용 수준 중 최소 1개가 입력으로 제공됨

## 절차

### Step 1. 입력 재확인

- `assessment-report.md` 를 읽어 dependency complexity, database size, traffic peak, compliance list 추출
- 사용자로부터 3개 제약 조건 확인:
  - 예산 상한 (annual cloud cost ceiling)
  - 일정 (target cutover date)
  - 리스크 허용 (low/medium/high)

### Step 2. 6R 후보 생성

aws-samples `modernization-strategy.md` 기반 6개 패턴을 워크로드 특성에 매핑합니다.

| Pattern | 적합 조건 | 일정 | 노력 | 클라우드 혜택 |
|---------|---------|------|------|-------------|
| **Rehost** | 시간 촉박, 리스크 낮게 유지 | 주-월 | 낮음 | 낮음 |
| **Replatform** | 일부 클라우드 혜택 원함 (MySQL → RDS) | 월 | 중간 | 중간 |
| **Refactor** | 전략적 앱, 마이크로서비스 목표 | 월-년 | 높음 | 최대 |
| **Repurchase** | 비차별화 기능, SaaS 대체 가능 | 월 | 중간 | 중간 |
| **Retire** | 사용 빈도 낮고 대체재 존재 | 주 | 낮음 | 비용 절감 |
| **Retain** | 아직 준비 미흡, 후속 재평가 | N/A | 없음 | 없음 |

### Step 3. Decision Tree 적용

```
Q1. 비즈니스 가치가 Low 이고 사용 빈도가 감소 중?
  YES → Retire 검토
  NO  → Q2
Q2. SaaS 로 대체 가능한 비차별화 기능?
  YES → Repurchase 검토
  NO  → Q3
Q3. 현재 준비도(readiness_score) 가 Low?
  YES → Retain 또는 Rehost 후 점진 개선
  NO  → Q4
Q4. 일정 6개월 이내 + 리스크 허용도 Low?
  YES → Rehost 또는 Replatform
  NO  → Q5
Q5. 전략적 중요도 High + 팀 DevOps 성숙도 Medium 이상?
  YES → Refactor (마이크로서비스 + 컨테이너 + IaC)
  NO  → Replatform (managed DB + Auto Scaling)
```

### Step 4. Cost/Time/Risk Matrix 작성

각 후보 패턴에 대해 정량 수치를 계산합니다. 숫자는 AWS Pricing MCP 와 과거 유사 프로젝트 데이터에서 추정합니다.

| Pattern | 3년 TCO (USD) | 마이그레이션 공수 (인-월) | 기술 리스크 (1-5) | 비즈니스 리스크 (1-5) | 컴플라이언스 리스크 (1-5) |
|---------|--------------|--------------------------|-----------------|--------------------|---------------------------|
| Rehost | 450,000 | 3 | 2 | 3 | 2 |
| Replatform | 380,000 | 8 | 3 | 2 | 2 |
| Refactor | 620,000 | 24 | 4 | 2 | 3 |

### Step 5. Output 산출

`.omao/plans/modernization/strategy-decision.md` 에 다음을 필수로 기록합니다.

```markdown
# Modernization Strategy Decision
- workload: ${workload-slug}
- decided_pattern: Replatform
- decision_date: YYYY-MM-DD
- rationale: |
    1. readiness_score = Medium → Refactor 무리
    2. 3년 TCO Replatform 이 Refactor 대비 39% 저렴
    3. RDS 매니지드 이전으로 운영 부담 -45%
- considered_alternatives: [Rehost, Refactor]
- rejected_reasons:
  - Rehost: 운영 부담 지속, TCO 절감 효과 미미
  - Refactor: 팀 DevOps 성숙도 Low, 24 인-월 공수 확보 불가
- cost_time_risk_matrix: (Step 4 표)
- next_skill: to-be-architecture
- audit_trail_ref: aidlc-docs/audit.md#DEC-MOD-001
```

### Step 6. risk-discovery 연동

`aidlc/skills/construction/risk-discovery` 를 호출하여 선택된 패턴의 리스크 4축(재무·기술·조직·규정) 을 재검증합니다. PASS 가 아니면 본 skill 은 중단하고 대안 패턴을 제시합니다.

### Step 7. 사용자 승인 체크포인트

`decided_pattern` 은 사용자 명시적 승인을 받기 전까지 Draft 상태로 유지됩니다. 승인 후에만 `to-be-architecture` skill 이 기동됩니다.

## 좋은 예시

- Java EE + Oracle → Replatform (ECS Fargate + Aurora PostgreSQL). Rationale: TCO -32%, 공수 8 인-월, 기술 리스크 3/5
- 사내 인사 시스템 → Repurchase (Workday 도입). Rationale: 비차별화, SaaS TCO 유리
- 사용자 10명 대시보드 → Retire. Rationale: 대체재(QuickSight) 존재, 연간 사용 시간 12h

## 나쁜 예시 (금지)

- "현대적 아키텍처가 좋다" 같은 주관 근거로 Refactor 선택 — 수치 없이 결정
- Cost/Time/Risk Matrix 생략하고 결론만 기록
- 사용자 승인 없이 `to-be-architecture` 자동 진행
- Retain 선택 시 재평가 일정(예: 6개월 후) 누락

## 참고 자료

### 공식 문서
- [AWS Prescriptive Guidance — 6R](https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/welcome.html) — AWS 공식 6R 전략 가이드
- [AWS Migration Hub](https://aws.amazon.com/migration-hub/) — 워크로드 평가·계획 도구

### 원천 방법론 (MIT-0)
- [modernization-strategy.md (Kiro)](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro/blob/main/.kiro/skills/aws-practices/modernization-strategy.md) — 6R 원본 정의
- [AWS Blog — 6 Application Migration Strategies](https://aws.amazon.com/blogs/enterprise-strategy/6-strategies-for-migrating-applications-to-the-cloud/) — 6R 공식 블로그

### 관련 문서 (내부)
- `../workload-assessment/SKILL.md` — 선행 skill
- `../to-be-architecture/SKILL.md` — 후속 skill
- `/home/ubuntu/workspace/oh-my-aidlcops/plugins/aidlc/CLAUDE.md` — risk-discovery 제공
