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

### Phase 2 — 代码审查合并

Reviewer Agent 逐个 repo 审查: 结构对齐类图、API 对齐文档、字段/注解一致，通过后合并到 main。

### Phase 3 — 测试循环

Test Agent 顺序跑各 repo: 编译/测试 → 失败 → dev agent 修复 → 循环直到全通过。

### Phase 4 — 文档矛盾裁决

任何时候发现 UML 文档不一致 → Architect 修 puml → 渲染 SVG → 提交 doc repo。