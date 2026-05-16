# 容器化与部署

本文件为容器化与持续交付的指导，包含 Dockerfile 要点、本地 Compose 场景、Kubernetes 生产建议与 CI/CD 流程示例。

## 系统架构

| 组件 | 技术栈 | 说明 |
|------|--------|------|
| 前端 | Flutter / Web | 用户与管理员界面 |
| 后端 | Java Spring Boot | REST API 服务，提供业务接口 |
| 数据库 | PostgreSQL | 核心业务数据存储 |
| 缓存 | Redis | 会话管理与数据缓存 |
| 支付 | Mock 支付网关 | 模拟外部支付回调 |

## 容器部署用例图

![容器部署用例](img/container_usecases.svg)

## 部署架构图

![部署架构](img/deployment_overview.svg)

## Docker 要点

- 使用多阶段构建以减小镜像体积。
- 运行时使用非 root 用户。
- 通过环境变量或 Secret 挂载配置。
- 添加健康检查。

## 本地集成（Docker Compose）

- 包含服务：`app`（后端 Spring Boot）、`db`（PostgreSQL）、`redis`（缓存）、`mock-payments`（支付模拟器）。
- 用于本地集成测试与开发。

### Mock 支付网关说明

```yaml
# docker-compose.yml 片段
mock-payments:
  image: your-mock-payments:latest
  ports:
    - "8081:8080"
  environment:
    - MOCK_MODE=always_success      # 当前阶段始终成功
    # - MOCK_MODE=random_failure     # 后期可切换到此模式
    # 或按接口粒度控制:
    # - MOCK_PAY_SUCCESS_RATE=1.0   # 成功率，0.0~1.0
```

Mock 支付网关当前阶段实现要点：

- 接收后端发起的支付请求，直接返回模拟回调。
- 回调内容包含模拟签名，后端对该签名做校验（后期接入真实网关时校验逻辑不变）。
- 回调始终返回 `success`，后端需设计幂等处理。
- 预留异常扩展：`failed`（支付失败）、`timeout`（回调超时），在后端回调处理逻辑中做好相应分支注释。

## Kubernetes 生产要点

- 使用 Deployment、Service、Ingress、ConfigMap、Secret。
- 设置 Liveness/Readiness probes 与 HorizontalPodAutoscaler。
- 使用私有镜像仓库与受控的凭证管理（Vault/KMS / Kubernetes Secret CSI）。

## CI/CD 流程

1. lint、静态检查、依赖扫描
2. 构建与单元测试
3. 集成测试（Testcontainers 或测试环境）
4. 构建镜像并推送到仓库
5. 部署到测试环境并运行烟雾测试
6. 按策略发布到生产（灰度/蓝绿）

## 交付清单

- Dockerfile（前端、后端）
- docker-compose.yml（含 mock-payments）
- CI workflow
- Kubernetes manifests / Helm charts

## 交叉索引

- [参与者定义与用例总览](../overview/usecases.md) — 参与者角色说明、核心用例、安全要点
- [后端 API 与权限映射](../backend/README.md) — 后端接口定义、权限控制、安全措施
- [数据库设计](../database/db.md) — 数据库表结构
- [数据库用例](../database/README.md) — 后端与数据库交互场景