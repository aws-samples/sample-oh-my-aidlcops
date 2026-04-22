# modernization — Legacy-to-AWS Brownfield Modernization Plugin

이 플러그인은 AIDLC Inception·Construction 단계에서 **기존(legacy) 워크로드를 AWS 위의 현대적 아키텍처로 이행**하는 데 사용합니다. 컨테이너 오케스트레이션(ECS/EKS), 매니지드 DB, IaC, CI/CD, Blue-Green/Canary 컷오버 전략까지 6단계 방법론을 단일 플러그인으로 제공합니다.

원천 방법론은 `aws-samples/sample-ai-driven-modernization-with-kiro`(MIT-0) 를 기반으로 하며, OMA 는 이를 Kiro CLI 구속에서 벗어나 Claude Code 네이티브 skill·agent·command 로 재구성했습니다.

## 역할 요약

- **대상 단계**: AIDLC Phase 1 (Inception) + Phase 2 (Construction) 교차 플러그인
- **커버리지**: As-Is 분석, 6R 결정, To-Be 아키텍처, 컨테이너화, 컷오버 계획
- **원천 자산**: Kiro `.kiro/skills/technical/*`, `.kiro/skills/aws-practices/*` 방법론
- **참조 지식**: AWS Modernization 공식 가이드, aws-samples MIT-0 라이선스 원문

## AIDLC 단계와의 관계

| AIDLC 단계 | modernization 플러그인 투입 skill | 산출물 |
|-----------|----------------------------------|--------|
| Inception — Requirements | `workload-assessment`, `modernization-strategy` | `assessment-report.md`, `strategy-decision.md` |
| Inception — Workflow Planning | `to-be-architecture` | `to-be-architecture.md` |
| Construction — Component Design | `to-be-architecture` (심화) | 아키텍처 다이어그램, VPC/IAM/DB 결정 |
| Construction — Code Generation | `containerization` | Dockerfile, ECR push script, ECS/EKS manifest |
| Construction — Test & Release | `cutover-planning` | `cutover-plan.md`, rollback trigger matrix |
| Operations — 운영 핸드오프 | (외부) `agenticops` operations-phase | 모니터링·감사·인시던트 연계 |

## Skills — 실행 순서와 의존성

본 플러그인은 5개 skill 을 제공합니다. 브라운필드 현대화의 표준 실행 순서는 다음과 같습니다.

```
workload-assessment → modernization-strategy → to-be-architecture → containerization → cutover-planning
   (As-Is 분석)       (6R 결정)             (To-Be 설계)        (빌드·푸시)       (트래픽 전환)
```

| Skill | 모델 | 선행 조건 |
|-------|------|----------|
| [`workload-assessment`](./skills/workload-assessment/SKILL.md) | `claude-opus-4-7` | 대상 레거시 시스템 read 권한 |
| [`modernization-strategy`](./skills/modernization-strategy/SKILL.md) | `claude-opus-4-7` | `assessment-report.md` 존재 |
| [`to-be-architecture`](./skills/to-be-architecture/SKILL.md) | `claude-opus-4-7` | `strategy-decision.md` 승인 완료 |
| [`containerization`](./skills/containerization/SKILL.md) | `claude-sonnet-4-6` | `to-be-architecture.md` 존재, Docker 설치 |
| [`cutover-planning`](./skills/cutover-planning/SKILL.md) | `claude-opus-4-7` | 컨테이너 이미지 ECR 푸시 완료 |

각 skill 의 SKILL.md 는 "When to Use / When NOT to Use / 절차 / 좋은 예시 / 나쁜 예시 / 참고 자료" 섹션을 따릅니다.

## Agents

| Agent | 모델 | 역할 |
|-------|------|------|
| `modernization-architect` | opus | 5개 skill 시퀀스 오케스트레이션, 단계 경계에서 `risk-discovery` 호출, 6R·To-Be 결정 판단 |

`agents/modernization-architect.md` 는 의사결정 트리, 자주 쓰는 커맨드, Error→Solution 매핑을 담습니다.

## Commands

- `/oma:modernize` — 6단계 현대화 루프 입구. 타깃 스택(`ecs`/`eks`/`serverless`)과 소스 타입(`monolith`/`microservices`/`legacy-db`)을 인자로 받아 `modernization-architect` 에게 오케스트레이션을 위임합니다.

## 교차 플러그인 통합 (Cross-Cutting Skills)

현대화 방법론은 **방법론 단독으로 완결되지 않습니다**. 다음 cross-cutting skill 이 플러그인 경계를 넘어 자동 활성화됩니다.

| Cross-cutting skill | 제공 플러그인 | 활성화 시점 |
|--------------------|-------------|-----------|
| `risk-discovery` | `aidlc-construction` | 각 phase 종료 직전 — 실행 전 리스크 식별 |
| `audit-trail` | `agenticops` | 모든 산출물 생성 후 — 의사결정 근거를 `audit.md` 에 기록 |

단계 경계별 호출 규약:

- `workload-assessment` 완료 → `risk-discovery` 를 호출하여 "재무/기술/조직/규정" 리스크 4축 평가
- `modernization-strategy` 완료 → 6R 선택이 "근거(cost/time/risk 수치)" 에 기반했는지 `risk-discovery` 로 재검증
- `containerization` 시작 전 → `risk-discovery` PASS 필수 (rollback 경로, 데이터 정합성)
- `cutover-planning` 종료 → `audit-trail` 로 SLO 위반 기준·알림 대상을 Operations 핸드오프 체크리스트에 고정

## MCP Servers

다음 AWS Hosted MCP 서버를 주 의존성으로 사용합니다. 등록은 OMA 최상위 `.mcp.json` 공통 정의를 따릅니다.

- `eks` — EKS 클러스터·Addon·kubectl wrapper (EKS 경로 전용)
- `ecs` — ECS 서비스·Task Definition·Capacity Provider
- `aws-documentation` — 공식 문서·서비스 한도 조회
- `aws-iac` — Terraform/CDK 리소스 생성
- `aws-pricing` — 인스턴스·RDS·ALB TCO 비교

사용 매핑:

- `workload-assessment` → `aws-documentation` (서비스 한도), `aws-pricing` (현재 TCO 추정)
- `modernization-strategy` → `aws-pricing` (6R 별 cost 비교)
- `to-be-architecture` → `aws-iac` (초기 CDK/Terraform 스케치)
- `containerization` → `ecs`, `eks` (매니페스트 검증)
- `cutover-planning` → `ecs`, `eks` (Blue-Green Target Group 검증)

## 사용 원칙

1. **MIT-0 원천 존중** — Kiro 원천 방법론의 라이선스·출처를 `NOTICE` 및 skill 본문 References 에 명시합니다. 재배포 시 MIT-0 원문 링크를 유지합니다.
2. **의견이 아닌 데이터** — 6R 결정은 반드시 cost·time·risk 수치를 `strategy-decision.md` 에 포함합니다. "현대화해야 한다" 같은 주관적 서술은 거부됩니다.
3. **보안 제약** — Security Group `0.0.0.0/0` 오픈 금지. 컷오버 중에도 ALB/NLB + 인증(Cognito/OIDC/mTLS) 경유 필수.
4. **데이터 정합성 우선** — `containerization` 은 stateless 워크로드만 대상으로 하며, stateful 컴포넌트는 `to-be-architecture` 에서 매니지드 DB(RDS/Aurora/DynamoDB) 로 분리합니다.
5. **언어 규칙** — 코드·설정은 영어, 본문은 한국어 경어체. 1인칭·감탄사 금지.
6. **에이전트 경로** — 복잡도 높은 설계 판단(6R, To-Be, 컷오버)은 `modernization-architect` (opus) 에 위임하고, 실행 단계(컨테이너 빌드)는 Sonnet 모델이 담당합니다.

## 상태 관리

본 플러그인이 생성·참조하는 상태 파일은 OMA 표준 `.omao/` 디렉토리를 따릅니다.

- `.omao/plans/modernization/assessment-report.md` — As-Is 분석 산출물
- `.omao/plans/modernization/strategy-decision.md` — 6R 결정 매트릭스
- `.omao/plans/modernization/to-be-architecture.md` — 타깃 아키텍처
- `.omao/plans/modernization/cutover-plan.md` — 트래픽 전환 계획
- `.omao/state/modernization/` — 각 skill 실행 체크포인트
- `aidlc-docs/modernization/` — AIDLC 공식 아티팩트 호환 경로

## 참고 자료

- [OMA 최상위 CLAUDE.md](../../CLAUDE.md) — OMA 전체 철학과 Tier-0 워크플로우
- [aws-samples/sample-ai-driven-modernization-with-kiro](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro) — MIT-0 원천 방법론
- [AWS Modernization Pathways](https://aws.amazon.com/modernization/) — AWS 공식 현대화 가이드
- [aidlc-construction plugin](../aidlc-construction/CLAUDE.md) — `risk-discovery` 의존 플러그인
- [agenticops plugin](../agenticops/CLAUDE.md) — `audit-trail` 및 Operations 핸드오프
- [steering/workflows](../../steering/workflows/) — modernization-loop 및 stage-gated-progression 연결
