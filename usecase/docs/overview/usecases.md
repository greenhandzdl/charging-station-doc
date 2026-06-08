# 用例总览

## 参与者

| 参与者 | 客户端 | 说明 | 权限等级 |
|--------|--------|------|----------|
| 未授权用户 | Flutter | 未登录访客，可注册（选择身份）和登录 | 无需认证 |
| 用户 | Flutter | 电动车车主，注册后获得基础权限，可发起充电、充值、查看个人记录、提交报修 | 基础 |
| 维修人员 | Flutter | 由管理员从用户提升获得维修权限，拥有用户全部功能，并可处理报修单 | 基础+ |
| 管理员 | Flutter | 维护充电站与充电桩信息，管理报修单与用户权限 | 中级 |
| 最高管理者 | Flutter | 具有全部管理权限，可提升用户权限、查看全局统计 | 最高 |
| 模拟充电桩（普通模式） | **Swing 桌面客户端** | 模拟物理充电机面板交互（插枪、拔枪）。使用专用测试账户 `mock_user/mock123` 登录，JWT scope=user，仅可见自己的测试充电桩。选择充电桩后自动生成含充电桩 ID 的二维码供 Flutter App 扫码启动充电，后台轮询充电状态（每 30 秒心跳），ChargeSimulator 模拟电量增长（0.1 kWh/秒）。内置断网/服务器重启/桩离线三种测试场景按钮。**不直接调用充电启停 API**。**注：模拟充电桩不是"用户端"，而是模拟的真实充电桩设备，需要比普通用户更高的权限与 Spring 中间件通讯、获取所有充电桩的信息** | **高（桩专用）** |
| 模拟充电桩（高级模式） | **Swing 桌面客户端** | 使用 `ADVANCED_API_KEY` 环境变量密钥认证。可见所有充电桩及与 Spring 中间件交互权限，UI 显示[高级模式]标记。**仅测试环境开放**。**注：高级权限仅用于模拟充电桩，不提供给 Flutter 用户** | **最高（桩专用）** |
| 支付网关 | — | 处理充值与扣费回调（可用模拟器） | 外部系统 |
| 系统 | — | 后台统计、报表导出、定时任务、自动扣费等 | 系统级 |

**权限说明：** Flutter 是用户端（普通用户/管理员/维修人员的操作界面），Swing 是模拟充电桩端（模拟物理充电机设备）。注册获得基础用户权限；权限提升仅由管理员及以上角色操作，可提升用户为维修人员或降级（降级由管理员在后台操作，系统不提供自助降级）。最高管理者拥有系统全部功能访问权。

**权限层级模型：** 系统采用三层权限模型 — 普通权限（Normal：USER/MAINTAINER，scope=user，Flutter 用户端，仅操作自己的充电桩）、管理权限（Admin：ADMIN/SUPER_ADMIN，scope=admin，Flutter 管理端，全部可见/管理）、高级权限（Advanced：桩专用，需 `ADVANCED_API_KEY` 密钥，Swing 模拟充电桩用，可见所有充电桩及中间件交互，仅测试环境开放）。

> **✅ 实现状态：** AdvancedApiKeyFilter 已实现，通过请求头 `X-Advanced-Api-Key` 传递密钥，授予 `ROLE_SUPER_ADMIN` + `SCOPE_advanced`。模拟充电桩支持普通模式（mock_user/mock123，scope=user）和高级模式（ADVANCED_API_KEY 密钥认证）。但 JWT scope claim（`mock_charger_only`）在 SecurityConfig 中尚未生效。

## 核心用例

- 用户注册 / 登录
- 账户充值（支付）
- 启动充电 / 结束充电并结算
- 查询充电与账单记录
- 故障报修与处理（含 CLAIM_REPAIR 维修人员接单）
- 管理充电站/充电桩
- 用户权限管理
- 生成统计报表
- 充电记录快捷视图
- 充电桩状态快捷查询

## 充电启动前置条件

充电启动必须同时满足以下四个条件：

1. **充电桩插入**：用户在 Mock 充电桩上选择充电桩并插枪，生成含充电桩 ID 的二维码
2. **客户端点击充电**：Flutter 扫码二维码后点击"启动充电"
3. **余额满足**：Spring 校验当前用户余额 >= 10 元
4. **充电桩在线**：充电桩通过定期遥测（heartbeat）向 Spring 上报在线状态，超过 60 秒未收到遥测则标记离线，离线桩不允许启动充电

## 充电桩在线检测机制

- Mock 充电桩每 30 秒发送遥测数据（heartbeat）到 Spring
- Spring 记录最后一次遥测时间（`chargers.last_heartbeat_at`）
- 超过 60 秒未收到遥测，标记充电桩为离线（OFFLINE）
- 离线充电桩不允许启动充电
- 正在充电的桩失去通讯超过 60 秒，Spring 强制停止充电

## 总体用例图

![总体用例](img/usecase_overall.svg)

### 用户用例

![用户用例](img/user_usecases.svg)

### 管理端用例

![管理端用例](img/admin_usecases.svg)

### 视图与便捷功能

![视图与便捷功能](img/view_features.svg)

### 系统与外部交互用例

![系统与外部交互用例](img/external_usecases.svg)

## 各模块说明

| 模块 | 路径 | 内容 |
|------|------|------|
| 后端 | [backend/](../backend/README.md) | 基础信息管理、充电流程、账户支付、故障报修 |
| 前端 | [frontend/](../frontend/README.md) | 前端用例与交互契约 |
| 部署 | [containerd/](../containerd/README.md) | 容器化与部署用例、部署架构 |
| 数据库 | [database/](../database/db.md) | 数据库表结构、后端-数据库交互用例 |
| 视图便捷 | [view-features](view-features.md) | 充电记录快捷视图、充电桩状态快捷查询 |
| 类图 | [class](../../../class/README.md) | 系统核心类及其关系 |
| 时序图 | [time](../../../time/README.md) | 启动充电、结束扣费、登录、注册、报修、充值、强制结束充电对象交互 |
| 状态图 | [status](../../../status/README.md) | 充电桩状态流转 |
| 活动图 | [activity](../../../activity/README.md) | 故障报修全流程 |

## 相关文档

- [统计与可视化](analytics.md) — 统计报表与导出用例
- [视图与便捷功能](view-features.md) — 充电记录快捷视图与桩状态快捷查询
- [类图](../../../class/README.md) — 系统核心类设计
- [时序图](../../../time/README.md) — 充电业务流程对象交互
- [状态图](../../../status/README.md) — 充电桩状态流转
- [活动图](../../../activity/README.md) — 故障报修处理流程
- [后端 API 与权限映射](../backend/README.md) — API 定义、权限控制、安全措施
- [前端用例](../frontend/README.md) — 前端界面与交互契约
- [数据库设计](../database/db.md) — 数据库表结构
- [数据库用例](../database/README.md) — 后端与数据库交互场景
- [容器化与部署](../containerd/README.md) — 容器化与部署用例、架构

## 未完成项

1. **> ⚠️ 未实现** JWT scope claim（mock_charger_only）已定义但未在 SecurityConfig 中生效
2. **> ⚠️ 未实现** HMAC-SHA256 签名验证未完整实现（PaymentChannel 始终返回 true）
3. **> ✅ 已实现** 高级密钥认证（Advanced API Key）已实现，通过请求头 `X-Advanced-Api-Key` 传递密钥，授予 `ROLE_SUPER_ADMIN` + `SCOPE_advanced`
4. **> ⚠️ 未实现** 充电桩通讯中间件（ChargerConnector）尚未实现
5. **> ⚠️ 未实现** 充电桩遥测/心跳检测（last_heartbeat_at + online_status）尚未实现

## 安全要点

- **认证与授权：** 用户注册后获得基础用户权限，管理员及以上角色可对用户权限进行变更。所有管理接口仅限管理员/最高管理者访问。
- **密码安全：** 密码使用 bcrypt/Argon2 加盐散列存储，禁止明文存储与传输。
- **输入校验：** 服务端对所有外部输入进行严格校验，防止注入与异常数据。
- **支付安全：** 不保存敏感支付信息；使用回调签名验证支付结果并设计幂等处理。
- **审计日志：** 关键操作（充值、扣费、报修处理、权限变更）记录审计日志，保存操作人、操作类型、资源与时间戳。
- **会话管理：** 短期凭证（JWT/HttpOnly Cookie），Token 失效机制防重放。