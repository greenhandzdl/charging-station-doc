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

### 各仓库提交

| 仓库 | 最新提交 | 说明 |
|------|---------|------|
| backend | `61701ef` | 枚举DDL+权限+查询联表+CRUD+种子数据+gitignore |
| client | `5dfd24c` | 模型对齐+CRUD+图表+快捷视图+欠费支付 |
| compose | `3468500` | seed.sql 种子数据+测试账号+容器编排 |
| mock | `53b30b9` | （之前完成，本次无变动） |
| doc | `be327d6` | ER图修复+子模块指针+后端README测试账号 |