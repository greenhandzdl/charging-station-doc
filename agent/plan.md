# Round 41 — 充电流程重构 + 充电桩身份模型重构 + DDL 优化

> **日期**: 2026-06-11  
> **状态**: 待审批  
> **项目**: 新能源汽车充电站管理与数据分析系统

---

## 项目状态

- **架构**: Flutter(前端) + Spring Boot(后端) + PostgreSQL + Redis + Mock Swing(模拟充电桩)
- **测试**: 后端 230 tests + Flutter 112 tests + Swing 60 tests = **402 自动化测试全部通过**
- **Git**: 5 个仓库均在 `main` 分支（非 detached），均有未提交本地改动

### 当前充电流程问题

| 问题 | 描述 |
|------|------|
| 缺少插枪流程 | Flutter 直接列表选桩启动，无需 Swing 插枪 |
| QR 不含会话绑定 | 扫码 `{chargerId,stationName}` 不含随机令牌，无防篡改 |
| 无占用锁 | 不能防止多个用户同时操作同一充电桩 |
| 拔枪不触发停止 | Swing 拔枪仅 UI 变化，不通知后端 |

### 当前 CHARGER 身份问题

| 问题 | 描述 |
|------|------|
| 充电桩身份混入 users 表 | role=CHARGER 与真人用户同表，余额/车牌号等字段对设备无意义 |
| 无 charger_id 关联 | CHARGER 用户行无法关联到具体 chargers 行 |
| 权限粒度粗 | 仅 gate 一个 plugIn 端点，无设备级身份认证 |

### 当前 DDL 问题

| 问题 | 描述 |
|------|------|
| 无 device_type | 无法区分模拟充电桩与真实环境充电桩 |
| 无电源参数 | 缺少额定功率、厂商、型号 |
| 无占用锁字段 | 缺少 `occupied_by`、`occupied_at` |

---

## 一、CHARGER 身份从 users 表独立

### 新建 `charger_devices` 表

```sql
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
```

### 后端改动

- **新建** `entity/ChargerDevice.java`、`mapper/ChargerDeviceMapper.java`、`service/ChargerDeviceService.java`
- **修改** `SecurityConfig.java` — 移除 `ROLE_USER > ROLE_CHARGER` 层级；新增设备认证过滤器
- **修改** `UserRole.java` — 移除 `CHARGER` 枚举值
- **修改** `ChargingController.java` — plugIn 端点从 `@PreAuthorize("hasRole('CHARGER')")` 改为自定义设备认证

### DDL 改动

- `init.sql`: users 表 role CHECK 约束移除 `'CHARGER'`
- `seed.sql`: 移除 `mock_charger` 用户行；新增 `charger_devices` 种子数据（7个充电桩对应 7 台模拟设备）
- `usecase/docs/database/ddl.sql`: 同步更新

---

## 二、充电桩 DDL 优化

### chargers 表新增字段

```sql
ALTER TABLE chargers ADD COLUMN device_type VARCHAR(32) NOT NULL DEFAULT 'SIMULATED'
    CHECK (device_type IN ('SIMULATED', 'REAL'));
ALTER TABLE chargers ADD COLUMN rated_power_kw NUMERIC(6,2);
ALTER TABLE chargers ADD COLUMN manufacturer VARCHAR(128);
ALTER TABLE chargers ADD COLUMN model VARCHAR(64);
ALTER TABLE chargers ADD COLUMN occupied_by UUID REFERENCES users(id);
ALTER TABLE chargers ADD COLUMN occupied_at TIMESTAMP;
```

### 后端 Entity 更新

- `Charger.java` 新增：`deviceType`, `ratedPowerKw`, `manufacturer`, `model`, `occupiedBy`, `occupiedAt`
- `ChargerMapper.java` 新增：占用独占更新 SQL（条件 `occupied_by IS NULL`）、释放 SQL（条件 `occupied_by = ?`）

### Flutter Model 更新

- `charger_model.dart` 新增字段：`deviceType`, `ratedPowerKw`, `manufacturer`, `model`

---

## 三、完整充电流程重构

### 新充电流程图

```
┌─────────────────────────────────────────────────────┐
│ 1. Swing: 选择充电桩 → 自动生成 QR 码               │
│    QR内容: {"chargerId":"xxx","sessionId":"随机UUID"} │
├─────────────────────────────────────────────────────┤
│ 2. Swing: 插枪                                     │
│    → POST /api/v1/chargers/{id}/plug-in             │
│    → 后端: 设置 occupied_by = 设备ID, occupied_at   │
├─────────────────────────────────────────────────────┤
│ 3. Flutter: 扫码 (或手动输入)                       │
│    → 解析 QR → 获取 chargerId + sessionId           │
│    → POST /api/v1/chargers/{id}/select              │
│    → 后端: 验证 sessionId, 绑定到当前用户           │
├─────────────────────────────────────────────────────┤
│ 4. Flutter: 点击"启动充电"                          │
│    → POST /api/v1/charges/start                     │
│    → 检查: 余额≥10元, 桩ONLINE, IDLE, occupied_by   │
│    → 创建PROCESSING记录, 通知Swing开始充电           │
├─────────────────────────────────────────────────────┤
│ 5. 结束充电 (满足任一)                              │
│    a) Flutter结束 → POST /api/v1/charges/stop       │
│    b) 余额不足 → autoStopOnInsufficientBalance      │
│    c) Swing拔枪 → POST /api/v1/chargers/{id}/unplug │
│    d) 桩离线60s → ChargingScheduler forceStop       │
│    e) 管理员强制停止                                 │
├─────────────────────────────────────────────────────┤
│ 6. 结算: 计算电量→计算费用→扣费/欠费→释放桩         │
└─────────────────────────────────────────────────────┘
```

### 新增/修改后端端点

| 端点 | 方法 | 说明 | 权限 |
|------|------|------|------|
| `POST /api/v1/chargers/{id}/plug-in` | POST | Swing插枪, 设置occupied_by | 设备认证 |
| `POST /api/v1/chargers/{id}/unplug` | POST | Swing拔枪, 释放+自动结束充电 | 设备认证 |
| `POST /api/v1/chargers/{id}/select` | POST | Flutter扫码绑定桩 | 用户认证 |
| `POST /api/v1/charges/start` | POST | (重构)增加occupied_by校验 | 用户认证 |

### Swing 端改动

| 文件 | 改动 |
|------|------|
| `QrCodeGenerator.java` | QR 内容升级为 JSON `{chargerId, sessionId, stationName}` |
| `ChargerUIPanel.java` | 插枪回调改为POST到后端；拔枪回调改为POST到后端；监听ChargerHttpServer通知 |
| `ApiClient.java` | 新增 `plugInCharger(id)`, `unplugCharger(id)` 方法 |
| `ChargeSimulator.java` | 开始/停止由后端通知驱动而非本地按钮 |
| `ChargerHttpServer.java` | 可扩展处理更多通知类型 |

### Flutter 端改动

| 文件 | 改动 |
|------|------|
| `charging_screen.dart` | 新增"扫码充电"入口；充电中显示实时信息（电量/费用/时长） |
| `qr_scan_screen.dart` | 解析新 QR 格式；扫码后调用 select 绑定桩 |
| `charging_provider.dart` | 优化轮询逻辑，显示实时电量/费用/时长 |
| `charge_record_model.dart` | 确认字段完整 |
| `api_service.dart` | 新增 selectCharger, getCurrentCharge 等方法 |

---

## 四、Admin 界面新增字段

| 文件 | 改动 |
|------|------|
| `station_charger_management_screen.dart` | 充电桩表单新增 device_type、rated_power_kw、manufacturer、model 字段 |
| `charger_model.dart` | 新增对应字段 + JSON 序列化 |
| `api_service.dart` | 相关 API 调用适配新字段 |

- `device_type` 列表：SIMULATED（模拟）/ REAL（真实），表单中可编辑
- 列表显示：模拟桩显示 🔧模拟 标签，真实桩显示 ⚡实机 标签
- Flutter 充电界面仅显示 `device_type = 'REAL'` 的桩（模拟桩仅供 Swing 使用）

---

## 五、实施步骤（按依赖顺序）

| # | 步骤 | 内容 | 仓库 |
|---|------|------|------|
| **1** | DDL 重构 | charger_devices 新表 + chargers 新增字段 + 移除 users.CHARGER + 更新 seed 数据 | compose + UML doc |
| **2** | Backend 新实体 | ChargerDevice Entity/Mapper/Service + Charger新增字段 + UserRole.CHARGER移除 | backend |
| **3** | Backend 安全重构 | SecurityConfig 更新 + 设备认证过滤器 + plugIn/unplug/select 端点 + 占用锁逻辑 | backend |
| **4** | Backend 充电流程 | startCharge 增加 occupied_by 校验 + 拔枪自动结束充电逻辑 | backend |
| **5** | Swing 重构 | QR 内容升级 + 插拔枪调后端 API + 通知监听 | mock-ser-client |
| **6** | Flutter 充电流程 | QrScanScreen 绑定 + ChargingScreen 扫码入口 + 实时信息 + 占用检查 | client |
| **7** | Flutter Admin 界面 | device_type 等新字段 + 充电桩类型标记显示 | client |
| **8** | 测试 + 编译 | 全量测试 + 编译验证 + 文档更新 | 所有 |
| **9** | Git 清理 | 提交 commit + 同步子模块指针 + 清理 untracked | 所有 |

---

---

## 七、各仓库文件结构指南

```
charging-station-doc/                          # 主仓库（文档）
├── agent/                                     # 工作跟踪
│   ├── plan.md                                # ← 你在此
│   ├── conflicts.md                           # 冲突决断历史
│   └── prompts.md                             # 可复用提示词
├── doc/
│   ├── 1.Java开发项目实训题目及评分标准.md      # 根本约束（必读）
│   └── 测试方案与结果记录.md                   # 测试文档
├── usecase/docs/database/ddl.sql              # UML DDL（同步更新！）
├── code/
│   ├── charging-station-backend/              # Spring Boot (Java 25)
│   │   └── src/main/java/com/charging/
│   │       ├── controller/                    # REST 控制器
│   │       │   ├── ChargingController.java    # 充电端点（核心改动）
│   │       │   ├── StationController.java     # 充电站/桩 CRUD
│   │       │   └── ...
│   │       ├── service/impl/
│   │       │   ├── ChargingServiceImpl.java   # 充电业务逻辑（核心改动）
│   │       │   └── ...
│   │       ├── entity/
│   │       │   ├── Charger.java               # 充电桩实体（需新增字段）
│   │       │   ├── ChargerDevice.java         # ★ 新建 - 充电桩设备身份
│   │       │   └── ...
│   │       ├── mapper/
│   │       │   ├── ChargerMapper.java         # 充电桩 Mapper（需新增占锁SQL）
│   │       │   ├── ChargerDeviceMapper.java   # ★ 新建
│   │       │   └── ...
│   │       ├── enums/
│   │       │   ├── UserRole.java              # 移除 CHARGER
│   │       │   ├── ChargerType.java           # FAST, SLOW, SUPER
│   │       │   └── ...
│   │       ├── infrastructure/
│   │       │   ├── connector/
│   │       │   │   ├── ChargerConnector.java  # 接口
│   │       │   │   └── HttpChargerConnector.java # → Swing:8081
│   │       │   └── security/
│   │       │       ├── SecurityConfig.java    # 角色层级、过滤器链
│   │       │       ├── JwtAuthenticationFilter.java
│   │       │       └── ...
│   │       └── dto/                           # StartChargeRequest 等
│   └── charging-station-mock-ser-client/      # Mock Swing (Java Swing)
│       └── src/main/java/com/charging/mock/
│           ├── MockChargerClient.java         # 主入口
│           ├── ChargerUIPanel.java            # UI面板（插拔枪按钮）
│           ├── service/
│           │   ├── ApiClient.java             # HTTP 通信（登录/充电API）
│           │   ├── ChargeSimulator.java       # 电量模拟
│           │   └── ChargerHttpServer.java     # 本地 HTTP Server（接收通知）
│           ├── util/QrCodeGenerator.java      # QR 生成
│           └── config/
│               ├── AppConfig.java             # 配置
│               ├── NetworkSimulator.java      # NAT 断网模拟
│               └── TestDataProvider.java      # 本地充电桩数据
├── charging-station-client/                   # Flutter (Dart)
│   └── lib/
│       ├── screens/
│       │   ├── user_screens/
│       │   │   ├── charging_screen.dart       # 充电主界面
│       │   │   ├── qr_scan_screen.dart        # 扫码界面（核心改动）
│       │   │   └── ...
│       │   └── admin_screens/
│       │       ├── station_charger_management_screen.dart # 站/桩管理
│       │       └── ...
│       ├── providers/
│       │   └── charging_provider.dart         # 充电状态管理
│       ├── services/api_service.dart          # 全部后端 API 调用
│       └── models/
│           ├── charger_model.dart             # 充电桩模型
│           └── charge_record_model.dart       # 充电记录模型
└── charging-station-compose/                  # Docker Compose
    └── init/
        ├── init.sql                           # DDL（生产 + 视图）
        └── seed.sql                           # 种子数据
```

## 八、交付物检查清单

| 步骤 | 改动文件清单 | 验证方法 |
|------|-------------|----------|
| **1. DDL** | `charging-station-compose/init/init.sql`, `seed.sql`, `usecase/docs/database/ddl.sql` | psql 导入后查表结构、查种子数据 |
| **2. Backend Entity** | `ChargerDevice.java`(新), `ChargerDeviceMapper.java`(新), `Charger.java`(改), `ChargerMapper.java`(改), `UserRole.java`(改) | `mvn compile` |
| **3. Backend Security** | `SecurityConfig.java`, `ChargingController.java`, `ChargerDeviceService.java`(新) | `mvn test` + 手动模拟 |
| **4. Backend Charging** | `ChargingServiceImpl.java`(改), `ChargerMapper.java`(增SQL) | `mvn test` |
| **5. Swing** | `ChargerUIPanel.java`, `ApiClient.java`, `QrCodeGenerator.java`, `ChargeSimulator.java`, `ChargerHttpServer.java` | `mvn compile` |
| **6. Flutter** | `charging_screen.dart`, `qr_scan_screen.dart`, `charging_provider.dart`, `api_service.dart` | `flutter test` |
| **7. Flutter Admin** | `station_charger_management_screen.dart`, `charger_model.dart`, `api_service.dart` | `flutter test` |
| **8. 测试** | 全部测试文件 + `测试方案与结果记录.md` | 全量 `mvn test` + `flutter test` |
| **9. Git** | 5 个仓库全部 commit + 主仓库更新子模块指针 | `git submodule status` 无 `+` 前缀 |

## 九、给下一位 Agent 的手册

### 9.1 关键文件索引

**充电流程核心链（按调用顺序）**:
1. Flutter `charging_screen.dart` → 用户操作
2. Flutter `api_service.dart` → HTTP 调用后端
3. Backend `ChargingController.java` → REST 入口
4. Backend `ChargingServiceImpl.java` → 业务逻辑（**核心**）
5. Backend `ChargerMapper.java` → 数据访问
6. Backend `ChargeRecordMapper.java` → 记录操作
7. Backend `HttpChargerConnector.java` → push 通知 Swing
8. Swing `ChargerHttpServer.java` → 接收通知
9. Swing `ChargeSimulator.java` → 模拟充电

### 9.2 数据库连接参数
```
Host: localhost:30001
DB: charging_station
User: cs_user
Pass: dev_password_123
重置命令: PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
导入DDL: PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station -f init/init.sql
导入种子: PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station -f init/seed.sql
```

### 9.3 编译命令
```bash
# Backend
cd charging-station-backend && mvn test

# Flutter
cd charging-station-client && flutter test

# Swing
cd charging-station-mock-ser-client && mvn compile
```

### 9.4 已知约束
- Swing 在 NAT 环境（无公网 IP），后端 push 通知到 Swing 的本地 ChargerHttpServer
- 后端到 Swing 的连接配置：`charger.mock.base-url=http://localhost:8081`（application.yml L86）
- `online_status DEFAULT 'OFFLINE'` 已完成，Swing 心跳上线后变 ONLINE
- Flutter 充电界面已过滤 MAINTENANCE 站 + OFFLINE 桩不可选
- init.sql 中种子数据和 seed.sql 有重复，当前已剥离（init.sql 纯 DDL，seed.sql 纯数据）

### 9.5 实施顺序依赖
```
DDL(1) → Backend Entity(2) → Backend Security(3) → Backend Charging(4)
                                                          ↓
                                                    Swing(5)  Flutter(6)  ← 可并行
                                                          ↓    ↓
                                                    Flutter Admin(7) ← 依赖(6)但改动小
                                                          ↓
                                                    测试(8) → Git(9)
```

## 十、回滚方案

若实施中出现不可修复的问题，按以下步骤回滚：
1. **DDL**: `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` + 重新导入旧版 init.sql
2. **Backend**: `git checkout -- src/`（回到改动前）
3. **Swing/Flutter**: `git checkout -- .`（回到改动前）
4. **测试**: 运行 `mvn test` + `flutter test` 确认回归

- **NAT 环境**: Swing 无公网 IP，Swing→Spring 通过心跳/API 轮询；Spring→Swing 通过主动 push 到 Swing 本地 ChargerHttpServer (localhost:8081)，所以 Spring 需要知道 Swing 内网地址或通过 Swing 先注册回调地址
  - **方案**: Swing 插枪时在 plug-in 请求中附带 `{callbackUrl: "http://<内网IP>:8081"}`，Spring 存储此地址用于后续通知
- **Android QR**: `mobile_scanner: ^6.0.2` 已依赖，需确保 Android camera 权限在 AndroidManifest.xml
- **数据库重置**: 每步 DDL 改动后需 `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` + 重新导入 init.sql + seed.sql
- **子模块同步**: 所有子仓库改动后需在主仓库 `git add <子模块目录>` + 提交以更新指针