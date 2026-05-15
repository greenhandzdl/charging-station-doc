# 用例（Use Cases）目录 — 用例图与逐步用例说明

本目录专注于项目的用例建模和用例图（UML Use Case Diagram），便于需求分析、设计与评审。每个主要功能以独立文档分模块说明，包含：参与者、前置条件、主场景、备选场景、后置条件与示意用例图（采用 Mermaid 语法）。

目录结构（已分类）：

- `docs/overview/`：总体概览与用例总览（`01-usecases.md`）
- `docs/frontend/`：前端用例与交互契约（Flutter/Web）
- `docs/backend/`：后端用例、MVC 映射、数据与安全要求（Spring Boot 参考）
- `docs/containerd/`：容器化、部署与 CI/CD 要求（Docker / Kubernetes / GitHub Actions 示例）

说明：各子目录包含精简的交付级用例说明与实施要点，所有文档均为中文、面向交付、已移除非正式措辞。

使用方式：

1. 打开 `docs/01-usecases.md` 查看总体用例图与模块划分。
2. 按需打开对应模块文档查看详细用例步骤与图示。
3. 如需生成或更新图像，执行：

```bash
python3 usecase/scripts/render_plantuml.py
```


