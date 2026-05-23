# 用例目录

本目录为充电站管理系统的用例文档，包含参与者定义、用例描述、UML 用例图与交互契约。每个模块以独立文档说明。

## 模块索引

| 模块 | 路径 | 内容 |
|------|------|------|
| 概览 | `docs/overview/` | [参与者定义与用例总览](docs/overview/usecases.md)、[统计与可视化](docs/overview/analytics.md)、[总体用例图](docs/overview/img/usecase_overall.svg) |
| 后端 | `docs/backend/` | [后端 API 与安全要求](docs/backend/README.md) 含基础信息管理、充电流程、账户支付、故障报修 |
| 前端 | `docs/frontend/` | [前端用例与交互契约](docs/frontend/README.md) 含 Mock充电机客户端（Swing）说明 |
| 部署 | `docs/containerd/` | [容器化与部署架构](docs/containerd/README.md) 含 Mock充电机客户端组件 |
| 数据库 | `docs/database/` | [数据库表结构](docs/database/db.md) 与 [后端-数据库交互用例](docs/database/README.md) |

各子目录包含 PlantUML 源（`src/`）与渲染图（`img/`）。

## 使用方式

1. 打开 [docs/overview/usecases.md](docs/overview/usecases.md) 查看总体用例图与模块划分。
2. 按需打开对应模块文档查看详细用例步骤与图示。
3. 渲染 PlantUML 图：

```bash
python3 usecase/scripts/render_plantuml.py
```