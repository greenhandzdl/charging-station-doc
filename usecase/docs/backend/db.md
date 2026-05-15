# 数据库用例与表结构说明（Postgres）

说明：数据库作为系统的核心持久化组件（在用例图中表现为组件/外部系统），选用 PostgreSQL（可选装 TimescaleDB 扩展用于时序数据）。本节列出最小可交付的数据表与字段，字段设计基于项目的评分标准要求（见 `doc/1.Java开发项目实训题目及评分标准.md`），前端部分不在此处重复。

表清单（最小实现）：

1. `users`（用户表）
- `id` UUID 主键
- `name` VARCHAR(100)
- `phone` VARCHAR(32) NOT NULL UNIQUE
- `plate_number` VARCHAR(32)
- `password_hash` VARCHAR(255) NOT NULL
- `balance` NUMERIC(12,2) DEFAULT 0.00
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()
- `updated_at` TIMESTAMP WITH TIME ZONE

2. `stations`（充电站）
- `id` UUID 主键
- `name` VARCHAR(200) NOT NULL
- `location` TEXT
- `charger_count` INTEGER DEFAULT 0
- `status` VARCHAR(32) -- 例如: normal/maintenance
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

3. `chargers`（充电桩）
- `id` UUID 主键
- `station_id` UUID REFERENCES stations(id)
- `charger_code` VARCHAR(64) NOT NULL UNIQUE -- 桩ID，必须唯一
- `type` VARCHAR(32) -- fast/slow
- `status` VARCHAR(32) -- idle/charging/fault
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

4. `charge_records`（充电记录）
- `id` UUID 主键
- `user_id` UUID REFERENCES users(id)
- `charger_id` UUID REFERENCES chargers(id)
- `start_time` TIMESTAMP WITH TIME ZONE
- `end_time` TIMESTAMP WITH TIME ZONE
- `energy_kwh` NUMERIC(10,3)
- `fee` NUMERIC(12,2)
- `status` VARCHAR(32) -- completed/processing/arrears
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

5. `payments`（支付记录）
- `id` UUID 主键
- `user_id` UUID REFERENCES users(id)
- `charge_record_id` UUID REFERENCES charge_records(id) NULLABLE
- `method` VARCHAR(32) -- wechat/alipay/card/etc
- `amount` NUMERIC(12,2)
- `status` VARCHAR(32) -- pending/success/failed
- `gateway_callback_payload` JSONB NULLABLE
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

6. `repairs`（报修单）
- `id` UUID 主键
- `charger_id` UUID REFERENCES chargers(id)
- `reporter_id` UUID REFERENCES users(id) NULLABLE
- `description` TEXT
- `status` VARCHAR(32) -- open/in_progress/closed
- `handled_by` UUID REFERENCES users(id) NULLABLE -- 维修或管理员
- `reported_at` TIMESTAMP WITH TIME ZONE DEFAULT now()
- `handled_at` TIMESTAMP WITH TIME ZONE NULLABLE

7. `audit_logs`（审计日志）
- `id` UUID 主键
- `actor_id` UUID NULLABLE
- `actor_type` VARCHAR(32) -- user/admin/system
- `action` VARCHAR(128)
- `resource` VARCHAR(128)
- `resource_id` UUID NULLABLE
- `payload` JSONB NULLABLE
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

实施与注意事项：

- 时序数据：充电记录的 `start_time`/`end_time` 为关键时序字段，若要进行高性能时序分析，建议在 Postgres 上启用 TimescaleDB 扩展，将 `charge_records` 或统计指标保存在 hypertable 中。
- 索引：为 `users.phone`、`chargers.charger_code`、`charge_records(user_id, start_time)`、`payments.gateway_callback_payload` 的常用查询字段建立适当索引。
- 幂等：支付回调必须使用 `payments` 表的 `id` 或业务幂等键来保证回调幂等性。
- 事务：对余额更新与账单写入要放在同一事务或使用补偿事务（SAGA）以确保一致性。
- 数据保留与归档：根据数据量计划分区或归档策略，充电记录与支付流水可能需要按时间分区。

交付文件：
- 本文件（`docs/backend/db.md`）为交付级数据库说明。数据库迁移脚本（DDL）建议用 Flyway/Liquibase 管理，并在后续提交中提供。
