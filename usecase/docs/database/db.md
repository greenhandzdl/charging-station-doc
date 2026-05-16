# 数据库设计说明

本系统选用 PostgreSQL 作为核心数据库（可选装 TimescaleDB 扩展用于时序数据分析）。以下列出七张核心表及其字段设计，与功能模块的对应关系见文末映射表。

## 表清单

![数据库用例图](img/database_usecases.svg)

### 1. users（用户表）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | UUID | PK | |
| name | VARCHAR(100) | | 用户名称 |
| phone | VARCHAR(32) | NOT NULL, UNIQUE | 登录账号 |
| plate_number | VARCHAR(32) | | 车牌号 |
| password_hash | VARCHAR(255) | NOT NULL | bcrypt/Argon2 散列 |
| role | VARCHAR(32) | NOT NULL DEFAULT 'user' | user / maintainer / admin / super_admin |
| balance | NUMERIC(12,2) | DEFAULT 0.00 | 账户余额 |
| created_at | TIMESTAMPTZ | DEFAULT now() | |
| updated_at | TIMESTAMPTZ | | |

**对应模块：** 账户与支付、基础信息管理、权限管理

### 2. stations（充电站表）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | UUID | PK | |
| name | VARCHAR(200) | NOT NULL | |
| location | TEXT | | 地址/位置描述 |
| charger_count | INTEGER | DEFAULT 0 | |
| status | VARCHAR(32) | | normal / maintenance |
| created_at | TIMESTAMPTZ | DEFAULT now() | |

**对应模块：** 基础信息管理、统计与可视化

### 3. chargers（充电桩表）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | UUID | PK | |
| station_id | UUID | FK REFERENCES stations(id) | 所属充电站 |
| charger_code | VARCHAR(64) | NOT NULL, UNIQUE | 充电桩编号 |
| type | VARCHAR(32) | | fast / slow |
| status | VARCHAR(32) | | idle / charging / fault |
| created_at | TIMESTAMPTZ | DEFAULT now() | |

**对应模块：** 基础信息管理、充电流程、故障报修、统计与可视化

### 4. charge_records（充电记录表）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | UUID | PK | |
| user_id | UUID | FK REFERENCES users(id) | |
| charger_id | UUID | FK REFERENCES chargers(id) | |
| start_time | TIMESTAMPTZ | | 充电开始时间 |
| end_time | TIMESTAMPTZ | | 充电结束时间 |
| energy_kwh | NUMERIC(10,3) | | 充电量（千瓦时） |
| fee | NUMERIC(12,2) | | 充电费用 |
| status | VARCHAR(32) | | completed / processing / arrears |
| created_at | TIMESTAMPTZ | DEFAULT now() | |

**对应模块：** 充电流程、账户与支付、统计与可视化

### 5. payments（支付记录表）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | UUID | PK | |
| user_id | UUID | FK REFERENCES users(id) | |
| charge_record_id | UUID | FK REFERENCES charge_records(id) | NULLABLE，仅扣费时有值 |
| method | VARCHAR(32) | | wechat / alipay / card |
| amount | NUMERIC(12,2) | | |
| status | VARCHAR(32) | | pending / success / failed |
| gateway_callback_payload | JSONB | NULLABLE | 支付网关回调原始数据 |
| created_at | TIMESTAMPTZ | DEFAULT now() | |

**对应模块：** 账户与支付

### 6. repairs（报修单表）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | UUID | PK | |
| charger_id | UUID | FK REFERENCES chargers(id) | |
| reporter_id | UUID | FK REFERENCES users(id) | NULLABLE，提交人 |
| description | TEXT | | 故障描述 |
| status | VARCHAR(32) | | open / in_progress / closed |
| handled_by | UUID | FK REFERENCES users(id) | NULLABLE，处理人 |
| reported_at | TIMESTAMPTZ | DEFAULT now() | |
| handled_at | TIMESTAMPTZ | NULLABLE | |

**对应模块：** 故障报修

### 7. audit_logs（审计日志表）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | UUID | PK | |
| actor_id | UUID | NULLABLE | 操作人 ID |
| actor_type | VARCHAR(32) | | user / admin / system |
| action | VARCHAR(128) | | 操作类型 |
| resource | VARCHAR(128) | | 操作资源 |
| resource_id | UUID | NULLABLE | |
| payload | JSONB | NULLABLE | 请求与响应摘要 |
| created_at | TIMESTAMPTZ | DEFAULT now() | |

**对应模块：** 全部模块

## 模块与数据表映射

| 功能模块 | 涉及表 | 主要操作 |
|----------|--------|----------|
| 用户注册/登录 | users | 写入用户，校验密码 |
| 基础信息管理 | stations, chargers, users | CRUD |
| 充电流程 | chargers, charge_records, users | 状态变更，记录写入，余额扣减 |
| 账户充值 | users, payments | 余额更新，支付流水记录 |
| 故障报修 | repairs, chargers | 报修单流转，桩状态变更 |
| 权限管理 | users | 角色字段变更（管理员以上操作） |
| 统计与可视化 | charge_records, payments, stations, chargers | 报表聚合，状态统计 |
| 审计日志 | audit_logs | 关键操作记录 |

## 实施要点

- **索引：** `users.phone`、`users.role`、`chargers.charger_code`、`charge_records(user_id, start_time)`、`repairs.status` 建立索引。
- **幂等：** 支付回调使用 `payments.id` 或业务幂等键确保幂等。
- **事务：** 余额更新与账单写入放在同一事务中，保证一致性。
- **时序数据：** 需要高性能时序分析时，启用 TimescaleDB 扩展，将 `charge_records` 保存在 hypertable 中。
- **数据保留：** 充电记录与支付流水按时间分区或归档。
- **审计完整性：** audit_logs 仅追加写入，禁止修改或删除。

## 交付物

- 本文件为交付级数据库说明。
- ER 关系图在后续迭代中补充。
- 数据库迁移脚本（DDL）使用 Flyway/Liquibase 管理，在后续提交中提供。

## 交叉索引

- [数据库用例](README.md) — 后端与数据库交互场景（含用例图）
- [参与者定义与用例总览](../overview/usecases.md) — 参与者角色说明、核心用例、安全要点
- [后端 API 与权限映射](../backend/README.md) — 后端接口定义、权限控制、安全措施
- [前端用例](../frontend/README.md) — 前端界面与交互契约
- [容器化与部署](../containerd/README.md) — Docker/K8s/CI 配置