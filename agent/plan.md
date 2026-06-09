# 第36轮 — 文档-代码全面对齐 + 自主迭代闭环

> 本轮目标：修复所有文档-代码差异，清理分支/worktree，完成完整测试闭环后提交。

---

## 一、准备工作

### 1.1 清理分支与 worktree
- 移除 3 个孤立 worktree：`agent-a1d2690d9e49bf303`、`agent-a7d9439eb77e6c35e`、`agent-ac297d07a109e80e3`
- 确认 main 分支为唯一工作分支

### 1.2 精简 agent 文件
- `agent/plan.md` → 更新为本轮计划（已精简）
- `agent/conflicts.md` → 保留关键 ADR，删除过时条目
- `AGENTS.md` → 无修改需要（通用指引不变）

---

## 二、代码-文档对齐（18 项差异）

### 类别 A：过期凭据 mock_user/mock123 → mock_charger/charger123

| # | 文件 | 行 | 当前内容 | 修复动作 |
|---|------|----|----------|----------|
| A1 | `usecase/docs/overview/usecases.md` | 12, 21 | `mock_user/mock123` | 改为 `mock_charger/charger123` |
| A2 | `usecase/docs/backend/README.md` | 14 | `mock_user/mock123` | 改为 `mock_charger/charger123` |
| A3 | `usecase/docs/frontend/README.md` | 18, 26 | `mock_user/mock123` | 改为 `mock_charger/charger123` |
| A4 | `usecase/docs/containerd/README.md` | 10 | `mock_user/mock123` | 改为 `mock_charger/charger123` |
| A5 | `doc/测试方案与结果记录.md` | 45, 270 | `mock_user/mock123` | 改为 `mock_charger/charger123` |
| A6 | `code/charging-station-compose/README.md` | 31, 37 | `mock_user/mock123` | 改为 `mock_charger/charger123` |
| A7 | `class/src/backend_class_diagram.puml` | 23 | `mock_user` | 改为 `mock_charger` |

### 类别 B：文档标记"未实现"但代码已实现

| # | 文件 | 行 | 当前标注 | 实际状态 | 修复动作 |
|---|------|----|----------|----------|----------|
| B1 | `usecase/docs/backend/README.md` | 28, 180 | "⚠️ 未实现 JWT scope claim" | ✅ SecurityConfig 已实现 SCOPE 检查 | 改为 ✅ 已实现 |
| B2 | `usecase/docs/overview/usecases.md` | 21, 103 | "⚠️ 未实现 JWT scope claim" | ✅ 已实现 | 改为 ✅ 已实现 |
| B3 | `usecase/docs/backend/README.md` | 181 | "⚠️ 未实现 HMAC-SHA256" | ✅ PaymentChannelTest 13项测试通过 | 改为 ✅ 已实现 |
| B4 | `usecase/docs/backend/charging-flow.md` | 96 | "⚠️ 未实现 HMAC-SHA256" | ✅ 已实现 | 改为 ✅ 已实现 |
| B5 | `usecase/docs/overview/usecases.md` | 104 | "⚠️ 未实现 HMAC-SHA256" | ✅ 已实现 | 改为 ✅ 已实现 |
| B6 | `usecase/docs/backend/README.md` | 184 | "⚠️ 未实现 ChargerConnector" | ✅ HttpChargerConnector 真实 HTTP | 改为 ✅ 已实现 |
| B7 | `usecase/docs/backend/charging-flow.md` | 97 | "⚠️ 未实现 ChargerConnector(stub)" | ✅ 已升级 | 改为 ✅ 已实现 |
| B8 | `usecase/docs/frontend/README.md` | 95 | "⚠️ 未实现 ChargerConnector" | ✅ 已实现 | 改为 ✅ 已实现 |
| B9 | `usecase/docs/overview/usecases.md` | 106 | "⚠️ 未实现 ChargerConnector" | ✅ 已实现 | 改为 ✅ 已实现 |
| B10 | `usecase/docs/backend/README.md` | 185 | "⚠️ 未实现 遥测/心跳检测" | ✅ Entity + Mapper + 端点 + Scheduler | 改为 ✅ 已实现 |
| B11 | `usecase/docs/backend/charging-flow.md` | 98 | "⚠️ 未实现 遥测/心跳检测" | ✅ 已实现 | 改为 ✅ 已实现 |
| B12 | `usecase/docs/frontend/README.md` | 96 | "⚠️ 未实现 遥测/心跳检测" | ✅ 已实现 | 改为 ✅ 已实现 |
| B13 | `usecase/docs/overview/usecases.md` | 107 | "⚠️ 未实现 遥测/心跳检测" | ✅ 已实现 | 改为 ✅ 已实现 |
| B14 | `usecase/docs/backend/README.md` | 183 | "⚠️ 未实现 audit_logs trigger" | ✅ 已同步至 compose init.sql | 改为 ✅ 已实现 |

### 类别 C：类图缺字段

| # | 文件 | 缺失项 | 修复动作 |
|---|------|--------|----------|
| C1 | `class/src/backend_class_diagram.puml` | Charger 缺 `onlineStatus`/`lastHeartbeatAt` | 补充字段 |
| C2 | `class/src/backend_class_diagram.puml` | UserRole 枚举缺 `CHARGER` | 补充枚举值 |
| C3 | `class/src/frontend_class_diagram.puml` | ChargerModel 缺 `onlineStatus` | 补充字段 |

### 类别 D：其他差异

| # | 文件 | 差异 | 修复动作 |
|---|------|------|----------|
| D1 | `code/charging-station-backend` | Submodule 有未提交变更 | commit + 推指针 |
| D2 | `doc/测试方案与结果记录.md` | 角色表缺 `CHARGER` 角色说明 | 补充 |

---

## 三、验证迭代（自主循环）

### 循环 1：文档修复 + 渲染
- 修改所有标识的文档文件
- 需改 .puml 的：`backend_class_diagram.puml`（C1, C2）+ `frontend_class_diagram.puml`（C3）
- 运行 `python3 render.py` 或 `python3 usecase/scripts/render_plantuml.py` 渲染 SVG
- 验证：所有 SVG 生成成功

### 循环 2：代码验证
- 提交后端 submodule 变更
- 运行 `mvn test`（后端 62 项应全绿）
- 运行 `flutter build web`（Flutter 应构建成功）

### 循环 3：测试检查（如失败则修复）
- 如有测试失败 → 定位问题 → 对应 agent 修复 → 重跑验证
- 确保最终 `mvn test` 全部通过 + `flutter build web` 成功

---

## 四、最终提交

- `git commit` 文档变更
- `git commit` 子模块指针更新
- 最终的 `agent/plan.md` 标记为 ✅ 完成状态
- `agent/conflicts.md` 精简更新