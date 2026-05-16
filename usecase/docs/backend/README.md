# 后端用例与架构要点（Spring Boot 参考）

本文件汇总后端必须支持的 API 用例、安全要求及交付物。

## 参与者与权限映射

| 参与者 | 权限等级 | 可访问功能 |
|--------|----------|-----------|
| 未授权用户 | 无需认证 | 注册、登录 |
| 用户 | 基础 | 充电、充值、查看自己的记录、提交报修 |
| 维修人员 | 基础+ | 用户全部功能 + 查看和处理报修单（由管理员从用户提升） |
| 管理员 | 中级 | CRUD 充电站/充电桩、管理用户权限、分配和处理报修、部分统计数据 |
| 最高管理者 | 最高 | 全部管理功能、权限变更、全局统计报表 |
| 系统 | 系统级 | 定时任务、自动结算、统计汇总 |

## 必须支持的 API

### 认证与账户
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/auth/register` | 用户注册 | 公开 |
| POST | `/api/v1/auth/login` | 用户登录，返回短期凭证 | 公开 |
| POST | `/api/v1/auth/refresh` | Token 刷新 | 已认证 |

### 充电流程
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/charges/start` | 启动充电 | 已认证用户 |
| POST | `/api/v1/charges/stop` | 结束充电并结算 | 已认证用户/管理员/系统 |
| GET | `/api/v1/charges` | 查询充电记录（分页、过滤） | 已认证用户（仅自己的）/管理员（全部） |

### 充值支付
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/payments/create` | 创建充值请求 | 已认证用户 |
| POST | `/api/v1/payments/callback` | 支付网关回调 | 支付网关 |
| GET | `/api/v1/payments` | 查询支付记录 | 已认证用户（仅自己的） |

### 基础信息管理
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| CRUD | `/api/v1/stations` | 充电站管理 | 管理员/最高管理者 |
| CRUD | `/api/v1/chargers` | 充电桩管理 | 管理员/最高管理者 |

### 用户管理
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/users` | 查看用户列表 | 管理员/最高管理者 |
| PUT | `/api/v1/users/{id}/role` | 变更用户角色 | 管理员/最高管理者 |
| PUT | `/api/v1/users/{id}` | 编辑用户信息 | 管理员/最高管理者 |

### 故障报修
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/repairs` | 提交报修单 | 已认证用户/管理员 |
| GET | `/api/v1/repairs` | 查看报修列表 | 已认证用户（仅自己的）/管理员（全部） |
| PUT | `/api/v1/repairs/{id}/assign` | 分配维修人员 | 管理员/最高管理者 |
| PUT | `/api/v1/repairs/{id}/resolve` | 处理完成报修 | 维修人员/管理员 |

### 统计
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/analytics/charges` | 充电统计报表 | 管理员/最高管理者 |
| GET | `/api/v1/analytics/revenue` | 收入统计报表 | 最高管理者 |
| GET | `/api/v1/analytics/export` | 导出 CSV | 管理员/最高管理者 |

## 关键安全措施

- **认证：** JWT 短期凭证（建议 30 分钟过期），Refresh Token 机制，登出时作废。
- **密码：** bcrypt/Argon2 加盐散列，密码强度校验（长度、复杂度）。
- **授权：** 基于 RBAC 的接口级权限控制，未授权请求返回 403。
- **输入校验：** 服务端对所有参数进行类型、长度、格式校验，防止 SQL 注入与 XSS。
- **支付安全：** 支付回调签名校验（HMAC / RSA），回调处理幂等，防止重放攻击。
- **审计日志：** 所有关键操作（权限变更、充值、扣费、充电启停、报修处理）记录日志，包含操作人、时间、资源与操作类型。
- **防重放：** Token 设置唯一 jti，服务端维护已作废 Token 黑名单或设置极短有效期。
- **接口防护：** 登录接口添加验证码防暴力破解；API 频率限制。

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

## 交叉索引

- [参与者定义与用例总览](../overview/usecases.md) — 参与者角色说明、核心用例、安全要点
- [统计与可视化](../overview/analytics.md) — 统计报表用例
- [数据库设计](../database/db.md) — 包含 `users`、`stations`、`chargers`、`charge_records`、`payments`、`repairs`、`audit_logs` 七张表
- [数据库用例](../database/README.md) — 后端与数据库交互场景
- [前端用例](../frontend/README.md) — 前端界面与交互契约
- [容器化与部署](../containerd/README.md) — Docker/K8s/CI 配置