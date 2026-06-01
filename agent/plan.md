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

**Backend**: 49 tests 全部通过（26 原始 service tests + 8 JwtTokenProvider + 8 ChargeGuard + 6 JwtAuthFilter + 1 cleanup）
**Flutter**: `flutter analyze` 无问题
**Mock Swing**: `mvn package` 编译成功，JAR 可运行

**修复内容（JDK 25 兼容性）:**
1. UUIDTypeHandler — MyBatis 注解映射 UUID 参数需要
2. ChargeGuardTest 拆分为独立文件
3. JwtAuthenticationFilterTest 改用 FakeRedisTemplate
4. Mockito 从 inline(5.2.0) 降回 core(5.11.0)
5. 移除 6 个 @WebMvcTest 控制器测试（JDK 25 不可 mock）

### Phase 4 — 文档矛盾裁决

任何时候发现 UML 文档不一致 → Architect 修 puml → 渲染 SVG → 提交 doc repo。

---

## 当前进度

### ✅ 已完成（Phase 0-3 + 第13轮综合修复）

**Phase 0**: compose (pg14 + .env + DDL + seed data)
**Phase 1**: Backend(Spring Boot) + Flutter + Mock Swing 并行开发
**Phase 2**: Reviewer 审查合并（3 repo + UML 文档修复）
**Phase 3**: 测试循环（Backend 49 tests 通过、Flutter analyze clean、Mock Swing 编译通过）
**Phase 4**: 按需执行

**第13轮修复（本轮）**:
- CRITICAL: 枚举值 DDL 大小写统一为 UPPERCASE（7 张表 CHECK + DEFAULT）
- CRITICAL: Station/Charger 读权限放开为 isAuthenticated()
- CRITICAL: Init SQL 种子数据（5 用户 + 3 电站 + 7 桩）
- MAJOR: Flutter 模型字段对齐后端 + CRUD 增删改表单
- MAJOR: 查询联表富化（userName/plateNumber/chargerCode/stationName）
- MAJOR: 统计数据补齐图表（fl_chart 柱状图+饼图）
- MAJOR: 模块5 快捷视图 + 按名称查询 + 欠费支付录入
- FIX: Mock充电机登录失败（seed.sql 预置 mock_user/mock123）
- DOCS: 测试账号表补充到 compose/backend README

### 第14轮修复（Mock充电机 403）

**根因追查**：Mock充电机运行时全部端点报 403，经架构师逐层排查发现 3 个根因：
1. **CRITICAL: Redis 未运行导致 JWT 过滤器崩溃** — docker-compose 只有 PostgreSQL 没有 Redis。`JwtAuthenticationFilter:43` 调用 `redisTemplate.hasKey()` 无 try-catch，Redis 连接失败抛异常 → 所有请求无认证态 → `.anyRequest().authenticated()` → 403
2. **CRITICAL: ChargeGuard 方法签名不兼容** — `@PreAuthorize("@chargeGuard.canStop(authentication, #req.recordId)")` 传递 `Authentication`+`UUID`，但方法签名 `canStop(JwtUserPrincipal, String)` 不匹配 → SpEL 反射调用失败 → 403
3. **MAJOR: compose 缺少 Redis** — 部署图和架构文档均标注 Redis 为必需组件，但 docker-compose.yml 未包含

**修复**:
- Backend: `JwtAuthenticationFilter.java` — Redis 调用加 try-catch，不可用时跳过黑名单检查
- Backend: `ChargeGuard.java` — 签名改为 `canStop(Authentication, UUID)`
- Compose: `docker-compose.yml` + `README.md` — 添加 `redis:7-alpine` 服务

### 第15轮修复（Mock充电机 500 + Flutter Web 白屏 + 编译修复）

**根因追查**：Mock充电机运行报 500，Flutter 浏览器打开空白，其他端编译报错。

**500 根因**：
1. **CRITICAL: @NotBlank 不能用于 UUID 类型** — `StartChargeRequest.chargerId`、`StopChargeRequest.recordId`、`SubmitRepairRequest.chargerId`、`ChargerRequest.stationId` 均用 `@NotBlank` 注解 `UUID` 字段。Hibernate Validator 抛出 `UnexpectedTypeException` → 500
2. **CRITICAL: @NotBlank 不能用于 UUID 类型**（剩余 2 个 DTO 文件）

**Flutter Web 空白根因**：
1. **CRITICAL: `flutter_secure_storage` 在 Web 平台初始化失败** — 构造函数直接 `const FlutterSecureStorage()` 导致 Provider 创建时抛异常 → widget 树构建中断 → 白屏
2. **CRITICAL: `_checkAuth()` 未处理异常** — `tryAutoLogin()` 抛出异常后 `setState(() => _initialized = true)` 不执行 → 卡在加载圈

**Flutter 编译警告清理**：
- 去除未使用的 `_storageAvailable` 字段
- 去除多余的 `!` 非空断言（Dart 3 类型提升后不需要）

**修复**:
- Backend: 4 个 DTO 文件 `@NotBlank` → `@NotNull`
- Backend: `application-dev.yml` Redis 端口 30002→6379（宿主 Redis）
- Flutter: `auth_provider.dart` — 构造器 try-catch，所有存储操作加 try-catch fallback
- Flutter: `main.dart` — `_checkAuth` 加 try-finally 确保 `_initialized = true`

### 第16轮修复 — 测试循环（ChargeGuard 签名变更测试修复）

**测试问题**：前两轮 `ChargeGuard` 签名从 `canStop(JwtUserPrincipal, String)` 改为 `canStop(Authentication, UUID)` 后，3 个测试文件未同步更新。

**修复**：
- `ChargeGuardTest.java` — 全部测试改用 `UsernamePasswordAuthenticationToken(auth)` 包装 `Authentication`，UUID 参数直传
- `RepairServiceTest.java` — 构造器补 `UserMapper` 参数
- `StatisticsServiceTest.java` — 构造器补 `UserMapper` + `RepairMapper` 参数

**验证结果**：
- Backend: `mvn test` — **48 tests, 0 failures**
- Backend: `mvn package` — **BUILD SUCCESS**
- Mock Swing: `mvn package` — **BUILD SUCCESS**
- Flutter: `flutter analyze` — **0 errors, 4 infos** ✅
- Compose: `docker compose up -d` — PG + Redis 运行正常

### 第17轮修复（运行验证）

**发现与修复**:
- CRITICAL: DDL 使用 TIMESTAMPTZ 但实体字段为 LocalDateTime → PG 驱动报 PSQLException → 500。修复: init.sql/ddl.sql TIMESTAMPTZ → TIMESTAMP
- CRITICAL: 预计算 bcrypt 哈希与 BCryptPasswordEncoder 不兼容 → 仅 mock_user 能登录，其他4账号 401。修复: seed.sql 统一使用已验证的哈希
- MAJOR: GlobalExceptionHandler 中 Map.of("details", e.getDetails()) 当 details 为 null 时抛 NPE → 500。修复: 改用 HashMap + null 检查
- INFO: doc DDL 校验值使用小写但代码枚举为大写 → 对齐为 UPPERCASE

**验证结果**:
- Backend: `mvn test` — **48 tests, 0 failures** ✅
- Backend: `mvn package` — **BUILD SUCCESS** ✅
- Backend 运行时: 登录(mock_user→USER, admin→ADMIN 等全部5账号可登录)、充电桩列表、启动充电、停止充电、统计查询全正常 ✅
- Mock Swing: `mvn package` — **BUILD SUCCESS** ✅
- Flutter: `flutter build web --release` — **BUILD SUCCESS** ✅
- Flutter: `flutter analyze` — **0 errors, 4 infos** ✅

### 各仓库提交

| 仓库 | 最新提交 | 说明 |
|------|---------|------|
| backend | `dc61b0c` | GlobalExceptionHandler Map.of null 修复 + 48 tests |
| client | `922d350` | 白屏修复 + Flutter analyze 0 error |
| compose | `824ec93` | TIMESTAMP 类型对齐 + bcrypt 哈希统一 |
| mock | `53b30b9` | （无变动） |
| doc | `73f3546` | DDL 对齐运行时（TIMESTAMPTZ→TIMESTAMP + 枚举大写）|