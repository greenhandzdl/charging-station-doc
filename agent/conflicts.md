# 冲突记录与决断

本文件记录在 UML 文档设计过程中出现的需求冲突、歧义或偏离评分标准的情况，以及用户的最终决断。

## 格式

```
### YYYY-MM-DD: [冲突标题]

**冲突描述：**
**涉及文件：**
**相关模块：**
**用户决断：**
```

---

### 2026-05-21: 前端技术选型变更 — Swing 转为 Flutter

**冲突描述：** 评分标准 `doc/1.Java开发项目实训题目及评分标准.md` 规定 Swing+JDBC 编程占 40 分，要求使用 Java Swing 桌面客户端。但用户决定前端采用 Flutter/Dart 实现。

**涉及文件：**
- class/src/class_diagram.puml → 拆分为后端类图 + 前端类图 + 总览三份文件
- time/src/sequence_charging.puml, sequence_stop_charge.puml
- time/src/ 下新增 5 个时序图（登录、注册、报修提交、报修处理、充值）
- usecase/docs/frontend/README.md
- usecase/docs/containerd/src/deployment_overview.puml
- usecase/docs/containerd/README.md
- usecase/docs/backend/README.md
- README.md、CLAUDE.md

**相关模块：** 全局 — class（类图）、time（时序图）、usecase/frontend（前端用例）、usecase/containerd（部署架构）

**用户决断：** 前端采用 Flutter/Dart。评分标准原文（Swing+JDBC 评分项）保持不动，UML 文档中的前端部分更新为 Flutter。类图拆分为前端 Flutter 模型与后端 Spring Boot 实体两个独立文件加一个总览图。