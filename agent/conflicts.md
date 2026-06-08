# 冲突记录与决断

本文件记录 UML 文档设计过程中出现的需求冲突与用户最终决断。已解决条目保留摘要，完整记录可在 git history 中查阅。

---

### 2026-06-08: 第35轮 — 代码-文档对齐 P0-P2 全部完成

**涉及差异：** 18 项审计差异中修复 15 项（A1-A6, C, F, I, J, K, N, O, P, T），3 项标记技术债务（E-15kWh硬编码, G-ChargeSimulator定价, H-Mock反序列化）

**完成项：** Entity在线字段、遥测端点、离线Scheduler、在线校验、Mock真实心跳、Connector升级、init.sql CHECK修复、JWT scope、文档同步(password_history/2 VIEW/captcha/suggest/AdvancedApiKeyFilter)

---

### 2026-06-07: 第34轮 — Swing=模拟充电桩(高权限) Flutter=用户端

**决断：** Mock充电机(Swing)是模拟的真实充电桩设备，需要高权限与Spring通讯；Flutter是用户端(普通用户/管理员/维修人员)。高级权限(ADVANCED_API_KEY)仅用于模拟充电桩。统一三层权限：Normal(USER/MAINTAINER scope=user)、Admin(ADMIN/SUPER_ADMIN scope=admin)、Advanced(ADVANCED_API_KEY scope=advanced)

---

### 2026-05-29: 第24轮评估 — ChargerService/StatisticsController/前端API方法缺失

**决断：** ChargerService补充updateStatus()、generateReport权限从ADMIN降级为SUPER_ADMIN、前端补充getFaultChargers/assignRepair/resolveRepair/closeRepair/rejectRepair

---

### 2026-05-29: 第23轮评估 — DCR用例缺失/报修时序缺审计日志

**决断：** usecase_overall/admin/frontend_admin 补充DCR连线，报修时序assign/resolve后追加审计日志

---

### 2026-05-29: 第22轮评估 — Controller/Service方法名不一致

**决断：** Controller方法名对齐Service(getChargeStats→generateReport等)、analytics.puml移除A→GR

---

### 2026-05-23: 安全审计 — Mock客户端安全约束与文档修复

**决断：** MockClient增加安全字段、移除->ChargerMapper直连(仅通过Controller)、@PreAuthorize统一、repairs表加reject_reason

---

### 2026-05-23: Swing+JDBC评分项 → Flutter实现转换

**决断：** 评分标准(Swing+JDBC 40分)保持不动，UML文档前端部分统一使用Flutter。类图拆为后端+前端+总览三文件

---

### 2026-05-23: 新增Mock充电机客户端(Swing)概念

**决断：** 新增Mock充电机actor(关联启动/结束/查询充电)、后端类图新增MockChargerClient/ChargerUIPanel/ChargeSimulator、部署图前端层新增Mock组件