---
name: containerization
description: "Containerize legacy applications with production-grade defaults — multi-stage Dockerfile, docker buildx multi-arch (amd64/arm64), Trivy/grype security scanning, Health Check, non-root user, minimal base (distroless/alpine), ECR push automation, and ECS/EKS manifest templates. Use after to-be-architecture is approved and risk-discovery PASSes."
argument-hint: "[app-path, target-orchestrator (ecs|eks), base-image-hint (alpine|distroless|ubi)]"
user-invocable: true
model: claude-sonnet-4-6
allowed-tools: "Read,Write,Edit,Bash,Grep,Glob,mcp__ecs,mcp__eks,mcp__aws-documentation,mcp__aws-iac"
---

## 언제 사용하나요

- `to-be-architecture.md` 가 ECS Fargate 또는 EKS 를 compute 로 지정했을 때
- 기존 JAR/WAR/Node.js/Python 애플리케이션을 Docker 이미지로 빌드하는 단계
- 이미 있는 Dockerfile 이 multi-stage, multi-arch, non-root 중 하나라도 미적용 상태인 경우의 리팩터링
- ECR 에 push 후 ECS Task Definition 또는 Kubernetes Deployment 매니페스트 초안이 필요할 때

## 언제 사용하지 않나요

- `decided_pattern == Rehost` 에 EC2 대상만 배포하는 경우 — 컨테이너화 미해당
- 서버리스 Lambda 전용 경로 — zip 패키징 또는 Container Image for Lambda 별도 skill 사용
- 이미 production 운영 중이고 CVE 패치 목적만 있는 경우 — 별도 패치 프로세스

## 전제 조건

- `.omao/plans/modernization/to-be-architecture.md` 존재 및 `compute` 필드 확정
- `aidlc-construction/skills/risk-discovery` PASS (데이터 정합성, 롤백 경로 검증 완료)
- Docker 24+ 설치, `docker buildx` 플러그인 활성화
- AWS CLI + ECR 푸시 권한 (IRSA 또는 로컬 profile)
- Trivy v0.48+ 또는 grype 설치 (보안 스캔용)

## 절차

### Step 1. Multi-Stage Dockerfile 작성

빌드 의존성과 런타임을 분리합니다. 언어별 최소 베이스 이미지는 다음과 같습니다.

| 런타임 | Builder | Runtime |
|--------|---------|---------|
| Node.js 20 | `node:20-alpine` | `gcr.io/distroless/nodejs20-debian12` |
| Python 3.11 | `python:3.11-slim` | `gcr.io/distroless/python3-debian12` |
| Java 21 | `eclipse-temurin:21-jdk-alpine` | `eclipse-temurin:21-jre-alpine` |
| Go 1.22 | `golang:1.22-alpine` | `gcr.io/distroless/static-debian12` |

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Runtime stage (distroless, non-root)
FROM gcr.io/distroless/nodejs20-debian12
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER nonroot
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/nodejs/bin/node", "dist/health.js"]
CMD ["dist/main.js"]
```

### Step 2. Multi-Arch 빌드 (amd64 + arm64)

AWS Graviton(arm64) 이 동일 성능 대비 최대 40% 저렴하므로 multi-arch 빌드를 기본으로 합니다.

```bash
# One-time setup
docker buildx create --name oma-builder --use
docker buildx inspect --bootstrap

# Build + push
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=ap-northeast-2
REPO=${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${APP_NAME}

aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin ${REPO}

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ${REPO}:${VERSION} \
  -t ${REPO}:latest \
  --push \
  .
```

### Step 3. 보안 스캔 (Trivy + grype)

CI 파이프라인에서 이미지 push 전 두 스캐너를 병렬 실행하고 **HIGH/CRITICAL** 0건을 게이트로 설정합니다.

```bash
# Trivy
trivy image --severity HIGH,CRITICAL --exit-code 1 ${REPO}:${VERSION}

# grype (2차 검증)
grype ${REPO}:${VERSION} --fail-on high
```

탐지 시 대응:

1. Base 이미지 업그레이드 (예: `node:20.11-alpine` → `node:20.12-alpine`)
2. 취약 패키지 제거 또는 pin
3. 불가피한 경우 `.trivyignore` 에 CVE 번호와 만료일 기록 + `audit.md` 에 근거 명시

### Step 4. ECR Lifecycle Policy

태그되지 않은 이미지 누적 방지를 위해 lifecycle policy 를 적용합니다.

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images older than 14 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 14
      },
      "action": {"type": "expire"}
    }
  ]
}
```

### Step 5. ECS Task Definition 템플릿

`to-be-architecture.compute == ECS Fargate` 경로일 때:

```json
{
  "family": "${APP_NAME}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "runtimePlatform": {"cpuArchitecture": "ARM64", "operatingSystemFamily": "LINUX"},
  "executionRoleArn": "arn:aws:iam::${ACCOUNT}:role/${APP_NAME}-exec",
  "taskRoleArn": "arn:aws:iam::${ACCOUNT}:role/${APP_NAME}-task",
  "containerDefinitions": [
    {
      "name": "${APP_NAME}",
      "image": "${REPO}:${VERSION}",
      "essential": true,
      "portMappings": [{"containerPort": 8080, "protocol": "tcp"}],
      "healthCheck": {
        "command": ["CMD-SHELL", "wget -qO- http://localhost:8080/healthz || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 10
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${APP_NAME}",
          "awslogs-region": "${REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Step 6. EKS Deployment + Service 템플릿

`to-be-architecture.compute == EKS` 경로일 때:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${NS}
spec:
  replicas: 3
  selector:
    matchLabels: {app: ${APP_NAME}}
  template:
    metadata:
      labels: {app: ${APP_NAME}}
    spec:
      serviceAccountName: ${APP_NAME}-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        fsGroup: 65532
        seccompProfile: {type: RuntimeDefault}
      containers:
      - name: app
        image: ${REPO}:${VERSION}
        ports: [{containerPort: 8080}]
        resources:
          requests: {cpu: 500m, memory: 512Mi}
          limits: {cpu: 1000m, memory: 1Gi}
        livenessProbe:
          httpGet: {path: /healthz, port: 8080}
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet: {path: /readyz, port: 8080}
          initialDelaySeconds: 5
          periodSeconds: 10
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities: {drop: [ALL]}
```

### Step 7. Output 산출

`.omao/plans/modernization/containerization-report.md` 에 기록합니다.

```markdown
# Containerization Report
- app: ${APP_NAME}
- base_image: gcr.io/distroless/nodejs20-debian12
- architectures: [linux/amd64, linux/arm64]
- image_size_mb: 142
- cve_scan: PASS (0 HIGH/CRITICAL)
- ecr_uri: ${REPO}:${VERSION}
- manifest_path: manifests/${APP_NAME}-task-def.json (ECS) | deployment.yaml (EKS)
- next_skill: cutover-planning
```

## 좋은 예시

- `gcr.io/distroless/nodejs20-debian12` + buildx multi-arch + Trivy 0 HIGH → production 배포 준비 완료
- Java Spring Boot → `eclipse-temurin:21-jre-alpine` + non-root user 10001 + JLink slim JRE
- Go static binary → `distroless/static` + CGO_ENABLED=0

## 나쁜 예시 (금지)

- `FROM ubuntu:latest` 또는 `FROM node:latest` — 재현성 손상
- `USER root` 또는 USER 지시어 누락 — 보안 통제 위반
- Health Check 미정의 — ECS/EKS 가 비정상 Task/Pod 재시작 불가
- multi-arch 빌드 생략 후 Graviton NodePool 에 배포 실패
- Trivy HIGH 무시 + `.trivyignore` 근거 미기록

## 참고 자료

### 공식 문서
- [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/) — 공식 가이드
- [Docker buildx](https://docs.docker.com/build/buildx/) — multi-arch 빌드
- [Amazon ECR User Guide](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html) — ECR 공식 문서
- [Trivy Documentation](https://aquasecurity.github.io/trivy/) — 컨테이너 취약점 스캔
- [Distroless images](https://github.com/GoogleContainerTools/distroless) — 최소 베이스 이미지

### 원천 방법론 (MIT-0)
- [container-best-practices.md (Kiro)](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro/blob/main/.kiro/skills/technical/container-best-practices.md) — 원본 Best Practice

### 관련 문서 (내부)
- `../to-be-architecture/SKILL.md` — 선행 skill
- `../cutover-planning/SKILL.md` — 후속 skill
- `/home/ubuntu/workspace/oh-my-aidlcops/plugins/aidlc-construction/CLAUDE.md` — risk-discovery 제공
