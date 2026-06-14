# 代码-文档同步审计报告

> **日期**: 2026-06-14
> **方法**: 逐模块对比实际代码（4个子仓库）与所有UML文档（用例图/类图/时序图/状态图/活动图/ER图/数据库设计/API文档）

---

## 总览

| 分类 | 数量 | 说明 |
|------|:----:|------|
| 代码有、文档缺（待文档补充） | 14 | 代码已实现，但文档未描述或描述不全 |
| 文档有、代码缺（标记TODO） | 1 | 文档描述了但代码中不存在 |
| 文档错误/过期引用 | 8 | 文档内容与代码实际不一致 |
| 架构建议（文档更优） | 3 | 当前实现偏航，文档方向更合理 |

---

## 一、代码有、文档缺（待补充文档）

### A1. `charger_users` 表 + `ChargerUser` 实体 + `ChargerAuthController` — 整个三级设备权限体系未记载

**影响范围**: 类图、数据库设计、后端API文档

**代码实际**:
- `charger_users` 表（init.sql lines 78-104）：三级权限 CHARGER/STATION/STATION_GLOBAL，含 token_version、parent_id 权限链
- `ChargerUser` 实体（entity/ChargerUser.java）：9 个字段
- `ChargerUserService` + `ChargerUserServiceImpl`
- `ChargerAuthController`：3 个端点
  - `POST /api/v1/auth/charger-login` — 设备登录
  - `POST /api/v1/auth/charger-reset-token/{targetUserId}` — 上级重置下级 token
  - `GET /api/v1/auth/charger-users` — 查询设备身份列表

**文档现状**: 所有 UML 文档中**完全没有** `charger_users` 表、`ChargerUser` 实体、设备认证流程的任何描述。类图、数据库设计 db.md、后端 README 均缺失。

**建议**: 在 db.md 增加第 9 张表（charger_users），在类图增加 ChargerUser 实体，在后端 README 增加设备认证 API 章节。

---

### A2. `Charger` 实体新增 7 个字段未在文档中描述

**代码实际** (`Charger.java`):
```java
private String deviceType;      // SIMULATED or REAL
private BigDecimal ratedPowerKw;
private String manufacturer;
private String model;
private UUID occupiedBy;        // 当前占用用户
private LocalDateTime occupiedAt; // 占用时间
```

**文档现状**:
- `db.md` chargers 表仅列出 9 个字段，缺上述 7 个字段
- `backend_class_diagram.puml` Charger 类仅含 `onlineStatus`/`lastHeartbeatAt`，缺 7 个新字段
- `init.sql` 已包含这些列（device_type, rated_power_kw, manufacturer, model, occupied_by, occupied_at）

**建议**: 补充 db.md 和类图中的 Charger 字段。

---

### A3. `RepairStatus.DELETED` + 软删除/审批删除端点未记载

**代码实际**:
- `RepairStatus` 枚举含 `DELETED` 值
- `RepairController` 有两个端点：
  - `PUT /api/v1/repairs/{id}/delete` — 申请删除（MAINTAINER/ADMIN/SUPER_ADMIN）
  - `PUT /api/v1/repairs/{id}/approve-delete` — 审批删除（ADMIN/SUPER_ADMIN）
- `RepairService` 含 `softDelete()` / `approveDelete()` 方法
- `init.sql` repairs 表状态 CHECK 含 `'DELETED'`

**文档现状**:
- `backend_class_diagram.puml` RepairStatus 枚举仅 `OPEN, IN_PROGRESS, RESOLVED, CLOSED`，缺 `DELETED`
- `status/README.md` 报修单状态图仅 4 种状态，缺 DELETED
- 后端 README 未列出 `delete` / `approve-delete` 端点
- `repair.md` 用例文档未提及软删除流程

**建议**: 补充枚举值、状态图、API 文档。

---

### A4. ChargingController 新增 5 个端点未在 API 文档中列出

**代码实际**:
| 端点 | 说明 | 权限 |
|------|------|------|
| `POST /api/v1/chargers/heartbeat` | 接收充电桩遥测心跳 | 公开（按 chargerCode 匹配） |
| `POST /api/v1/chargers/{id}/plug-in` | 设备插枪 | `SCOPE_charger` |
| `POST /api/v1/chargers/{id}/unplug` | 设备拔枪 | `SCOPE_charger` |
| `POST /api/v1/chargers/{id}/select` | 用户选择充电桩 | 已认证 |
| `GET /api/v1/charges/active` | 查询当前活跃充电记录+离线通知 | 已认证 |

**文档现状**: 后端 README 的充电流程 API 表中均未列出上述端点。

**建议**: 在后端 README 充电流程表中增加这 5 个端点。

---

### A5. PaymentController 的 `GET /payments/deductions` 未记载

**代码实际**: `GET /api/v1/payments/deductions` — 查询扣费记录，已认证用户可见自己的扣费记录。

**文档现状**: 后端 README 充值支付 API 表未列出。

**建议**: 补充到后端 README。

---

### A6. UserController 的 `GET /users/search` 和 `PUT /users/profile` 未记载

**代码实际**:
- `GET /api/v1/users/search?keyword=xxx` — 用户搜索（ADMIN/SUPER_ADMIN）
- `PUT /api/v1/users/profile` — 当前用户编辑个人资料（isAuthenticated）

**文档现状**: 后端 README 用户管理 API 表未列出这两个端点。

**建议**: 补充到后端 README。

---

### A7. `StationController` 含 suggest 搜索补全端点未在基础信息 API 表中列出

**代码实际**:
- `GET /api/v1/stations/search/suggest?keyword=xxx&limit=5` — 充电站名称搜索补全
- `GET /api/v1/chargers/search/suggest?keyword=xxx&limit=5` — 充电桩编码搜索补全

**文档现状**: 后端 README 基础信息管理 API 表中已列出这两个端点。✅ 无问题。

---

### A8. audit_logs CHECK constraint 新增 13 个 action 枚举值

**代码实际** (init.sql): audit_logs.action CHECK 比 db.md 多出以下值：
`FORCE_STOP_OFFLINE`, `PLUG_IN`, `UNPLUG`, `CLAIM_REPAIR`, `SOFT_DELETE_REPAIR`, `REGISTRATION_FAILED`, `UPDATE_PROFILE`, `RESET_CHARGER_TOKEN`, `REJECT_REPAIR_IN_PROGRESS`, `APPROVE_DELETE_REPAIR`, `APPROVE_PAYMENT`, `REJECT_PAYMENT`, `CAPTCHA_FAILED`, `PAY_ARREARS`

**文档现状**: db.md audit_logs 表 action CHECK 列表仅含原有 30+ 个值，缺少以上新增值。

**建议**: 同步更新 db.md 中的 action CHECK 约束列表。

---

### A9. 类图中 `PeakPricing` 峰时定价策略存在但用例文档描述不完整

**代码实际**: `PeakPricing` 策略类已实现（8:00-22:00 高峰 1.2x，低谷 0.8x）。

**文档现状**: `charging-flow.md` 有提及但未在类图中展示 ChargingService → PricingStrategy 的委托关系细节。类图已有此关系 ✅。

---

### A10. `ChargingService` 接口新增 4 个方法未在类图中反映

**代码实际** (`ChargingService.java`):
```java
int autoStopOnInsufficientBalance();
Map<String, Object> plugIn(UUID chargerId, UUID deviceUserId);
Map<String, Object> unplug(UUID chargerId, UUID deviceUserId);
Map<String, Object> selectCharger(UUID chargerId, UUID userId, String sessionId);
int forceStopByChargerId(UUID chargerId, String reason);
List<Map<String, Object>> getActiveChargesWithChargerInfo(UUID userId);
```

**文档现状**: `backend_class_diagram.puml` ChargingService 接口仅列出 5 个方法（startCharge/stopCharge/calculateFee/forceStop/queryCharges），缺以上 6 个方法。

**建议**: 更新类图中 ChargingService 接口的方法签名。

---

### A11. `RepairService` 接口新增 `claim`/`softDelete`/`approveDelete` 方法未在类图中反映

**代码实际**:
```java
void claim(UUID repairId, UUID userId);
void softDelete(UUID repairId, UUID userId, String userRole);
void approveDelete(UUID repairId, UUID adminId);
```

**文档现状**: `backend_class_diagram.puml` RepairService 接口仅含 submit/listRepairs/assign/resolve/close/reject，缺上述 3 个方法。

**建议**: 更新类图。

---

### A12. `SmsService` 接口存在于代码但未在类图中反映

**代码实际**: `infrastructure/sms/SmsService.java` 接口 + `RedisSmsService.java` 实现类。

**文档现状**: `class/README.md` 提及 SmsService/RedisSmsService，但 `backend_class_diagram.puml` 的 Service 包中没有这两个类。

**建议**: 类图 Service 包增加 SmsService + RedisSmsService。

---

### A13. Flutter `StatisticsProvider` 在类图中定义但代码路径待确认

**代码实际**: `lib/providers/statistics_provider.dart` 存在于代码中。

**文档现状**: `frontend_class_diagram.puml` 包含 StatisticsProvider。✅ 一致。

---

### A14. 时序图缺"插枪/拔枪"流程

**代码实际**: 已实现 plug-in/unplug 端点 + selectCharger 端点。

**文档现状**: 时序图目录（time/）共 9 个图，但无插枪/拔枪/选择充电桩的时序图。当前充电流程图仅涉及启动充电步骤，跳过了"插枪→生成二维码→扫码"的完整交互。

**建议**: 考虑添加一个"充电桩选择与插枪"时序图，或扩展现有 sequence_charging.puml。

---

## 二、文档有、代码缺（标记 TODO）

### B1. 后端 README 中 `handleCallback` 的 IP 白名单注解未实现

**文档描述**: `@PreAuthorize("hasIpAddress('10.0.0.0/8')")` 在 PaymentController.handleCallback 上，用于回调 IP 来源校验。

**代码实际**: `PaymentController.java` line 35-36 使用的是 `@PreAuthorize("permitAll()")`，无 IP 校验。Nginx 层 IP 白名单也未在代码中体现。

**建议**: 两条路径 — ① 如果认为回调安全应由 Nginx 层负责，则更新文档为 `permitAll()` + Nginx 白名单说明；② 如果认为需要 Controller 层深度防护，则在代码中实现 `hasIpAddress` 校验。

> **状态**: 标记为 TODO（文档描述的 IP 校验未在代码中实现）

---

## 三、文档错误 / 过期引用

### C1. PlantUML 类图中 `UserRole` 枚举含 `CHARGER` 值 — 代码中已不存在

**文档**: `backend_class_diagram.puml` line 183-189：
```
enum UserRole {
  USER
  MAINTAINER
  ADMIN
  SUPER_ADMIN
  CHARGER
}
```

**代码实际** (`UserRole.java`):
```java
public enum UserRole {
    USER, MAINTAINER, ADMIN, SUPER_ADMIN
}
```

CHARGER 角色已从 `users` 表迁移至独立的 `charger_users` 表（参见 Round 41 决策）。

**修复**: 从类图 UserRole 枚举中移除 CHARGER。

---

### C2. db.md 称"八张核心表"实际为九张

**文档** (`db.md` line 3): "以下列出八张核心表及其字段设计"

**实际**: init.sql 含 9 张表：users, stations, chargers, charger_users, charge_records, payments, repairs, audit_logs, password_history。

**修复**: 改为"九张核心表"，并增加 charger_users 表的完整字段说明。

---

### C3. db.md 外键约束表缺 charger_users 的外键

**文档** (`db.md` 外键约束表): 列出 9 个外键，但缺 charger_users 表的 3 个外键：
- `charger_users.charger_id → chargers(id)`
- `charger_users.station_id → stations(id)`
- `charger_users.parent_id → charger_users(id)`

**修复**: 补充外键约束表。

---

### C4. `v_user_charge_records` VIEW 缺少 `plate_number` 字段

**评分标准要求** (模块5): 快捷视图应显示"用户姓名、**车牌号**、充电桩ID、充电量、费用"。

**代码实际** (init.sql): `v_user_charge_records` VIEW 联表查询了 `users u` 但仅取 `u.name, u.phone`，没有取 `u.plate_number`。

**修复**: VIEW 增加 `u.plate_number AS plate_number`。

---

### C5. README.md 引用不存在的文件

**文档** (`README.md` lines 61-63):
```
├── agent/
│   ├── prompts.md                    # 可复用提示词模板
│   ├── verification-results.md       # API 端到端验证日志
```

**实际**: `agent/` 目录下仅存在 `plan.md` 和 `conflicts.md`，无 `prompts.md` 和 `verification-results.md`。

**修复**: 更新 README 目录结构或创建缺失文件。

---

### C6. `doc/测试方案与结果记录.md` 引用错误的表名

**文档** (测试方案 line 280): "CHARGER 角色已从 users 表移除，改为 `charger_devices` 表通过 `X-Device-Token` 认证。"

**实际**: 表名为 `charger_users`（非 `charger_devices`），认证方式为 JWT（scope=charger），非 `X-Device-Token` header。

**修复**: 更正表名和认证方式描述。

---

### C7. PlantUML 类图中 `PaymentController.handleCallback` 注解与代码不一致

**文档**: `backend_class_diagram.puml` line 239 — `@PreAuthorize("hasIpAddress('10.0.0.0/8')")`

**代码实际**: `@PreAuthorize("permitAll()")`

**修复**: 更新类图中的注解为实际值，或在类图注释中说明 Nginx 层已完成 IP 白名单校验。

---

### C8. `usecase/docs/overview/usecases.md` "未完成项"全部标记为已完成但未清理

**文档** (usecases.md lines 101-108): "未完成项"章节列出 5 项，全部标记 `✅ 已实现`。

**建议**: 该章节无存在意义，建议删除或合并进"实现状态"章节。

---

## 四、架构建议（当前代码偏航，文档方向更合理）

### D1. 充电启动前置条件文档说"四条件"、测试文档说"四条件"但代码校验链较分散

**文档**: `charging-flow.md` / `usecases.md` 明确定义启动充电四条件：插枪 → 扫码 → 余额 >= 10 → 桩在线。

**代码**: 校验逻辑分散在 ChargingServiceImpl.startCharge() 和 plugIn/selectCharger 流程中，缺乏统一的前置条件校验入口。

**影响**: 低（代码可正常工作），但代码结构与文档描述的清晰流程存在偏差。

**建议**: 暂不修改代码，但文档描述的"四条件"流程可作为后续重构的目标架构。

---

### D2. 审计日志 action 枚举管理

**代码**: audit_logs.action CHECK constraint 硬编码 40+ 个枚举值于 SQL 中。

**文档**: db.md 描述了一个统一的审计 action 列表，可作为枚举管理的参照。

**建议**: 将 action 枚举提取为独立的数据库枚举类型或应用层常量，便于维护和文档同步。

---

### D3. `Charger` 实体的 `onlineStatus` 字段默认值

**文档** (`db.md`): `online_status VARCHAR(16) DEFAULT 'OFFLINE'`

**代码**: 实体无默认值（由 DB 层提供），但 `init.sql` 种子数据中所有充电桩 `online_status = 'OFFLINE'`。

**建议**: 考虑在 Charger 实体中设置 `@Builder.Default onlineStatus = "OFFLINE"`，确保新建充电桩默认为离线状态，与实际行为一致。

---

## 修复优先级建议

| 优先级 | 类别 | 条目 | 工作量 |
|:------:|------|------|:------:|
| **P0** | 文档错误 | C1 UserRole.CHARGER 不存在 | 1行修改 |
| **P0** | 文档错误 | C2 db.md "八张表"→"九张" | 1行修改 |
| **P0** | 文档错误 | C7 类图 handleCallback 注解不一致 | 1行修改 |
| **P1** | 代码缺 | B1 IP白名单未实现 | 需讨论方案 |
| **P1** | 文档缺 | A1 charger_users 整套体系 | 需多处补充 |
| **P1** | 文档缺 | A2 Charger 新增 7 字段 | 补充 db.md + 类图 |
| **P2** | 文档缺 | A3 RepairStatus.DELETED + 软删除 | 补充枚举值+状态图+API |
| **P2** | 文档缺 | A4 充电桩心跳/插拔/选择/活跃查询 5 端点 | 补充 API 表 |
| **P2** | 文档缺 | A8 audit_logs action 枚举值 | 更新 db.md |
| **P3** | 文档错误 | C4 VIEW 缺 plate_number | 1行 SQL 修改 |
| **P3** | 文档错误 | C5/C6/C8 过期引用 | 清理文本 |
| **P4** | 文档缺 | A10/A11/A12 类图方法接口 | 更新 PlantUML |
| **P4** | 架构 | D1/D3 代码改进 | 视情况决定 |

---

## 审计结论

项目中 **代码超前于文档** 是主要矛盾（14 项 vs 1 项反向）。代码在经过多轮迭代修复（Round 1-45）后已相当成熟（402 测试全部通过），但文档更新未能完全同步跟进。建议优先修复 P0/P1 级别的问题后，再逐步完善 P2-P4 项目。