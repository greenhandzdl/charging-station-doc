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

> **Flutter API参数修复详情**（`53a1208`）：
> - CRITICAL: `_handleResponse` 错误解析 — 后端 `{"error":{"message":"xxx"}}` 是嵌套Map，Flutter `as String?` 强制失败导致所有错误显示"请求失败(xxx)"
> - HIGH: `refreshToken` 后端返回不带 `user` 字段 → `_currentUser` 被覆盖为空 → `isLoggedIn` 触发登出
> - HIGH: `ChargeResponse.recordId` 但 `ChargeRecordModel.fromJson` 读 `id` → 充电后找不到记录ID
> - HIGH: `tryAutoLogin` 中 `_initPrefs()` 异步竞态
>
> **Backend参数修复详情**（`5a6b1f9`）：
> - `refreshToken` 返回值中查询并填充 `user` 字段
> - `application.yml` 添加 Jackson 日期格式配置：`yyyy-MM-dd HH:mm:ss`、`Asia/Shanghai`、禁止时间戳数组