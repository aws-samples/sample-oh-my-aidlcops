---
name: cutover-planning
description: "Plan production traffic cutover — Blue/Green, Canary (1%→10%→50%→100%), DNS-based strategies on ALB/Route53. Defines explicit rollback triggers (SLO violation, error rate, p99 latency), data synchronization via DMS zero-downtime migration, and post-cutover validation checklist. Use when containerization is done and production traffic needs to move from legacy to new environment."
argument-hint: "[strategy (canary|blue-green|rolling), sync-tool (dms|native-replication|dual-write)]"
user-invocable: true
model: claude-opus-4-7
allowed-tools: "Read,Write,Edit,Bash,Grep,Glob,mcp__ecs,mcp__eks,mcp__aws-documentation,mcp__aws-iac,mcp__aws-pricing"
---

## 언제 사용하나요

- `containerization-report.md` 가 존재하고 이미지가 ECR 에 푸시되어 ECS/EKS 에 배포 가능한 상태일 때
- 기존(legacy) 환경의 production 트래픽을 신규(modernized) 환경으로 이전하는 마지막 단계
- DB 가 함께 이전되는 경우(DMS 기반 zero-downtime 마이그레이션) 데이터 동기화 전략 결정이 필요할 때
- 실패 시 자동 롤백 기준을 SLO 메트릭과 연결하여 사전 정의할 때

## 언제 사용하지 않나요

- 단순 Rehost(EC2 복제) 로 인프라 변경이 없는 경우 — 전용 컷오버 전략 불필요
- Stateless 내부 도구처럼 다운타임 허용이 명확한 경우 — 단순 배포 스크립트로 충분
- Repurchase(SaaS 전환) — SaaS 벤더 컷오버 지원 별도 활용

## 전제 조건

- `.omao/plans/modernization/containerization-report.md` 존재
- `aidlc-construction/skills/risk-discovery` 재실행 PASS (DB·세션·외부 연동 리스크 4축)
- ALB v2 또는 Route53 접근 권한, CloudWatch Alarms 생성 권한
- (DB 이전 시) DMS 복제 인스턴스 프로비저닝 가능 권한

## 절차

### Step 1. 컷오버 전략 선택

| 전략 | 특징 | 적합 조건 | 롤백 시간 |
|------|------|---------|----------|
| **Canary** | ALB weighted (1→10→50→100%) | Default 권장, 리스크 분산 | 즉시 (weight 조정) |
| **Blue/Green** | 100% 즉시 전환 | 충분한 사전 테스트, 빠른 컷오버 필요 | 즉시 (DNS/listener) |
| **Rolling** | 인스턴스 단위 교체 | 추가 자원 확보 어려울 때 | 느림 (인스턴스별 롤백) |

선택 근거를 반드시 `cutover-plan.md` 에 기록합니다.

### Step 2. Canary 단계 설계

권장 가중치 진행:

```
Step A: Blue 99% / Green 1%   — 30 min 관측
Step B: Blue 90% / Green 10%  — 1 hour 관측
Step C: Blue 50% / Green 50%  — 2 hour 관측
Step D: Blue 0%  / Green 100% — 24 hour 관측
```

ALB Weighted Target Group 전환 예시:

```bash
aws elbv2 modify-listener \
  --listener-arn ${LISTENER_ARN} \
  --default-actions '[{
    "Type":"forward",
    "ForwardConfig":{
      "TargetGroups":[
        {"TargetGroupArn":"'${BLUE_TG}'","Weight":90},
        {"TargetGroupArn":"'${GREEN_TG}'","Weight":10}
      ]
    }
  }]'
```

### Step 3. Rollback Trigger 정의

다음 3축 중 하나라도 임계값 초과 시 **자동 롤백** 을 발동합니다.

| 메트릭 | 임계값 (Green TG) | 관측 기간 | 액션 |
|--------|------------------|---------|------|
| HTTP 5xx rate | > 1% | 5 min | Revert to Blue 100% |
| P99 Latency | > 1.5× baseline | 5 min | Revert to Blue 100% |
| SLO Error Budget | 시간당 10% 소모 | 10 min | Pause + Executive 승인 요청 |
| DB Replica lag | > 60s | 1 min | Data sync 중단 + 수동 개입 |

CloudWatch Alarm → EventBridge → Lambda (가중치 되돌림) 파이프라인으로 자동화합니다.

### Step 4. Data Synchronization (DMS)

기존 DB 가 Oracle/MySQL 등 다른 엔진이거나 region 이동이 있는 경우 **DMS zero-downtime migration** 을 사용합니다.

1. **Full Load + CDC** 모드 replication task 생성
2. Full Load 완료 후 CDC 가 Source WAL 을 계속 소비하도록 대기
3. 컷오버 직전 Source 쓰기 트래픽 차단 (read-only 모드)
4. DMS lag 0 확인
5. 애플리케이션 writer endpoint 를 Target 으로 전환
6. 검증 후 Source DB decommission

DMS CLI 예:

```bash
aws dms start-replication-task \
  --replication-task-arn ${TASK_ARN} \
  --start-replication-task-type start-replication
```

### Step 5. Dual-Write 또는 Native Replication 대안

- **Dual-Write**: 애플리케이션 레벨에서 Source/Target 동시 기록. 데이터 정합성 위험 높음, 마이그레이션 동안 idempotency 핵심
- **Native Replication**: 동일 엔진(Oracle→Oracle, MySQL→MySQL) 에 한해 Binary log/logical replication 활용

### Step 6. Pre-Cutover 검증 체크리스트

컷오버 개시 전 반드시 확인합니다.

- [ ] Green 환경 E2E 통합 테스트 PASS
- [ ] 보안 스캔(Trivy/grype) 0 HIGH/CRITICAL
- [ ] CloudWatch Alarms 4종 활성 (5xx/P99/SLO/DB lag)
- [ ] Runbook 작성 완료 (`.omao/plans/modernization/cutover-runbook.md`)
- [ ] Rollback 자동화 Lambda 배포 및 수동 트리거 테스트 완료
- [ ] 이해관계자 알림 채널 확정 (Slack #inc-modernization, PagerDuty)
- [ ] Maintenance window 공지 완료 (최소 72h 전)
- [ ] 고객 지원팀 FAQ 배포

### Step 7. Post-Cutover 검증 체크리스트

Green 100% 도달 후 24h 이내 확인합니다.

- [ ] Error rate, latency, throughput 이 SLO 범위 내
- [ ] DB Replica lag == 0, 데이터 건수 일치 (hash 검증)
- [ ] 로그 수집 정상, X-Ray trace 누락 없음
- [ ] 비용 이상 징후 없음 (AWS Cost Anomaly Detection)
- [ ] 사용자 문의 스파이크 없음
- [ ] Blue 환경 shutdown 계획 승인 (보통 7-14일 유지 후 해체)
- [ ] `audit.md` 에 컷오버 타임라인 기록

### Step 8. Output 산출

`.omao/plans/modernization/cutover-plan.md` 에 다음을 포함합니다.

```markdown
# Cutover Plan
- strategy: Canary (1→10→50→100)
- sync_tool: DMS Full Load + CDC
- rollback_triggers: (Step 3 표)
- pre_cutover_checklist: (Step 6)
- post_cutover_checklist: (Step 7)
- maintenance_window: 2026-05-10 02:00 KST (2h)
- stakeholders: [CTO, SRE Lead, DBA, Support]
- runbook_link: cutover-runbook.md
- operations_handoff: agenticops plugin (operations-phase)
```

### Step 9. Operations 핸드오프

`audit-trail` (agenticops) 을 호출하여 컷오버 종료 증거를 `audit.md` 에 고정합니다. 이후 운영은 `agenticops` 플러그인의 operations-phase 로 승계됩니다.

## 좋은 예시

- Canary 1→10→50→100 + CloudWatch Alarms 4종 + DMS CDC 0 lag → 무중단 컷오버
- Blue/Green 전환 + 7일 Blue 유지 + 자동 롤백 Lambda 2분 이내 동작
- 금융권 ISMS-P 대상 워크로드 + Maintenance window 72h 전 공지 + Executive 승인 체크포인트

## 나쁜 예시 (금지)

- Rollback trigger 임계값을 "경험에 따라" 로 기재 — 수치 없음
- DMS CDC lag 검증 없이 writer endpoint 전환 — 데이터 손실 위험
- Blue 환경 즉시 삭제 — 롤백 불가능
- Canary 100% 도달 후 Post-Cutover 체크리스트 생략
- Maintenance window 공지 없이 비즈니스 시간 중 컷오버

## 참고 자료

### 공식 문서
- [AWS DMS Documentation](https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html) — zero-downtime 마이그레이션
- [ELB Weighted Target Groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) — Canary 구현
- [Route53 Weighted Routing](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-weighted.html) — DNS 기반 전환
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html) — SLO 감시

### 원천 방법론 (MIT-0)
- [traffic-cutover-strategy.md (Kiro)](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro/blob/main/.kiro/skills/aws-practices/traffic-cutover-strategy.md) — 원본 컷오버 전략

### 관련 문서 (내부)
- `../containerization/SKILL.md` — 선행 skill
- `../../CLAUDE.md` — modernization 플러그인 개요
- `/home/ubuntu/workspace/oh-my-aidlcops/plugins/agenticops/CLAUDE.md` — Operations 핸드오프
