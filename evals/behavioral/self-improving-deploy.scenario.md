---
name: self-improving-deploy
description: Langfuse trace 기반 regression 식별부터 프롬프트 diff 제안, Ragas 평가, 드래프트 PR 생성, 휴먼 리뷰, 카나리 배포까지 5-checkpoint로 실행한다.
plugin: agenticops
tier_0_command: /oma:self-improving
difficulty: intermediate
estimated_duration: 30 minutes
---

# Self-Improving Deploy 시나리오

## 목적

운영 중 수집된 Langfuse trace에서 regression candidate를 식별하고, 프롬프트 또는 스킬 diff를 제안하며, Ragas 평가 before/after 리포트를 첨부한 드래프트 PR을 생성해 휴먼 리뷰 게이트를 준수하는지 검증한다. engineering-playbook의 `self-improving-agent-loop.md` ADR 규약 준수 여부를 확인한다.

## 사전 조건 (Prerequisites)

- [ ] OMA 플러그인 설치: `agenticops`
- [ ] Langfuse 프로젝트 접근 가능: API endpoint, API key, project ID 설정 완료
- [ ] Langfuse에 최근 24시간 trace 50개 이상 수집됨
- [ ] Ragas 환경 설치: `pip install ragas llama-index-evaluation`
- [ ] Ragas 평가 데이터셋 준비: `.omao/plans/ragas-eval-dataset.jsonl`
- [ ] Git 저장소 clean 상태
- [ ] GitHub CLI 설치 및 인증 완료 (`gh auth status`)
- [ ] 타깃 에이전트 서비스: RAG 기반 질의응답 시스템 운영 중

## 시나리오 (Scenario)

### 입력 (User Input)

```
/oma:self-improving agent:rag-service — 최근 24시간 Langfuse 트레이스 분석해줘
```

### 기대 동작 (Expected Behavior)

#### Stage 1: Gather Context

- **예상 도구 호출**: `Bash` `curl -H "Authorization: Bearer $LANGFUSE_SECRET" "https://<langfuse>/api/public/traces?fromTimestamp=<24h-ago>"`, `Bash` `git log -1 --pretty=format:%H -- prompts/`
- **예상 질문**:
  - Langfuse 프로젝트 ID·API key → `.omao/project-memory.json`에서 로드 또는 사용자 제공
  - 조회 기간 → "24시간" (입력에서 명시)
  - 현재 활성 프롬프트·스킬 스냅샷 → `git HEAD` 자동 확인
  - 최근 배포 이력 → `kubectl get pods -n <namespace>` 또는 Helm release 로그
  - 예산·SLO 임계값 → `.omao/project-memory.json` 기준선
  - Ragas 평가 데이터셋 위치 → `.omao/plans/ragas-eval-dataset.jsonl`
  - 카나리 배포 타깃 → "5~10% 트래픽" 기본값
- **체크포인트**: 7개 필수 컨텍스트 항목 확보 후 Stage 2로 진행

#### Stage 2: Pre-flight Checks

- **예상 도구 호출**: `Bash` Langfuse API 조회 (응답 200 확인), `Bash` `ls .omao/plans/ragas-eval-dataset.jsonl`, `Bash` `pip list | grep ragas`
- **예상 검증**:
  - Langfuse 접근 (P/F): API 응답 200
  - Trace 충분성 (P/F): 최소 50개 trace 수집
  - Regression 신호 (P/F): faithfulness ↓ 15% 또는 latency p95 ↑ 20% 또는 cost/request ↑ 10% 중 1개 이상 임계 초과
  - 이전 PR 중복 (P/F): 동일 regression에 대한 open PR 없음
  - Ragas 환경 (P/F): `ragas` 설치 확인
  - 예산 여유 (P/F): 평가 실행 예상 비용이 잔여 예산 이내
- **예상 출력**: Pre-flight Report 테이블 (6개 항목 P/F 표시)
- **특수 케이스**: Check 3 Regression 신호가 없으면 "변동 없음. 루프를 조용히 종료합니다." 메시지 후 종료 (정상 동작)
- **체크포인트**: Regression 신호 존재 시 Stage 3로 진행, 없으면 종료

#### Stage 3: Plan

- **예상 도구 호출**: `Read` `prompts/system-prompt.md` (현재 프롬프트), `Write` `.omao/plans/self-improve-proposal.md` (제안서)
- **예상 계획 항목**:
  1. Root cause 가설: 예) "faithfulness 0.85 → 0.70 하락. trace #12345, #12389에서 context retrieval이 관련성 낮은 문서 3개 포함. system prompt의 'context prioritization' 지시가 불명확."
  2. Diff 후보:
     - 프롬프트: system prompt 재구성 (context prioritization 명확화, few-shot 추가)
     - 스킬: (이 시나리오에서는 프롬프트만 수정)
  3. Ragas 평가 설계: before/after 비교, 샘플 100개, 메트릭 faithfulness, answer_relevancy, context_precision
  4. Canary 배포 계획: 트래픽 5% 시작, 롤백 조건 faithfulness < 0.75
  5. 성공 기준: faithfulness ≥ 0.80, latency p95 회귀 없음, cost/request 회귀 없음
- **예상 출력**: 제안서 요약 (가설·diff 후보·평가 계획)

#### 🛑 CHECKPOINT — Proposal Approval

- **예상 에이전트 동작**: Root cause 가설 + trace 링크 + diff 후보 제시 후 대기 ("다음 제안을 검토 후 'proceed' 또는 'revise' 응답해주세요.")
- **사용자 응답**: "proceed"
- **검증 기준**:
  - root cause 가설이 trace 증거로 뒷받침됨 (trace ID 링크 포함)
  - diff 범위가 프롬프트 OR 스킬 중 하나로 한정 (둘 다 수정 금지)
  - Ragas 샘플 수와 예산이 합리적 (100개 샘플, 예상 비용 $5 이내)
  - 에이전트가 사용자 응답 없이 Execute로 진행하지 않음

#### Stage 4: Execute

##### 4-1. Diff 생성
- **예상 도구 호출**: `Bash` `git checkout -b self-improve/2026-04-21-context-prioritization`, `Edit` `prompts/system-prompt.md` (context prioritization 섹션 개선)
- **체크포인트**: 브랜치 생성 확인, 프롬프트 파일 수정 확인

##### 4-2. Ragas Before/After 평가
- **예상 도구 호출**:
  - `Bash` `python scripts/run_ragas.py --version main --dataset .omao/plans/ragas-eval-dataset.jsonl --metrics faithfulness,answer_relevancy,context_precision --output reports/before.json`
  - `Bash` `python scripts/run_ragas.py --version self-improve/2026-04-21-context-prioritization --dataset .omao/plans/ragas-eval-dataset.jsonl --metrics faithfulness,answer_relevancy,context_precision --output reports/after.json`
  - `Bash` `python scripts/compare_ragas.py reports/before.json reports/after.json > reports/comparison.md`
- **예상 결과**: `reports/comparison.md`에 before/after 비교 표
  - Before: faithfulness 0.70, answer_relevancy 0.82, context_precision 0.75
  - After: faithfulness 0.81, answer_relevancy 0.83, context_precision 0.78
- **체크포인트**: Ragas 평가 완료, 개선 확인

##### 4-3. 드래프트 PR 오픈
- **예상 도구 호출**: `Bash` `gh pr create --draft --title "self-improve: context prioritization 명확화" --body-file reports/pr-body.md`
- **예상 PR body 구조**:
  - Root cause 가설 및 trace 링크 (Langfuse trace #12345, #12389)
  - Before/after Ragas 비교 표
  - Canary 배포 계획 (5% 시작, 롤백 조건)
  - 관련 ADR 링크 (`self-improving-agent-loop.md`)
- **체크포인트**: PR 생성 확인, draft 상태 확인

#### 🛑 CHECKPOINT — Human Review

- **예상 에이전트 동작**: PR URL + Ragas 요약 표 + canary diff 제시 후 대기 ("GitHub에서 리뷰 후 'approve' 또는 'revise' 응답해주세요.")
- **사용자 응답**: "approve"
- **검증 기준**:
  - Ragas 비교에서 faithfulness ≥ 0.80 개선
  - 비용·latency 회귀 없음 (cost/request, latency p95 유지 또는 감소)
  - diff가 프롬프트만 수정 (스킬 변경 없음)
  - 카나리 배포 매니페스트와 롤백 경로 준비
  - 에이전트가 사용자 approve 없이 merge하지 않음

#### Stage 5: Validate

- **예상 도구 호출**: `Bash` `gh pr merge <pr-number> --squash`, `Bash` `kubectl argo rollouts set image <rollout> <container>=<new-image>`, `Bash` `kubectl argo rollouts get rollout <name>`
- **예상 검증**:
  - PR merged (P/F)
  - Canary deployment healthy (P/F): 트래픽 5% 시작
  - Post-merge Ragas ≥ target (P/F): faithfulness ≥ 0.80 유지
  - No cost/latency regression (P/F): 1시간 Langfuse trace 재측정
  - Rollback ready (P/F): 롤백 조건 준비 (임계 위반 시 자동 롤백)
- **예상 출력**: Validation Report 테이블 (5개 항목 P/F 표시)
- **예상 최종 동작**: OVERALL Pass → "Self-improving 루프 완료. Canary 비율을 단계적으로 확대합니다."

### 기대 산출물 (Expected Artifacts)

- `.omao/plans/self-improve-proposal.md` — 제안서 (가설·diff·평가 계획)
- `.omao/plans/regression-report-20260421.md` — Regression 분석 리포트 (trace ID, 지표 변동)
- `reports/before.json` — Ragas before 평가 결과
- `reports/after.json` — Ragas after 평가 결과
- `reports/comparison.md` — Ragas before/after 비교 표
- `reports/pr-body.md` — PR body 텍스트
- PR draft (GitHub) — 브랜치 `self-improve/2026-04-21-context-prioritization`
- Canary deployment manifest (Argo Rollouts 또는 Flagger)

## 검증 기준 (Acceptance Criteria)

- [ ] 5-checkpoint 구조(Gather Context → Pre-flight → Plan → Execute → Validate)를 순서대로 실행했는가
- [ ] Pre-flight에서 regression 신호(faithfulness ↓ 15%)를 정확히 식별했는가
- [ ] Regression 신호가 없을 경우 조용히 종료했는가 (정상 동작)
- [ ] Proposal Approval 체크포인트에서 root cause 가설과 trace 증거를 제시했는가
- [ ] diff가 프롬프트 OR 스킬 중 하나로 한정됐는가 (둘 다 수정 금지)
- [ ] Ragas before/after 평가를 실행하고 비교 리포트를 생성했는가
- [ ] 드래프트 PR이 ADR 링크와 롤백 조건을 포함했는가
- [ ] Human Review 체크포인트에서 사용자 approve 없이 merge하지 않았는가
- [ ] 카나리 배포가 5~10% 트래픽으로 시작했는가
- [ ] Post-merge Ragas 재측정에서 목표 지표(faithfulness ≥ 0.80)를 충족했는가

## 일반적인 실패 모드 (Common Failure Modes)

| 증상 | 원인 | 복구 |
|---|---|---|
| Pre-flight Langfuse 접근 실패 | API key 만료 또는 네트워크 차단 | `.omao/project-memory.json` API key 갱신 |
| Pre-flight Trace 충분성 실패 | 수집 기간이 짧거나 트래픽 부족 | 조회 기간 연장 (24h → 7d) |
| Pre-flight Regression 신호 없음 | 정상 상태 (변동 없음) | 루프 조용히 종료 (정상) |
| Ragas 평가 실패 | 데이터셋 경로 오류 또는 의존성 미설치 | `pip install ragas`, 데이터셋 경로 확인 |
| Ragas after 결과 회귀 | diff가 개선 대신 악화 | PR revise 요청, diff 재설계 |
| PR 생성 실패 | GitHub CLI 미인증 또는 권한 부족 | `gh auth login`, 저장소 write 권한 확인 |
| Canary 배포 임계 위반 | 프롬프트 수정이 예상 외 부작용 | 자동 롤백 트리거, 루프 재시작 |

## 참고 자료

- [Self-Improving Deploy Workflow](../../steering/workflows/self-improving-deploy.md) — 워크플로우 정의
- [Langfuse API Reference](https://langfuse.com/docs/api) — trace 조회·메트릭 API
- [Ragas Documentation](https://docs.ragas.io/) — RAG 평가 메트릭 라이브러리
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/) — 프로그레시브 딜리버리
- [engineering-playbook ADR: Self-Improving Loop](https://devfloor9.github.io/engineering-playbook/docs/agentic-ai-platform/design-architecture/advanced-patterns/adr-self-improving-loop) — ADR 원본
- [engineering-playbook: Self-Improving Agent Loop](https://devfloor9.github.io/engineering-playbook/docs/agentic-ai-platform/design-architecture/advanced-patterns/self-improving-agent-loop) — 상세 설계
- [OMA CLAUDE.md](../../CLAUDE.md) — 플러그인 카탈로그
