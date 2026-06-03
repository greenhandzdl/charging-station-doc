# 充电流程用例

**参与者：** 用户、维修人员、管理员、系统

**前置条件：** 用户已登录，充电桩在系统中存在且未被占用。

## 启动充电

1. 用户或维修人员选择充电桩并发起"启动充电"。
2. 系统校验用户存在、账户余额 >= 10元、账户未被冻结（`users.frozen_until` 为 NULL 或已过期）且充电桩状态为"空闲"。
3. 系统创建充电记录，记录开始时间，并将充电桩状态设为"使用中"。

> **定价策略**：实际费用根据充电桩类型计算——快充桩（DC）按 1.5 元/kWh 计费，慢充桩（AC）按 0.8 元/kWh 计费。可在 StandardPricing 基础上扩展为 PeakPricing 峰谷定价策略。
>
> **并发控制：** 充电桩状态更新必须使用原子 SQL 避免竞态条件：
> ```sql
> UPDATE chargers SET status = 'charging' WHERE id = ? AND status = 'idle';
> ```
> 检查上述语句的 `affected_rows`（JDBC `executeUpdate()` 返回值），若为 0 则表示桩已被其他请求占用，需回滚事务并返回错误。此操作与 INSERT charge_records 应在同一数据库事务中执行。
>
> **注意：** 启动充电使用乐观锁模式（`WHERE status = 'idle'`），结束充电和强制结束使用悲观锁（`SELECT ... FOR UPDATE`）。两种模式在事务隔离级别为 READ COMMITTED 时均可正确工作，但需确保整个事务不跨请求边界（即不持有数据库连接等待用户输入）。

## 结束充电

1. 用户、管理员或系统触发"结束充电"。
2. 系统记录结束时间，计算充电量与费用。
3. 系统从用户账户扣费；成功则更新充电记录状态为"完成"，并将充电桩状态设为"空闲"。
4. 扣费失败则更新 `charge_records.status = 'completed'`、`charge_records.deduction_status = 'arrears'`，并将充电桩状态恢复为 `idle`，同时冻结用户的启动充电权限（`users.frozen_until` 设为截止时间），记录异常日志并通知管理员。

> **TOCTOU 防护：** 结束充电时的余额校验与扣费操作之间存在 Time-of-Check Time-of-Use 窗口。解决方案：使用 `SELECT ... FOR UPDATE` 锁定用户余额行，在同一事务中完成余额校验和扣减：
> ```sql
> -- 事务内：
> SELECT balance FROM users WHERE id = ? FOR UPDATE;  -- 锁定行
> -- 应用层校验 balance >= fee
> UPDATE users SET balance = balance - ? WHERE id = ? AND balance >= ?;
> UPDATE charge_records SET status = 'completed', deduction_status = 'paid' WHERE id = ?;
> UPDATE chargers SET status = 'idle' WHERE id = ?;
> COMMIT;
> ```
> 任一 UPDATE 的 affected_rows 为 0 则整体回滚。

## 备选场景

- 充电桩已被占用：返回错误并提示用户选择其他桩。
- 余额不足：阻止启动并提示充值（管理员可介入处理）。
- 充电异常中断：系统检测到异常后自动结束充电并按已充电量结算。

## 后置条件

充电记录入库，充电桩状态与用户余额一致。

## 用例图

![充电流程用例图](img/charging_flow.svg)

## 相关文档

- [账户与支付](account-payment.md) — 注册/登录/充值流程
- [后端 API 与权限映射](README.md) — 充电相关接口与权限
- [数据库设计](../database/db.md) — charge_records 表结构