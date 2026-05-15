# 容器化与部署（Docker / Kubernetes / CI）

本文件为容器化与持续交付的精简指导，包含 Dockerfile 要点、本地 Compose 场景、Kubernetes 生产建议与 CI/CD 流程示例。

Docker 要点：
- 使用多阶段构建以减小镜像体积；运行时使用非 root 用户；通过环境变量或 Secret 挂载配置；添加健康检查。 

本地集成（Docker Compose）：
- 建议包含服务：`app`（后端）、`db`（Postgres）、`redis`、`mock-payments`；用于本地集成测试与开发。 

Kubernetes（生产）要点：
- 使用 Deployment、Service、Ingress、ConfigMap、Secret；设置 Liveness/Readiness probes 与 HorizontalPodAutoscaler。 
- 使用私有镜像仓库与受控的凭证管理（Vault/KMS / Kubernetes Secret CSI）。

CI/CD（要点示例）：
1. `lint`、静态检查、依赖扫描
2. 构建与单元测试
3. 集成测试（Testcontainers 或测试环境）
4. 构建镜像并推送到仓库
5. 部署到测试环境并运行烟雾测试
6. 按策略发布到生产（灰度/蓝绿）

交付清单示例：`Dockerfile`、`docker-compose.yml`、CI workflow、Kubernetes manifests / Helm charts。

附图：

![部署概览](img/deployment_overview.svg)
