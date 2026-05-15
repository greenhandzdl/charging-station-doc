# 前端用例与交互契约（前端 / Flutter for Web 优先）

本文件为前端交付级说明的精简版，涵盖关键用例、与后端的接口契约要点、安全与测试要求，以及交付清单。

主要用例（精简）：注册/登录、充值、启动充电、结束充电与结算、查看历史记录、提交报修、管理员桩管理。

与后端契约要点：
- 使用 HTTPS，敏感操作由后端处理或加密传输。
- 登录使用短期凭证（HttpOnly Cookie 或安全存储 JWT）。
- 支付流程：前端调用 `POST /api/v1/payments/create` 获取支付参数，支付完成后由后端回调并确认。

前端安全与测试要点：
- 凭证不在前端明文持久化；严格输入校验与输出转义（防 XSS）。
- CSRF 防护（SameSite/CSRF token）。
- 单元测试、集成测试与 E2E（建议使用 Playwright / Cypress / Flutter integration tests），并在 CI 中执行关键 E2E 流程。

交付清单示例：构建产物（Flutter Web）、接口契约文档（OpenAPI snippet）、E2E 测试脚本与说明。

附图：

![前端用例](img/frontend_usecases.svg)
