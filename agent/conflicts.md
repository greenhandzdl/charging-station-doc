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