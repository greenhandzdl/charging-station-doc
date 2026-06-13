-- ============================================================================
-- charging-station-backend 数据库模式定义 (PostgreSQL)
-- 基于 Java 实体类 (Entity) 与 MyBatis Mapper 注解反向生成
-- 生成时间: 2026-06-13
-- ============================================================================

-- ============================================================================
-- 枚举类型 (使用 VARCHAR + CHECK 约束，避免 ENUM 迁移问题)
-- ============================================================================

-- 用户角色: USER(普通用户), MAINTAINER(维护员), ADMIN(管理员), SUPER_ADMIN(超级管理员)
-- 充电站状态: NORMAL(正常), MAINTENANCE(维护中)
-- 充电桩类型: FAST(快充), SLOW(慢充)
-- 充电桩状态: IDLE(空闲), CHARGING(充电中), FAULT(故障)
-- 充电记录状态: PROCESSING(处理中), COMPLETED(已完成)
-- 扣费状态: PENDING(待扣费), PAID(已支付), ARREARS(欠费)
-- 维修状态: OPEN(待处理), IN_PROGRESS(处理中), RESOLVED(已解决), CLOSED(已关闭), DELETED(已删除)
-- 支付状态: PENDING(待支付), APPROVED(已批准), SUCCESS(成功), FAILED(失败)

-- ============================================================================
-- 1. users — 用户表
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id                      UUID            NOT NULL,
    name                    VARCHAR(100)    NOT NULL,
    phone                   VARCHAR(20)     NOT NULL,
    plate_number            VARCHAR(20),
    password_hash           VARCHAR(255)    NOT NULL,
    role                    VARCHAR(20)     NOT NULL DEFAULT 'USER'
                            CHECK (role IN ('USER', 'MAINTAINER', 'ADMIN', 'SUPER_ADMIN')),
    balance                 DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    frozen_until            TIMESTAMP,
    failed_login_attempts   INTEGER         NOT NULL DEFAULT 0,
    account_locked_until    TIMESTAMP,
    password_reset_token    VARCHAR(255),
    password_reset_token_hash VARCHAR(255),
    reset_token_expires_at  TIMESTAMP,
    created_at              TIMESTAMP       NOT NULL DEFAULT now(),
    updated_at              TIMESTAMP,
    PRIMARY KEY (id)
);

COMMENT ON COLUMN users.id IS '用户 UUID 主键';
COMMENT ON COLUMN users.phone IS '手机号，唯一登录凭证';
COMMENT ON COLUMN users.plate_number IS '车牌号';
COMMENT ON COLUMN users.password_hash IS '密码哈希值 (bcrypt)';
COMMENT ON COLUMN users.role IS '用户角色: USER, MAINTAINER, ADMIN, SUPER_ADMIN';
COMMENT ON COLUMN users.balance IS '账户余额';
COMMENT ON COLUMN users.frozen_until IS '欠费冻结截止时间，NULL 表示未冻结';
COMMENT ON COLUMN users.failed_login_attempts IS '连续登录失败次数';
COMMENT ON COLUMN users.account_locked_until IS '账户锁定截止时间，NULL 表示未锁定';
COMMENT ON COLUMN users.password_reset_token_hash IS '密码重置令牌哈希';
COMMENT ON COLUMN users.reset_token_expires_at IS '密码重置令牌过期时间';

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone ON users (phone);
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users (created_at);

-- ============================================================================
-- 2. stations — 充电站表
-- ============================================================================

CREATE TABLE IF NOT EXISTS stations (
    id              UUID            NOT NULL,
    name            VARCHAR(200)    NOT NULL,
    location        VARCHAR(500)    NOT NULL,
    charger_count   INTEGER         NOT NULL DEFAULT 0,
    status          VARCHAR(20)     NOT NULL DEFAULT 'NORMAL'
                    CHECK (status IN ('NORMAL', 'MAINTENANCE')),
    created_at      TIMESTAMP       NOT NULL DEFAULT now(),
    updated_at      TIMESTAMP,
    PRIMARY KEY (id)
);

COMMENT ON COLUMN stations.name IS '充电站名称';
COMMENT ON COLUMN stations.location IS '充电站地址/位置';
COMMENT ON COLUMN stations.charger_count IS '充电桩数量';
COMMENT ON COLUMN stations.status IS '充电站状态: NORMAL, MAINTENANCE';

CREATE INDEX IF NOT EXISTS idx_stations_name ON stations (name);
CREATE INDEX IF NOT EXISTS idx_stations_status ON stations (status);

-- ============================================================================
-- 3. chargers — 充电桩表
-- ============================================================================

CREATE TABLE IF NOT EXISTS chargers (
    id                  UUID            NOT NULL,
    station_id          UUID            NOT NULL,
    charger_code        VARCHAR(50)     NOT NULL,
    type                VARCHAR(20)     NOT NULL DEFAULT 'SLOW'
                        CHECK (type IN ('FAST', 'SLOW')),
    status              VARCHAR(20)     NOT NULL DEFAULT 'IDLE'
                        CHECK (status IN ('IDLE', 'CHARGING', 'FAULT')),
    created_at          TIMESTAMP       NOT NULL DEFAULT now(),
    updated_at          TIMESTAMP,
    online_status       VARCHAR(20)     NOT NULL DEFAULT 'OFFLINE'
                        CHECK (online_status IN ('ONLINE', 'OFFLINE')),
    last_heartbeat_at   TIMESTAMP,
    device_type         VARCHAR(20)     NOT NULL DEFAULT 'SIMULATED'
                        CHECK (device_type IN ('SIMULATED', 'REAL')),
    rated_power_kw      DECIMAL(10,2),
    manufacturer        VARCHAR(200),
    model               VARCHAR(200),
    occupied_by         UUID,
    occupied_at         TIMESTAMP,
    PRIMARY KEY (id)
);

COMMENT ON COLUMN chargers.station_id IS '所属充电站 ID → stations.id';
COMMENT ON COLUMN chargers.charger_code IS '充电桩编码，唯一标识';
COMMENT ON COLUMN chargers.type IS '充电类型: FAST(快充), SLOW(慢充)';
COMMENT ON COLUMN chargers.status IS '运行状态: IDLE, CHARGING, FAULT';
COMMENT ON COLUMN chargers.online_status IS '在线状态: ONLINE, OFFLINE';
COMMENT ON COLUMN chargers.last_heartbeat_at IS '最后心跳时间';
COMMENT ON COLUMN chargers.device_type IS '设备类型: SIMULATED(模拟), REAL(真实)';
COMMENT ON COLUMN chargers.rated_power_kw IS '额定功率 (kW)';
COMMENT ON COLUMN chargers.manufacturer IS '制造商';
COMMENT ON COLUMN chargers.model IS '型号';
COMMENT ON COLUMN chargers.occupied_by IS '当前占用用户 ID → users.id';
COMMENT ON COLUMN chargers.occupied_at IS '占用开始时间';

CREATE UNIQUE INDEX IF NOT EXISTS idx_chargers_code ON chargers (charger_code);
CREATE INDEX IF NOT EXISTS idx_chargers_station_id ON chargers (station_id);
CREATE INDEX IF NOT EXISTS idx_chargers_status ON chargers (status);
CREATE INDEX IF NOT EXISTS idx_chargers_online_status ON chargers (online_status);
CREATE INDEX IF NOT EXISTS idx_chargers_occupied_by ON chargers (occupied_by);

-- ============================================================================
-- 4. charge_records — 充电记录表
-- ============================================================================

CREATE TABLE IF NOT EXISTS charge_records (
    id                  UUID            NOT NULL,
    user_id             UUID            NOT NULL,
    charger_id          UUID            NOT NULL,
    start_time          TIMESTAMP,
    end_time            TIMESTAMP,
    energy_kwh          DECIMAL(12,2),
    fee                 DECIMAL(12,2),
    status              VARCHAR(20)     NOT NULL DEFAULT 'PROCESSING'
                        CHECK (status IN ('PROCESSING', 'COMPLETED')),
    deduction_status    VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                        CHECK (deduction_status IN ('PENDING', 'PAID', 'ARREARS')),
    created_at          TIMESTAMP       NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

COMMENT ON COLUMN charge_records.user_id IS '用户 ID → users.id';
COMMENT ON COLUMN charge_records.charger_id IS '充电桩 ID → chargers.id';
COMMENT ON COLUMN charge_records.start_time IS '充电开始时间，NULL 表示尚未开始';
COMMENT ON COLUMN charge_records.end_time IS '充电结束时间';
COMMENT ON COLUMN charge_records.energy_kwh IS '充电电量 (kWh)';
COMMENT ON COLUMN charge_records.fee IS '充电费用 (元)';
COMMENT ON COLUMN charge_records.status IS '记录状态: PROCESSING, COMPLETED';
COMMENT ON COLUMN charge_records.deduction_status IS '扣费状态: PENDING, PAID, ARREARS';

CREATE INDEX IF NOT EXISTS idx_charge_records_user_id ON charge_records (user_id);
CREATE INDEX IF NOT EXISTS idx_charge_records_charger_id ON charge_records (charger_id);
CREATE INDEX IF NOT EXISTS idx_charge_records_status ON charge_records (status);
CREATE INDEX IF NOT EXISTS idx_charge_records_deduction_status ON charge_records (deduction_status);
CREATE INDEX IF NOT EXISTS idx_charge_records_created_at ON charge_records (created_at);
CREATE INDEX IF NOT EXISTS idx_charge_records_user_status ON charge_records (user_id, status);

-- ============================================================================
-- 5. repairs — 维修/报修表
-- ============================================================================

CREATE TABLE IF NOT EXISTS repairs (
    id              UUID            NOT NULL,
    charger_id      UUID            NOT NULL,
    reporter_id     UUID            NOT NULL,
    description     TEXT            NOT NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'OPEN'
                    CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'DELETED')),
    handled_by      UUID,
    reported_at     TIMESTAMP       NOT NULL DEFAULT now(),
    handled_at      TIMESTAMP,
    reject_reason   TEXT,
    PRIMARY KEY (id)
);

COMMENT ON COLUMN repairs.charger_id IS '故障充电桩 ID → chargers.id';
COMMENT ON COLUMN repairs.reporter_id IS '报修用户 ID → users.id';
COMMENT ON COLUMN repairs.description IS '故障描述';
COMMENT ON COLUMN repairs.status IS '维修状态: OPEN, IN_PROGRESS, RESOLVED, CLOSED, DELETED';
COMMENT ON COLUMN repairs.handled_by IS '处理人 ID → users.id';
COMMENT ON COLUMN repairs.reported_at IS '报修时间';
COMMENT ON COLUMN repairs.handled_at IS '处理完成时间';
COMMENT ON COLUMN repairs.reject_reason IS '驳回原因（从 RESOLVED 退回 IN_PROGRESS 时使用）';

CREATE INDEX IF NOT EXISTS idx_repairs_charger_id ON repairs (charger_id);
CREATE INDEX IF NOT EXISTS idx_repairs_reporter_id ON repairs (reporter_id);
CREATE INDEX IF NOT EXISTS idx_repairs_status ON repairs (status);
CREATE INDEX IF NOT EXISTS idx_repairs_reported_at ON repairs (reported_at);

-- ============================================================================
-- 6. payments — 支付记录表
-- ============================================================================

CREATE TABLE IF NOT EXISTS payments (
    id                      UUID            NOT NULL,
    user_id                 UUID            NOT NULL,
    charge_record_id        UUID,
    method                  VARCHAR(20)     NOT NULL,
    amount                  DECIMAL(12,2)   NOT NULL,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING', 'APPROVED', 'SUCCESS', 'FAILED')),
    gateway_tx_id           VARCHAR(255),
    gateway_callback_payload TEXT,
    created_at              TIMESTAMP       NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

COMMENT ON COLUMN payments.user_id IS '用户 ID → users.id';
COMMENT ON COLUMN payments.charge_record_id IS '关联充电记录 ID → charge_records.id';
COMMENT ON COLUMN payments.method IS '支付方式';
COMMENT ON COLUMN payments.amount IS '支付金额 (元)';
COMMENT ON COLUMN payments.status IS '支付状态: PENDING, APPROVED, SUCCESS, FAILED';
COMMENT ON COLUMN payments.gateway_tx_id IS '支付网关交易流水号';
COMMENT ON COLUMN payments.gateway_callback_payload IS '支付网关回调原始 JSON 负载';

CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments (user_id);
CREATE INDEX IF NOT EXISTS idx_payments_charge_record_id ON payments (charge_record_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments (status);
CREATE INDEX IF NOT EXISTS idx_payments_gateway_tx_id ON payments (gateway_tx_id);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments (created_at);

-- ============================================================================
-- 7. charger_users — 充电桩运维/管理用户表（非普通用户）
-- ============================================================================

CREATE TABLE IF NOT EXISTS charger_users (
    id                  UUID            NOT NULL,
    login_id            VARCHAR(100)    NOT NULL,
    name                VARCHAR(100)    NOT NULL,
    password_hash       VARCHAR(255)    NOT NULL,
    permission_level    VARCHAR(20)     NOT NULL
                        CHECK (permission_level IN ('CHARGER', 'STATION', 'STATION_GLOBAL')),
    charger_id          UUID,
    station_id          UUID,
    parent_id           UUID,
    token_version       INTEGER         NOT NULL DEFAULT 0,
    is_active           BOOLEAN,
    last_login_at       TIMESTAMP,
    created_at          TIMESTAMP       NOT NULL DEFAULT now(),
    updated_at          TIMESTAMP,
    PRIMARY KEY (id)
);

COMMENT ON COLUMN charger_users.login_id IS '登录账号';
COMMENT ON COLUMN charger_users.name IS '显示名称';
COMMENT ON COLUMN charger_users.password_hash IS '密码哈希值';
COMMENT ON COLUMN charger_users.permission_level IS '权限级别: CHARGER(单桩), STATION(单站), STATION_GLOBAL(全局)';
COMMENT ON COLUMN charger_users.charger_id IS 'CHARGER 级别绑定的充电桩 ID → chargers.id';
COMMENT ON COLUMN charger_users.station_id IS 'STATION 级别管理的充电站 ID → stations.id';
COMMENT ON COLUMN charger_users.parent_id IS '上级身份 ID → charger_users.id';
COMMENT ON COLUMN charger_users.token_version IS 'JWT token 版本号，用于强制下线';
COMMENT ON COLUMN charger_users.is_active IS '是否启用';

CREATE UNIQUE INDEX IF NOT EXISTS idx_charger_users_login_id ON charger_users (login_id);
CREATE INDEX IF NOT EXISTS idx_charger_users_charger_id ON charger_users (charger_id);
CREATE INDEX IF NOT EXISTS idx_charger_users_station_id ON charger_users (station_id);
CREATE INDEX IF NOT EXISTS idx_charger_users_parent_id ON charger_users (parent_id);
CREATE INDEX IF NOT EXISTS idx_charger_users_permission_level ON charger_users (permission_level);

-- ============================================================================
-- 8. audit_logs — 审计日志表
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id              UUID            NOT NULL,
    actor_id        UUID            NOT NULL,
    actor_type      VARCHAR(50)     NOT NULL,
    action          VARCHAR(100)    NOT NULL,
    resource        VARCHAR(100)    NOT NULL,
    resource_id     UUID,
    payload         JSONB,
    client_ip       VARCHAR(50),
    user_agent      TEXT,
    created_at      TIMESTAMP       NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

COMMENT ON COLUMN audit_logs.actor_id IS '操作者 ID';
COMMENT ON COLUMN audit_logs.actor_type IS '操作者类型 (USER / CHARGER_USER)';
COMMENT ON COLUMN audit_logs.action IS '操作动作 (如 CREATE, UPDATE, DELETE, LOGIN)';
COMMENT ON COLUMN audit_logs.resource IS '操作资源类型 (如 USER, CHARGER, REPAIR)';
COMMENT ON COLUMN audit_logs.resource_id IS '操作资源 ID';
COMMENT ON COLUMN audit_logs.payload IS '操作详情 JSON';
COMMENT ON COLUMN audit_logs.client_ip IS '客户端 IP';
COMMENT ON COLUMN audit_logs.user_agent IS '客户端 User-Agent';

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON audit_logs (actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs (resource);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource_lookup ON audit_logs (resource, resource_id);

-- ============================================================================
-- 9. password_history — 密码历史表
-- ============================================================================

CREATE TABLE IF NOT EXISTS password_history (
    id              BIGSERIAL       NOT NULL,
    user_id         UUID            NOT NULL,
    password_hash   VARCHAR(255)    NOT NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

COMMENT ON COLUMN password_history.user_id IS '用户 ID → users.id';
COMMENT ON COLUMN password_history.password_hash IS '历史密码哈希值';
COMMENT ON COLUMN password_history.created_at IS '记录创建时间（即密码变更时间）';

CREATE INDEX IF NOT EXISTS idx_password_history_user_id ON password_history (user_id, created_at DESC);

-- ============================================================================
-- 外键约束
-- 延迟添加以避免循环依赖 / 表创建顺序问题
-- ============================================================================

-- chargers → stations
ALTER TABLE chargers
    ADD CONSTRAINT fk_chargers_station_id
    FOREIGN KEY (station_id) REFERENCES stations(id) ON DELETE CASCADE;

-- chargers → users (occupied_by)
ALTER TABLE chargers
    ADD CONSTRAINT fk_chargers_occupied_by
    FOREIGN KEY (occupied_by) REFERENCES users(id) ON DELETE SET NULL;

-- charge_records → users
ALTER TABLE charge_records
    ADD CONSTRAINT fk_charge_records_user_id
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- charge_records → chargers
ALTER TABLE charge_records
    ADD CONSTRAINT fk_charge_records_charger_id
    FOREIGN KEY (charger_id) REFERENCES chargers(id) ON DELETE CASCADE;

-- repairs → chargers
ALTER TABLE repairs
    ADD CONSTRAINT fk_repairs_charger_id
    FOREIGN KEY (charger_id) REFERENCES chargers(id) ON DELETE CASCADE;

-- repairs → users (reporter)
ALTER TABLE repairs
    ADD CONSTRAINT fk_repairs_reporter_id
    FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE;

-- repairs → users (handler)
ALTER TABLE repairs
    ADD CONSTRAINT fk_repairs_handled_by
    FOREIGN KEY (handled_by) REFERENCES users(id) ON DELETE SET NULL;

-- payments → users
ALTER TABLE payments
    ADD CONSTRAINT fk_payments_user_id
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- payments → charge_records
ALTER TABLE payments
    ADD CONSTRAINT fk_payments_charge_record_id
    FOREIGN KEY (charge_record_id) REFERENCES charge_records(id) ON DELETE SET NULL;

-- charger_users → chargers
ALTER TABLE charger_users
    ADD CONSTRAINT fk_charger_users_charger_id
    FOREIGN KEY (charger_id) REFERENCES chargers(id) ON DELETE SET NULL;

-- charger_users → stations
ALTER TABLE charger_users
    ADD CONSTRAINT fk_charger_users_station_id
    FOREIGN KEY (station_id) REFERENCES stations(id) ON DELETE SET NULL;

-- charger_users → charger_users (parent)
ALTER TABLE charger_users
    ADD CONSTRAINT fk_charger_users_parent_id
    FOREIGN KEY (parent_id) REFERENCES charger_users(id) ON DELETE SET NULL;

-- password_history → users
ALTER TABLE password_history
    ADD CONSTRAINT fk_password_history_user_id
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;