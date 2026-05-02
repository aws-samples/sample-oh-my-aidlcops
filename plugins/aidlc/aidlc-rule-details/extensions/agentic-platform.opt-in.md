# PRIORITY: This extension activates MANDATORY checks for Agentic AI Platform domain

When the AIDLC Inception workflow runs inside an Agentic AI / LLM serving project,
this extension adds non-negotiable domain checks on top of `core-workflow.md`.
It is loaded only when the user explicitly opts in during Requirements Analysis.

## When to Load

Load this extension when **any** of the following signals are present:

- `workspace-report.md` 에 `vllm`, `langfuse`, `kgateway`, `llm-d`, `kagent` 키워드 포함
- 프로젝트 슬러그가 `agentic-*`, `llm-*`, `inference-*` 로 시작
- `requirements.md` 의 태그에 `agentic-ai`, `inference`, `observability` 중 하나 이상 존재
- 사용자가 Requirements Analysis 단계에서 `agentic-platform` 옵트인을 명시적으로 선택

이 조건을 만족하지 않으면 확장은 비활성 상태로 유지되며, 어떤 규칙도 강제되지
않습니다.

## MANDATORY: GPU Capacity Plan Present

- REQ-NF 섹션에 GPU 타입(p5 / g6e / trn2 등), 수량, Spot/On-Demand 비율이 수치로 기재되어야 합니다.
- Karpenter NodePool 설계가 `workflow-plan.md` 의 Unit 또는 Checkpoint 에 명시되어야 합니다.
- GPU 쿼터 리스크 항목이 Risk Matrix 에 포함되어야 합니다.

## MANDATORY: Langfuse Observability Referenced in Design

- 비기능 요구사항 또는 Gate 중 하나에 **Langfuse v3.x 기반 트레이스 수집** 이 명시되어야 합니다.
- OpenTelemetry Collector → Langfuse 경로가 아키텍처 설명에 포함되어야 합니다.
- Self-hosted 인 경우 PostgreSQL, ClickHouse, Redis, S3 의존성이 REQ-NF 에 기록되어야 합니다.

## MANDATORY: Inference Gateway Routing Defined

- kgateway v2.0+ 또는 동등 게이트웨이 도입 여부가 명시되어야 합니다.
- 라우팅 전략(2-Tier / Cascade / Semantic Router) 중 하나가 선택되고 근거가 기술되어야 합니다.
- HTTPRoute / xRoute 정의가 Phase 2 핸드오프 항목에 포함되어야 합니다.

## MANDATORY: Guardrails Policy Documented

- PII 마스킹 정책이 REQ-NF 또는 보안 섹션에 기술되어야 합니다.
- Prompt Injection 방어(입력 필터링, 도구 허용 목록) 가 명시되어야 합니다.
- 정책 위반 시 대응 플로우(거부, 로그, 알림) 가 워크플로우 플랜에 포함되어야 합니다.

## Blocking Findings

다음 FINDING 중 하나라도 발견되면 Inception 을 종료하지 못합니다.

- **FINDING-AP-001**: GPU 타입/수량 수치 누락
- **FINDING-AP-002**: Langfuse 또는 동등 관측성 설계 누락
- **FINDING-AP-003**: Inference Gateway 라우팅 전략 미선정
- **FINDING-AP-004**: PII / Prompt Injection 방어 정책 공백
- **FINDING-AP-005**: GPU 쿼터 리스크가 Risk Matrix 에서 누락

## Integration with core-workflow.md

- `core-workflow.md` 의 Requirements Analysis 단계가 끝나기 전, 위 4개 MANDATORY 블록의
  준수 여부를 평가합니다.
- 평가 결과는 compliance summary 에 `compliant / non-compliant / N/A` 로 기록되고,
  non-compliant 항목이 존재하면 stage 완료를 차단합니다.
- N/A 결정은 근거와 함께 `audit.md` 에 기록되어야 합니다.

## Rule Details Loading

opt-in 이 승인된 뒤 로드할 상세 규칙 파일 경로는 다음과 같습니다(존재 순서대로 첫 번째 매치 사용).

1. `.aidlc/aidlc-rules/aws-aidlc-rule-details/extensions/agentic-platform.md`
2. `.aidlc-rule-details/extensions/agentic-platform.md`
3. `.kiro/aws-aidlc-rule-details/extensions/agentic-platform.md`
4. `.amazonq/aws-aidlc-rule-details/extensions/agentic-platform.md`

상세 규칙 파일이 아직 제공되지 않은 경우, 본 opt-in 파일이 정의한 MANDATORY 블록을
최소 기준으로 사용합니다.
