# 充电流程用例

**参与者：** 用户（Flutter端）、维修人员（Flutter端）、管理员、系统、模拟充电桩（Swing端）

**前置条件：** 用户已登录（Flutter端），充电桩在系统中存在、未被占用且在线。模拟充电桩（Swing端）需在线上报遥测（heartbeat）。

## 充电桩在线检测

充电桩在线检测是启动充电的前置条件之一：

- Mock 充电桩每 30 秒发送遥测数据（heartbeat）到 Spring
- Spring 记录最后一次遥测时间（`chargers.last_heartbeat_at`），存储在 chargers 表的 `last_heartbeat_at` 字段
- `chargers.online_status` 字段记录充电桩在线状态：ONLINE / OFFLINE
- 超过 60 秒未收到遥测，标记充电桩为离线（OFFLINE）
- 离线充电桩不允许启动充电
- 正在充电的桩失去通讯超过 60 秒，Spring 强制停止充电

## 启动充电

启动充电必须同时满足以下四个条件：
1. **充电桩插入**：用户在 Mock 充电桩上选择充电桩并插枪，生成含充电桩 ID 的二维码
2. **客户端点击充电**：Flutter 扫码二维码后点击"启动充电"
3. **余额满足**：系统校验用户当前余额 >= 10 元
4. **充电桩在线**：校验充电桩在线状态为 ONLINE

1. 用户通过 Flutter 端扫描模拟充电桩（Swing）生成的二维码，获取充电桩 ID，发起"启动充电"。
2. 系统依次校验：用户存在 → 账户余额不少于 10 元（`balance < 10` 则返回 403 "余额不足 10 元，请充值"）→ 账户未被冻结（`users.frozen_until` 为 NULL 或已过期）→ 充电桩状态为"空闲" → 充电桩在线状态为 ONLINE。
3. 系统创建充电记录，记录开始时间，并将充电桩状态设为"使用中"。
4. Spring 通过 ChargerConnector 通知模拟充电桩充电已启动，模拟充电桩收到确认（ACK）后开始显示充电进度。

> **定价策略**：实际费用根据充电桩类型计算——快充桩（DC）按 1.5 元/kWh 计费，慢充桩（AC）按 0.8 元/kWh 计费。已实现 PeakPricing 峰谷定价策略（8:00-22:00 峰值时段按 1.2 倍计费，其余时段按基础价格 0.8 倍计费）。
>
> **并发控制：** 充电桩状态更新必须使用原子 SQL 避免竞态条件：
> ```sql
> UPDATE chargers SET status = 'charging' WHERE id = ? AND status = 'idle';
> ```
> 检查上述语句的 `affected_rows`（JDBC `executeUpdate()` 返回值），若为 0 则表示桩已被其他请求占用，需回滚事务并返回错误。此操作与 INSERT charge_records 应在同一数据库事务中执行。
>
> **注意：** 启动充电使用乐观锁模式（`WHERE status = 'idle'`），结束充电和强制结束使用悲观锁（`SELECT ... FOR UPDATE`）。两种模式在事务隔离级别为 READ COMMITTED 时均可正确工作，但需确保整个事务不跨请求边界（即不持有数据库连接等待用户输入）。

### 模拟充电桩（Swing） + Flutter QR 交互流程

模拟充电桩客户端（Swing）与 Flutter App 通过以下流程协作完成一次充电：

1. 用户在模拟充电桩（Swing 桌面端）选择充电桩，客户端自动生成含充电桩 ID 的 QR 码（二维码）。
2. Flutter App（已登录用户）扫描 QR 码，解析出充电桩 ID。
3. Flutter 调用 `POST /api/v1/charges/start`（携带充电桩 ID）发起充电请求。
4. 后端校验余额 >= 10 元、账户冻结状态、充电桩空闲、充电桩在线等前置条件后创建充电记录，返回 recordId。
5. Spring 通过 HttpChargerConnector POST 通知 Swing 内嵌 ChargerHttpServer（localhost:8081）充电已启动。
6. Swing 收到 notifyStart 后启动 ChargeSimulator，每秒 tick 更新 UI（JProgressBar + 电量/费用/时长标签）。
7. Flutter 每 5 秒轮询 `GET /api/v1/charges?recordId=xxx` 获取最新电量/费用。
8. 结束充电四种场景：
   - ① Flutter 用户点击"结束充电"
   - ② Swing 拔枪自动调用 `POST /api/v1/charges/stop`
   - ③ ChargingScheduler 检测余额不足自动停止
   - ④ 充电桩 60 秒无心跳 → Scheduler 标记 OFFLINE → 自动 forceStopByChargerId
9. Spring 事务内结算（计算费用 + 扣减余额 + 记录支付 + 释放桩）→ ChargerConnector 通知 Swing → Swing 停止模拟显示结算结果。

> **测试场景按钮：** 模拟充电桩面板内置断网测试、服务器重启、充电桩离线三个按钮，用于模拟异常场景验证客户端行为。

## 结束充电

### 结束充电四种场景

结束充电由以下四种场景触发（任一满足即触发）：

| 场景 | 触发者 | 说明 |
|------|--------|------|
| 余额不足自动停 | 系统(定时任务) | `ChargingScheduler` 每 30 秒扫描 PROCESSING 状态的充电记录，若用户余额低于 10 元阈值则自动停止充电、冻结账户、标记欠费 |
| 用户主动结束 | 用户 | 用户设定充电时间到或通过 Flutter/Mock 客户端主动断开，系统结算扣费 |
| 桩无通讯 | 系统 | 检测到充电桩 60 秒无遥测心跳，Spring 强制停止充电并结算 |
| 管理员强制结束 | 管理员/最高管理者 | `POST /api/v1/charges/{id}/force-stop`，需携带终止原因，记录 audit_log |

2. 系统记录结束时间，计算充电量与费用。
3. 系统从用户账户扣费；成功则更新充电记录状态为"完成"，并将充电桩状态设为"空闲"。
4. 扣费失败则更新 `charge_records.status = 'completed'`、`charge_records.deduction_status = 'arrears'`，并将充电桩状态恢复为 `idle`，同时冻结用户的启动充电权限（`users.frozen_until` 设为截止时间），记录异常日志并通知管理员。
5. **欠费自动补扣：** 系统在用户充值成功或执行其他支付操作时，自动检测当前用户是否存在欠费记录（`deduction_status = 'arrears'`），若有则自动发起补扣，补扣成功后清除冻结状态（`frozen_until = NULL`）。多次重试均失败时更新重试计数并记录审计日志。

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
- 充电桩离线：校验在线状态失败，返回 503 "充电桩离线，请稍后重试"。
- 充电异常中断：系统检测到异常后自动结束充电并按已充电量结算。
- 余额不足自动停+冻结：系统在结束充电扣费检测到余额不足时，标记扣费状态为欠费（arrears），冻结用户启动充电权限（frozen_until），充值后自动解冻并补扣。
- 充电桩无通讯：60 秒未收到遥测心跳，Spring 强制停止充电，标记桩为故障。

## 未完成项

1. **> ✅ 已实现** HMAC-SHA256 签名验证已实现（WeChatPayChannel hex + AliPayChannel base64），13 项单元测试验证通过
2. **> ✅ 已实现** 充电桩通讯中间件（HttpChargerConnector）已升级为真实 HTTP POST（`POST /api/notify/start`、`POST /api/notify/stop`、`GET /api/health/{chargerCode}`）
3. **> ✅ 已实现** 充电桩遥测/心跳检测（last_heartbeat_at + online_status）已实现（Entity 补充字段 + Mapper 更新方法 + 心跳接收端点 `POST /api/v1/chargers/heartbeat` + 60s离线Scheduler）

## 后置条件

充电记录入库，充电桩状态与用户余额一致。

## 用例图

![充电流程用例图](img/charging_flow.svg)

## 相关文档

- [账户与支付](account-payment.md) — 注册/登录/充值流程
- [后端 API 与权限映射](README.md) — 充电相关接口与权限
- [数据库设计](../database/db.md) — charge_records 表结构