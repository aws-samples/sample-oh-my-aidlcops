---
name: ontology-wiki
description: "생성 전(pre-generation) grounding 레이어. 온톨로지 엔티티(Spec/ADR/Deployment/Agent/Skill/Incident/Budget/Risk)를 작성하기 전에 지식 그래프를 질의해 기존 정의·enum·전례·결정 이유를 확인함으로써 drift를 소스에서 차단한다. adr-0001-graphify-knowledge-wiki 결정에 따라 Graphify(MIT)를 런타임 질의 substrate로 사용하며, Graphify 미가용 시 raw 스키마/docs 읽기로 graceful degradation 한다."
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Grep,Glob,Bash"
---

## 언제 사용하나요

- 온톨로지 엔티티(`Spec`·`ADR`·`Deployment`·`Agent`·`Skill`·`Incident`·`Budget`·`Risk`)를 **작성·수정하기 직전**
- enum·필드·참조 관계가 이미 정의돼 있는지 확인이 필요할 때 (예: "Deployment.target에 어떤 값이 허용되나")
- 과거 결정 이유(`ADR`의 context/decision) 또는 기존 Risk 분류(OWASP/NIST)를 재사용하려 할 때
- 스키마 진화(새 enum 값·새 필드) 제안 전, 기존 정의와 충돌하는지 검증할 때

## 언제 사용하지 않나요

- 온톨로지와 무관한 일반 코드 작성 (엔티티 산출물이 없는 작업)
- 이미 같은 세션에서 동일 엔티티를 질의해 grounding이 끝난 경우 (중복 질의 금지)

## 동작 계약 (retrieval surface)

이 skill은 **읽기 전용 grounding**이다. 엔티티를 쓰지 않고, 작성 주체(다른 skill/agent)에게 컨텍스트만 제공한다.

### 1순위 — Graphify MCP (설치된 경우)

`oma setup`이 Graphify를 구성했다면 그 MCP 서버로 질의한다:

```
mcp__graphify__query "Deployment.target에 허용되는 enum 값은?"
mcp__graphify__path "Risk" "Deployment"          # 두 엔티티 간 관계 경로
mcp__graphify__explain "Budget"                  # 한 엔티티에 대해 그래프가 아는 전부
```

Graphify는 관계-인지 압축 결과만 반환하므로(raw 파일 대비 대폭 적은 토큰), 반복 질의에서 토큰·지연이 줄어든다. **이 수치는 Graphify 자체 벤치이며 OMA 코퍼스에서 실측되기 전까지 사실로 단정하지 않는다.**

### 2순위 — 커밋된 코퍼스 (Graphify 실행은 없지만 코퍼스가 있는 경우)

`plugins/aidlc/skills/ontology-wiki/`에 커밋된 산출물을 직접 읽는다:

- `GRAPH_REPORT.md` — god node·관계 맵·surprising edge·질의 제안
- `wiki/<entity>.md` — 엔티티별 정의·enum·참조·왜(rationale)·gotcha
- `graph.json` — 구조적 백킹 (엣지 provenance: `EXTRACTED`/`INFERRED`/`AMBIGUOUS`)

### 3순위 — Graceful degradation (Graphify도 코퍼스도 없는 경우)

`schemas/ontology/*.schema.json` 원본을 직접 읽어 grounding 한다. **wiki는 가속기이지 정확성의 hard precondition이 아니다** — 이 경로에서도 정확성은 `oma validate`(사후 검증)가 보장한다.

## 산출물

없음(읽기 전용). 조회 결과를 호출자에게 grounding 컨텍스트로 전달할 뿐이며, 엔티티 작성/검증은 각 담당 skill(`aidlc` inception/construction, `agenticops` operations)이 수행한다.

## 코퍼스 최신성 (staleness)

커밋된 코퍼스는 스키마·docs·`.omao/ontology` 변경 시 재생성되어야 한다. 재생성 트리거:

- `graphify --update` / `--watch` (증분 재추출), 또는
- git post-commit 훅 (`graphify hook install`)

코퍼스가 스키마보다 뒤처지면 **없느니만 못하다**. 최신성이 의심되면 3순위(raw 스키마 읽기)로 강등하고 재생성을 권고한다.

## provenance 해석 규칙

`graph.json`/`wiki`의 참조 엣지는 신뢰도 태그를 갖는다:

- **EXTRACTED** — 스키마 pattern에서 기계 도출. 신뢰하고 사용.
- **INFERRED** — 필드 description이 대상 엔티티를 지목. 사용 가능하나 대상 확인 권장.
- **AMBIGUOUS** — 대상 엔티티가 산문으로만 명시됨(예: `Budget.scope_ref`, `produced_by`, `gate_ref`). **의존 전 반드시 실제 대상 확인.**

## 참고

- [adr-0001-graphify-knowledge-wiki](./examples/adr-0001-graphify-knowledge-wiki.json) — 이 skill의 근거 결정 (런타임 질의 모델). `oma setup`은 이를 사용자의 `.omao/plans/adr/`에 생성하며, 여기 사본은 커밋되는 예시다.
- [Knowledge Wiki 설계 문서](../../../../docs/docs/knowledge-wiki.md) — 아키텍처·정직한 한계
- [Graphify](https://graphify.net/) — 채택된 지식 그래프 엔진 (MIT)
