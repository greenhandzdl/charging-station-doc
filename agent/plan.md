# Round 43 — 8项Bug修复 + 充电离线处理 + 多车充电 + UI改进

> **日期**: 2026-06-12  
> **状态**: 待实施  
> **项目**: 新能源汽车充电站管理与数据分析系统

---

## 已知问题列表

| # | 问题 | 模块 | 优先级 | 描述 |
|---|------|------|--------|------|
| 1 | 离线桩自动扣费为0元 | Backend+Swing | P0 | 离线桩上充电被forceStopByChargerId标记ARREARS时energy=0/fee=0 |
| 2 | Flutter切换账号仍显示充电状态 | Flutter charging_provider | P0 | 充电状态跟账号走，切换后应清空 |
| 3 | 实时功率/费用模拟显示 | Flutter+Swing+Backend | P0 | 本地模拟充电功率+实时扣费显示，服务器只做截止时计算 |
| 4 | 充电桩列表重复显示 | Flutter charging_screen | P0 | 点击站时充电桩列表重复2次 |
| 5 | 报修管理缺"打回"功能 | Backend+Flutter | P0 | 维修人员误标完成后管理员可打回维修 |
| 6 | 编辑资料500 | Backend+Flutter | P0 | PUT /users/profile 返回500 |
| 7 | 注册验证提示不友好 | Flutter register | P0 | 校验失败时提示词生硬 |
| 8 | seed.sql mock_user应移除 | DDL | P1 | 模拟充电站功能已被charger_users替代 |

---

## 当前项目状态

- **架构**: Flutter(112t) + Spring Boot(231t) + PostgreSQL + Redis + Swing(compile ✅)
- **后端已运行**: localhost:8080 (新代码)
- **数据库**: 已重建(charger_users三级权限11行)
- **charger_users权限**: CHARGER(7) < STATION(3) < STATION_GLOBAL(1)
- **Git**: 5仓库全部committed, worktrees已清理
- **所有代码均在main分支**, 无detach

### 三级权限登录凭据(密码均为dev123)
- `station_global` — STATION_GLOBAL(全局模拟充电站,任意桩可操作)
- `station_chaoyang` / `station_haidian` / `station_pudong` — STATION
- `charger_cy_a01` ~ `charger_pd_b01` — CHARGER

---

## 实施步骤

### Step 1: 离线桩停止充电扣费修复

**文件**: `backend/.../ChargingServiceImpl.java:forceStopByChargerId()`

**问题**: `forceStopByChargerId` 调用 `estimateEnergyKwh` 时 `startTime` 可能为NULL,导致energy=0,fee=0,显示"自动扣费0元"

**修复**:
```java
// 当startTime为NULL时,用当前时间减去默认30分钟作为估算
if (record.getStartTime() == null) {
    // 默认按30分钟充电量计算
    BigDecimal minEnergy = type == FAST ? 30.0 : 3.5; // 30min * rate
    energyKwh = BigDecimal.valueOf(minEnergy);
} else {
    energyKwh = estimateEnergyKwh(charger.getType(), record.getStartTime());
}
```

**Swing端**: `MockChargerClient.onHeartbeatTick()` 断网时标记"离线停止充电"
- 当 `NetworkSimulator.isOffline()` 时,增加 `statusText` 显示"⚠ 离线中 — 充电已停止"

### Step 2: Flutter充电状态跟随账号

**文件**: `client/.../charging_provider.dart`
- `logout()` 或切换账号时清空 `_currentRecord` 和 `_chargers`
- 在 `auth_provider.logout()` 中调用 `chargingProvider.clear()`

**后端**: `GET /api/v1/charges` 过滤当前用户记录(已有逻辑,确认Flutter端调用)

### Step 3: 实时充电功率/费用模拟

**需求**: Flutter和Swing本地模拟充电过程(每1秒或5秒更新),服务器只在截止时计算最终费用。

**后端修改** — 新增端点 `GET /api/v1/charges/active?userId=xxx`:
- 返回当前用户所有PROCESSING状态的记录(支持多车充电)
- 返回绑定的充电桩的type(FAST/SLOW)和ratedPowerKw,供客户端本地计算
- `startCharge` 时需要记录start_time(当前只insert但不设start_time)

**Flutter修改** — `charging_provider.dart`:
- 启动充电后,本地模拟电量累计: `energy += (ratedPowerKw / 3600) * elapsedSeconds`
- 实时费用: `fee = energy * 1.5` (快充) 或 `fee = energy * 0.8` (慢充)
- 用户登录后立即调用 `GET /api/v1/charges/active`:
  - 如果有PROCESSING记录,获取chargerId→查type/ratedPowerKw
  - 从 `startTime` 开始本地计算当前电量/费用
  - 恢复实时显示,每5秒更新

**Flutter修改** — `charging_screen.dart`:
- 显示实时功率(kW)、已用电量(kWh)、当前费用(元)、充电时长
- 支持同时多车充电(用List显示多条)

**Swing修改** — 无需修改(已有本地模拟)

### Step 4: 充电桩列表重复

**文件**: `client/.../charging_screen.dart`
**问题**: 切换站时`_loadChargers`调用`fetchChargers`, provider里`_chargers = await ApiService.getChargers(...)`已是替换,但Widget Map了2次。

**修复**: 在 `setState` 中选择站前先清空 `_chargers`,检查provider无重复

```dart
// 在charging_screen onTap中:
setState(() {
  _selectedStation = station;
  _selectedCharger = null;
  // 清空充电桩列表,避免重复
});
_loadChargers(station.id);
```

**后端**: `GET /api/v1/chargers?stationId=xxx` 检查不会返回重复数据(目前是直接查DB,应该OK)

### Step 5: 报修管理 — 增加"打回"按钮

**后端**: 已有 `PUT /api/v1/repairs/{id}/reject` (RESOLVED→OPEN)
- 无需修改后端

**Flutter**: `admin_screens/repair_management_screen.dart`
- 对RESOLVED状态的报修单显示"打回"按钮
- 调用 `ApiService.rejectRepair(id, reason)`
- 打回后刷新列表

**Flutter**: `maintainer_workspace_screen.dart`
- 确认"标记完成"只能由MAINTAINER对自己负责的报修单操作

### Step 6: 编辑资料500修复

**问题**: `PUT /users/profile` 接收 `UpdateUserRequest` (name, plateNumber), 但Flutter多传了 `phone` 字段。后端可能拒绝多余字段或phone唯一冲突。

**后端修复**: `UserServiceImpl.updateProfile()` 只更新name和plateNumber,忽略phone。

**Flutter修复**: `profile_screen.dart` 的 `_showEditProfileDialog` 检查是否传了phone字段,phone不应被更新。

### Step 7: 注册验证提示优化

**文件**: `client/.../api_service.dart` 的 `register()` 和 `Flutter` 注册页面

**问题**: 后端返回的校验失败信息未友好展示。

**修复**: 
- 后端 `RegisterRequest` 的验证消息改为中文
- Flutter端 `_handleResponse` 展示原始错误 message

### Step 8: 移除seed.sql中的mock_user

**文件**: `compose/init/seed.sql` (line 13)
- 删除 `Mock充电机` 用户行
- 数据库重建验证

**文件**: `compose/init/init.sql` (line: users表)
- 删除 `COMMENT ON COLUMN users.role` 中关于CHARGER的描述(已无CHARGER角色)

**Swing**: `AppConfig.java` 默认改为 `station_global` (已完成,确认正确)
- Swing应该使用STATION_GLOBAL身份对所有充电桩操作
- 勾选充电桩→"应用"按钮保存状态(非自动选择)

---

## 验证方法

```bash
# Step 1: 离线扣费
curl -X POST http://localhost:8080/api/v1/auth/charger-login -H 'Content-Type: application/json' -d '{"loginId":"station_global","password":"dev123"}'
# 然后启动充电→模拟断网→确认扣费>0

# Step 6: 编辑资料
curl -X PUT http://localhost:8080/api/v1/users/profile \
  -H 'Authorization: Bearer <user_token>' \
  -H 'Content-Type: application/json' \
  -d '{"name":"新名字","plateNumber":"京B·99999"}'
```

## 编译测试
```bash
cd charging-station-backend && mvn test
cd charging-station-client && flutter test
cd charging-station-mock-ser-client && mvn compile
```

## DB重置
```bash
PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station -f init/init.sql
PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station -f init/seed.sql
```