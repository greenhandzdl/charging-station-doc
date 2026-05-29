# 数据库用例 — 后端与数据库交互

本文档描述后端业务模块与 PostgreSQL 数据库之间的数据交互场景，展示各用例中数据库的读写操作。

## 参与对象

| 对象 | 说明 |
|------|------|
| 后端服务 | Java Spring Boot，通过 JDBC/JPA 操作数据库 |
| 数据库 | PostgreSQL（可选 TimescaleDB），存储全部业务数据 |

## 数据库用例图

![数据库用例](img/database_usecases.svg)

## 用例：注册

| 步骤 | 操作 | SQL / 说明 |
|------|------|------------|
| 1 | 校验手机号唯一性 | `SELECT id FROM users WHERE phone = ?` |
| 2 | 写入用户记录 | `INSERT INTO users (id, name, phone, password_hash, role, balance) VALUES (?, ?, ?, ?, 'user', 0.00)` |
| 3 | 返回用户信息 | 读取刚写入的记录返回 |

## 用例：登录

| 步骤 | 操作 | SQL / 说明 |
|------|------|------------|
| 1 | 根据手机号查询用户 | `SELECT id, password_hash, role, name FROM users WHERE phone = ?` |
| 2 | 校验密码散列 | 后端比对 bcrypt 散列 |
| 3 | 生成 Token 返回 | 无数据库操作 |

## 用例：充值

| 步骤 | 操作 | SQL / 说明 |
|------|------|------------|
| 1 | 创建充值记录 | `INSERT INTO payments (id, user_id, method, amount, status) VALUES (?, ?, ?, ?, 'pending')` |
| 2 | 请求支付网关 | 后端调用外部支付接口（暂用 Mock） |
| 3 | 支付网关回调 | 后端接收回调，验证签名 |
| 4 | 更新用户余额 | `UPDATE users SET balance = balance + ?, updated_at = now() WHERE id = ?`（事务中） |
| 5 | 更新支付记录状态 | `UPDATE payments SET status = 'success', gateway_callback_payload = ? WHERE id = ?`（同一事务） |
| 6 | 记录审计日志 | `INSERT INTO audit_logs (id, actor_id, actor_type, action, resource, resource_id, payload, client_ip) VALUES (?, ?, 'user', 'recharge', 'payment', ?, ?, ?)` |

## 用例：启动充电

| 步骤 | 操作 | SQL / 说明 |
|------|------|------------|
| 1 | 查询用户与充电桩 | `SELECT id, balance FROM users WHERE id = ?` + `SELECT id, status FROM chargers WHERE id = ?` |
| 2 | 校验余额与状态 | 后端校验 balance >= 最低金额 且 status = 'idle' |
| 3 | 更新充电桩状态 | `UPDATE chargers SET status = 'charging' WHERE id = ? AND status = 'idle'`（乐观锁防并发） |
| 4 | 创建充电记录 | `INSERT INTO charge_records (id, user_id, charger_id, start_time, status) VALUES (?, ?, ?, now(), 'processing')` |
| 5 | 记录审计日志 | `INSERT INTO audit_logs ... action='start_charge'` |

## 用例：结束充电并扣费

| 步骤 | 操作 | SQL / 说明 |
|------|------|------------|
| 1 | 更新充电记录 | `UPDATE charge_records SET end_time = now(), energy_kwh = ?, fee = ?, status = 'completed' WHERE id = ?` |
| 2 | 扣减用户余额 | `UPDATE users SET balance = balance - ?, updated_at = now() WHERE id = ? AND balance >= ?`（事务） |
| 3 | 记录扣费支付 | `INSERT INTO payments (id, user_id, charge_record_id, method, amount, status) VALUES (?, ?, ?, 'system', ?, 'success')` |
| 4 | 更新充电桩状态 | `UPDATE chargers SET status = 'idle' WHERE id = ?` |
| 5 | 扣费失败处理 | 若余额不足则 `UPDATE charge_records SET deduction_status = 'arrears' WHERE id = ?`，充电桩状态恢复为 'idle'（释放桩避免被无限期占用） |
| 6 | 记录审计日志 | `INSERT INTO audit_logs ... action='stop_charge' / 'charge_arrears'` |

## 用例：故障报修与处理

| 步骤 | 操作 | SQL / 说明 |
|------|------|------------|
| 1 | 提交报修 | `INSERT INTO repairs (id, charger_id, reporter_id, description, status) VALUES (?, ?, ?, ?, 'open')` |
| 2 | 更新充电桩状态 | `UPDATE chargers SET status = 'fault' WHERE id = ?` |
| 3 | 管理员分配处理人 | `UPDATE repairs SET handled_by = ?, status = 'in_progress' WHERE id = ?` |
| 4 | 维修完成 | `UPDATE repairs SET status = 'closed', handled_at = now() WHERE id = ?` + `UPDATE chargers SET status = 'idle' WHERE id = ?` |
| 5 | 记录审计日志 | `INSERT INTO audit_logs ... action='submit_repair' / 'resolve_repair'` |

## 用例：统计报表

| 步骤 | 操作 | SQL / 说明 |
|------|------|------------|
| 1 | 按站点/时间汇总 | `SELECT station_id, COUNT(*), SUM(fee) FROM charge_records cr JOIN chargers c ON cr.charger_id = c.id WHERE cr.start_time BETWEEN ? AND ? AND cr.status = 'completed' GROUP BY c.station_id` |
| 2 | 充电桩状态统计 | `SELECT status, COUNT(*) FROM chargers GROUP BY status` |
| 3 | 导出 CSV | 同上查询，结果流式写入文件 |

## 事务边界说明

| 用例 | 事务范围 | 说明 |
|------|----------|------|
| 注册 | 单条 INSERT | 唯一约束保证原子性 |
| 充值回调 | UPDATE users + UPDATE payments | 同一事务，保证余额与支付记录一致 |
| 启动充电 | UPDATE chargers + INSERT charge_records | 乐观锁防并发，失败回滚 |
| 结束扣费 | UPDATE charge_records + UPDATE users + INSERT payments + UPDATE chargers | 多表写操作，事务回滚保证数据一致 |
| 报修处理 | UPDATE repairs + UPDATE chargers | 两表状态同时变更 |

## 相关文档

- [数据库表结构](db.md) — 完整字段定义、约束与索引
- [后端 API 与权限映射](../backend/README.md) — 后端接口定义、权限控制
- [参与者与用例总览](../overview/usecases.md) — 参与者角色与核心用例