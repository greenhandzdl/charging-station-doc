# 第34轮 — 修正权限映射：Swing=模拟充电桩（高权限） Flutter=用户端

## 一、当前状态摘要

### 后端运行状态
- Spring Boot 运行中 (PID 680931), 端口 8080
- Swagger: `302` (正常重定向)
- Docker: PostgreSQL (:30001), Redis (:30002) 正常运行
- **未提交更改**: PaymentController/PaymentService/PaymentMapper/PaymentStatus/ServiceImpl — approvePayment enum 比较修复

### 已知问题
1. **Flutter Web 空白页** — `curl` 返回 HTML(200) 但 Canvaskit 渲染可能失败
2. ~~**文档与代码严重不同步** — 测试文档(v1.5)过时、Mock描述不准、权限说明偏离代码~~ ✅ Phase 1 完成
3. **Mock Swing 权限模型需重做** — 需要普通权限(充电桩验证)和高级权限(密钥+测试环境)
4. **权限系统整体重设计** — 充电流程需余额校验 + Spring-充电桩通讯
5. **agent/ 目录膨胀** — 需清理已完成项

## 二、执行阶段

### Phase 0: 准备工作 (架构师)
1. 清理工作树：删除 `worktree-agent-*` 分支
2. 提交当前未完成的 Payment 修复到子模块
3. 更新子模块指针到主仓库
4. 精简 `agent/` 目录：移除已完成轮次记录，保留当前计划
5. 记录架构决策 (ADR) 到 conflicts.md

### Phase 1: 文档同步 (架构师主导) — ✅ 已完成
已完成所有 8 项文档同步任务，具体修改见下方文档修改清单。

#### 修改文件清单
| 文件 | 修改内容 |
|------|----------|
| `usecase/docs/backend/README.md` | charger PUT 权限添加 MAINTAINER；repair 表添加 claim 端点；Mock 描述添加轮询+模拟；密码强度修正；IP封禁5分钟；Swagger 描述修正；添加三层权限模型表和未完成项 |
| `usecase/docs/backend/charging-flow.md` | PeakPricing 改为已实现(8:00-22:00峰值)；添加余额校验步骤；添加 Mock+Flutter QR 交互；添加结束充电三种场景表；添加自动补扣描述；添加未完成项 |
| `usecase/docs/frontend/README.md` | Mock 描述同步；添加 Flutter 路由权限控制(UserRole枚举+ProfileScreen门禁)；添加 Web 版注意事项；添加未完成项 |
| `usecase/docs/overview/usecases.md` | Mock 描述修正；添加 CLAIM_REPAIR 用例标注；添加三层权限模型说明；添加未完成项 |
| `usecase/docs/containerd/README.md` | Mock 描述同步；补充 Redis 部署说明；补充高级权限(Advanced API Key)说明；添加未完成项 |
| `usecase/docs/database/README.md` | 添加 audit_logs trigger 未完成项说明 |
| `code/charging-station-compose/init/init.sql` | 补充 audit_logs 的 REVOKE 和 trigger 保护（与 ddl.sql 同步） |
| `doc/测试方案与结果记录.md` | 升级至 v1.6；修正 6 项已实现功能；替换已知问题为新的 5 项未实现项 |
   - `usecase/docs/database/ddl.sql` — 同步 audit_logs trigger/REVOKE 缺失, payment status 增加 APPROVED
   - `code/charging-station-compose/init/init.sql` — 同步 trigger/REVOKE (目前缺失)
   - `doc/测试方案与结果记录.md` — 升级至 v1.6, 修正过时结论(password历史/搜索补全/密码强度)
   - 所有 Mock 相关文档 — 修正"不轮询/不模拟"描述 (实际有心跳+模拟器)
2. **标记未完成项**: 在文档中标注 scope claim 未实装、HMAC 签名未完整实装

### Phase 2: Flutter Web 修复 (并行 agent)
1. 分析 Web 构建配置 → 添加 HTML renderer 兜底 或 修复 canavaskit 加载
2. 添加 base href 替换脚本 (web/index.html 中 $FLUTTER_BASE_HREF)
3. 构建发布版 (`flutter build web --release`)
4. 验证: `curl http://localhost:PORT` 返回包含 Flutter 内容的 HTML, 非空白
5. 测试: 在浏览器打开确认登录页渲染正常

### Phase 3: Mock Swing 权限细分 (并行 agent)
1. **普通权限** (current): mock_user + JWT → 充电桩验证面板
2. **高级权限**: 新增 `advanced_mode` 配置，需密钥 (`advanced.key`) 才能激活
   - 激活后可查看所有充电桩(与Spring中间件交互)
   - 仅在测试环境开放
   - 使用独立密钥认证，不走普通登录流程
3. 修改 `AppConfig` 和 `ApiClient` 支持两种模式
4. 新增 UI 切换开关 (仅开发者模式可见)
5. 更新文档: `frontend/README.md` 中记录权限模式

### Phase 4: 权限系统 + 充电流程重设计 (架构师 + 多 Agent)

#### 4.1 新权限模型设计

**当前问题:**
- 所有认证用户可见所有充电桩 (`@PreAuthorize("isAuthenticated()")`)
- 无细粒度 charger-level 权限
- scope claim (`mock_charger_only`) 未实际生效

**新模型:**
```
层级                 | 用户                    | 充电桩                  | 密钥
普通权限 (Normal)     | USER/MAINTAINER         | 仅可见自己站的桩         | 无
管理权限 (Admin)      | ADMIN/SUPER_ADMIN       | 全部可见/管理            | 无
高级权限 (Advanced)   | 测试用户(manual)        | 全部可见+中间件交互       | 需要密钥(env: ADVANCED_API_KEY)
```

**充电流程变更:**
1. Flutter → `POST /api/v1/charges/start` (带 chargerId)
2. Spring 校验余额 ≥ 10元, 否则拒绝
3. Spring 通过 `ChargerConnector` 通知 Mock 充电桩 (HTTP/internal event)
4. 充电桩回复 ACK → Spring 标记 CHARGING
5. 结束充电:
   - 余额不足 → Spring 自动停 + 冻结账户
   - 用户主动停止 → Flutter 发 stop
   - 充电桩异常/无通讯 → 心跳超时 → Spring 强制停

#### 4.2 后端实现

| 组件 | 变更 |
|------|------|
| `ChargerConnector` (新) | 与充电桩通讯的接口, HTTP/WebSocket 适配 |
| `ChargingController.startCharge()` | 增加余额校验(≥10元), 调用 Connector 通知桩 |
| `ChargingController.stopCharge()` | 增加余额不足自动停逻辑 |
| `ChargingServiceImpl` | 重构: 拆分为 start/stop/validate/notify 子方法 |
| `ChargeGuard` | 扩展: 检查用户-充电桩所属关系 |
| `SecurityConfig` | 新增高级密钥过滤器 `AdvancedApiKeyFilter` |
| `UserController` | 新增 scope 管理端点 (SUPER_ADMIN only) |

#### 4.3 Flutter 前端实现

| 组件 | 变更 |
|------|------|
| `ChargingScreen` | 启动前增加余额校验显示 |
| `AuthProvider` | 新增 scope 属性, 控制高级功能可见性 |
| `ApiService` | 新增 `getChargerAccessibility()` 端点 |
| QR 扫码 | 无变更 (已有手动输入兜底) |

#### 4.4 Mock Swing 实现

| 组件 | 变更 |
|------|------|
| `ChargerUIPanel` | 增加桩状态监听 (收到 Spring 通知后亮灯) |
| `ApiClient` | 新增 `ChargerConnector` 回调端点 |
| `NetworkSimulator` | 强化: 心跳超时自动断开 |
| `QrCodeGenerator` | 维持现有逻辑 |

### Phase 5: 测试与验证 (测试 agent)
1. 后端编译: `mvn clean package -DskipTests` → 编译通过
2. 后端测试: `mvn test` → 全绿
3. Flutter 分析: `flutter analyze` → 无问题
4. 集成测试:
   - USER 登录 → 查看充电桩(仅可见自己的) → 余额不足时启动被拒 → 充值 → 余额≥10 → 启动成功
   - ADMIN 可见所有充电桩 → 可 approve 充值
   - Advanced 模式: 密钥验证 → 可见所有 + 中间件交互
   - Mock Swing: 插枪 → QR → Flutter 扫码 → 启动 → 停止
5. Web 测试: curl 返回含 Flutter 内容的 HTML + 浏览器登录正常

### Phase 6: 收尾
1. 提交所有子模块变更
2. 更新主仓库子模块指针
3. 精简 agent/ 目录
4. 最终 E2E 测试

## 三、并行策略

```
Round 1: 架构师同步文档 + Agent-A Flutter Web修复 + Agent-B Mock权限
                            ↓
Round 2: 架构师完成权限模型设计 → Agent-C Backend权限重写
                            ↓
Round 3: Agent-D Flutter权限适配 + Agent-E Mock充电桩通讯
                            ↓
Round 4: Agent-F 集成测试 → 失败 → 对应Agent修复 → 循环
                            ↓
Round 5: 架构师终审 + 提交
```

## 四、待裁决问题

1. **高级权限密钥格式**: UUID 还是 JWT? → **建议: HMAC-SHA256 API key** (如 `cs_adv_xxxx`)
2. **充电桩通讯协议**: HTTP polling 还是 WebSocket? → **建议: HTTP polling 先 (MVVM), 后续升级 WebSocket**
3. **Flutter Web renderer**: 是否退化为 HTML renderer? → **建议: canvaskit + html fallback 双构建**
4. **Balance 检查时机**: 启动前 vs 启动中? → **建议: 启动前硬检查 + 启动中实时监控**