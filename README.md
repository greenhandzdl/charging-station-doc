# 新能源汽车充电站管理与数据分析系统 — UML 文档库

基于 Java 的新能源汽车充电站管理与数据分析系统课程结课设计 UML 文档库。

## 约束文档

所有 UML 文档、用例描述、数据表设计严格依据以下文档中的功能需求与评分标准：

- 考核题目：[doc/1.Java开发项目实训题目及评分标准.md](doc/1.Java开发项目实训题目及评分标准.md)

## 评分标准映射

| 评分维度 | 分值 | 对应文档 |
|----------|:----:|----------|
| 面向对象思想应用 | 40 分 | 类图、用例关系（include/extend）、状态图 |
| Swing + JDBC 编程 | 40 分 | 前端用例、时序图（Flutter 前端→HTTP→后端→数据库交互） |
| 系统完整性与规范性 | 20 分 | 六大模块全覆盖、活动图、交叉引用一致性 |

> 注：评分标准原文为"Swing+JDBC 编程"（见 `doc/1.Java开发项目实训题目及评分标准.md`），本 UML 文档库反映的实际技术栈为 Flutter/Dart 前端 + Spring Boot 后端。

### 六大功能模块覆盖

| 模块 | 名称 | 用例文档 | 状态 |
|------|------|----------|:----:|
| 1 | 基础信息管理 | [basic-info.md](usecase/docs/backend/basic-info.md) | ✅ |
| 2 | 充电业务与记录管理 | [charging-flow.md](usecase/docs/backend/charging-flow.md) | ✅ |
| 3 | 支付与故障报修管理 | [account-payment.md](usecase/docs/backend/account-payment.md)、[repair.md](usecase/docs/backend/repair.md) | ✅ |
| 4 | 数据统计与可视化分析 | [analytics.md](usecase/docs/overview/analytics.md) | ✅ |
| 5 | 视图与便捷功能 | [view-features.md](usecase/docs/overview/view-features.md) | ✅ |
| 6 | 简易交互与扩展功能 | [charging-flow.md](usecase/docs/backend/charging-flow.md)、[account-payment.md](usecase/docs/backend/account-payment.md) | ✅ |

## 目录结构

```
.
├── doc/                              # 考核题目与原始文件
│   ├── 1.Java开发项目实训题目及评分标准.md
│   └── original/                     # 原始 .doc / .docx
│
├── usecase/                          # 用例文档与 UML 用例图
│   ├── docs/
│   │   ├── overview/                 # 参与者定义、用例总览、统计
│   │   ├── backend/                  # 基础信息、充电流程、账户支付、报修
│   │   ├── frontend/                 # 前端用例与交互契约
│   │   ├── containerd/               # 容器化部署用例与架构图
│   │   └── database/                 # 数据库ER设计与交互用例
│   └── scripts/
│       └── render_plantuml.py        # PlantUML 自动渲染脚本
│
├── class/                            # 类图
├── time/                             # 时序图
├── status/                           # 状态图
├── activity/                         # 活动图
│
├── agent/                            # 工作跟踪
│   ├── plan.md                       # 项目计划与进度
│   ├── conflicts.md                  # 冲突决断记录
│   └── prompts.md                    # 可复用提示词模板
│
├── CLAUDE.md                         # AI 协作指导
└── README.md                         # 本文件
```

### 各模块 README

| 模块 | 路径 | 内容 |
|------|------|------|
| 用例总览 | [usecase/docs/overview/usecases.md](usecase/docs/overview/usecases.md) | 参与者、核心用例、安全要点 |
| 后端 | [usecase/docs/backend/README.md](usecase/docs/backend/README.md) | 基础信息、充电流程、账户支付、故障报修 |
| 前端 | [usecase/docs/frontend/README.md](usecase/docs/frontend/README.md) | 前端用例与交互契约 |
| 部署 | [usecase/docs/containerd/README.md](usecase/docs/containerd/README.md) | 容器化与部署架构 |
| 数据库 | [usecase/docs/database/db.md](usecase/docs/database/db.md) | 七张核心表、ER 图、索引、DDL |
| 类图 | [class/README.md](class/README.md) | 系统核心类及其关系 |
| 时序图 | [time/README.md](time/README.md) | 启动充电、结束扣费、登录、注册、报修、充值、强制结束充电对象交互 |
| 状态图 | [status/README.md](status/README.md) | 充电桩状态流转 |
| 活动图 | [activity/README.md](activity/README.md) | 故障报修全流程 |

## UML 图清单

| 图类型 | 数量 | 文件 |
|--------|:----:|------|
| 用例图 | 15 | overview(6) + backend(4) + frontend(2) + containerd(2) + database(1) |
| ER 图 | 1 | 7 张表实体关系 |
| 类图 | 3 | 总览 + 前端 Flutter 模型 + 后端 Spring Boot 实体 |
| 时序图 | 8 | 启动充电、结束扣费、登录、注册、报修提交、报修处理、充值、强制结束充电 |
| 状态图 | 3 | 充电桩 3 种状态流转 + 报修单 4 种状态流转 + 支付单 3 种状态流转 |
| 活动图 | 2 | 充电业务全流程 + 故障报修处理流程 |

## 渲染 PlantUML

修改 `.puml` 源文件后，运行以下命令重新渲染 SVG：

```bash
python3 usecase/scripts/render_plantuml.py
```

支持按模块渲染：

```bash
python3 usecase/scripts/render_plantuml.py --module overview
python3 usecase/scripts/render_plantuml.py --module backend,frontend
```

渲染器自动选择：`plantuml` 命令 → `plantuml-native` → `plantuml.jar` → Docker `plantuml/plantuml`。

## 文档完善状态

| 项目 | 状态 | 说明 |
|------|:----:|------|
| 考核要求文档 | ✅ | doc/ 目录已转换并解析 |
| 六大模块用例 | ✅ | 全覆盖，含模块5补充 |
| 用例关系 | ✅ | 核心流程补充 <<include>>/<<extend>> |
| 类图 | ✅ | 总览 + 前端 Flutter 模型 + 后端 Spring Boot 实体 |
| 时序图 | ✅ | 启动充电 + 结束扣费 + 登录 + 注册 + 报修提交 + 报修处理 + 充值 + 强制结束充电 |
| 状态图 | ✅ | 充电桩三态流转 |
| 活动图 | ✅ | 报修全流程 |
| 数据库设计 | ✅ | ER 图、7 张表、外键约束、索引明细、DDL 脚本 |
| 容器部署图 | ✅ | 部署架构 + 容器用例 |
| 交叉引用 | ✅ | 模块间 README 路径链接 |