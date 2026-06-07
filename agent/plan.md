# 多Agent并行开发与测试流水线计划

## Context

四个代码仓库已创建（仅 .gitignore + LICENSE），需从 UML 文档生成完整代码。要求多 Agent 并行开发，代码审查合并，测试驱动修复，架构师统一裁决文档矛盾。

## 架构概览

```
Phase 0: compose (pg14 + .env)
   │
Phase 1: 并行开发 ──── backend ──── client ──── mock-client
   │
Phase 2: Reviewer 审查 + 合并到 main
   │
Phase 3: Test Agent 写测试 → 运行 → 失败 → 对应 dev agent 修复 → 循环
   │
Phase 4: 文档矛盾 → Architect 修复文档 → 通知 dev 同步
```

## 执行步骤

### Phase 0 — compose 先行

写入文件: docker-compose.yml, .env, .env.example, .gitignore, init/init.sql, README.md

### Phase 1 — 并行开发

三个 dev agent 并行在各自 repo 上工作，各自完成后提交到各自 main：

- **Agent A — Backend (Spring Boot)**: pom.xml, 实体, 枚举, Mapper, Service(接口+Impl), Controller, Security(JWT), DTO, 设计模式(Strategy/Factory)
- **Agent B — Flutter Client**: pubspec.yaml, models, ApiService, AuthProvider, 用户界面, 管理界面
- **Agent C — Mock Swing Client**: pom.xml, MockChargerClient(JFrame), ChargerUIPanel, ChargeSimulator, QrCodeGenerator, ApiClient

### Phase 2 — 代码审查合并 ✅

Reviewer Agent 逐个 repo 审查:
- Backend: PASS (1 MAJOR — UML 注解已修复)
- Flutter: FAIL → 修复 2 CRITICAL bug → flutter analyze 通过 ✅
- Mock Swing: PASS
- UML 文档: @PreAuthorize 注解不匹配 → 修 puml → 渲染 SVG → 提交 ✅

### Phase 3 — 测试循环 ✅

Test Agent 顺序跑各 repo: 编译/测试 → 失败 → dev agent 修复 → 循环直到全通过。

**Backend**: 49 tests 全部通过
**Flutter**: `flutter analyze` 无问题
**Mock Swing**: `mvn package` 编译成功，JAR 可运行

---

## 第24轮 — UI优化 + Flutter登录修复 + CaptchaController + 文档一致性

### 本轮问题

| # | 问题 | 仓库 | 根因 | 严重度 |
|---|------|------|------|:------:|
| 1 | 拔枪后二维码消失 | Mock | `resetToIdle()` 清空了 `currentChargerId` 和 QR | HIGH |
| 2 | 测试场景按钮太小 | Mock | 字体仅12px，按钮初始状态几乎不可见 | HIGH |
| 3 | 菜单栏和主界面重复 | Mock | File/操作/测试场景菜单与面板按钮功能完全重复 | MEDIUM |
| 4 | Flutter注册/登录失败 | Flutter + Backend | 后端缺少CaptchaController，`/api/v1/captcha/**` 不存在 | CRITICAL |
| 5 | 注册强制验证码必败 | Flutter | `RegisterRequest` 中 `captchaId/@NotBlank`，但获取验证码失败后继续提交 | CRITICAL |
| 6 | Mock文档描述过时 | Doc | `frontend/README.md` 仍提进度条/轮询/ChargeSimulator | MEDIUM |
| 7 | Mock角色描述过时 | Doc | `usecases.md` Mock行未更新为当前架构 | LOW |

---

### 执行计划

#### Step 1 🔄 架构师文档同步

| 文件 | 变更内容 |
|------|---------|
| `frontend/README.md` | 移除进度条/ChargeSimulator/轮询同步旧描述，更新为仅插枪/拔枪+自动QR+测试场景按钮 |
| `overview/usecases.md` | Mock角色描述更新：Swing客户端仅模拟面板交互，不轮询、不模拟电量 |

#### Step 2 🔄 架构师 + 安全师联合评估

评估本轮变更的安全影响与架构一致性。

#### Step 3 🔄 并行子Agent实现（3路并行）

**Agent A — Backend：添加 CaptchaController**
- 新增 `CaptchaController.java` — `GET /api/v1/captcha` 生成4位验证码，Redis存储，返回 captchaId+captchaCode
- MVP方案：文本验证码（非图片），TTL 5分钟
- `RegisterRequest.java`: captchaId/captchaCode 改为非必须（`@NotBlank` → 去掉）

**Agent B — Flutter：登录注册容错**
- `register_screen.dart`: 当 `_loadCaptcha()` 失败时，跳过验证码提交
- **注意**: 这个修改和后端CaptchaController是互补关系 — 即使后端有验证码，Flutter也要处理好网络异常

**Agent C — Mock UI 优化**
- `resetToIdle()`: 保留QR不清除（仅重置plugged状态和按钮状态）
- 移除 `initMenuBar()` 及相关所有菜单项
- 测试场景按钮: 字体12px→14px，按钮设最小尺寸120×35，面板整体优化布局

#### Step 4 🔄 全仓库测试验证

| 检查项 | 预期 |
|--------|:----:|
| Mock `mvn test` | 60/60 ✅ |
| Mock `mvn package -DskipTests` | BUILD SUCCESS ✅ |
| Flutter `flutter test` | 25/25 ✅ |
| Flutter `flutter analyze` | 0 errors ✅ |
| Backend `mvn test` | 通过 ✅ |
| Backend `mvn compile` | BUILD SUCCESS ✅ |
| Doc 提交 | plan.md 更新 |

### 依赖关系

```
T0: 架构师同步文档 + 评估
  │
  ├── T1a: Agent C — Mock UI (独立)
  ├── T1b: Agent A — CaptchaController (独立)
  │
  └── T2: Agent B — Flutter修复 (依赖T1b完成，需要后端验证码可用)
       │
       └── T3: 全仓库测试
```

---

## 第24轮 — UI优化 + Flutter登录修复 + CaptchaController + 文档一致性

### 本轮问题与修复

| # | 问题 | 仓库 | 解决方案 |
|---|------|------|---------|
| 1 | 拔枪后二维码消失 | Mock | `resetToIdle()` 保留 `currentChargerId` 和 QR |
| 2 | 测试场景按钮太小 | Mock | 字体 12px→14px，最小尺寸 140×38（BOLD） |
| 3 | 菜单栏和面板重复 | Mock | 删除整个 `initMenuBar()` |
| 4 | `/api/v1/captcha` 不存在 | Backend | 新增 `CaptchaController.java` |
| 5 | 注册强制验证码必败 | Backend+Flutter | `RegisterRequest` 移除 `@NotBlank` |
| 6 | Mock文档描述过时 | Doc | 3个README同步更新 |

### 完整验证结果

| 检查项 | 结果 |
|--------|:----:|
| Flutter `flutter analyze` | ✅ 0 errors |
| Flutter `flutter test` | ✅ 25/25 |
| Backend CaptchaController | ✅ 3 files, 65+ lines |
| Mock resetToIdle QR保留 | ✅ |
| Mock 菜单栏删除 | ✅ -71 lines |

### 各仓库提交

| 仓库 | 最新提交 | 说明 |
|------|---------|------|
| backend | `e06186f` | fix: CaptchaController + RegisterRequest验证码可选 |
| backend | `5a6b1f9` | fix: refreshToken返回User信息 + Jackson日期配置 |
| client | `6b1c447` | fix: 注册页验证码容错 |
| client | `53a1208` | fix: Flutter API参数全面修复 |
| mock | `e2e5bd5` | fix: Mock UI优化 — QR保留+删除菜单栏+测试按钮放大 |
| doc | `ead14b1` | fix: 第24轮 — 全仓库变更 + 文档同步 |
| backend | `a1a40f8` | feat: 集成SpringDoc OpenAPI (Swagger) — 三组安全分组 |
| doc | `991944e` | fix: 集成Swagger + 子模块指针同步 |
| doc | `ca76a32` | docs: 架构师文档更新 — Swagger文档同步 + Mock描述修正 |

> **Flutter API参数修复详情**（`53a1208`）：
> - CRITICAL: `_handleResponse` 错误解析 — 后端 `{"error":{"message":"xxx"}}` 是嵌套Map，Flutter `as String?` 强制失败导致所有错误显示"请求失败(xxx)"
> - HIGH: `refreshToken` 后端返回不带 `user` 字段 → `_currentUser` 被覆盖为空 → `isLoggedIn` 触发登出
> - HIGH: `ChargeResponse.recordId` 但 `ChargeRecordModel.fromJson` 读 `id` → 充电后找不到记录ID
> - HIGH: `tryAutoLogin` 中 `_initPrefs()` 异步竞态
>
> **Backend参数修复详情**（`5a6b1f9`）：
> - `refreshToken` 返回值中查询并填充 `user` 字段
> - `application.yml` 添加 Jackson 日期格式配置：`yyyy-MM-dd HH:mm:ss`、`Asia/Shanghai`、禁止时间戳数组
>
> **Swagger集成详情**（`a1a40f8`）：
> - pom.xml 添加 springdoc-openapi-starter-webmvc-ui 2.6.0
> - SwaggerConfig.java: 三组 GroupedOpenApi（公开/认证/管理）+ Bearer JWT 安全方案
> - Swagger UI: http://localhost:8080/swagger-ui/index.html
>
> **架构师文档更新**（`ca76a32`）：
> - backend/README.md 新增「API文档(Swagger)」章节
> - Mock描述修正：删除轮询/ChargeSimulator/进度条旧描述

---

## 第25轮 — 多Agent并行: Flutter修复 + Swagger简化 + 配置外部化 + 架构审查

### 本轮问题

| # | 问题 | 仓库 | 根因 | 严重度 |
|---|------|------|------|:------:|
| 1 | Flutter安卓编译失败 | Client | Gradle 9.1.0未完全下载(网络隔离), AGP 9.0.1与缓存Gradle 8.3/8.10不兼容 | CRITICAL |
| 2 | Flutter网页端空白页面 | Client | 后台不可达时AuthGate无限等待无反馈; CORS已配但无错误UI | HIGH |
| 3 | Swagger JWT验证过于复杂 | Backend | 三组安全分组+JWT方案对课程项目过度设计 | MEDIUM |
| 4 | 后端配置散落硬编码 | Backend | JWT密钥/数据库URL/支付密钥硬编码在application.yml | MEDIUM |
| 5 | 文档-代码不一致 | Doc | 密码强度规则、密码历史检查描述与实际不符 | MEDIUM |

### 执行方案

#### Phase 1 — 并行Agent修复（4路并行）

| Agent | 任务 | 仓库 |
|-------|------|------|
| Agent A | Gradle降级: 9.1.0→8.10.2(已缓存), AGP 9.0.1→8.7.3, Kotlin 2.3.20→2.0.21 | Client/Android |
| Agent B | AuthGate添加"无法连接服务器"错误界面; CORS确认已配无无需变更 | Client+Backend |
| Agent C | Swagger简化: @Profile("dev")控制, 移除JWT安全方案, 添加context-path=/api | Backend |
| Agent D | 配置外部化: 创建config/目录, application-dev.yml/prod.yml, .env.example | Backend |

#### Phase 2 — 测试验证

| 检查项 | 结果 |
|--------|:----:|
| Flutter `flutter analyze` | ✅ 0 error, 6 info (deprecation/style) |
| Flutter `flutter build web --release` | ✅ BUILD SUCCESS (3MB main.dart.js) |
| `gradle-wrapper.properties` | ✅ 8.10.2-all (已缓存无需下载) |
| Swagger仅在dev profile启用 | ✅ @Profile("dev") |
| 配置外部化结构 | ✅ application.yml(公共)+config/目录(环境覆盖) |

#### Phase 3 — 架构师全面审查

由 tech-architect-coordinator 对全部6大模块评分：

| 模块 | 状态 | 评分 |
|------|:----:|:----:|
| 基础信息管理 | ✅ COMPLETE | 完整 |
| 充电业务与记录 | ✅ COMPLETE | 完整 |
| 支付与故障报修 | ✅ COMPLETE | 完整 |
| 数据统计与可视化 | ✅ COMPLETE | 完整 |
| 视图与便捷功能 | ⚠️ PARTIAL | 缺少数据库VIEW、无自动补全搜索 |
| 简易交互与扩展 | ✅ COMPLETE | 完整 |

**综合评分: 85/100 (良好, 80-89分段)**

发现的问题：
1. 🔴 密码强度规则: 文档要求大+小+数字+特殊字符选3类，代码只校验字母+数字
2. 🔴 密码历史检查: 文档要求禁止使用最近3次密码，代码未实现
3. 🟡 Mock心跳检测: 文档提30秒心跳，代码未实现

### 各仓库提交

| 仓库 | 提交 | 说明 |
|------|------|------|
| backend | `5eace7d` | refactor: Swagger简化+配置外部化(5 files) |
| backend | `ef61b49` | fix: 回调URL路径对齐context-path /api |
| client | `4c7f144` | fix: Android Gradle降级+Web空白页修复(3 files) |

### 待办

1. 统一密码强度规则（文档&代码对齐）
2. 实现密码历史存储（最近3次密码哈希）
3. Mock添加定时心跳检测
4. 视图与便捷功能: 数据库VIEW + 搜索自动补全
---

## 第26轮 — 网络恢复后修复: seed.sql密码哈希 + Web加载UI + 文档对齐

### 本次问题

| # | 问题 | 仓库 | 根因 | 严重度 |
|---|------|------|------|:------:|
| 1 | Flutter网页端登录页面空白 | Client | web/index.html 无加载/错误兜底 UI；CanvasKit 加载失败时静默白屏 | HIGH |
| 2 | 测试账号密码登录失败 | Compose | seed.sql 中5个用户共用同一 bcrypt 哈希，实测只匹配 `mock123` | CRITICAL |
| 3 | 测试方案文档账号不准确 | Doc | SUPER_ADMIN 手机号写 `super123`、mock_user 手机号写 `13800138004` | MEDIUM |

### 修复方案

| 文件 | 变更 | 说明 |
|------|------|------|
| `code/charging-station-client/web/index.html` | 重写 | 添加加载动画、30秒超时兜底、错误详情展示+刷新按钮、全局onerror捕获 |
| `code/charging-station-client/lib/main.dart` | 增强 | 添加 `_ErrorBoundary` Widget，捕获Flutter框架运行时错误并展示错误UI |
| `code/charging-station-compose/init/seed.sql` | 修复 | 替换为各密码独立生成的 bcrypt 哈希 |
| `doc/测试方案与结果记录.md` | 修复 | 修正SUPER_ADMIN/mock_user账号列 |

### 验证结果

| 检查项 | 结果 |
|--------|:----:|
| `flutter analyze` | ✅ 0 error, 6 info |
| `flutter test` | ✅ 25/25 all passed |
| `flutter build web --release` | ✅ BUILD SUCCESS |
| `flutter build apk --debug` | ✅ BUILD SUCCESS (40.6s, AGP已缓存) |
| bcrypt哈希验证（5个账号） | ✅ 全部匹配 |
| 文档-种子数据一致性 | ✅ 账号/密码/哈希完全对齐 |

---

## 第27轮 — dwds 26.2.5 序列化 Bug 修复 + 图形环境修复

### 本次问题

| # | 问题 | 根因 | 严重度 |
|---|------|------|:------:|
| 1 | `flutter run -d chrome` debug模式白屏崩溃 | dwds 26.2.5 的 `main__closure5.call$2` 中 `A._asString(eventData)` 强制断言字符串类型，但 Chrome CDP 发送的 `eventData` 是 JSON 对象 (`_JsonMap`)，导致 `BuiltJsonSerializers.deserialize` 抛出未捕获异常，Flutter 框架初始化中断 | CRITICAL |

### 修复方案

#### 修改 dwds 源码（系统级补丁）

**文件:** `~/.pub-cache/hosted/pub.dev/dwds-26.2.5/lib/src/injected/client.js`

**变更（第26849行前插入）：**
```javascript
// Patch: Chrome DevTools Protocol sometimes sends eventData as a JSON
// object (e.g. Debugger.scriptParsed params) instead of a String.
// JSON.stringify handles both cases safely.
if (typeof eventData !== "string") eventData = JSON.stringify(eventData);
```

**原理：** `main__closure5` 是 dwds 调试服务器注入到页面的事件转发闭包，`A._asString()` 是 Dart 编译为 JS 后的类型断言。Chrome DevTools Protocol 的 `Debugger.scriptParsed` 等事件通知中，`params`（eventData 字段）是一个 JSON 对象而非字符串。在调用 `_asString` 之前用 `JSON.stringify` 序列化，确保类型断言通过。

#### 图形环境修复

~/.config/fish/config.fish 和 ~/.bashrc 添加 DISPLAY/XAUTHORITY 自动检测。

### 验证结果

| 模式 | 命令 | 状态 |
|------|------|:----:|
| Chrome + DDS（原崩溃模式） | `flutter run -d chrome` | ✅ 正常启动 |
| Web Server + DDS | `flutter run -d web-server` | ✅ 200, 4个"充电" |
| Release | `flutter build web --release` | ✅ 已验证 |

### 补丁持久化说明

由于 dwds 缓存在 `~/.pub-cache/`，升级 Flutter SDK 后需重新打补丁。
`scripts/dev_web.sh` 中的 `--no-dds` 方案作为备用，在新版本出现同样问题时使用。

---

## 第28轮 — 文档同步 + 架构评估

### 本轮任务

| # | 任务 | 负责人 | 说明 |
|---|------|--------|------|
| 1 | Flutter权限路由 + MAINTAINER支持 | Agent A | UserRole枚举、集中式权限、MAINTAINER维修工作台 |
| 2 | Spring配置验证 | Agent B | 确认配置外部化、Swagger dev-only |
| 3 | 文档同步 + 架构评估 | Agent C | 全面review文档一致性、创建架构评估报告 |
| 4-6 | 代码审查 + 测试验证 + 最终提交 | 各Agent | 全仓库测试 → 修复 → 提交 |

### 本轮发现的问题

| # | 问题 | 仓库 | 严重度 |
|---|------|------|:------:|
| 1 | Flutter MAINTAINER角色无独立页面 | Client | MEDIUM |
| 2 | Flutter无UserRole枚举，路由散落 | Client | MEDIUM |
| 3 | 密码强度未满足文档要求 | Doc+Backend | MEDIUM |
| 4 | 密码历史检查未实现 | Doc+Backend | MEDIUM |
| 5 | 数据库VIEW未创建 | Doc | LOW |
| 6 | 搜索无自动补全 | Doc+Backend+Client | LOW |
| 7 | Mock无30秒心跳 | Doc+Mock | LOW |

### 文档更新

| 文件 | 变更 |
|------|------|
| `doc/测试方案与结果记录.md` | 版本v1.0→v1.3，日期2026-06-05，新增"未实现功能"章节 |
| `agent/architecture-assessment.md` | 新建，评分80/100，含差距分析 + 改进建议 |
| `agent/plan.md` | 追加第28轮摘要 |

### 架构评分

| 维度 | 分数 |
|------|:----:|
| 面向对象设计 | 32/40 |
| Swing/JDBC (Flutter替代) | 32/40 |
| 完整性与规范性 | 16/20 |
| **总分** | **80/100** |

### 差距总结

- **已实现**：六大模块全覆盖，前后端CRUD完整，充电业务/支付/报修/统计流程通顺
- **缺失项**：密码强度&历史、数据库VIEW、搜索自动补全、Mock心跳、Flutter MAINTAINER独立页面
- **文档过时**：`1.评分标准.md` 描述部分功能（密码强度、历史检查）与实际代码不匹配

---

## 第29轮 — 全量API测试 + 业务流验证 + Bug修复 + 文档同步

### 本轮工作

| 阶段 | 内容 | 结果 |
|------|------|:----:|
| 后端编译启动 | Docker Maven编译打包，配置修复（删除 context-path） | ✅ |
| API端到端测试 | 36个API端点逐模块验证 | ✅ 36/36 PASS |
| 完整业务流程 | 注册→充值→启动→停止→扣费→欠费→补缴→解冻→RBAC | ✅ 22/22 PASS |
| Flutter/Swing兼容性 | 全部ApiService端点和响应格式校验 | ✅ 无兼容性问题 |

### Bug修复

| # | 问题 | 严重度 | 修复 |
|---|------|:------:|------|
| 1 | `context-path: /api` 与 Controller `@RequestMapping("/api/v1")` 冲突，URL实际变为 `/api/api/v1/...` | **HIGH** | 删除 `application.yml` 中 `server.servlet.context-path` |
| 2 | `audit_logs` 的 action CHECK 约束缺少 `PAY_ARREARS`，欠费支付时500 | **HIGH** | DDL新增 `PAY_ARREARS` + 数据库同步约束 |
| 3 | `PaymentServiceImpl` 写入 audit_logs 使用小写 `pay_arrears`（违反枚举约定） | **MEDIUM** | 改为 `PAY_ARREARS` |
| 4 | `payment.callback-url` 路径 `/api/payments/callback` 错误（应为 `/api/v1/payments/callback`） | **MEDIUM** | 修复为正确的完整路径 |

### 提交记录

| 仓库 | 提交 |
|------|------|
| **backend** | `3b4c1c4` fix: 移除重复的 context-path（+ 回调URL修复） |
| **compose** | `init.sql` audit_logs CHECK 增加 PAY_ARREARS |
| **backend** | `PaymentServiceImpl.java` action 改为 PAY_ARREARS |
| **client** | `faa6105` feat: 权限路由重构 |
| **doc** | `b5351e6` docs: 第28轮提交 |
| **doc** | (本轮) 测试方案v1.4 + plan.md第29轮 |

---

## 第30轮 — 充值审批流 + 通用扫码 + Mock适配

### 需求

| # | 需求 | 说明 |
|---|------|------|
| 1 | 充值审批流 | 用户提交→PENDING→管理员审核→模拟回调→加余额 |
| 2 | 通用扫码 | Flutter摄像头扫码→解析二维码→操作选择（充电/报修/查信息） |
| 3 | Mock QR升级 | 二维码格式升级，含完整信息（stationName/chargerCode/type） |

### 架构师文档更新（Phase 0）

| 文件 | 变更 |
|------|------|
| `status/src/state_payment.puml` | 状态图增加 APPROVED 状态：PENDING→APPROVED→SUCCESS/FAILED |
| `time/src/sequence_recharge.puml` | 时序图增加管理员审批环节 + 模拟回调处理 |
| `usecase/docs/backend/README.md` | 充值支付API表新增 pending/approve/reject 三个管理端点 |

### Phase 1: 并行开发

| Agent | 任务 |
|-------|------|
| **Agent A — Backend** | PaymentStatus增加APPROVED、审核API（pending列表/approve/reject）、模拟回调、payments表DDL增加APPROVED约束 |
| **Agent B — Flutter** | mobile_scanner依赖、扫码界面、扫码后操作Sheet、管理后台充值审核入口 |
| **Agent C — Mock** | 二维码格式升级（增加stationName/chargerCode/type）、扫码充电联动 |

---

## 第31轮 — 全面修复 + 分支清理 + 文档同步 + Swing权限升级

### 本轮6大任务

| # | 任务 | 严重度 | 仓库 | 说明 |
|---|------|:------:|------|------|
| 1 | **Web端启动脚本** | HIGH | Client | Flutter web 需 `flutter run -d web-server` 启动，添加启动脚本+健康检查 |
| 2 | **配置抽离 + Swagger** | HIGH | Backend | 配置外部化（application-dev.yml/prod.yml）+ springdoc依赖补回+@Profile("dev") |
| 3 | **文档全面同步** | HIGH | Doc | 架构师review全项目，同步现状到文档，标注未实现项 |
| 4 | **Swing权限升级** | HIGH | Mock | 普通权限（现有）+ 高级权限（密钥+测试环境+全量查看） |
| 5 | **Round 30收尾** | HIGH | All | 确认菜单项/扫码/审批流 E2E |
| 6 | **分支清理** | MEDIUM | Doc | 删除 worktree-agent-* 分支，只留 main |

### Phase 0 — 架构师先行：分支清理 + 状态盘点

**分支清理操作：**
```
git branch -D worktree-agent-*  # 删除所有残留分支
git push origin --delete worktree-agent-*  # 远端清理
git branch -a  # 确认只剩 main
```

**状态盘点：**
- 确认各子仓库当前 commit 和干净状态
- 记录所有未提交变更

### Phase 1 — 6路并行Agent

#### Agent 1 — Flutter Web启动脚本

**文件：** `scripts/start-flutter-web.sh`

```bash
#!/bin/bash
# 启动 Flutter Web Server 并记录 PID
cd code/charging-station-client
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081 &
PID=$!
echo $PID > /tmp/flutter-web.pid
echo "Flutter Web Server PID: $PID"
# 健康检查：等待 flutter_bootstrap.js 可访问
for i in $(seq 1 30); do
  if curl -s http://localhost:8081 | grep -q "flutter"; then
    echo "Flutter Web is ready!"
    exit 0
  fi
  sleep 2
done
echo "Timeout waiting for Flutter Web"
exit 1
```

#### Agent 2 — Backend 配置抽离 + Swagger

**配置抽离方案：**
```
application.yml → 只保留公共配置（server.port, spring.profiles.active, mybatis全局）
  ↓
application-dev.yml → dev环境覆盖（datasource, redis, JWT dev密钥）
  ↓
application-prod.yml → 生产环境覆盖（全部通过环境变量）
```

**Swagger修复：**
- pom.xml 添加 `springdoc-openapi-starter-webmvc-ui:2.6.0`（第25轮移除的依赖补回）
- SwaggerConfig.java 添加 `@Profile("dev")`，仅开发环境启用
- SecurityConfig.java 保留 `/swagger-ui/**`, `/v3/api-docs/**` 的 `.permitAll()`
- 移除 JWT 验证要求 → 当前已在SecurityConfig中 permitAll，无需改动

#### Agent 3 — 架构师文档全面Review

**对照清单：**

| 文档 | 检查项 |
|------|--------|
| `usecase/docs/backend/README.md` | API列表 vs 实际Controller 7个 |
| `usecase/docs/frontend/README.md` | 页面列表 vs 实际Flutter screens 17个 |
| `status/src/state_payment.puml` | APPROVED状态是否加入 |
| `time/src/sequence_recharge.puml` | 审批流是否加入 |
| `class/` 所有 puml | PaymentStatus enum 是否含 APPROVED |
| `doc/测试方案与结果记录.md` | 版本号更新到最新 |
| 所有 .puml | → 渲染 SVG |
| 标注未实现项 | 密码强度、密码历史、数据库VIEW、自动补全、Mock心跳 |

#### Agent 4 — Swing充电桩权限升级

**需求分析：**
- **普通权限**（现有）：mock_user → /auth/login → JWT → /charges/* 端点
- **高级权限**（新增）：密钥输入 → 测试环境验证 → 查看所有充电桩 → 查看中间件交互密钥

**实现方案：**

1. `AppConfig.java` 增加：
   - `ADVANCED_SECRET` — 高级权限密钥（env: `ADVANCED_SECRET`, 默认 `charger-admin-secret-2024`）
   - `IS_TEST_ENV` — 是否测试环境（env: `IS_TEST_ENV`, 默认 `false`），高级模式仅在此为true时可用

2. `ChargerUIPanel.java` 增加：
   - 权限模式切换按钮/下拉框（普通/高级）
   - 高级模式需输入密钥弹出对话框
   - 高级模式 UI 指示器（如标题栏颜色变化或状态文字）
   - 高级模式额外功能区：查看全部充电桩 + 查看中间件密钥

3. `ApiClient.java` 增加：
   - `getAllChargers()` — 带管理员token获取全部充电桩
   - `getMiddlewareKeys()` — 获取中间件交互密钥列表
   - 高级模式使用专用JWT（admin token而非mock_user token）

4. 权限状态指示器：
   - 普通模式：绿色 `🔵 普通模式`
   - 高级模式（已验证）：红色 `🔴 高级模式`

#### Agent 5 — Round 30收尾验证

**检查清单：**
- [ ] `admin_dashboard_screen.dart` 导入 `recharge_approval_screen.dart` + 菜单项已添加
- [ ] Flutter 扫码界面可编译（`mobile_scanner` 依赖已添加）
- [ ] 充值审批流：创建充值 → PENDING → 管理员批准 → 模拟回调 → 余额增加
- [ ] Mock QR 格式：升级为含 stationName/chargerCode/type 的完整 JSON

**修复项（如检测到未完成）：**
- 菜单项缺失 → 添加 grid card
- QR 格式未升级 → 修改 `ChargerUIPanel.generateQrCode()`
- 审批流未测试 → Test Agent 写 E2E 测试

#### Agent 6 — 分支清理

**命令序列：**
```bash
# 列出所有 worktree-agent 分支
git branch | grep worktree-agent

# 删除本地分支（强制）
git branch | grep worktree-agent | xargs -r git branch -D

# 删除远端分支
git branch -r | grep worktree-agent | sed 's/origin\///' | xargs -r -I{} git push origin --delete {}

# 确认只剩 main
git branch
```

### Phase 2 — 代码审查（Reviewer Agent）

所有 Agent 完成变更后，Reviewer 逐个审查：

| Repo | 审查项 | 门禁 |
|------|--------|:----:|
| Backend | 配置结构、Swagger控制、无密钥泄露 | ✅ |
| Client | Web启动脚本、扫码界面、管理菜单 | ✅ |
| Mock | 权限模式设计、密钥安全、UI状态 | ✅ |
| Doc | 文档一致性、未实现项标注、puml→svg | ✅ |

### Phase 3 — 测试验证（Test Agent）

#### 后端测试
```bash
# 启动 PostgreSQL + Redis
cd code/charging-station-compose && docker compose up -d
# 启动后端
cd code/charging-station-backend && nohup mvn spring-boot:run > /tmp/backend.log 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > /tmp/backend.pid

# 等待后端启动
for i in $(seq 1 30); do
  if curl -s http://localhost:8080/actuator/health; then break; fi
  sleep 2
done

# 运行 API 测试
cd /mnt/data/charging-station-doc && bash agent/api_e2e_test.sh

# 运行审批流专项测试
curl -s -X POST http://localhost:8080/api/v1/payments/recharge \
  -H "Content-Type: application/json" \
  -d '{"amount":50,"method":"支付宝充值","userId":"<user-id>"}' | jq '.'
# 验证 status = "PENDING"
# 管理员审批
curl -s -X PUT "http://localhost:8080/api/v1/payments/<id>/approve" \
  -H "Authorization: Bearer <admin-token>"
# 验证 status = "SUCCESS", balance 增加

# 完成后 kill
kill $(cat /tmp/backend.pid)
```

#### Flutter 测试
```bash
flutter analyze
flutter test

# Web 启动测试
bash scripts/start-flutter-web.sh
# 验证 curl http://localhost:8081 返回含 Flutter 框架的 HTML
```

#### Mock 测试
```bash
cd code/charging-station-mock-ser-client
mvn test
# 手动测试：权限模式切换（普通→高级→普通）
```

### Phase 4 — 迭代提交

**退出条件（必须全部满足）：**
- ✅ 后端 `mvn test` 全部通过
- ✅ Flutter `flutter analyze` 0 errors
- ✅ Flutter `flutter test` 全部通过
- ✅ Mock `mvn test` 全部通过
- ✅ 审批流 E2E 通过（PENDING→APPROVED→SUCCESS）
- ✅ Web 端 curl 返回登录页面
- ✅ Swagger UI dev 环境可访问
- ✅ 文档已同步项目现状并标注未实现项
- ✅ 分支清理完毕，只剩 main
- ✅ 所有变更已提交

**只有 kill 不正常退出才提交。**

### 依赖关系

```
T0: 架构师先行（分支清理 + 状态盘点 + 文档基线）
  │
  ├── T1: Mock权限升级 (Agent 4, 独立)
  │
  ├── T2: Backend配置+Swagger (Agent 2, 独立)
  │
  ├── T3: Round30收尾 (Agent 5, 独立)
  │
  ├── T4: Flutter启动脚本 (Agent 1, 独立)
  │
  └── T5: 文档同步 (Agent 3, 依赖 T0, 可并行)
       │
       └── T6: 代码审查 (Reviewer, 依赖 T1-T5 全部完成)
            │
            └── T7: 测试验证 (Test, 依赖 T6)
                 │
                 └── T8: 迭代修复 (循环直到全通过) → 提交
```

### 当前状态 (2026-06-07)

| 阶段 | 状态 | 备注 |
|------|:----:|------|
| **T0: 架构师先行** | ✅ | 分支清理 + 盘点 + 文档基线 |
| **T0a: 分支清理** | ✅ | 13个 worktree-agent-* 分支已清理 |
| **T0b: 状态盘点** | ✅ | 已完成全面探索 |
| **T0c: 文档基线** | ✅ | puml/SVG已同步，标注未实现项 |
| **T1: Mock权限升级** | ✅ | 普通+高级模式，密钥+测试环境控制 |
| **T2: Backend配置+Swagger** | ✅ | 3层配置 + springdoc @Profile("dev") |
| **T3: Round30收尾** | ✅ | 菜单项+扫码+审批流已实现 |
| **T4: Flutter启动脚本** | ✅ | start-flutter-web.sh + dev-web.sh |
| **T5: 文档同步** | ✅ | 测试方案v1.5 + 架构评估v2.0 |
| **T6: 代码审查** | ✅ | 所有Agent变更已审查 |
| **T7: 测试验证** | ✅ | Backend 26/26, Flutter 25/25, Mock BUILD SUCCESS |
| **T8: 迭代提交** | ⏳ | 等待第32轮（未实现功能开发）完成后提交 |

---

## 第32轮 — 开放未实现功能

### 本轮目标

从架构评估中提取的6项未实现/待修复功能：

| # | 功能 | 仓库 | 优先级 | 说明 |
|---|------|------|:------:|------|
| 1 | **密码强度规则统一** | Backend | HIGH | 文档要求大+小+数字+特殊字符选3，代码仅校验字母+数字 |
| 2 | **密码历史检查** | Backend+DB | HIGH | 禁止使用最近3次密码，需存储密码哈希历史 |
| 3 | **Mock 30秒心跳检测** | Mock | MEDIUM | Mock客户端定时向后端发送心跳 |
| 4 | **数据库VIEW** | Compose | MEDIUM | 充电记录快捷视图（按用户/按桩/按日统计） |
| 5 | **搜索自动补全** | Backend+Client | LOW | 充电站/充电桩搜索下拉提示 |
| 6 | **Flutter MAINTAINER独立页面** | Client | LOW | MAINTAINER角色专用维修工作台 |

### Phase 1 — 并行开发（4路Agent）

| Agent | 任务 | 仓库 |
|-------|------|------|
| **Agent A — 密码安全** | 密码强度校验升级 + 密码历史存储+检查 | Backend+DB |
| **Agent B — Mock心跳** | 30秒定时心跳检测 | Mock |
| **Agent C — 自动补全+VIEW** | 搜索端点模糊匹配 + 数据库VIEW | Backend+Compose |
| **Agent D — MAINTAINER页面** | 维修工作台页面 + 路由接入 | Client |

### Phase 2 — 测试验证

| 检查项 | 预期 |
|--------|:----:|
| Backend `mvn test` | ✅ 全部通过 |
| Flutter `flutter analyze` | ✅ 0 error |
| Flutter `flutter test` | ✅ 全部通过 |
| Mock `mvn compile` | ✅ BUILD SUCCESS |
| 密码强度规则（>=3类字符） | ✅ 满足要求 |
| 密码历史（拒绝最近3次） | ✅ |
| Mock心跳（30秒/次） | ✅ |
| 数据库VIEW存在 | ✅ |
| 搜索自动补全返回结果 | ✅ |
| MAINTAINER页面可访问 | ✅ |