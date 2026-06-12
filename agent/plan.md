# Round 42 — 充电桩身份重构(charger_users表) + 全部问题修复

> **日期**: 2026-06-12  
> **状态**: 待审批  
> **项目**: 新能源汽车充电站管理与数据分析系统

---

## 项目状态

- **架构**: Flutter + Spring Boot + PostgreSQL + Redis + Mock Swing
- **测试**: 后端 231 tests ✅ / Flutter 112 tests ✅ / Swing compile ✅
- **当前问题**: Round 41 引入的充电桩身份 + 充电流程重构存在多个 Bug 需要修复

### 已知 Bug 清单

| # | 问题 | 模块 | 优先级 |
|---|------|------|--------|
| 1 | Flutter 点击充电站重复显示充电桩 | Flutter charging_screen | P0 |
| 2 | 用户管理显示"充电机"用户(不应显示设备用户) | Flutter admin + Backend | P0 |
| 3 | 报修接口完全失败 + 充电桩编号信息未带入 | Flutter repair | P0 |
| 4 | 支付审批后仍显示"处理中"(列表未刷新) | Flutter payment_approval | P1 |
| 5 | 用户无个人信息修改入口 | Flutter profile_screen | P1 |
| 6 | 维修工作台异常 | Flutter maintainer | P1 |
| 7 | Swing 只能给 CY-A01 发心跳(不能选择指定桩) | Swing MockChargerClient | P0 |
| 8 | Swing 本地测试数据与后端 seed 数据不匹配 | Swing TestDataProvider | P0 |

### 新架构需求

| # | 需求 | 说明 |
|---|------|------|
| A | 新建 charger_users 表 | 替代 users 表中 role='CHARGER' 方式，存储充电桩设备登录身份 |
| B | 两种身份模式 | 单桩身份(只能登录指定桩) / 全局身份(可模拟任意桩，发心跳等) |
| C | 独立充电桩登录 API | 后端新增长押金设备登录端点(/api/v1/auth/charger-login)，不与 Flutter 用户登录共用 |
| D | DDL + seed 数据更新 | 清空数据库，重新验证新 DDL |

---

## 一、DDL 重构 — charger_users 表

### 新建 charger_users 表

```sql
CREATE TABLE charger_users (
    id UUID PRIMARY KEY,
    charger_id UUID REFERENCES chargers(id),           -- NULL 表示全局身份
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(32) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    identity_type VARCHAR(32) NOT NULL DEFAULT 'SINGLE'
        CHECK (identity_type IN ('SINGLE', 'GLOBAL')),
    is_active BOOLEAN DEFAULT true,
    allowed_charger_ids TEXT[],                         -- GLOBAL 身份可操作的充电桩 ID 列表
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP
);
```

### 数据迁移

- 将原来 users 表中的 mock_charger 用户迁移到 charger_users 表
- seed.sql 新增 charger_users 种子数据（7 个单桩身份 + 1 个全局身份）

### 后端 Entity

- 新建 `entity/ChargerUser.java`
- 新建 `mapper/ChargerUserMapper.java`
- 新建 `service/ChargerUserService.java`
- 新建 `dto/ChargerLoginRequest.java`

---

## 二、后端充电桩登录 API

### 新增端点

| 端点 | 方法 | 说明 | 权限 |
|------|------|------|------|
| `POST /api/v1/auth/charger-login` | POST | 充电桩设备登录(与用户登录完全分离) | permitAll |
| `GET /api/v1/charger-users/me` | GET | 获取当前充电桩身份信息 | 设备认证 |
| `POST /api/v1/charger-auth/refresh` | POST | 充电桩令牌刷新 | 设备认证 |

### 认证流程

```
1. Swing 调用 POST /api/v1/auth/charger-login
   Body: { "phone": "charger_cy_a01", "password": "dev123" }
2. 后端验证 charger_users 表，生成专用 JWT（scope=charger）
3. Swing 用此 token 调用心跳/插枪/拔枪等 API
4. 心跳端点检查 charger_id 权限（SINGLE 只能发自己桩的心跳，GLOBAL 可发任意）
```

### JWT 改造

新建 `ChargerTokenProvider.java`（或扩展 JwtTokenProvider）：
- charger JWT 包含字段：`sub=charger_user_id`, `chargerId=xxx`, `identityType=SINGLE|GLOBAL`, `scope=charger`
- 新增 `ChargerAuthFilter.java` — 解析 `charger_` 开头的 JWT，设置安全上下文

---

## 三、Swing 端重构

### AppConfig 更新

```java
public static final String CHARGER_PHONE = getEnvOrDefault("CHARGER_PHONE", "charger_cy_a01");
public static final String CHARGER_PASSWORD = getEnvOrDefault("CHARGER_PASSWORD", "dev123");
```

### MockChargerClient 更新

- login 流程改为调用 charger-login 端点
- 在 ChargerUIPanel 添加充电桩选择下拉框（选择以哪个身份登录/发心跳）
- 全局身份时，心跳对所有选中桩发送
- 单桩身份时，心跳只对指定桩发送

### 本地测试数据同步

- TestDataProvider.java 的充电桩数据与 seed.sql 完全一致

---

## 四、Flutter 问题修复清单

### 4.1 充电站重复显示充电桩

**文件**: `lib/providers/charging_provider.dart`
- `fetchChargers()` 中确保 `_chargers` 被替换而非追加

### 4.2 用户管理过滤设备用户

**文件**: `lib/screens/admin_screens/user_management_screen.dart`
- 用户列表不再显示 charger_users 中的设备账户

**后端**: `UserService.listUsers()` 确保 SQL 过滤掉非用户角色

### 4.3 报修修复

**文件**: `lib/screens/user_screens/repair_screen.dart`
- 进入报修界面时已获取充电桩编号信息
- 提交报修时附带 chargerCode

**文件**: `lib/screens/admin_screens/repair_management_screen.dart`
- 状态变更按钮正常工作（OPEN→IN_PROGRESS→RESOLVED→CLOSED）
- 支持模糊搜索（按充电桩编号/描述搜索）

### 4.4 支付审批刷新

**文件**: `lib/screens/admin_screens/payment_approval_screen.dart`
- 审批/拒绝后自动刷新列表

### 4.5 用户个人信息修改

**文件**: `lib/screens/user_screens/profile_screen.dart`
- 新增"编辑资料"按钮，可修改 name/phone/plate_number

**后端**: `UserController`
- 新增 `PUT /api/v1/users/profile` 端点（isAuthenticated 级别）
- 已有 `updateUser` 但仅 ADMIN/SUPER_ADMIN 可用

### 4.6 维修工作台修复

**文件**: `lib/screens/maintainer_screens/maintainer_workspace_screen.dart`
- 检查报修单加载、状态变更、接单/完成流程

---

## 五、实施步骤（按依赖顺序）

| # | 步骤 | 内容 | 仓库 |
|---|------|------|------|
| **1** | DDL 重构 | 新建 charger_users 表 + 迁移 mock_charger 数据 + 更新 seed.sql | compose + UML |
| **2** | Backend 充电桩登录 | ChargerUser Entity/Mapper/Service + charger-login 端点 + ChargerAuthFilter | backend |
| **3** | Swing 重构 | 改为 charger-login 认证 + 支持选择身份 + 支持多桩心跳 | mock-ser-client |
| **4** | Backend 用户端点 | PUT /users/profile (用户自修改) | backend |
| **5** | Flutter Bug 修复 | 重复桩/报修/支付/用户管理/Profile/维修台 全部修复 | client |
| **6** | 全量测试 | 重置数据库 + 验证 DDL + mvn test + flutter test + Swing compile | 所有 |
| **7** | Git 提交 | 所有仓库 commit + 子模块指针更新 | 所有 |

---

## 六、验证方法

### DDL 验证
```bash
PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station -f init/init.sql
PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station -f init/seed.sql
```

### 后端测试
```bash
cd charging-station-backend && mvn test
```

### Flutter 测试
```bash
cd charging-station-client && flutter test
```

### Swing 测试
```bash
cd charging-station-mock-ser-client && mvn compile
```

---

## 七、已知约束

- 后端需要重启才能加载新代码（`mvn spring-boot:run -q`）
- Swing 需要后端运行才能正常登录和通讯
- 数据库 DDL 修改后必须清空重建，不支持 ALTER 迁移
- charger_users 与 users 是两张独立的表，互不干扰
- Flutter 用户仍使用 `/api/v1/auth/login`，充电桩设备使用 `/api/v1/auth/charger-login`