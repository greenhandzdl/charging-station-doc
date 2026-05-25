# 项目计划与进度

## 项目概况

本项目为充电站管理系统 UML 文档库，核心依据为 `doc/1.Java开发项目实训题目及评分标准.md`，覆盖六大功能模块和三档评分维度。目标是为课程设计学生提供完整、一致的用例文档与 UML 图。

## 当前状态（2026-05-25 更新）

### 已就位

- ✅ `doc/` — 评分标准文档（原始 .docx + 转换 .md）
- ✅ `usecase/docs/` — 五大模块（overview/backend/frontend/containerd/database），13 张用例图
- ✅ `class/` — 3 张类图（后端类图、前端类图、总览图）
- ✅ `time/` — 8 张时序图（充电启动/结束/强制结束/登录/注册/充值/报修提交/报修处理）
- ✅ `status/` — 3 张状态图（充电桩、报修单、支付单）
- ✅ `activity/` — 2 张活动图（充电全流程、报修处理）
- ✅ `agent/` — 计划、冲突记录、提示词模板
- ✅ 共 32 个 .puml 源文件，5 模块渲染全部通过（0 failed）

### 架构与安全评估（已完成 2 轮迭代）

#### 第 1 轮修复（commit `04b5b24`）
- 架构 + 安全全量评估 → 修复 19 个问题
- 关键修复：stopCharge 授权加固（@chargeGuard.canStop）、欠费冻结（frozen_until）、支付回调幂等性、refresh token rotation 文档化、forceStop 桩释放条件修正、登录 @Valid、活动图异常路径重构、类图/用例图跨图一致性补全

#### 第 2 轮修复（commit `ae67892`）
- 架构评估：4 个 MAJOR/MINOR → 全部修复
- 安全审计：**0 CRITICAL/HIGH 问题**
- 修复：usecase_overall SA→QV 补全、README 补充 UCS 端点、activity_repair 退回分支注说明、frontend_usecases MC 余额校验说明
- **最终一致性检查：0 CRITICAL，6 维度全部通过**

### 交付清单

| 文件 | 状态 | 说明 |
|------|------|------|
| `.gitignore` | 修改 | 添加 `.claude/` 和 `_bmad/` 排除 |
| `usecase/docs/backend/src/statistics.puml` | 删除 | 被 `analytics.puml` 替代 |
| `usecase/docs/backend/img/statistics.svg` | 删除 | 对应 puml 已移除 |
| `usecase/docs/database/img/er_diagram.png` | 删除 | 已有等价的 `er_diagram.svg` |
| `usecase/docs/containerd/README.md` | 修改 | 修复 AI 措辞"如需" |