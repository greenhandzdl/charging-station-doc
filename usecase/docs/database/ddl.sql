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
    role VARCHAR(32) NOT NULL DEFAULT 'USER' CHECK (role IN ('USER', 'MAINTAINER', 'ADMIN', 'SUPER_ADMIN')),
    balance NUMERIC(12,2) DEFAULT 0.00,
    frozen_until TIMESTAMP,
    failed_login_attempts INTEGER DEFAULT 0 NOT NULL,
    account_locked_until TIMESTAMP,
    password_reset_token VARCHAR(255),
    password_reset_token_hash VARCHAR(64),
    reset_token_expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP
);

CREATE UNIQUE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_password_reset_token_hash ON users(password_reset_token_hash) WHERE password_reset_token_hash IS NOT NULL;
COMMENT ON TABLE users IS '用户表，存储用户认证信息与账户余额';
COMMENT ON COLUMN users.role IS '用户角色: user / maintainer / admin / super_admin';
COMMENT ON COLUMN users.balance IS '余额，UPDATE 时使用 SET balance = balance - ? WHERE id = ? AND balance >= ? 原子操作';
COMMENT ON COLUMN users.password_hash IS 'bcrypt/Argon2 加盐散列，禁止明文或 MD5/SHA 直接存储';
COMMENT ON COLUMN users.frozen_until IS '欠费冻结截止时间，NULL 表示未冻结；冻结期间禁止启动充电';
COMMENT ON COLUMN users.failed_login_attempts IS '连续登录失败次数，>= 5 触发验证码，>= 10 锁定账户';
COMMENT ON COLUMN users.account_locked_until IS '账户锁定截止时间，锁定期间禁止登录；NULL 表示未锁定';
COMMENT ON COLUMN users.password_reset_token IS '密码重置令牌，与用户会话绑定';
COMMENT ON COLUMN users.password_reset_token_hash IS '密码重置令牌 SHA-256 哈希，用于 O(1) 查找';
COMMENT ON COLUMN users.reset_token_expires_at IS '密码重置令牌过期时间，有效期 15 分钟';

-- 2. stations（充电站表）
CREATE TABLE stations (
    id UUID PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    location TEXT,
    charger_count INTEGER DEFAULT 0 CHECK (charger_count >= 0),
    status VARCHAR(32) CHECK (status IN ('NORMAL', 'MAINTENANCE')),
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP
);

COMMENT ON TABLE stations IS '充电站表';
COMMENT ON COLUMN stations.status IS '运营状态: normal / maintenance';

-- 3. chargers（充电桩表）
CREATE TABLE chargers (
    id UUID PRIMARY KEY,
    station_id UUID NOT NULL REFERENCES stations(id),
    charger_code VARCHAR(64) NOT NULL,
    type VARCHAR(32),
    status VARCHAR(32) CHECK (status IN ('IDLE', 'CHARGING', 'FAULT')),
    online_status VARCHAR(16) DEFAULT 'OFFLINE' CHECK (online_status IN ('ONLINE', 'OFFLINE')),
    last_heartbeat_at TIMESTAMP,
    device_type VARCHAR(32) NOT NULL DEFAULT 'SIMULATED' CHECK (device_type IN ('SIMULATED', 'REAL')),
    rated_power_kw NUMERIC(6,2),
    manufacturer VARCHAR(128),
    model VARCHAR(64),
    occupied_by UUID REFERENCES users(id),
    occupied_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP
);

CREATE UNIQUE INDEX idx_chargers_charger_code ON chargers(charger_code);
CREATE INDEX idx_chargers_station_id ON chargers(station_id);
CREATE INDEX idx_chargers_occupied_by ON chargers(occupied_by) WHERE occupied_by IS NOT NULL;
COMMENT ON TABLE chargers IS '充电桩表，关联充电站';
COMMENT ON COLUMN chargers.type IS '充电类型: fast / slow';
COMMENT ON COLUMN chargers.status IS '桩状态: idle / charging / fault';
COMMENT ON COLUMN chargers.online_status IS '在线状态: online / offline，基于 last_heartbeat_at 定时更新';
COMMENT ON COLUMN chargers.last_heartbeat_at IS '最后一次遥测心跳时间，超过 60 秒未更新视为离线';
COMMENT ON COLUMN chargers.device_type IS '设备类型: SIMULATED（模拟/测试环境）/ REAL（真实环境）';
COMMENT ON COLUMN chargers.rated_power_kw IS '额定功率（kW）';
COMMENT ON COLUMN chargers.manufacturer IS '设备制造商';
COMMENT ON COLUMN chargers.model IS '设备型号';
COMMENT ON COLUMN chargers.occupied_by IS '当前占用用户 ID（插枪后设置，启动充电时验证，拔枪/结束充电后释放）';
COMMENT ON COLUMN chargers.occupied_at IS '占用开始时间（插枪时间戳）';

-- 3b. charger_devices（充电桩设备身份表）
CREATE TABLE charger_devices (
    id UUID PRIMARY KEY,
    charger_id UUID NOT NULL UNIQUE REFERENCES chargers(id),
    device_name VARCHAR(100) NOT NULL,
    device_type VARCHAR(32) NOT NULL DEFAULT 'SIMULATED'
        CHECK (device_type IN ('SIMULATED', 'REAL')),
    auth_token VARCHAR(255),
    serial_number VARCHAR(128),
    firmware_version VARCHAR(64),
    last_online_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP
);

CREATE INDEX idx_charger_devices_charger_id ON charger_devices(charger_id);
COMMENT ON TABLE charger_devices IS '充电桩设备身份表，存储充电桩认证信息，与 users 表解耦';
COMMENT ON COLUMN charger_devices.device_type IS '设备类型: SIMULATED（模拟充电桩）/ REAL（真实物理桩）';
COMMENT ON COLUMN charger_devices.auth_token IS '设备认证令牌，用于桩到后端的 HTTP 请求认证';
COMMENT ON COLUMN charger_devices.serial_number IS '设备序列号';
COMMENT ON COLUMN charger_devices.firmware_version IS '固件版本号';
COMMENT ON COLUMN charger_devices.last_online_at IS '最后在线时间';

-- 4. charge_records（充电记录表）
CREATE TABLE charge_records (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    charger_id UUID NOT NULL REFERENCES chargers(id),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    energy_kwh NUMERIC(10,3),
    fee NUMERIC(12,2),
    status VARCHAR(32) CHECK (status IN ('PROCESSING', 'COMPLETED')),
    deduction_status VARCHAR(32) NOT NULL DEFAULT 'PENDING' CHECK (deduction_status IN ('PENDING', 'PAID', 'ARREARS')),
    created_at TIMESTAMP DEFAULT now()
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
    status VARCHAR(32) CHECK (status IN ('PENDING', 'APPROVED', 'SUCCESS', 'FAILED')),
    gateway_tx_id VARCHAR(255) UNIQUE,
    gateway_callback_payload JSONB,
    created_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_payments_user_id ON payments(user_id);
COMMENT ON TABLE payments IS '支付记录表';
COMMENT ON COLUMN payments.method IS '支付方式: wechat / alipay / card / system / auto_deduct';
COMMENT ON COLUMN payments.status IS '支付状态: pending / approved / success / failed';
COMMENT ON COLUMN payments.charge_record_id IS '关联充电记录，仅扣费时有值';
COMMENT ON COLUMN payments.gateway_tx_id IS '支付网关交易流水号，UNIQUE 约束用作幂等键';

-- 6. repairs（报修单表）
CREATE TABLE repairs (
    id UUID PRIMARY KEY,
    charger_id UUID NOT NULL REFERENCES chargers(id),
    reporter_id UUID REFERENCES users(id),
    description TEXT,
    status VARCHAR(32) CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
    handled_by UUID REFERENCES users(id),
    reject_reason TEXT,
    reported_at TIMESTAMP DEFAULT now(),
    handled_at TIMESTAMP
);

CREATE INDEX idx_repairs_status ON repairs(status);
COMMENT ON TABLE repairs IS '故障报修单表';
COMMENT ON COLUMN repairs.status IS '报修状态: open / in_progress / resolved / closed';

-- 7. audit_logs（审计日志表）
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY,
    actor_id UUID,
    actor_type VARCHAR(32),
    action VARCHAR(128) NOT NULL CHECK (action IN ('START_CHARGE', 'STOP_CHARGE', 'STOP_CHARGE_DEDUCTED', 'FORCE_STOP', 'FORCE_STOP_ARREARS', 'RECHARGE', 'ARREARS_AUTO_DEDUCT', 'DEDUCT', 'SUBMIT_REPAIR', 'ASSIGN_REPAIR', 'CLAIM_REPAIR', 'RESOLVE_REPAIR', 'CLOSE_REPAIR', 'CLOSE_REPAIR_DIRECT', 'REJECT_REPAIR', 'REGISTER', 'REGISTRATION_FAILED', 'LOGIN', 'LOGIN_SUCCESS', 'LOGIN_FAILED', 'PASSWORD_RESET', 'PASSWORD_RESET_REQUEST', 'PASSWORD_RESET_CONFIRM', 'CHANGE_PASSWORD', 'CHANGE_ROLE', 'UPDATE_USER', 'DELETE_USER', 'CREATE_STATION', 'UPDATE_STATION', 'DELETE_STATION', 'CREATE_CHARGER', 'UPDATE_CHARGER', 'DELETE_CHARGER', 'EXPORT_CSV', 'CHARGE_ARREARS', 'PAY_ARREARS', 'APPROVE_PAYMENT', 'REJECT_PAYMENT', 'CALLBACK_SIGNATURE_FAILED', 'TOKEN_REPLAY_DETECTED', 'CAPTCHA_FAILED')),
    resource VARCHAR(128),
    resource_id UUID,
    payload JSONB,
    client_ip VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT now()
);

-- 注意：该表为仅追加写入，禁止 UPDATE/DELETE，下方通过 REVOKE + 触发器强制约束
REVOKE UPDATE, DELETE ON audit_logs FROM PUBLIC;

CREATE OR REPLACE FUNCTION prevent_audit_logs_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'audit_logs is append-only: UPDATE and DELETE are prohibited';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_logs_append_only
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION prevent_audit_logs_modification();

CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id, created_at);
COMMENT ON TABLE audit_logs IS '审计日志表，仅追加写入（禁止 UPDATE/DELETE，强制触发器 + REVOKE 保护，防止日志篡改）';
COMMENT ON COLUMN audit_logs.actor_type IS '操作人类型: user / admin / system';
COMMENT ON COLUMN audit_logs.action IS '操作类型: start_charge / stop_charge / recharge / resolve_repair 等';
COMMENT ON COLUMN audit_logs.client_ip IS '客户端 IP 地址，VARCHAR(45) 支持 IPv6';
COMMENT ON COLUMN audit_logs.user_agent IS '客户端 User-Agent 原始字符串';COMMENT ON COLUMN audit_logs.payload IS 'JSONB 操作详情，禁止存储密码明文、完整银行卡号等敏感信息';

-- 8. password_history（密码历史表）
CREATE TABLE password_history (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_password_history_user ON password_history(user_id, created_at DESC);
COMMENT ON TABLE password_history IS '密码历史表，保留最近3次密码哈希，供密码修改时检查';

-- ===== 视图定义 =====

-- 1. 用户充电记录快捷视图
CREATE OR REPLACE VIEW v_user_charge_records AS
SELECT
  cr.id AS record_id,
  cr.user_id,
  u.name AS user_name,
  u.phone,
  cr.charger_id,
  s.name AS station_name,
  c.charger_code,
  cr.start_time,
  cr.end_time,
  EXTRACT(EPOCH FROM (cr.end_time - cr.start_time)) / 60 AS duration_minutes,
  cr.energy_kwh AS kwh_used,
  cr.fee AS total_cost,
  cr.status
FROM charge_records cr
JOIN users u ON cr.user_id = u.id
JOIN chargers c ON cr.charger_id = c.id
JOIN stations s ON c.station_id = s.id;

-- 2. 按日统计充电量视图
CREATE OR REPLACE VIEW v_daily_charge_stats AS
SELECT
  DATE(start_time) AS charge_date,
  COUNT(*) AS total_sessions,
  SUM(energy_kwh) AS total_kwh,
  SUM(fee) AS total_revenue,
  AVG(EXTRACT(EPOCH FROM (end_time - start_time)) / 60) AS avg_duration_minutes
FROM charge_records
WHERE status = 'COMPLETED'
GROUP BY DATE(start_time)
ORDER BY charge_date DESC;

-- 3. 充电桩使用率视图
CREATE OR REPLACE VIEW v_charger_usage_rate AS
SELECT
  c.id AS charger_id,
  c.charger_code,
  s.name AS station_name,
  COUNT(cr.id) AS total_sessions,
  SUM(cr.energy_kwh) AS total_kwh,
  SUM(cr.fee) AS total_revenue,
  MAX(cr.start_time) AS last_used,
  c.status
FROM chargers c
LEFT JOIN stations s ON c.station_id = s.id
LEFT JOIN charge_records cr ON c.id = cr.charger_id
GROUP BY c.id, c.charger_code, s.name, c.status;
