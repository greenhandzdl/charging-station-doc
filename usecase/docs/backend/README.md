# 后端用例与架构要点（Spring Boot 参考）

精简交付说明：本文件汇总后端必须支持的 API 用例、MVC 分层映射、关键安全与测试要求，以及对容器化与 CI/CD 的最小建议。

必须支持的 API（摘要）：
- `POST /api/v1/users`：用户注册（密码哈希、输入校验）。
- `POST /api/v1/auth/login`：登录（返回短期凭证，记录登录事件）。
- `POST /api/v1/payments/create`、`POST /api/v1/payments/callback`：充值与回调（幂等与签名校验）。
- `POST /api/v1/charges/start`、`POST /api/v1/charges/stop`：充电控制与结算。
- `GET /api/v1/charges`：查询记录（分页、过滤、权限）。
- `POST /api/v1/repairs`：报修工单（图片上载、状态流转）。

关键安全/可靠性措施：
- 认证授权（JWT / 会话 + RBAC）。
- 密码使用 bcrypt/Argon2 哈希并加盐。 
- 支付回调签名校验与幂等处理。 
- 审计日志记录关键操作并保存请求 ID。 
- 对外部依赖使用超时/重试/熔断策略（Resilience4j）。

测试与质量保障：
- 单元测试、依赖注入的 Mock 测试。
- 集成测试使用 Testcontainers 启动数据库与依赖。
- 静态分析与依赖漏洞扫描（SpotBugs / OWASP Dependency-Check）。

交付清单示例：可运行镜像、`docker-compose.yml`（开发集成）、OpenAPI 文档、CI workflow 示例。

附图：

![基础信息用例](img/basic_info.svg)

数据库说明：

- 详见 `db.md`，包含最小数据表与字段（`users`、`stations`、`chargers`、`charge_records`、`payments`、`repairs`、`audit_logs`），字段设计遵循 `doc/1.Java开发项目实训题目及评分标准.md` 要求。推荐使用 PostgreSQL（可选 TimescaleDB 扩展用于时序数据）。
