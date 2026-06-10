# 后端用例与架构要点（Spring Boot 参考）

本文件汇总后端必须支持的 API 用例、安全要求及交付物。

## 参与者与权限映射

| 参与者 | 客户端 | 权限等级 | 可访问功能 |
|--------|--------|----------|-----------|
| 未授权用户 | Flutter | 无需认证 | 注册、登录 |
| 用户 | Flutter | 基础 | 充电、充值、查看自己的记录、提交报修 |
| 维修人员 | Flutter | 基础+ | 用户全部功能 + 查看和处理报修单（由管理员从用户提升）。**注意：维修人员不可访问统计报表端点** |
| 管理员 | Flutter | 中级 | CRUD 充电站/充电桩、管理用户权限、分配和处理报修、部分统计数据 |
| 最高管理者 | Flutter | 最高 | 全部管理功能、权限变更、全局统计报表 |
| 模拟充电桩（普通模式） | **Swing 桌面客户端** | **高（桩专用）** | 模拟物理充电机面板交互。使用专用测试账户 `mock_charger/charger123` 登录，JWT scope=user，仅可见自己的测试充电桩。每 30 秒心跳上报遥测数据。**模拟充电桩不是"用户端"，而是模拟的真实充电桩设备，需要比普通用户更高的权限与 Spring 中间件通讯、获取所有充电桩的信息** |
| 模拟充电桩（高级模式） | **Swing 桌面客户端** | **最高（桩专用）** | 需 `ADVANCED_API_KEY` 环境变量，使用密钥认证。可见所有充电桩及与 Spring 中间件交互权限，UI 显示[高级模式]标记。**高级权限仅用于模拟充电桩，不提供给 Flutter 用户**。仅测试环境开放 |
| 系统 | — | 系统级 | 定时任务（`ChargingScheduler` 每 30 秒检查余额不足自动停）、自动结算、统计汇总 |

### 权限层级模型

系统采用三层权限模型：

| 层级 | 角色 | 客户端 | JWT Scope | 说明 |
|------|------|--------|-----------|------|
| **普通权限 (Normal)** | USER、MAINTAINER | Flutter 用户端 | `scope=user` | 只能操作自己的充电桩和记录 |
| **管理权限 (Admin)** | ADMIN、SUPER_ADMIN | Flutter 管理端 | `scope=admin` | 全部可见/管理，可管理用户权限 |
| **高级权限 (Advanced)** | 模拟充电桩专用 | Swing 充电桩端 | 需 `ADVANCED_API_KEY` 密钥 | 可见所有充电桩并支持中间件交互，仅测试环境开放 |

> **✅ 已实现**：JWT scope claim（`SCOPE_admin`/`SCOPE_advanced`）已在 SecurityConfig 中生效；充电桩遥测/心跳检测（last_heartbeat_at + online_status）已实现（Entity + Mapper + 端点 + Scheduler + Mock客户端心跳）。

## 必须支持的 API

### 认证与账户
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/captcha` | 获取图形验证码图片，验证码 ID 与图片字节流一同返回。含 IP 级限流：同一 IP 每分钟最多请求 10 次，超出返回 429 | 公开 |
| POST | `/api/v1/auth/register` | 用户注册（需验证码，防止机器人注册）。限流策略：同一 IP 每小时最多注册 3 次；同一手机号每日最多注册 1 次 | 公开 |
| POST | `/api/v1/auth/login` | 用户登录，返回短期凭证。含暴力破解防护：IP 维度 5 分钟内失败 5 次触发验证码，10 次封禁 IP 30 分钟；账户维度连续失败 10 次锁定 30 分钟 | 公开 |
| POST | `/api/v1/auth/refresh` | Token 刷新（refresh_token 轮换机制，旧 token 立即失效）。含 IP 级限流：同一 IP 每分钟最多刷新 5 次，超出返回 429 | 已认证 |
| POST | `/api/v1/auth/password-reset` | 密码重置请求（第一步）。需图形验证码 + 短信验证码双重校验，重置令牌绑定用户会话，令牌有效期 15 分钟。含 IP 级限流：同一 IP 5 分钟内最多发起 3 次重置请求；手机维度限流：同一手机号每日最多 3 次 | 公开 |
| POST | `/api/v1/auth/password-reset/confirm` | 密码重置确认（第二步）。提交短信验证码、重置令牌和新密码，校验通过后更新密码并清除旧会话。含 IP 级限流：同一 IP 每分钟最多尝试 5 次确认操作，防止验证码暴力破解，超出返回 429 | 公开 |
| PUT | `/api/v1/auth/password` | 修改密码（需旧密码校验，校验失败返回 401） | 已认证 |

### 充电流程
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/charges/start` | 启动充电 | 已认证用户 |
| POST | `/api/v1/charges/stop` | 结束充电并结算。`@PreAuthorize("@chargeGuard.canStop(authentication, #req.recordId)")` — 使用 ChargeGuard bean 在注解层进行授权校验：普通用户仅能结束自己的充电记录，管理员可结束任意充电记录。recordId 来自请求体，由 ChargeGuard 查询归属 | 已认证用户/管理员/系统 |
| POST | `/api/v1/charges/{id}/force-stop` | 管理员强制结束指定充电记录，需在请求体中携带强制终止原因，系统将该原因写入 audit_log。服务端校验 reason 参数：长度 ≤ 200 字符，HTML 标签过滤（使用白名单机制，仅允许 `<br/>` 等基本安全标签）。`@PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_ADMIN')")` — 仅管理员和最高管理者可操作 | 管理员/最高管理者 |
| GET | `/api/v1/charges` | 查询充电记录列表。Service 层按当前用户 ID 过滤，普通用户仅能看到自己的充电记录，管理员可查看全部 | 已认证用户/管理员/最高管理者 |
> **模拟充电桩客户端（Swing）** 使用 Swing 桌面客户端模拟物理充电机的面板显示与交互。模拟充电桩是模拟的真实充电桩设备，不是"用户端"。用户选择充电桩后屏幕自动生成含充电桩 ID 的二维码，Flutter App 扫码调用 `POST /api/v1/charges/start` 启动充电。后台轮询充电状态（每 30 秒心跳，`GET /api/v1/charges`），同时每 30 秒发送遥测数据（heartbeat）到 Spring 上报在线状态。ChargeSimulator 模拟电量增长（0.1 kWh/秒）。面板内置断网测试/服务器重启/桩离线三个测试场景按钮。**不直接调用充电启停 API**。
> **模拟充电桩安全约束：** 面板仅含充电桩选择与插拔枪操作，无管理功能入口。使用隔离测试用户账户，不影响真实用户数据。模拟充电桩需要比普通用户更高的权限才能与 Spring 中间件通讯、获取所有充电桩的信息。

### 充值支付
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/payments/recharge` | 创建充值请求（状态为 PENDING，等待管理员审批） | 已认证用户 |
| GET | `/api/v1/payments/pending` | 查询待审核充值列表 | 管理员/最高管理者 |
| PUT | `/api/v1/payments/{id}/approve` | 批准充值请求（触发系统模拟回调处理 → 加余额） | 管理员/最高管理者 |
| PUT | `/api/v1/payments/{id}/reject` | 拒绝充值请求 | 管理员/最高管理者 |
| GET | `/api/v1/users/balance` | 查询当前用户余额 | 已认证用户 |
| POST | `/api/v1/payments/callback` | 支付网关回调 | 支付网关 |
| GET | `/api/v1/payments` | 查询支付记录 | 已认证用户（仅自己的） |
| POST | `/api/v1/payments/pay-arrears` | 支付欠费（选择支付方式后调用） | 已认证用户 |

> **审批流程说明**：用户提交充值申请后，状态为 `PENDING`。管理员在后台查看待审核列表，批准后系统自动执行模拟回调处理（校验HMAC → 标记SUCCESS → 增加余额 → 自动补扣欠费）。拒绝后状态变为 `FAILED`。

### 基础信息管理
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/stations` | 查询充电站列表 — `@PreAuthorize("isAuthenticated()")` 任何已认证用户可读 | 已认证用户 |
| GET | `/api/v1/stations/search?name=xxx` | 按名称查询充电站 | 已认证用户 |
| GET | `/api/v1/stations/search/suggest?prefix=xxx` | 充电站名称搜索补全提示，根据前缀返回匹配的充电站名称列表 | 已认证用户 |
| GET | `/api/v1/stations/{id}` | 按 ID 查询充电站 | 已认证用户 |
| POST | `/api/v1/stations` | 创建充电站 — `@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")` | 管理员/最高管理者 |
| PUT | `/api/v1/stations/{id}` | 更新充电站信息 | 管理员/最高管理者 |
| DELETE | `/api/v1/stations/{id}` | 删除充电站 | 管理员/最高管理者 |
| GET | `/api/v1/chargers` | 查询充电桩列表（可选按 stationId 筛选）— `@PreAuthorize("isAuthenticated()")` | 已认证用户 |
| GET | `/api/v1/chargers/{id}` | 按 ID 查询充电桩 | 已认证用户 |
| GET | `/api/v1/chargers/by-code/{code}` | 按充电桩编码查询 | 已认证用户 |
| GET | `/api/v1/chargers/search/suggest?prefix=xxx` | 充电桩编码搜索补全提示，根据前缀返回匹配的充电桩编码列表 | 已认证用户 |
| POST | `/api/v1/chargers` | 创建充电桩 — `@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")` | 管理员/最高管理者 |
| PUT | `/api/v1/chargers/{id}` | 更新充电桩信息 | 管理员/最高管理者/维修人员 |
| DELETE | `/api/v1/chargers/{id}` | 删除充电桩 | 管理员/最高管理者 |

### 用户管理
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/users` | 查看用户列表 | 管理员/最高管理者 |
| PUT | `/api/v1/users/{id}/role` | 变更用户角色 | 管理员/最高管理者 |
| PUT | `/api/v1/users/{id}` | 编辑用户信息 | 管理员/最高管理者 |
| DELETE | `/api/v1/users/{id}` | 删除用户 | 管理员/最高管理者 |

**用户管理安全约束：**
- ADMIN 不得删除或修改其他 ADMIN 用户（同级保护），也不得删除或修改 SUPER_ADMIN 用户（越级保护）
- SUPER_ADMIN 不得删除自身（自我保护），但可以管理其他 ADMIN 和普通用户
- 系统中必须至少保留 1 名 SUPER_ADMIN 用户，deleteUser 方法在删除 SUPER_ADMIN 前检查剩余 SUPER_ADMIN 数量，若仅为 1 人则拒绝操作并返回 HTTP 403
- Service 层在 updateUser/deleteUser 方法中校验当前操作者与目标用户的关系，违反约束返回 HTTP 403

### 故障报修
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/repairs` | 提交报修单 | 已认证用户/管理员 |
| GET | `/api/v1/repairs` | 查看报修列表 | 已认证用户（仅自己的）/管理员（全部） |
| PUT | `/api/v1/repairs/{id}/assign` | 分配维修人员 | 管理员/最高管理者 |
| PUT | `/api/v1/repairs/{id}/resolve` | 处理完成报修 | 维修人员/管理员 |
| PUT | `/api/v1/repairs/{id}/claim` | 接单（维修人员自分配） | 维修人员/管理员 |
| PUT | `/api/v1/repairs/{id}/close` | 管理员审核关闭报修单 | 管理员/最高管理者 |
| PUT | `/api/v1/repairs/{id}/reject` | 退回报修 | 管理员/最高管理者 |

### 统计
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/analytics/charges` | 充电统计报表（非金额维度：充电次数、充电量等） | 管理员/最高管理者 |
| GET | `/api/v1/analytics/revenue` | 收入统计报表（金额维度：总收入、日均收入等，仅含金额敏感数据） | 最高管理者 |
| GET | `/api/v1/analytics/utilization` | 充电桩使用率：返回空闲/使用中/故障三种状态比例 | 管理员/最高管理者 |
| GET | `/api/v1/analytics/user-charges` | 查看用户充电统计 | 管理员/最高管理者 |
| GET | `/api/v1/analytics/stations` | 充电站运营分析：返回各充电站的总充电次数、总收入等 | 管理员/最高管理者 |
| GET | `/api/v1/analytics/fault-chargers` | 故障充电桩列表：返回当前所有状态为 fault 的充电桩 | 管理员/最高管理者 |
| GET | `/api/v1/analytics/export` | 导出 CSV。含 IP 级限流：同一 IP 每 10 分钟最多导出 3 次，超出返回 429 | 管理员/最高管理者 |

## API 文档（Swagger）

项目集成 SpringDoc OpenAPI (Swagger) 提供在线 API 文档：

| 分组 | 访问入口 | 说明 |
|------|---------|------|
| 全部 | `http://localhost:8080/swagger-ui.html` | 全部 API 分组（默认启用，生产环境建议关闭） |

**安全约束：**
- Swagger UI 默认启用，生产环境建议通过 `spring.profiles.active=prod` 关闭
- API 文档不暴露密钥等敏感配置

## 关键安全措施

- **认证：** JWT（无状态令牌），access_token 过期时间 15 分钟；refresh_token 存储在 Redis 中并设置 TTL（建议 7 天），用于无感续期。
  - 针对 Flutter 客户端，Token 存储在内存中（应用退出即失效），不持久化到本地存储。生产环境部署到 Web 时，建议使用 HttpOnly Cookie 替换前端内存存储，防止 XSS 攻击窃取 Token。
  - 每个 Token 包含唯一 jti（JWT ID），服务端维护 jti 黑名单用于令牌吊销，登出时将 access_token 和 refresh_token 加入黑名单。
  - **refresh_token 轮换：** 每次使用 refresh_token 换取新 access_token 时，服务端同时颁发新的 refresh_token 并使旧的 refresh_token 失效（替换 Redis 中的记录），防止 refresh_token 泄露后被重放。
- **密码：** bcrypt 加盐散列，密码强度校验（至少 8 位，4 类中至少 3 类：大写字母、小写字母、数字、特殊字符）
- **授权：** 基于 RBAC 的接口级权限控制，未授权请求返回 403。关键接口使用 `@PreAuthorize` 注解进行细粒度授权（如结束充电检查记录所有者、强制结束仅 ADMIN 可用）。
- **输入校验：** 服务端对所有参数进行类型、长度、格式校验，防止 SQL 注入与 XSS。所有数据库操作用 PreparedStatement 参数绑定。
- **支付安全：** 支付回调签名校验（HMAC-SHA256 / RSA），回调处理幂等，防止重放攻击。回调端点 `/api/v1/payments/callback` 必须验证请求来源：开发环境使用 IP 白名单（仅允许 Mock 支付网关地址）；生产环境建议使用 mTLS 双向认证或预共享网关 API Key。建议使用 `payment_gateway_tx_id` 作为幂等键，在 payments 表增加 UNIQUE 约束。此外，回调请求应校验时间戳（timestamp 参数在服务端当前时间 +/- 5 分钟内），结合可选 nonce 参数形成双层重放防护。HMAC 签名密钥通过环境变量配置，定期轮换（建议 90 天），密钥仅服务端持有，不暴露至客户端。

> **密钥轮换自动化：** 密钥托管于 Kubernetes Secret（或 Vault/KMS），由 Secrets Operator 定时轮换（CronJob）。轮换策略：新密钥立即生效，旧密钥保留 24 小时宽限期用于处理已发出但未完成的回调验证，宽限期后自动废弃。密钥泄露时执行紧急轮换：立即更新 Secret + 刷新所有网关配置 + 记录安全审计事件。每个支付通道（微信、支付宝、银联）使用独立 API Key，参见下方密钥隔离说明。
> **密钥隔离：** 每个支付通道（微信、支付宝、银联等）使用独立 API Key，单通道密钥泄露不影响其他通道安全。密钥按通道存储在环境变量中，如 `WECHAT_API_KEY`、`ALIPAY_API_KEY`。
- **审计日志：** 所有关键操作（权限变更、充值、扣费、充电启停、报修处理、强制结束充电）记录日志，包含操作人、时间、资源与操作类型。权限提升/降级操作必须额外记录变更前后的角色值及操作原因。
  - audit_logs.payload 字段（JSONB）存储操作详情，例如强制结束充电时记录终止原因：`{"reason": "设备异常发热"}`；权限变更时记录变更前后角色：`{"old_role": "user", "new_role": "maintainer", "reason": "维修能力考核通过"}`。
- **防重放：** Token 设置唯一 jti，服务端维护已作废 Token 黑名单或设置极短有效期。
- **jti 黑名单 TTL：** 与 access_token 有效期一致（15 分钟），由 Redis TTL 自动清理，避免黑名单无限增长。refresh_token 的 jti 同样加入黑名单，TTL 与 refresh_token 有效期一致（7 天），由 Redis TTL 自动清理，防止已轮换的 refresh_token 被重放。
- **防暴力破解：** 双重防护机制：
  - IP 维度：同一 IP 5 分钟内登录失败 5 次触发图形验证码，失败 10 次封禁该 IP 5 分钟（代码 hardcoded `5, TimeUnit.MINUTES`）。封禁状态记录在 Redis 中，设置 TTL 自动解封。
  - 账户维度：`users.failed_login_attempts` 记录连续失败次数，达到 10 次时设置 `account_locked_until = now() + 30min` 锁定账户。**登录成功后 `failed_login_attempts` 重置为 0**，避免前次失败的遗留计数导致后续误锁定。
- **密码重置安全：** 密码重置分为两步：第一步 `POST /api/v1/auth/password-reset` 校验图形验证码后生成重置令牌并发送短信验证码；第二步 `POST /api/v1/auth/password-reset/confirm` 校验短信验证码 + 重置令牌后执行密码更新。重置令牌（`passwordResetToken`）绑定用户会话，有效期 15 分钟；短信验证码为 6 位数字，有效期 5 分钟。服务端对同一 IP 实施限流：5 分钟内最多 3 次重置请求，超出返回 429。同时增加手机维度限流：同一手机号每日最多 3 次重置请求，使用 Redis key `password_reset:phone:{phone}`（TTL 86400），与 IP 限流形成双层防御。
- **验证码安全：** 注册和登录的验证码存储在 Redis，TTL 5 分钟，使用后立即删除防止重放。验证码 ID 由服务端 `/api/v1/captcha` 端点生成，随机不可预测。生成验证码的端点 `/api/v1/captcha` 同样需要限流：同一 IP 每分钟最多请求 10 次，防止 Redis 内存耗尽或验证码泛滥，超出返回 429。验证码校验失败（验证码错误或过期）应记录审计日志（action='CAPTCHA_FAILED'），用于检测自动化攻击。
- **授权检查可视化：** 所有涉及资源归属的关键操作（结束充电、强制结束充电、报修处理）在时序图中明确标注 `@PreAuthorize` 授权检查步骤，展示 Spring Security Filter Chain 处理流程。

## 测试与质量保障

- 单元测试，依赖注入的 Mock 测试。
- 集成测试使用 Testcontainers 启动数据库与依赖。
- 安全测试：认证绕过、SQL 注入、XSS、CSRF 等测试用例。

## 交付物

- 可运行镜像、`docker-compose.yml`、OpenAPI 文档、CI workflow 示例。

## 后端模块文档

| 文档 | 内容 | 用例图 |
|------|------|--------|
| `basic-info.md` | 充电站/充电桩/用户管理 | ![基础信息](img/basic_info.svg) |
| `charging-flow.md` | 启动/结束充电与结算 | ![充电流程](img/charging_flow.svg) |
| `account-payment.md` | 注册/登录/充值/支付回调 | ![账户支付](img/account_payment.svg) |
| `repair.md` | 报修提交与处理 | ![故障报修](img/repair.svg) |

## 实现状态

以上涉及的所有功能均已实现（JWT scope 检查、HMAC-SHA256 签名验证、高级密钥认证、audit_logs 完整性保护、ChargerConnector HTTP 推送、充电桩遥测/心跳检测）。测试覆盖 101 项（含 CaptchaService、UserService 边界测试、调度器测试、并发竞争条件测试）。

## 交叉索引

- [参与者定义与用例总览](../overview/usecases.md) — 参与者角色说明、核心用例、安全要点
- [统计与可视化](../overview/analytics.md) — 统计报表用例
- [数据库设计](../database/db.md) — 包含 `users`、`stations`、`chargers`、`charge_records`、`payments`、`repairs`、`audit_logs` 七张表
- [数据库用例](../database/README.md) — 后端与数据库交互场景
- [前端用例](../frontend/README.md) — 前端界面与交互契约
- [容器化与部署](../containerd/README.md) — Docker/K8s/CI 配置