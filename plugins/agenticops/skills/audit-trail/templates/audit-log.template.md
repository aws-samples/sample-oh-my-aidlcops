# Audit Log — <session-id>

Session initialized: YYYY-MM-DDTHH:MM:SSZ
Retention policy: 90 days (SOC2 CC7.2)
Compliance frameworks: SOC2, ISMS-P

---

## Event Format

각 이벤트는 다음 구조를 따릅니다. 필드 이름과 순서를 변경하지 않습니다.

```markdown
### [YYYY-MM-DDTHH:MM:SSZ] <event-type>
- **Actor**: user | ai | system
- **Action**: (수행된 행위 요약 1문장)
- **User Prompt (verbatim)** (사용자 입력 이벤트인 경우):
  > 원문 그대로. 축약·의역 금지.
- **AI Judgment / Suggestion**: (AI가 판단한 내용 요약)
- **User Answer / Decision (verbatim)** (사용자 응답 이벤트인 경우):
  > 원문 그대로.
- **Result**: success | failed | skipped
- **Files Touched**: list of file paths or "-"
- **Notes**: (특이사항·에러 메시지·skip 사유 등)
```

---

## Example Events

### [2026-04-21T09:00:00Z] stage-start
- **Actor**: user
- **Action**: AIDLC Inception stage 시작
- **User Prompt (verbatim)**:
  > RAG QA 시스템 신규 구축. 3개월 내 프로토타입 필요.
- **AI Judgment**: structured-intake skill 실행 권장.
- **Result**: success
- **Files Touched**: -
- **Notes**: 세션 slug = `rag-qa`

### [2026-04-21T09:05:43Z] user-answer
- **Actor**: user
- **Action**: project-info 이해관계자 섹션 응답
- **User Answer (verbatim)**:
  > 의사결정자는 홍길동 CTO, 사용자 대표는 이영희(고객센터장), 설계 리뷰는 김철수(Staff Eng). 전부 slack DM으로 소통합니다.
- **Result**: success
- **Files Touched**: `.omao/plans/rag-qa/project-info.md`

### [2026-04-21T09:15:22Z] file-created
- **Actor**: ai
- **Action**: requirements.md 초안 생성
- **Result**: success
- **Files Touched**: `.omao/plans/rag-qa/requirements.md`
- **Notes**: REQ-001 ~ REQ-003 초안 포함. 이후 requirements-analysis skill이 정제 예정.

### [2026-04-21T09:30:10Z] gate-evaluation
- **Actor**: ai
- **Action**: Inception gate 평가 실행
- **AI Judgment**: 모든 필수 체크 PASS. 다음 phase 진입 허용.
- **Result**: success
- **Files Touched**: `.omao/state/gates/inception.json`
- **Notes**: `next_phase_allowed: true`

### [2026-04-21T10:00:00Z] approval-requested
- **Actor**: ai
- **Action**: design.md 리뷰 승인 요청
- **Result**: success
- **Files Touched**: `.omao/plans/construction/design.md`
- **Notes**: 리뷰어 = 김철수 (Staff Eng)

### [2026-04-21T11:15:33Z] approval-granted
- **Actor**: user
- **Action**: design.md 승인
- **User Answer (verbatim)**:
  > 인터페이스 계약 부분 좋습니다. Data Model 섹션에 TTL 기본값만 추가해주시면 승인합니다.
- **Result**: success
- **Notes**: 조건부 승인. TTL 기본값 추가 후 재확인 불필요.

### [2026-04-21T14:22:08Z] test-skipped
- **Actor**: ai
- **Action**: integration test skip
- **Result**: skipped
- **Notes**: 외부 결제 게이트웨이 sandbox 미가용. 수동 검증으로 대체.

### [2026-04-21T15:45:00Z] waiver-issued
- **Actor**: user (홍길동 CTO)
- **Action**: risk-discovery category 11 (dependency vulnerability) 48시간 waiver 발급
- **User Answer (verbatim)**:
  > CVE-2026-1234는 PR #1234에서 48시간 내 업그레이드 완료 예정. 그 전까지 waiver 승인합니다.
- **Result**: success
- **Files Touched**: `.omao/state/gates/waivers/construction-20260421T154500Z.md`
- **Notes**: TTL = 2026-04-23T15:45:00Z

### [2026-04-21T16:30:00Z] error
- **Actor**: ai
- **Action**: vLLM 배포 실패
- **Result**: failed
- **Notes**: GPU 노드 프로비저닝 timeout. Karpenter 로그 참조.

### [2026-04-21T16:45:12Z] error-resolved
- **Actor**: ai
- **Action**: vLLM 배포 재시도 성공
- **Result**: success
- **Notes**: g5.xlarge → g5.2xlarge로 인스턴스 타입 변경 후 정상 프로비저닝.

---

## 금지 패턴

- 사용자 입력을 **요약**으로 대체 (❌ `사용자가 빠른 배포 요청`)
- 로컬 시간대 사용 (❌ `오전 9시 15분`)
- 기존 이벤트 **수정/삭제** (❌ 직접 편집)
- 타임스탬프 **누락** (❌ `### user answered`)
- 비표준 actor 값 (❌ `Actor: bot`)
