---
id: telemetry
title: Telemetry
sidebar_position: 51
---

# Telemetry

**OMA 는 telemetry 를 수집하지 않습니다.** 수집되는 데이터가 전혀 없습니다.

- `oma setup`, `oma doctor`, `oma compile`, `oma upgrade`, `oma uninstall` 은
  모두 **로컬에서만** 동작합니다.
- `.omao/` 디렉터리(프로파일, 온톨로지 씨드, 세션 상태, 감사 로그, 프로젝트
  메모리)는 **commit 되지 않습니다** (`.gitignore` 로 차단). 외부 전송 경로가 없습니다.
- MCP 서버 호출은 해당 MCP 서버 공급자(예: awslabs)의 정책을 따릅니다. OMA 는
  중계·샘플링·집계를 하지 않습니다.
- `hooks/session-start.sh`, `hooks/user-prompt-submit.sh` 는 프롬프트 컨텍스트에
  경고 문자열을 삽입할 뿐, 네트워크 요청을 발생시키지 않습니다.

## 확인 방법

```bash
# 1. 네트워크 의존성이 있는 곳을 직접 확인
grep -RIn 'curl\|wget\|http' scripts/ bin/ hooks/ | grep -v '^\s*#'

# 2. install.sh 는 GitHub tarball 다운로드만 수행 (설치 이후 네트워크 요청 0)
head -30 install.sh
```

## 예외 — 명시적 외부 호출

OMA 가 외부 호스트에 요청을 보내는 유일한 경로:

1. `install.sh` — tarball 및 sha256 다운로드 (`raw.githubusercontent.com`,
   `github.com`). 설치 후에는 호출되지 않습니다.
2. `scripts/install/aidlc-extensions.sh` — `awslabs/aidlc-workflows` 저장소 clone.
3. `oma doctor` → `aws sts get-caller-identity` — **사용자의** AWS 계정으로 STS
   호출. AWS CLI 가 설치된 경우에만. 결과는 로컬에만 저장.

이 외의 경로는 존재하지 않으며, 추가된다면 `CHANGELOG.md` 의 "Telemetry" 섹션에
반드시 명시됩니다.
