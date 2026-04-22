---
name: oma:agenticops
description: Operations 위상의 자동화 모드를 활성화한다. continuous-eval, incident-response, cost-governance 에이전트를 동시에 기동해 운영 중인 워크로드의 품질·안정성·비용을 지속 관리한다.
---
<objective>
배포 완료된 AIDLC 워크로드에 대해 agenticops 플러그인의 3개 에이전트(continuous-eval, incident-response, cost-governance)를 동시에 기동해 운영 자동화 모드를 유지한다. 이 모드는 명시적으로 `/oma:cancel`이 호출될 때까지 지속된다.
</objective>

<when_to_use>
- 배포가 완료된 후 품질(Ragas), 안정성(SLO 위반), 비용(예산 초과) 3개 축을 동시에 모니터링해야 할 때
- Langfuse trace, Prometheus 알람, AWS Cost Explorer 시그널을 통합해 사람이 승인만 하는 운영 모델을 구축하고 싶을 때
- 단발성 피드백 루프만 필요하면 `/oma:self-improving`을 대신 사용한다
- Operations 모드는 `/oma:platform-bootstrap` 완료와 Langfuse/OTel 계측이 선행 조건이다
</when_to_use>

<execution_context>
@steering/workflows/self-improving-deploy.md
</execution_context>

<process>
agenticops 플러그인의 세 에이전트를 병렬 기동하고, 각 에이전트는 주기적으로 시그널을 수집·평가·제안한다. 사람은 제안 PR을 머지할지만 결정한다.

1. **Gather Context** — 활성 워크로드 목록, Langfuse 프로젝트, 예산 임계값, 알람 채널(Slack/PagerDuty) 로드
2. **Pre-flight Checks** — Langfuse v3.x 접근 가능, Prometheus 스크래핑 정상, AWS Cost Explorer 권한 확인
3. **Plan** — 에이전트별 scan 주기(예: continuous-eval 1h, incident-response 1m, cost-governance 24h) 합의
4. **Execute** — 3개 에이전트 동시 기동
   - `continuous-eval` — Ragas 메트릭 추적, regression 감지 시 제안 티켓 생성
   - `incident-response` — SLO 위반 감지 시 근본 원인 분석 + 롤백 PR 초안 생성
   - `cost-governance` — 예산 anomaly 감지 시 rightsizing/카핀터 설정 변경 제안
5. **Validate** — 각 에이전트 heartbeat 확인, 최초 1사이클 산출물 점검

사용자는 제안된 PR/티켓을 승인/거부하며, 에이전트는 자율적으로 실행하지 않는다. 모드 종료는 `/oma:cancel`로만 가능하다.
</process>

<state_handling>
- 활성화 시: `.omao/state/active-mode` = `oma:agenticops`, 3개 에이전트 lease 파일 생성
- 지속 모드: `.omao/state/sessions/{sessionId}/agents/` 아래 하트비트 기록
- `/oma:cancel` 호출 시: 3개 에이전트 정상 종료 후 active-mode 초기화
</state_handling>
