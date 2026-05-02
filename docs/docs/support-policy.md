---
id: support-policy
title: Support Policy (Tech Preview)
sidebar_position: 50
---

# Support Policy — Tech Preview

OMA `v0.2.0-preview.1` 은 **Tech Preview** 릴리스입니다. 프로덕션 SLA 를 제공하지
않으며, 아래 기준에 따라 지원 범위를 확정합니다.

## 안정성 계약

| 표면 | 상태 | 정책 |
|---|---|---|
| `.omao/profile.yaml` v1 스키마 | **stable** | GA 전까지 breaking change 없음 |
| `schemas/ontology/*.schema.json` v1 | **stable** | GA 전까지 breaking change 없음 |
| `schemas/harness/dsl.schema.json` v1 | **beta** | 피드백에 따라 필드 추가 가능, 기존 필드 제거 금지 |
| `bin/oma` 서브커맨드 이름 / exit code | **beta** | 이름 변경은 deprecation 주기 거쳐야 함 |
| `oma doctor` JSON 리포트 스키마 v1 | **beta** | 필드 추가 가능, 제거 금지 |
| 플러그인 내부 스킬 본문 / 프롬프트 | **evolving** | 마이너 릴리스 사이에도 변경 가능 |
| `templates/` 기본값 | **evolving** | 수정 빈번 |

## 지원 범위

- 제공: 문서 기반 설치, `oma setup` / `oma doctor` 버그 수정, 스키마 위반 리포트.
- 제공하지 않음: 프로덕션 배포 지원, 24x7 on-call, paid SLA, 보안 CVE 책임.

## 이슈 제출

- 버그: https://github.com/aws-samples/sample-oh-my-aidlcops/issues

## 텔레메트리

OMA 는 **telemetry 를 수집하지 않습니다.** 상세는 [Telemetry](./telemetry.md) 참조.

## 업그레이드

- `oma upgrade` (clone 설치의 경우) 또는 새 `install.sh` 재실행.
- 메이저/마이너 릴리스 노트는 [`CHANGELOG.md`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/CHANGELOG.md) 참조.

## 제거

```bash
oma uninstall     # 심링크 해제 + settings.json 정리 (WIP)
rm -rf ~/.oma
rm ~/.local/bin/oma
```

## GA 기준

다음 네 항목이 모두 충족되면 GA (`v1.0.0`) 로 진입합니다.

1. 두 harness (Claude Code, Kiro) 에서 E2E 시나리오 3 개 이상 재현 가능.
2. 4 개 플러그인 모두 DSL 이주 완료.
3. 다운스트림 사용자 bug 리포트 0 critical / 90 일.
4. 릴리스 artifact supply-chain 검증 (sha256 + SBOM + signed commit) 자동화 완료.
