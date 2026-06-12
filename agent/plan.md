# Round 43 — 8项修复 + 离线即结算 + 报修工作流 + 注册测试 + Swing全桩模拟

> **日期**: 2026-06-12  
> **状态**: ✅ 已完成（2026-06-12）  
> **项目**: 新能源汽车充电站管理与数据分析系统

---

## 设计澄清（重要）

| 概念 | 正确设计 | 说明 |
|------|----------|------|
| `users` 表的 `phone` | ✅ 保留不变 | Flutter 用户注册/登录用手机号 |
| `charger_users` 的 `login_id` | ✅ 正确设计 | 充电站/充电桩没有手机号，用 login_id 登录 |
| 三级权限 | ✅ 已实现 | CHARGER < STATION < STATION_GLOBAL |

---

## 已知问题列表（8项）

| # | 问题 | 模块 | 优先级 | 详细描述 |
|---|------|------|--------|----------|
| 1 | **离线桩停止充电扣费为0元** | Backend | P0 | `forceStopByChargerId` 检测到桩断线时应立即结算，但 `startTime` 可能为 NULL 导致 energy=0/fee=0，且未通知 Flutter 用户 |
| 2 | **Flutter 切换账号仍显示充电状态** | Flutter | P0 | 充电状态应跟账号走，切换后 `_currentRecord` 要清空 |
| 3 | **本地实时功率/费用模拟(含多车)** | Flutter+Backend | P0 | 本地模拟充电过程，服务器只做截止时计算。登录后先查是否有 PROCESSING 记录→拉 startTime/ratedPowerKw 本地恢复计算 |
| 4 | **充电桩列表重复显示** | Flutter | P0 | 点站时充电桩列表重复2次 |
| 5 | **报修工作流不完整** | Backend+Flutter | P0 | 维修人员可修改状态/删除(软删)，管理后台审批/打回/关闭 |
| 6 | **编辑资料500** | Backend+Flutter | P0 | Flutter 多传了 phone 字段导致冲突 |
| 7 | **注册验证提示 + 确保能注册** | Backend+Flutter | P0 | 验证消息改为中文，**必须做端到端注册测试** |
| 8 | **移除 seed.sql 中的 mock_user** | DDL | P1 | mock_user 功能已被 charger_users.STATION_GLOBAL 替代 |

---

## 当前项目状态

- **架构**: Flutter(112t) + Spring Boot(231t) + PostgreSQL + Redis + Swing(compile ✅)
- **后端已运行**: localhost:8080 (新代码)
- **数据库**: 已重建(charger_users 三级权限 11 行)
- **权限**: CHARGER(7) < STATION(3) < STATION_GLOBAL(1)
- **Git**: 5仓库全 main，worktrees 已清理，无 detach

### 三级权限登录凭据（密码均为 `dev123`）

| login_id | 权限 | 登录方式 | 说明 |
|----------|------|----------|------|
| `station_global` | **STATION_GLOBAL** | `POST /charger-login` → `X-Charger-Token` | Swing 默认身份，可重置任意下级 token，模拟所有充电桩 |
| `station_chaoyang` | **STATION** | `POST /charger-login` | 可重置旗下 CHARGER 的 token |
| `station_haidian` | **STATION** | `POST /charger-login` | 同上 |
| `station_pudong` | **STATION** | `POST /charger-login` | 同上 |
| `charger_cy_a01` ~ `pd_b01` | **CHARGER** | `POST /charger-login` | 只能操作绑定的单个充电桩 |
| `13800138002` | **ADMIN** | `POST /auth/login` (Flutter) | Flutter 用户用 phone+password |
| `13800138001` | **USER** | `POST /auth/login` (Flutter) | Flutter 普通用户 |

### 测试数据准备

```bash
# 用于编辑资料测试的用户 JWT
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138001","password":"zhang123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# 用于注册测试
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"测试用户","phone":"13999999999","password":"test123456","plateNumber":"京C·12345"}'
```

---

## 实施步骤（按依赖顺序）

---

### Step 1: 离线桩停止充电 → 立即结算 + 通知 Flutter + Swing 断线检测

#### 1A. 后端 `forceStopByChargerId` → 立即结算（扣费不为0）

**文件**: `ChargingServiceImpl.java:606` (forceStopByChargerId)

**修复**：当 `startTime == null` 时用默认值估算：
```java
// 在 forceStopByChargerId 中，计算 energy 前增加兜底逻辑
if (record.getStartTime() == null) {
    // 没有 startTime（早期流程缺陷），按30分钟估算
    // 快充 60kW/h → 30kWh, 慢充 7kW/h → 3.5kWh
    BigDecimal defaultKwh = charger.getType() == ChargerType.FAST 
        ? BigDecimal.valueOf(30.0) : BigDecimal.valueOf(3.5);
    energyKwh = defaultKwh;
} else {
    energyKwh = estimateEnergyKwh(charger.getType(), record.getStartTime());
}
```

#### 1B. 后端 → WebSocket 通知 Flutter（可选：先用轮询兜底）

**文件**: `ChargingScheduler.java` 的 `checkOfflineChargers()`

当前已有定时任务每60秒扫描离线桩 → 调用 `forceStopByChargerId`。但 Flutter 端需要实时感知。

**方案（简化）**: 
- 后端 `forceStopByChargerId` 结束时，将"被停止的 userId 列表"暂存到 Redis（`offline:notify:{userId} = true`，TTL=5min）
- Flutter 轮询 `GET /api/v1/charges/active` 时返回 `offlineStopped: true/false`
- 如果 `offlineStopped == true`，Flutter 弹出通知"充电桩已离线，充电已自动停止，扣费 xx 元"

**具体后端修改**:
- 在 `forceStopByChargerId` 末尾写 Redis key
- 新增 `GET /api/v1/charges/active` 端点（同时用于 Step 3）:
```java
// 返回用户当前进行中的充电记录 + 充电桩信息 + 离线通知标记
@GetMapping("/charges/active")
public ResponseEntity<Map<String, Object>> getActiveCharges(
        @AuthenticationPrincipal JwtUserPrincipal principal) {
    UUID userId = UUID.fromString(principal.getUserId());
    List<ChargeRecord> activeRecords = chargeRecordMapper.findByUserIdAndStatus(userId, "PROCESSING");
    // 如果没 active records，检查是否有离线通知
    boolean offlineStopped = redisTemplate.hasKey("offline:notify:" + userId) == Boolean.TRUE;
    return ResponseEntity.ok(Map.of(
        "activeRecords", activeRecords,
        "offlineStopped", offlineStopped
    ));
}
```

#### 1C. Swing 断线检测 + 自动结束充电状态

**文件**: `MockChargerClient.java`

- `onHeartbeatTick()` 中如果 `NetworkSimulator.isOffline()`:
  - 设置状态文字 "⚠ 离线中 — 充电已停止"
  - 如果 `chargeSimulator.isCharging()`，调用 `chargeSimulator.stopSimulation()` 并重置
  - 设置 `selectedChargerId = null`, `pluggedIn = false`
  - 显示最终费用结果

---

### Step 2: Flutter 充电状态跟随账号

**文件**: `charging_provider.dart`

```dart
void clear() {
  _currentRecord = null;
  _chargers = [];
  _stations = [];
  stopPolling();
  notifyListeners();
}
```

**文件**: `auth_provider.dart` → `logout()` 方法中调用 `chargingProvider.clear()`:
```dart
// 在 auth_provider 中注入 ChargingProvider
final chargingProvider = ref.read(chargingProvider);
chargingProvider.clear();
```

---

### Step 3: 本地实时功率/费用模拟（支持多车充电）

#### 3A. 后端：`GET /api/v1/charges/active` — 返回当前用户所有 PROCESSING 记录

**文件**: `ChargingController.java` / `ChargingService.java`

```java
// ChargingController 新增
@GetMapping("/charges/active")
@PreAuthorize("isAuthenticated()")
public ResponseEntity<List<Map<String, Object>>> getActiveCharges(
        @AuthenticationPrincipal JwtUserPrincipal principal) {
    UUID userId = UUID.fromString(principal.getUserId());
    List<Map<String, Object>> activeCharges = chargingService.getActiveChargesWithChargerInfo(userId);
    return ResponseEntity.ok(activeCharges);
}
```

返回格式：
```json
[
  {
    "recordId": "...",
    "chargerId": "...",
    "chargerCode": "CY-A01",
    "type": "FAST",
    "ratedPowerKw": 60.00,
    "startTime": "2026-06-12T10:00:00",
    "status": "PROCESSING"
  },
  ...
]
```

#### 3B. Flutter `charging_provider.dart` — 本地模拟引擎

```dart
class LocalChargeSimulation {
  String recordId;
  String chargerId;
  String chargerCode;
  String type;          // FAST or SLOW
  double ratedPowerKw;
  DateTime startTime;
  double energyKwh;     // 本地累计
  double fee;           // 本地累计
  Timer? _tickTimer;
}
```

- `startLocalSimulation(...)` → 启动每5秒的 Timer，`energy += (ratedPowerKw / 3600) * 5`
- `resumeFromBackend(...)` — 登录后检查是否有 PROCESSING 记录：
  - 如果有，用 `startTime` 计算已充电时长，`energy = (ratedPowerKw / 3600) * elapsedSeconds`
  - 恢复本地模拟
- 支持多个 LocalChargeSimulation 实例（多车充电）

#### 3C. Flutter `charging_screen.dart` — 实时显示

- 用 ListView 显示多条充电记录
- 每条显示：充电桩编号、实时功率(kW)、已用电量(kWh)、当前费用(元)、已充时长
- 结束充电调用 `POST /charges/stop`（后端算最终费用）

---

### Step 4: 充电桩列表重复

**文件**: `charging_screen.dart`

**问题分析**：`_loadChargers(station.id)` 中 `setState` 选择站时没有立即清空旧的 `_chargers` 列表。虽然 provider 里 `fetchChargers` 是替换，但在异步加载完成前 Widget 重新构建时可能同时展示新旧数据。

**修复**：
```dart
onTap: () {
  setState(() {
    _selectedStation = station;
    _selectedCharger = null;
  });
  // 立即清空 provider 的 chargers 列表
  context.read<ChargingProvider>().clearChargers();
  _loadChargers(station.id);
}
```

在 `charging_provider.dart` 新增：
```dart
void clearChargers() {
  _chargers = [];
  notifyListeners();
}
```

---

### Step 5: 报修工作流完整设计

当前状态流: `OPEN → IN_PROGRESS → RESOLVED → CLOSED`

#### 5A. 维修人员（MAINTAINER）能力

| 操作 | 端点 | 状态变化 | 说明 |
|------|------|----------|------|
| 接单 | `PUT /repairs/{id}/claim` | OPEN → IN_PROGRESS | 维修工认领报修单 |
| 标记完成 | `PUT /repairs/{id}/resolve` | IN_PROGRESS → RESOLVED | 维修完成等待审核 |
| 删除 | `PUT /repairs/{id}/delete` | 任何状态 → DELETED | 软删除（修改 status='DELETED'），**需管理后台审批** |
| 修改说明 | `PUT /repairs/{id}/description` | 任何状态 | 更新描述 |

#### 5B. 管理员（ADMIN/SUPER_ADMIN）能力

| 操作 | 端点 | 状态变化 | 说明 |
|------|------|----------|------|
| 分配 | `PUT /repairs/{id}/assign` | OPEN → IN_PROGRESS | 指派给指定维修工 |
| 打回 | `PUT /repairs/{id}/reject` | RESOLVED → OPEN | 维修不达标打回重做 |
| 关闭 | `PUT /repairs/{id}/close` | RESOLVED → CLOSED | 维修达标，关闭工单 |
| 审核删除 | `PUT /repairs/{id}/approve-delete` | DELETED → 永久删除 | 审批通过后物理删除 |
| 直接关闭 | `PUT /repairs/{id}/close` | OPEN → CLOSED | 无需维修直接关 |

#### 5C. 后端修改

1. **枚举添加 `DELETED`**（RepairStatus.java）:
```java
public enum RepairStatus {
    OPEN, IN_PROGRESS, RESOLVED, CLOSED, DELETED
}
```

2. **新增端点** `PUT /repairs/{id}/delete`（维修人员软删除）:
```java
@PutMapping("/repairs/{id}/delete")
@PreAuthorize("hasAnyRole('MAINTAINER', 'ADMIN')")
public ResponseEntity<Map<String, String>> deleteRepair(@PathVariable UUID id,
        @AuthenticationPrincipal JwtUserPrincipal principal) {
    repairService.softDelete(id, UUID.fromString(principal.getUserId()), principal.getRole());
    return ResponseEntity.ok(Map.of("message", "已申请删除"));
}
```

3. **新增端点** `PUT /repairs/{id}/approve-delete`（管理员审批删除）:
```java
@PutMapping("/repairs/{id}/approve-delete")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
public ResponseEntity<Map<String, String>> approveDelete(@PathVariable UUID id) {
    repairService.approveDelete(id);
    return ResponseEntity.ok(Map.of("message", "已永久删除"));
}
```

#### 5D. Flutter 修改

- `maintainer_workspace_screen.dart`: 增加"删除"按钮（弹出确认+输入原因）
- `admin_screens/repair_management_screen.dart`: 
  - RESOLVED → 显示"打回"和"关闭"按钮
  - DELETED → 显示"审批删除"按钮（仅管理员可见）
  - 增加"维修记录归档"标签页

---

### Step 6: 编辑资料500修复

**问题根因**: 
- Flutter `profile_screen.dart` 的 `updateProfile` 调用传了 `phone` 字段
- 后端 `UpdateUserRequest` 只有 `name` 和 `plateNumber`，没有 `phone`
- 后端 `UserServiceImpl.updateProfile()` 只更新 name/plateNumber，但 Flutter 传来的 phone 字段可能被 Jackson 忽略或触发某种错误

**后端修复**: `UpdateUserRequest.java` 不需要改（它本来就不含 phone）。检查 `UserServiceImpl.updateProfile` 中的 `userMapper.update()` 是否正确处理。

**Flutter修复**:
```dart
// profile_screen.dart — 确认传给 API 的 body：
await ApiService.updateProfile({
  'name': name,
  'plateNumber': plate,  // 不要传 phone！
});
```

**验证**:
```bash
# 获取用户 token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138001","password":"zhang123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# 测试编辑资料（不带 phone）
curl -s -X PUT http://localhost:8080/api/v1/users/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"张三","plateNumber":"京B·99999"}' | python3 -m json.tool
```

---

### Step 7: 注册验证提示优化 + 注册测试

#### 7A. 后端验证消息改为中文

**文件**: `RegisterRequest.java`
```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegisterRequest {

    @NotBlank(message = "姓名不能为空")
    private String name;

    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String phone;

    @NotBlank(message = "密码不能为空")
    @Size(min = 6, message = "密码长度至少6位")
    private String password;

    private String plateNumber;

    private String captchaId;

    private String captchaCode;
}
```

#### 7B. Flutter 错误展示优化

**文件**: `api_service.dart` 的 `_handleResponse()` 和 `register()` 调用处

确保 `_handleResponse` 返回的 message 直接展示给用户（不要包装成 "请求参数校验失败"）。

```dart
// 在 register 调用处，用中文提示
try {
  await ApiService.register(name, phone, password, plateNumber,
      captchaId: captchaId!, captchaCode: captchaCode!);
} on ApiException catch (e) {
  // e.message 已经是后端返回的中文错误
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message)),
  );
}
```

#### 7C. 注册端到端测试步骤

```bash
# 1. 获取验证码（如果没有绕过的话）
# 当前验证码是 mock 模式（固定 0000），直接注册即可

# 2. 注册测试
curl -v -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "测试用户",
    "phone": "13900000001",
    "password": "test123456",
    "plateNumber": "京Z·99999"
  }'

# 期望: 201 Created + {"message":"注册成功"}

# 3. 测试重复手机号 → 应返回错误提示
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"重复","phone":"13900000001","password":"test123456"}' | python3 -m json.tool

# 4. Flutter 模拟器中实际测试注册流程
```

---

### Step 8: 移除 seed.sql 中的 mock_user + Swing 完善

#### 8A. 删除 seed.sql 中的 mock_user

```sql
-- 删除这一行（line 13-15）:
-- ('a0000000-0000-4000-8000-000000000001', 'Mock充电机', 'mock_user', '模拟-00001',
--  '$2a$10$o8zYr4NJFAo555ZiBPRRj.mKaDJkCQ0.NW.BVzl0sAlVmoE.sZZb6',
--  'USER', 100.00),
```

减少为4个用户（张三 + 管理员 + 维修工 + 超级管理员）。

#### 8B. Swing — 全局充电站身份，选择充电桩 → 应用模式

**Swing 当前状态**：已使用 `station_global` 登录（STATION_GLOBAL），但充点桩选择逻辑不够完善。

**改进**：
1. `ChargerUIPanel` / `MockChargerClient`：充电桩下拉框 → 勾选 + "应用"按钮
   - 勾选要模拟的充电桩（多选）
   - 点击"应用"保存选择状态
   - 心跳/插枪/拔枪只对已"应用"的充电桩执行

2. 当 STATION_GLOBAL 身份时，可以调用 `POST /api/v1/auth/charger-reset-token/{id}` 重置下级 token（例如重置 station_chaoyang 或 charger_cy_a01 的 token）
   - 新增"重置 Token"按钮
   - 选择下级身份 → 点击重置 → 返回新 token → 显示在界面

3. **Swing 离线断线处理**:
   - `onHeartbeatTick()` 中检测到断线 → 立即停止所有模拟充电
   - 状态文字更新: "⚠ 离线 — 已停止所有充电"
   - 调用 `chargeSimulator.stopSimulation()` 显示最终结果

---

## 验证方法

### Step 1 — 离线扣费验证
```bash
# 1. STATION_GLOBAL 登录
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/charger-login \
  -H 'Content-Type: application/json' \
  -d '{"loginId":"station_global","password":"dev123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# 2. 查看离线桩上的充电记录
# forceStopByChargerId 在 ChargingScheduler 每60秒自动触发
# 检查扣费金额不为0
curl -s http://localhost:8080/api/v1/charges \
  -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json; records=json.load(sys.stdin); [print(r.get('fee'), r.get('energyKwh'), r.get('status')) for r in records[:5]]"
```

### Step 6 — 编辑资料验证
```bash
USER_TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138001","password":"zhang123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")
curl -s -X PUT http://localhost:8080/api/v1/users/profile \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"张三测试","plateNumber":"京B·99999"}' | python3 -m json.tool
```

### Step 7 — 注册测试
```bash
curl -v -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"注册测试","phone":"13988880001","password":"pass123456","plateNumber":"京N·88888"}'
```

### 全量测试
```bash
cd charging-station-backend && mvn test
cd charging-station-client && flutter test
cd charging-station-mock-ser-client && mvn compile
```

### DB 重置
```bash
PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station \
  -f code/charging-station-compose/init/init.sql
PGPASSWORD=dev_password_123 psql -h localhost -p 30001 -U cs_user -d charging_station \
  -f code/charging-station-compose/init/seed.sql
```

---

## Git 提交要求

- 最小化增量 commit（每个 Step 一个 commit，如果关联性强可合并）
- 每个 commit 末尾加 `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- 5 仓库全部提交，确保子模块指针同步
- 所有 worktrees/detach 清理干净（当前已清理）