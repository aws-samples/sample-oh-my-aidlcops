---
name: risk-discovery
description: Construction 단계 실행 직전, Inception 아티팩트와 설계 문서를 교차 분석하여 12개 카테고리 기반 위험 체크포인트를 탐지한다. 비즈니스 연속성·보안·외부 통합·데이터 일관성·비용·성능·규제·가용성·장애 전파 반경·운영 복잡도·의존성 취약점·롤백 가능성을 각각 PASS/WARN/BLOCK으로 판정하고 BLOCK 항목은 다음 phase 진입을 차단한다.
argument-hint: "[slug or design.md path]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Grep,Bash,mcp__aws-documentation,mcp__well-architected-security"
ontology:
  produces: [Risk]
  consumes: [Spec, ADR]
---

## 언제 사용하나요

다음 상황에서 본 skill을 실행합니다.

- Construction 단계 진입 직전, 설계(`design.md`)와 Inception 아티팩트(`requirements.md`, `user-stories.md`, `workflow-plan.md`, `project-info.md`)가 모두 승인된 시점
- Operations 단계 직전 quality gate로, 프로덕션 배포 전 최종 위험 스캔이 필요할 때
- 큰 설계 변경·신규 외부 통합·데이터 모델 마이그레이션이 발생한 시점

다음 상황에서는 사용하지 않습니다.

- Inception·Construction 아티팩트가 부재한 상태 — 교차 분석 불가. 먼저 상위 skill을 완료해야 합니다.
- 단순 타이포·문구 수정 — 설계·아키텍처에 영향이 없는 변경은 대상이 아닙니다.

## 전제 조건

- `.omao/plans/<slug>/project-info.md`, `requirements.md`, 그리고 `.omao/plans/construction/design.md` 존재 및 승인 완료.
- `mcp__aws-documentation`, `mcp__well-architected-security` MCP 서버 등록(AWS 참조 자료 인용 시).
- `.omao/state/risk-checkpoints/` 디렉토리 쓰기 권한. 본 skill이 카테고리별 판정 결과를 누적 저장합니다.
- Kiro 레포 MIT-0 라이선스의 `risk-discovery-methodology.md`를 원본 방법론으로 참조하며, OMA 경어체 12 카테고리로 확장 한국어화.

## 실행 원칙

직접 질문하지 않고 **추천 형식**으로 위험을 제시합니다. 분석 문서에서 발견된 사실을 인용하고, 잠재 위험을 설명한 뒤, 체크포인트 고려 여부를 묻는 형태로 구성합니다.

```
"{분석 문서에서 발견한 사실}이 확인되었습니다.
{잠재 위험 설명}이 발생할 수 있어
{구체적 체크포인트}가 검토되었는지 확인이 필요해 보입니다."
```

**좋은 예시**

> "설계 문서에서 결제 게이트웨이 API 통합이 확인되었습니다. 이 API가 서버 IP 기반 인증을 사용한다면 ECS 전환 시 NAT Gateway IP로 변경되어 연동이 중단될 가능성이 있어, 해당 이슈 진단·대응이 검토되었는지 확인이 필요해 보입니다."

**나쁜 예시 (금지)**

> "결제 게이트웨이 API가 IP 기반 인증을 사용합니까?" (직접 질문)
> "외부 연동 시스템이 있습니까?" (분석에서 이미 식별된 내용 재질문)

## 12 카테고리 체크

각 카테고리는 3~5개 체크 항목 + 증상 + 조치 + 차단 조건으로 구성됩니다. 체크 항목 중 BLOCK 조건이 1개라도 충족되면 Construction 진입을 차단합니다.

### 1. 비즈니스 연속성 (Business Continuity)

- [ ] 피크 트래픽·배치 작업 시간대와 전환 일정이 충돌하지 않는가
- [ ] 다운타임 허용치가 요구사항에 수치로 명시되어 있는가
- [ ] 주문·결제 등 트랜잭션 정합성이 cutover 시점에 보호되는가
- 증상: 월말 정산·분기 마감일과 배포 일정 겹침, 결제 중복/손실 리스크
- 조치: 배포 금지 기간 캘린더 수립, in-flight transaction drain 전략 수립
- BLOCK: 다운타임 허용치가 명시되지 않았거나 피크 시간대 배포가 계획된 경우

### 2. 보안 (Security)

- [ ] 시크릿(DB 비밀번호·API 키)이 환경 변수·설정 파일에 평문으로 존재하지 않는가
- [ ] 인증 방식이 컨테이너·관리형 서비스 환경에서 정상 작동하는가
- [ ] 전송/저장 암호화가 신규 리소스에 동일 수준으로 적용되는가
- [ ] IAM·보안 그룹이 최소 권한 원칙을 준수하는가
- 증상: 시크릿 유출, 인증 토큰 탈취, 과도 권한으로 측면 이동
- 조치: Secrets Manager/Parameter Store 이관, IAM 정책 감사, TLS 1.2+ 강제
- BLOCK: 평문 시크릿 발견 또는 0.0.0.0/0 inbound rule 존재

### 3. 외부 통합 (External Integrations)

- [ ] 외부 API가 IP 기반 인증을 사용하여 IP 변경 시 차단되지 않는가
- [ ] mTLS 인증서가 신규 환경에서 유효한가
- [ ] 외부 파트너에게 엔드포인트·IP 변경 사전 공지가 계획되었는가
- [ ] 서드파티 SDK·라이선스가 컨테이너 환경(특히 Alpine)에서 호환되는가
- 증상: 결제 API 단절, B2B 파트너 호출 실패, 라이선스 위반
- 조치: 소스 IP 고정용 NAT EIP 할당, 인증서 교체 계획, 파트너 공지 lead time 확보
- BLOCK: IP 기반 인증 존재 + 고정 IP 계획 없음

### 4. 데이터 일관성 (Data Consistency)

- [ ] 세션·파일 업로드·캐시가 외부 저장소로 이관되는가
- [ ] cutover 시점 in-flight request가 graceful shutdown으로 보호되는가
- [ ] 메시지 큐에 미처리 메시지가 유실되지 않는가
- [ ] CDC(Change Data Capture)가 DB 마이그레이션에 적용되는가
- 증상: 세션 드롭, 업로드 파일 유실, 메시지 누락, 이중 처리
- 조치: Redis·DynamoDB로 세션 이관, S3 업로드, SIGTERM 30초 grace period, DMS CDC
- BLOCK: 로컬 파일 시스템 의존 + 마이그레이션 계획 없음

### 5. 비용 함정 (Cost Pitfalls)

- [ ] NAT Gateway·Cross-AZ 트래픽 비용이 예상 내역에 포함되었는가
- [ ] 기존 Reserved Instance/Savings Plan이 낭비되지 않는가
- [ ] 서드파티 라이선스 과금 모델이 컨테이너 환경에서 변경되지 않는가
- [ ] dev/staging 환경 비용 최적화(야간 종료 등)가 고려되었는가
- 증상: 월 $1,000+ 예상외 청구, RI 손실, 라이선스 계약 재협상
- 조치: Cost Explorer로 트래픽·NAT·Cross-AZ 비용 시뮬레이션, RI 재배치 계획
- BLOCK: 비용 상한이 명시되었는데 검증되지 않은 경우

### 6. 성능 회귀 (Performance Regression)

- [ ] baseline 성능(p50/p95/p99, throughput, error rate)이 수집되었는가
- [ ] 컨테이너 Cold start·DB 커넥션 풀 재크기 조정이 계획되었는가
- [ ] 캐시 warm-up 전략이 수립되었는가
- [ ] Multi-LoRA·KV cache 구성이 성능 SLO를 만족하는가
- 증상: 전환 직후 p95 2배 증가, DB CPU 급등, 사용자 체감 저하
- 조치: k6·Locust 부하 테스트, Readiness Probe·minReplicas 조정, 캐시 pre-populate
- BLOCK: baseline이 존재하지 않아 비교 불가한 경우

### 7. 규제·컴플라이언스 (Compliance)

- [ ] SOC2·ISMS-P·PCI DSS·HIPAA 등 요구사항이 신규 환경에서 충족되는가
- [ ] 감사 로그 연속성이 유지되며 보존 기간이 정책을 만족하는가
- [ ] 데이터 국외 이전·리전 제약이 준수되는가
- [ ] 개인정보·PII 취급 동의·파기 프로세스가 설계에 반영되었는가
- 증상: 감사 실패, 규제 기관 제재, 사용자 신뢰 손실
- 조치: CloudTrail·Langfuse 감사 로그 이관, 보존 정책 IaC 코드화, DPIA 수행
- BLOCK: 규제 요구사항 명시되었는데 매핑 증빙 부재

### 8. 가용성·SLA (Availability)

- [ ] Multi-AZ 배포가 적용되며 AZ 장애 시 failover가 검증되었는가
- [ ] 헬스체크 엔드포인트가 의존성(DB·Redis·벡터 DB)까지 반영하는가
- [ ] SLA 99.9% 이상 요구 시 Business Support 계약이 있는가
- 증상: AZ 장애로 전체 서비스 중단, 헬스체크 거짓 양성
- 조치: Liveness·Readiness 분리, AZ fail-drill 수행, Route 53 health check
- BLOCK: 단일 AZ 배포 + SLA 99.9% 요구 동시

### 9. 장애 전파 반경 (Blast Radius)

- [ ] Agent·Tool·Memory·Gateway 중 단일 장애가 전체로 전파되지 않는가
- [ ] Circuit breaker·bulkhead·timeout이 모든 외부 호출에 적용되는가
- [ ] Tenant isolation(multi-tenant 시)이 quota·네트워크 레벨에서 강제되는가
- 증상: 한 tenant의 LLM 호출 급증으로 전체 응답 지연, 벡터 DB 장애가 전체 중단
- 조치: Hystrix 패턴, k8s ResourceQuota, LiteLLM virtual key 격리
- BLOCK: multi-tenant인데 격리 계층 부재

### 10. 운영 복잡도 (Operational Complexity)

- [ ] 운영팀이 신규 환경(EKS·Aurora·Bedrock 등) 운영 역량을 보유하는가
- [ ] Runbook·on-call rotation·Slack/PagerDuty 채널이 준비되었는가
- [ ] 장애 시 rollback 의사결정권자·고객 공지 절차가 명확한가
- 증상: 장애 대응 시간 증가, rollback 지연, 고객 신뢰 손실
- 조치: 사전 교육·runbook 리허설·war-room 시나리오
- BLOCK: on-call rotation 미지정

### 11. 의존성 취약점 (Dependency Vulnerabilities)

- [ ] 베이스 이미지·패키지·LLM 모델 체크포인트의 CVE 스캔이 수행되었는가
- [ ] SBOM(Software Bill of Materials)이 생성되어 아티팩트 레지스트리에 저장되는가
- [ ] 서드파티 모델 라이선스(Llama, Qwen, DeepSeek)가 사용 사례와 호환되는가
- 증상: Critical CVE 미패치, 라이선스 위반 소송, supply chain 공격
- 조치: Trivy·Grype 스캔, Syft SBOM, 라이선스 매트릭스 검증
- BLOCK: Critical CVE 존재 + 패치 계획 없음

### 12. 롤백 가능성 (Rollback Capability)

- [ ] Blue/green·canary 배포 전략이 정의되었는가
- [ ] DB 마이그레이션이 forward-only인 경우 데이터 백업·복구 리허설이 수행되었는가
- [ ] IaC(Terraform·CDK)가 이전 상태로 revert 가능한가
- [ ] rollback 의사결정 기준(예: error rate > X%)이 수치로 명시되었는가
- 증상: 장애 발생 시 rollback 불가, 데이터 손실
- 조치: DB snapshot 사전 확보, Terraform state backup, Argo Rollouts canary
- BLOCK: rollback 경로 미정의 + 상태 변경 마이그레이션 포함

## 산출물

본 skill 실행 종료 시 `.omao/state/risk-checkpoints/<slug>-<timestamp>.md` 파일을 생성합니다. 형식은 `templates/risk-checkpoint-report.template.md`를 따르며 12개 카테고리 PASS/WARN/BLOCK 판정과 증거 인용을 포함합니다.

BLOCK 판정이 1개라도 있으면 `.omao/state/gates/construction.json`에 `{"status": "blocked", "blockers": [...]}` 을 기록하고 `quality-gates` skill이 다음 phase 진입을 차단합니다.

## 참고 자료

### 공식 문서

- [AWS Well-Architected Framework — Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html) — 보안 위험 카테고리 매핑 원본
- [AWS Well-Architected — Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html) — 가용성·장애 전파 원칙
- [aws-samples/sample-ai-driven-modernization-with-kiro — risk-discovery-methodology](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro/blob/main/.kiro/skills/common/risk-discovery-methodology.md) — MIT-0 원본 방법론

### 관련 문서 (내부)

- `../../aidlc-inception/skills/structured-intake/SKILL.md` — 입력 intake 생성자
- `../component-design/SKILL.md` — 본 skill이 분석할 design.md 생성자
- `../quality-gates/SKILL.md` — BLOCK 판정 시 phase 진입 차단 담당
- `../../../agenticops/skills/audit-trail/SKILL.md` — 판정 결과를 감사 로그에 기록
