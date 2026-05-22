# 项目计划与进度

## 项目概况

本项目为充电站管理系统 UML 文档库，核心依据为 `doc/1.Java开发项目实训题目及评分标准.md`，覆盖六大功能模块和三档评分维度。目标是为课程设计学生提供完整、一致的用例文档与 UML 图。

## 当前状态（2026-05-22 更新）

### 已就位

- ✅ `doc/` — 评分标准文档（原始 .docx + 转换 .md）
- ✅ `usecase/docs/` — 五大模块：overview、backend、frontend、containerd、database
- ✅ `class/` — 类图（7大核心类 + 枚举 + 关系）
- ✅ `time/` — 时序图（8 张）
- ✅ `status/` — 状态图（充电桩、报修单、支付单）
- ✅ `activity/` — 活动图（充电全流程、报修处理）
- ✅ `agent/` — 计划、冲突、提示词

### 已完成清理（2026-05-22）

- ✅ 图片/文档交叉核对：所有 SVG 引用路径正确，无断链
- ✅ AI 措辞清理：`containerd/README.md` 一处"如需"已替换
- ✅ 冗余文件清理：移除 `statistics.puml`/`statistics.svg`（被 `analytics.puml` 替代）、`er_diagram.png`（已有 `er_diagram.svg`）
- ✅ `.gitignore` 新增 `.claude/` 和 `_bmad/` 排除规则
- ✅ 全部 30 张图渲染通过

### 交付清单

| 文件 | 状态 | 说明 |
|------|------|------|
| `.gitignore` | 修改 | 添加 `.claude/` 和 `_bmad/` 排除 |
| `usecase/docs/backend/src/statistics.puml` | 删除 | 被 `analytics.puml` 替代 |
| `usecase/docs/backend/img/statistics.svg` | 删除 | 对应 puml 已移除 |
| `usecase/docs/database/img/er_diagram.png` | 删除 | 已有等价的 `er_diagram.svg` |
| `usecase/docs/containerd/README.md` | 修改 | 修复 AI 措辞"如需" |