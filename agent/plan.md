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
