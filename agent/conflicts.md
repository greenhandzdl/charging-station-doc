# 冲突记录与决断

本文件记录在 UML 文档设计过程中出现的需求冲突、歧义或偏离评分标准的情况，以及用户的最终决断。

## 格式

```
### YYYY-MM-DD: [冲突标题]

**冲突描述：**
**涉及文件：**
**相关模块：**
**用户决断：**
```

---

### 2026-05-23: 新增 Mock 充电机客户端（Swing）概念

**冲突描述：** 用户提出需要引入一个 Mock 充电机客户端，这是一个前后端不分离的 Swing 桌面客户端，用于模拟物理充电机的交互（插枪/拔枪/刷卡启动、充电进度显示、电量模拟生成）。该客户端作为 Swing 组件的展示载体，满足评分标准中 Swing+JDBC（40分）的要求，同时 Flutter 管理后台作为实际技术栈保持不变。

**涉及文件：** 35 个文件（6 个用例图、2 个类图、3 个时序图、2 个部署/容器图、1 个活动图、8 个 README 文档）

**相关模块：** 全局 — usecase（用例图）、class（类图）、time（时序图）、activity（活动图）、containerd（部署图）

**用户决断：**
- 新增 `Mock充电机` actor 到所有用例图，关联 3 个用例：启动充电、结束充电、查询充电状态
- 后端类图新增 `MockChargerClient`、`ChargerUIPanel`、`ChargeSimulator` 三个类，独立包
- 充电启动/结束/强制结束时序图插入 Mock Client 作为用户与后端的中介
- Mock Client 不参与充值、报修、管理等非充电业务流程
- 总览类图同样新增 Mock 充电机客户端包
- 部署图前端层新增 Mock充电机客户端组件
- 活动图新增 Mock充电机客户端泳道

---
### 2026-05-23: 安全审计 — Mock 客户端安全约束与文档修复

**冲突描述：** 安全审计发现 Mock 充电机客户端文档缺少安全隔离描述，包括：
1. Mock 客户端在后端类图中直接调用 ChargerMapper（绕过 Controller 层校验）
2. Mock 客户端 JWT 缺少作用域限制（mock_charger_only）
3. 部署图缺少网络隔离说明
4. ChargingController 缺少 @PreAuthorize 注解
5. forceStop() 的 @PreAuthorize 在类图与时序图不一致
6. repairs 表缺少 reject_reason 字段（时序图使用了但数据表定义缺失）

**涉及文件：**
- class/src/backend_class_diagram.puml（Mock 客户端类字段、ChargingController 注解）
- class/src/class_diagram.puml（Mock 客户端 API 调用说明修正）
- time/src/sequence_charging.puml（Mock 客户端 Token 作用域说明）
- usecase/docs/containerd/src/deployment_overview.puml（网络隔离说明）
- usecase/docs/database/db.md + ddl.sql + er_diagram.puml（reject_reason 字段）
- usecase/docs/{backend,frontend,containerd}/README.md（安全约束描述）

**用户决断：**
- MockChargerClient 增加 authToken/tokenScope/testUserId/isTestMode 安全字段
- 移除 MockChargerClient --> ChargerMapper 直接关联（改为仅通过 Controller 层通信）
- ChargingController.startCharge() 增加 @PreAuthorize("isAuthenticated()")
- ChargingController.stopCharge() 增加 @PreAuthorize("(#record.userId == authentication.principal.id) or hasRole('ADMIN')")
- ChargingController.forceStop() 的 @PreAuthorize 统一为 hasRole('ADMIN') or hasRole('SUPER_ADMIN')
- StationController.chargerOperations() 增加 @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_ADMIN')")
- 部署图标注 Mock 客户端网络隔离路由规则
- repairs 表增加 reject_reason TEXT NULLABLE 字段

---
### 2026-06-07: 第34轮 — 修正权限映射：Swing=模拟充电桩（高权限） Flutter=用户端

**冲突描述：** 此前文档中权限描述存在系统性错误：
1. Mock充电机（Swing）被描述为"用户端"或"基础权限"，但实际它是模拟的真实充电桩设备，需要比普通用户更高的权限与 Spring 中间件通讯
2. Flutter 被描述为"充电桩"端，但 Flutter 实际是用户端（普通用户/管理员/维修人员的操作界面）
3. 高级权限（ADVANCED_API_KEY）被描述为给 "Flutter 用户"使用的，实际上它仅用于模拟充电桩

**涉及文件：**
- usecase/docs/overview/usecases.md
- usecase/docs/backend/README.md
- usecase/docs/frontend/README.md
- usecase/docs/containerd/README.md
- usecase/docs/backend/charging-flow.md
- doc/测试方案与结果记录.md
- agent/conflicts.md

**相关模块：** 全局 — 所有文档中的参与者与权限描述

**用户决断：**
- 统一使用 **正确的权限映射**：

| 角色 | 客户端 | 权限 |
|------|--------|------|
| 普通用户 | Flutter | 基础 |
| 维修人员 | Flutter | 基础+ |
| 管理员 | Flutter | 中级 |
| 最高管理者 | Flutter | 最高 |
| 模拟充电桩（普通模式） | **Swing** | **高（桩专用）** |
| 模拟充电桩（高级模式） | **Swing** | **最高（桩专用）** |

- Swing 桌面客户端是模拟的真实充电桩设备，不是"用户端"。Flutter 是用户端，不是充电桩
- 高级权限（ADVANCED_API_KEY）仅用于模拟充电桩，不提供给 Flutter 用户
- 所有文档中的参与者描述、权限表、流程描述按此映射修正

### 2026-05-29: 第24轮评估 — ChargerService 缺失 updateStatus、generateReport 权限偏差、前端缺失 FCL 及管理端报修方法

**冲突描述：** 跨图一致性检查发现：
1. (CRITICAL) ChargerService 接口在类图中缺少 updateStatus 方法（第23轮移除了该方法），但 sequence_repair_submit.puml 报修提交时序图调用了 CS.updateStatus(chargerId, FAULT)，时序图消息与类图接口不一致
2. (MAJOR) StatisticsController.generateReport 的 @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')") 允许管理员访问，但整体用例图 usecase_overall.puml 和 analytics.puml 中管理员(A)没有"生成统计报表"（GS/GR）连线
3. (MAJOR) 后端 StatisticsController 有 getFaultChargers() 端点且用例图中有"故障充电桩列表"(FCL)用例，但前端 ApiService 和 StatisticsProvider 均缺少对应方法
4. (MINOR) 后端 RepairController 定义了 assignRepair/resolveRepair/closeRepair/rejectRepair 方法，前端管理用例图中有 HR/DCR 操作，但前端 ApiService 缺少这些方法

**涉及文件：**
- class/src/backend_class_diagram.puml（ChargerService + generateReport 权限）
- class/src/frontend_class_diagram.puml（ApiService + StatisticsProvider 补充方法）
- class/img/backend_class_diagram.svg、class/img/frontend_class_diagram.svg

**相关模块：** class（类图）、time（时序图）、usecase/overview（用例图）

**用户决断：**
- ChargerService 接口及 ChargerServiceImpl 补充 updateStatus(chargerId, status) 方法
- generateReport 权限从 hasAnyRole('ADMIN', 'SUPER_ADMIN') 降级为 hasRole('SUPER_ADMIN')，对齐用例图——普通充电统计报表（A有UCS）与收入统计报表（仅SA有GS）分层设计，GS已明确为汇总性收入报表
- 前端 ApiService 补充 getFaultChargers()、assignRepair()、resolveRepair()、closeRepair()、rejectRepair() 方法
- 前端 StatisticsProvider 补充 faultChargers 字段及 fetchFaultChargers() 方法

---

### 2026-05-29: 第23轮评估 — overall/admin/frontend_admin 用例图缺少 DCR 连线、报修时序图缺审计日志

**冲突描述：** 跨图一致性检查发现：
1. usecase_overall.puml 完全没有"直接关闭报修"(DCR)用例及 A->DCR/SA->DCR 连线
2. admin_usecases.puml 和 frontend_admin_usecases.puml 中 SA 缺少 DCR 连线
3. sequence_repair_process.puml 中 assign（分配维修人员）和 resolve（维修完成）操作后缺少审计日志 INSERT
4. 后端类图 closeRepair 注解为 `hasAnyRole('ADMIN', 'SUPER_ADMIN')`，repair.puml 也有 SA->直接关闭报修

**涉及文件：**
- usecase/docs/overview/src/usecase_overall.puml
- usecase/docs/overview/src/admin_usecases.puml
- usecase/docs/frontend/src/frontend_admin_usecases.puml
- time/src/sequence_repair_process.puml

**相关模块：** usecase/overview, usecase/frontend, time

**用户决断：**
- usecase_overall.puml 新增 DCR 用例及 A->DCR、SA->DCR 连线
- admin_usecases.puml 和 frontend_admin_usecases.puml 补充 SA->DCR 连线
- sequence_repair_process.puml assign 后追加 audit_logs INSERT (action=assign_repair)
- sequence_repair_process.puml resolve 后追加 audit_logs INSERT (action=resolve_repair)

---

### 2026-05-29: 第22轮评估 — StatisticsController 与 StatisticsService 方法名不一致、analytics.puml 权限偏差

**冲突描述：** 跨图一致性检查发现：
1. StatisticsController 方法名 `getChargeStats`/`getUserChargeStats`/`getUtilizationStats` 与 StatisticsService 接口的 `generateReport`/`getUserChargingStats`/`getChargerUtilization` 不一致
2. StatisticsService 的 `getStationAnalysis()` 方法在 Controller 无对应端点
3. analytics.puml 中管理员(A)连接"生成统计报表"(GR)，但 admin_usecases.puml/usecase_overall.puml/frontend_admin_usecases.puml 中管理员无此权限

**涉及文件：**
- class/src/backend_class_diagram.puml（Controller 方法名对齐 + 新增 getStationAnalysis 端点）
- class/img/backend_class_diagram.svg
- class/src/frontend_class_diagram.puml（resetPassword 参数名对齐）
- class/img/frontend_class_diagram.svg
- usecase/docs/overview/src/analytics.puml（移除 A->GR 连线）
- usecase/docs/overview/img/analytics.svg

**相关模块：** class、usecase/overview

**用户决断：**
- Controller 方法名对齐 Service 接口名（generateReport/getUserChargingStats/getChargerUtilization）
- Controller 新增 getStationAnalysis() 端点映射 /analytics/stations
- analytics.puml 移除 A->GR，与后端权限注解和其他用例图一致
- ChargingController.forceStop 类图签名补充 @RequestBody req 参数
- 前端 ApiService.resetPassword 参数名从 captcha 改为 captchaId, captchaCode

---

### 2026-05-23: 架构与安全审计第二轮 — 类图权限注解、审计日志字段一致性、状态图恢复时机

**冲突描述：** 架构师和安全员分别对所有 32 个 .puml 文件进行全面评估，发现 9 个架构问题和 20 个安全问题（含 2 CRITICAL + 6 MAJOR + 7 MINOR + 5 INFO），涉及跨图一致性、权限模型遗漏、字段格式不统一。

**涉及文件：** 24 个文件（class/status/time/activity/usecase 五个模块）

**相关模块：** 全局

**用户决断：**
- PaymentController 补充 @PreAuthorize 注解 + 回调安全说明
- RepairController 补充 @PreAuthorize 注解（含 submit/list/resolve）
- 统一所有时序图 audit_logs INSERT 字段为 (actor_id, actor_type, action, resource, resource_id, payload)
- 充电桩状态图：FAULT → IDLE 明确为"报修审核通过（close）"并补充报修流程说明
- changeRole() 权限 from hasRole('ADMIN') → hasAnyRole('ADMIN', 'SUPER_ADMIN')
- 前端 ChargeRecordModel 补充 chargerCode + stationName 字段
- 活动图异常中断分支补充计费扣费逻辑
- 报修活动图移除 while 循环改为线性流程
- 统计用例图补充权限注释（收入统计仅限 SUPER_ADMIN）
- 部署图 Nginx 路由规则改为前缀匹配描述 + 双层安全隔离注释
- 注册时序图欠费提示改为注册成功后的可操作说明
- admin_usecases.puml 补充 SA → MU 连线
- 结束充电/强制结束/充电启动/报修提交时序图统一加入 Mock Scope 校验组

**冲突描述：** 评分标准 `doc/1.Java开发项目实训题目及评分标准.md` 规定 Swing+JDBC 编程占 40 分，要求使用 Java Swing 桌面客户端。但用户决定前端采用 Flutter/Dart 实现。

**涉及文件：**
- class/src/class_diagram.puml → 拆分为后端类图 + 前端类图 + 总览三份文件
- time/src/sequence_charging.puml, sequence_stop_charge.puml
- time/src/ 下新增 5 个时序图（登录、注册、报修提交、报修处理、充值）
- usecase/docs/frontend/README.md
- usecase/docs/containerd/src/deployment_overview.puml
- usecase/docs/containerd/README.md
- usecase/docs/backend/README.md
- README.md、CLAUDE.md

**相关模块：** 全局 — class（类图）、time（时序图）、usecase/frontend（前端用例）、usecase/containerd（部署架构）

**用户决断：** 前端采用 Flutter/Dart。评分标准原文（Swing+JDBC 评分项）保持不动，UML 文档中的前端部分更新为 Flutter。类图拆分为前端 Flutter 模型与后端 Spring Boot 实体两个独立文件加一个总览图。

---

### 2026-06-07: 第33轮 — 权限系统重设计 + 三层权限模型

**冲突描述：** 现有权限系统为单层 RBAC（4 角色：USER/MAINTAINER/ADMIN/SUPER_ADMIN），不符合以下新需求：
1. Mock Swing 充电桩需要权限细分：普通权限(充电桩验证+spring通讯) vs 高级权限(密钥+测试环境+可见所有+中间件交互)
2. 权限系统整体重设计：充电流程需余额校验(≥10元) → Spring通知充电桩 → 桩确认后开通充电
3. 结束充电三种场景：余额不够/用户主动断开/桩异常无通讯
4. scope claim (mock_charger_only) 代码中存在但未生效

**涉及文件：**
- 全局 — SecurityConfig、JwtAuthenticationFilter、JwtTokenProvider、ChargeGuard
- usecase/docs/backend/README.md、charging-flow.md
- usecase/docs/backend/所有类图 .puml
- code/charging-station-mock-ser-client 所有源文件
- doc/测试方案与结果记录.md

**相关模块：** 全局 — 后端安全、前端路由、Mock客户端、文档

**用户决断：**
- 三层权限模型：
  1. **普通权限** (Normal): USER/MAINTAINER → 仅操作自己的充电桩（余额≥10启动→通知桩→开通），JWT scope=user
  2. **管理权限** (Admin): ADMIN/SUPER_ADMIN → 全部可见/管理，JWT scope=admin
  3. **高级权限** (Advanced): 测试专用 → 密钥(ADVANCED_API_KEY)验证，可见所有充电桩+中间件交互，仅测试环境开放，JWT scope=advanced
- 充电流程：Flutter → POST /charges/start(chargerId) → Spring校验余额≥10元 → ChargerConnector通知Mock桩 → 桩ACK → Spring标记CHARGING
- 结束充电：余额不足(自动停+冻结) / 用户主动(Flutter发stop) / 桩心跳超时(Spring强制停)
- 新增 AdvancedApiKeyFilter 支持密钥认证
- 新增 ChargerConnector 接口(HTTP polling先，后续升级WebSocket)

**冲突描述：** 全量文档审查发现以下不一致：
1. (MAJOR) frontend/README.md、containerd/README.md、overview/usecases.md 中 Mock 充电机描述仍沿用"直接调用 start/stop API"，与实际代码（QR 生成 + 轮询同步）不一致
2. (MINOR) backend/README.md 基础信息管理表使用"CRUD"聚合描述，缺少 5 个细分端点（`GET /stations/{id}`、`GET /chargers/{id}`、`GET /stations/search`、`GET /chargers/by-code/{code}`、`GET /analytics/stations`）及 `POST /payments/pay-arrears`
3. (MINOR) charging-flow.md 缺少 frozen_until 冻结检查、定价策略描述、Mock+Flutter QR 交互说明
4. (MINOR) 测试方案 doc/测试方案与结果记录.md 版本号仍为 v1.0，应升级至 v1.2

**涉及文件：**
- usecase/docs/frontend/README.md
- usecase/docs/containerd/README.md
- usecase/docs/overview/usecases.md
- usecase/docs/backend/README.md
- usecase/docs/backend/charging-flow.md
- doc/测试方案与结果记录.md

**相关模块：** 后端、前端、部署、总体用例

**用户决断：**
- 所有 Mock 充电机描述统一为：插枪→生成二维码→Flutter扫码启动充电→Mock轮询同步状态→Flutter停止充电→Mock显示结果。明确标注"不直接调用 start/stop API"
- backend/README.md 基础信息管理表补全 7 个细分端点 + pay-arrears + analytics/stations
- charging-flow.md 补充 frozen_until 检查、快慢充差异化定价、Mock+Flutter QR 交互段落
- 测试方案文档版本号升级至 v1.2