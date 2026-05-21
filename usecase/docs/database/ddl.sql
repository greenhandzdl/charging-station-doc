-- =============================================================
-- 充电站管理系统 — 数据库建表脚本 (DDL)
-- 数据库: PostgreSQL 15+
-- =============================================================

-- 1. users（用户表）
CREATE TABLE users (
    id UUID PRIMARY KEY,
    name VARCHAR(100),
    phone VARCHAR(32) NOT NULL,
    plate_number VARCHAR(32),
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL DEFAULT 'user',
    balance NUMERIC(12,2) DEFAULT 0.00,
    frozen_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);
COMMENT ON TABLE users IS '用户表，存储用户认证信息与账户余额';
COMMENT ON COLUMN users.role IS '用户角色: user / maintainer / admin / super_admin';
COMMENT ON COLUMN users.balance IS '余额，UPDATE 时使用 SET balance = balance - ? WHERE id = ? AND balance >= ? 原子操作';
COMMENT ON COLUMN users.password_hash IS 'bcrypt/Argon2 加盐散列，禁止明文或 MD5/SHA 直接存储';
COMMENT ON COLUMN users.frozen_until IS '欠费冻结截止时间，NULL 表示未冻结；冻结期间禁止启动充电';

-- 2. stations（充电站表）
CREATE TABLE stations (
    id UUID PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    location TEXT,
    charger_count INTEGER DEFAULT 0,
    status VARCHAR(32),
    created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE stations IS '充电站表';
COMMENT ON COLUMN stations.status IS '运营状态: normal / maintenance';

-- 3. chargers（充电桩表）
CREATE TABLE chargers (
    id UUID PRIMARY KEY,
    station_id UUID NOT NULL REFERENCES stations(id),
    charger_code VARCHAR(64) NOT NULL,
    type VARCHAR(32),
    status VARCHAR(32),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX idx_chargers_charger_code ON chargers(charger_code);
CREATE INDEX idx_chargers_station_id ON chargers(station_id);
COMMENT ON TABLE chargers IS '充电桩表，关联充电站';
COMMENT ON COLUMN chargers.type IS '充电类型: fast / slow';
COMMENT ON COLUMN chargers.status IS '桩状态: idle / charging / fault';

-- 4. charge_records（充电记录表）
CREATE TABLE charge_records (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    charger_id UUID NOT NULL REFERENCES chargers(id),
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    energy_kwh NUMERIC(10,3),
    fee NUMERIC(12,2),
    status VARCHAR(32),
    deduction_status VARCHAR(32) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_charge_records_user_start ON charge_records(user_id, start_time);
CREATE INDEX idx_charge_records_charger_time ON charge_records(charger_id, start_time);
COMMENT ON TABLE charge_records IS '充电记录表';
COMMENT ON COLUMN charge_records.status IS '充电过程状态: processing / completed';
COMMENT ON COLUMN charge_records.deduction_status IS '扣费状态: pending / paid / arrears';
CREATE INDEX idx_charge_records_deduction ON charge_records(deduction_status);

-- 5. payments（支付记录表）
CREATE TABLE payments (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    charge_record_id UUID REFERENCES charge_records(id),
    method VARCHAR(32),
    amount NUMERIC(12,2) NOT NULL,
    status VARCHAR(32),
    gateway_tx_id VARCHAR(255) UNIQUE,
    gateway_callback_payload JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_payments_user_id ON payments(user_id);
COMMENT ON TABLE payments IS '支付记录表';
COMMENT ON COLUMN payments.method IS '支付方式: wechat / alipay / card / system';
COMMENT ON COLUMN payments.status IS '支付状态: pending / success / failed';
COMMENT ON COLUMN payments.charge_record_id IS '关联充电记录，仅扣费时有值';
COMMENT ON COLUMN payments.gateway_tx_id IS '支付网关交易流水号，UNIQUE 约束用作幂等键';

-- 6. repairs（报修单表）
CREATE TABLE repairs (
    id UUID PRIMARY KEY,
    charger_id UUID NOT NULL REFERENCES chargers(id),
    reporter_id UUID REFERENCES users(id),
    description TEXT,
    status VARCHAR(32),
    handled_by UUID REFERENCES users(id),
    reported_at TIMESTAMPTZ DEFAULT now(),
    handled_at TIMESTAMPTZ
);

CREATE INDEX idx_repairs_status ON repairs(status);
COMMENT ON TABLE repairs IS '故障报修单表';
COMMENT ON COLUMN repairs.status IS '报修状态: open / in_progress / resolved / closed';

-- 7. audit_logs（审计日志表）
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY,
    actor_id UUID,
    actor_type VARCHAR(32),
    action VARCHAR(128) NOT NULL,
    resource VARCHAR(128),
    resource_id UUID,
    payload JSONB,
    client_ip VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id, created_at);
COMMENT ON TABLE audit_logs IS '审计日志表，仅追加写入';
COMMENT ON COLUMN audit_logs.actor_type IS '操作人类型: user / admin / system';
COMMENT ON COLUMN audit_logs.action IS '操作类型: start_charge / stop_charge / recharge / resolve_repair 等';
COMMENT ON COLUMN audit_logs.client_ip IS '客户端 IP 地址，VARCHAR(45) 支持 IPv6';
COMMENT ON COLUMN audit_logs.user_agent IS '客户端 User-Agent 原始字符串';