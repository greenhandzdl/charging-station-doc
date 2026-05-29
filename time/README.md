# 时序图

充电业务核心流程的对象交互时序设计。

## 图

### 启动充电

![启动充电时序图](img/sequence_charging.svg)

**流程：** 用户通过 Flutter 选择充电桩 → Mock充电机客户端显示插枪界面 → 用户模拟插枪 → Mock客户端调用启动充电 API → 后端校验用户身份与余额（>= 10元）→ 校验桩状态（空闲）→ 乐观锁锁定桩 → 创建充电记录 → AuditLog → 充电成功 → Mock客户端启动电量模拟（0.1kWh/秒）→ Flutter 显示"充电中"。

### 结束充电与自动扣费

![结束充电时序图](img/sequence_stop_charge.svg)

**流程：** 用户通过 Mock充电机模拟拔枪 → Mock客户端停止模拟并获取电量数据 → Flutter 确认弹窗 → 用户确认 → 后端事务内（计算费用 + 扣减余额 + 记录支付 + 释放桩）→ 结果推送到 Mock客户端显示。

### 登录

![登录时序图](img/sequence_login.svg)

**流程：** 用户输入凭证 → Flutter 调用 REST API → 后端校验密码 → 生成 JWT → Redis 存储 refresh_token → 返回令牌。

### 注册

![注册时序图](img/sequence_register.svg)

**流程：** 用户填写注册信息 → 手机号唯一性校验 → 密码强度验证 → bcrypt 加密 → 写入数据库。

### 报修提交

![报修提交时序图](img/sequence_repair_submit.svg)

**流程：** 用户选择故障桩 → 创建报修单 → 桩状态更新为故障 → 审计日志。

### 报修处理

![报修处理时序图](img/sequence_repair_process.svg)

**流程：** 管理员查看待处理报修 → 分配维修人员 → 维修人员维修 → 管理员审核通过 → 桩恢复空闲。

### 账户充值

![充值时序图](img/sequence_recharge.svg)

**流程：** 用户选择金额 → 后端创建支付单 → Mock 支付网关回调 → 签名校验 → 更新余额与支付状态。

### 密码重置

![密码重置时序图](img/sequence_password_reset.svg)

**流程：** 用户点击"忘记密码" → 输入手机号 → IP 和手机号双层限流 → 图形验证码校验 → 生成重置令牌 → 发送短信验证码 → 用户输入短信验证码和令牌 → 第二重短信验证码校验 → 令牌验证 → 新密码写入数据库 → 清除旧会话。

### 管理员强制结束充电

![强制结束充电时序图](img/sequence_force_stop.svg)

**流程：** 管理员选择强制结束 → 填写终止原因 → 角色权限校验 → 事务内释放桩 → 审计日志记录终止原因 → 强制结束通知推送至 Mock充电机客户端显示。

## 源文件

- `src/sequence_charging.puml` — 启动充电时序图源文件
- `src/sequence_stop_charge.puml` — 结束充电时序图源文件
- `src/sequence_login.puml` — 登录时序图源文件
- `src/sequence_register.puml` — 注册时序图源文件
- `src/sequence_password_reset.puml` — 密码重置时序图源文件
- `src/sequence_repair_submit.puml` — 报修提交时序图源文件
- `src/sequence_repair_process.puml` — 报修处理时序图源文件
- `src/sequence_recharge.puml` — 充值时序图源文件
- `src/sequence_force_stop.puml` — 强制结束充电时序图源文件

## 相关文档

- [充电流程用例](../usecase/docs/backend/charging-flow.md) — 充电流程场景描述
- [数据库设计](../usecase/docs/database/db.md) — charge_records/payments 表结构