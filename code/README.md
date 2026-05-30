# 充电站管理系统 — 代码仓库

按模块拆分为四个独立子仓库：

- **charging-station-backend** — Spring Boot 3.x 后端（Java 17+, Spring Security, PostgreSQL, Redis）
- **charging-station-client** — Flutter/Dart 移动客户端（用户端 + 管理端）
- **charging-station-mock-ser-client** — Java Swing 桌面应用，模拟充电桩生成二维码供客户端扫码
- **charging-station-compose** — Docker Compose 编排（PG、Redis、后端容器化部署）

```bash
git clone https://github.com/greenhandzdl/charging-station-backend.git
git clone https://github.com/greenhandzdl/charging-station-client.git
git clone https://github.com/greenhandzdl/charging-station-mock-ser-client.git
# compose 包含 .env 密钥，需单独克隆
git clone https://github.com/greenhandzdl/charging-station-compose.git
```

启动基础设施：`cd charging-station-compose && docker compose up -d`。

各子仓库均有独立的 `README.md` 提供详细启动说明。