# Round 45 — 5项修复 + DDL调整

> **日期**: 2026-06-13
> **状态**: 待实施
> **项目**: 新能源汽车充电站管理与数据分析系统

---

## 当前项目状态

- **架构**: Flutter(112t) + Spring Boot(231t) + PostgreSQL + Redis + Swing(compile ✅)
- **后端已运行**: localhost:8080
- **Git**: 5仓库全 main，无 detach，worktrees 已清理

---

## 问题分析

| # | 问题 | 根因 | 修复方案 |
|---|------|------|----------|
| 1 | **编辑资料500** + **管理员不能修改自己资料** | `updateUser` 服务层禁止 ADMIN/SUPER_ADMIN 编辑自身；`updateProfile` 可能因其他原因返回500 | 修改服务层允许自身编辑（仅禁用role变更）；增加日志以便排查500 |
| 2 | **离线充电桩仍显示"充电中"** | `checkOfflineChargers` 第一次扫描将桩标记OFFLINE+forceStop，但后续扫描跳过已OFFLINE的桩；`updateStatusConditionally` 返回值未检查 | 修改扫描条件：即使已OFFLINE但status=CHARGING也做forceStop；检查并记录条件更新结果 |
| 3 | **进入充电站列表多次刷新** + **show menu未实现Token重置** | `getChargerUsers` 返回类型错误（_handleResponse返回Map但方法声明List），导致`_chargerUsersMap`始终为空，Token重置永不生效 | 修复 `getChargerUsers` 正确解析JSON数组；添加loading guard防止并发加载 |
| 4 | **注册提示请求参数校验失败** | 后端返回大写status但admin screen用大写比较（后端实际用小写）→ 按钮全隐藏；**这是Issue 5的根因，与注册无关** | 修复admin screen状态比较为小写 |
| 5 | **报修管理-管理员不能打回/删除** | `reject` 仅从RESOLVED状态可调用；IN_PROGRESS无打回路径；admin screen缺"删除"按钮 | `close`扩展支持IN_PROGRESS；admin screen增加"拒绝"+"删除"按钮 |
| 6 | **DDL调整** | 项目中无SQL DDL文件，表结构由MyBatis注解隐式定义 | 检查现有schema定义，生成DDL脚本 |

---

## 详细修复方案

### Fix 1: 编辑资料500 + 管理员自身编辑限制

#### 1A. 后端: `UserServiceImpl.updateUser()` — 允许自身编辑

**当前代码** (lines 456-466):
```java
if (currentUserRole.equals("ADMIN")) {
    UserRole targetRole = target.getRole();
    if (targetRole == UserRole.ADMIN || targetRole == UserRole.SUPER_ADMIN) {
        throw BusinessException.forbidden("ADMIN不可修改其他ADMIN或SUPER_ADMIN");
    }
}
if (currentUserRole.equals("SUPER_ADMIN") && currentUserId.equals(id)) {
    throw BusinessException.forbidden("SUPER_ADMIN不可修改自身");
}
```

**修改后**:
```java
// ADMIN cannot modify other ADMIN or SUPER_ADMIN (but can modify self)
if (currentUserRole.equals("ADMIN") && !currentUserId.equals(id)) {
    UserRole targetRole = target.getRole();
    if (targetRole == UserRole.ADMIN || targetRole == UserRole.SUPER_ADMIN) {
        throw BusinessException.forbidden("ADMIN不可修改其他ADMIN或SUPER_ADMIN");
    }
}
// SUPER_ADMIN cannot modify other SUPER_ADMIN (but can modify self)
if (currentUserRole.equals("SUPER_ADMIN") && !currentUserId.equals(id)) {
    // Same check for other SUPER_ADMIN accounts
}
// Self-editing is allowed regardless of role
```

**注意**: 自身编辑时仍不可修改role，`UpdateUserRequest` 不包含role字段，所以天然安全。

#### 1B. 排查updateProfile的500

**方案**: 在 `updateProfile` 增加 try-catch 和详细日志；用 curl 测试定位具体错误。

```bash
# 测试命令
curl -v -X PUT http://localhost:8080/api/v1/users/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"测试","plateNumber":"京B·99999"}'
```

---

### Fix 2: 离线充电桩状态显示"充电中"

#### 2A. ChargingScheduler.checkOfflineChargers()

**当前代码** (line 56):
```java
if ("ONLINE".equals(charger.getOnlineStatus()) || charger.getOnlineStatus() == null) {
```

**修改后**:
```java
if ("ONLINE".equals(charger.getOnlineStatus()) || charger.getOnlineStatus() == null
    || "CHARGING".equals(charger.getStatus())) {
    // 即使已OFFLINE但状态仍为CHARGING，也需要做forceStop
```

这样即使第一次forceStop失败，后续扫描仍会尝试。

#### 2B. ChargingServiceImpl.forceStopByChargerId()

**当前代码** (line 630):
```java
chargerMapper.updateStatusConditionally(charger.getId(), "IDLE", "CHARGING");
```

**修改后**:
```java
int updated = chargerMapper.updateStatusConditionally(charger.getId(), "IDLE", "CHARGING");
if (updated == 0) {
    log.warn("forceStop: charger {} status was not CHARGING (already IDLE or FAULT)", charger.getId());
}
```

---

### Fix 3: 充电桩列表刷新 + Token重置

#### 3A. ApiService.getChargerUsers() — 修复返回类型

**当前代码** (api_service.dart lines 757-764):
```dart
static Future<List<Map<String, dynamic>>> getChargerUsers(String? stationId) async {
    final query = stationId != null ? '?stationId=$stationId' : '';
    final response = await _get(
      Uri.parse('$baseUrl/auth/charger-users$query'),
      headers: _headers(),
    );
    return await _handleResponse(response);  // BUG: _handleResponse returns Map, not List
}
```

**修改后**: 与 `getChargers` 同样的模式，从 `data['data']` 提取列表。

#### 3B. StationChargerManagementScreen — 添加loading guard

**新增** `_loadingStations` Set，防止快速点击导致并发加载：
```dart
Set<String> _loadingStations = {};

Future<void> _loadChargers(String stationId) async {
    if (_loadingStations.contains(stationId)) return;
    _loadingStations.add(stationId);
    try { ... } finally { _loadingStations.remove(stationId); }
}
```

---

### Fix 4: 注册提示"请求参数校验失败"

**这是一个误解** — 这个问题实际上是 Issue 5 的一部分（状态大小写不匹配导致的全部按钮不可见）。

#### 4A. 修复注册的captcha传递逻辑

**当前代码**: 即使 `_captchaId` 为空字符串，仍发送 `captchaId: ''` 到后端。

**修改后**: 当captcha未加载完成时，不发送captcha字段。

---

### Fix 5: 报修管理 — 管理员不能打回/删除

#### 5A. 修复状态比较（最关键的Bug）

**根因**: `RepairServiceImpl.listRepairs()` 返回 lowercase status (`r.getStatus().name().toLowerCase()`)，
但 `repair_management_screen.dart` 全部用 uppercase 比较（`r.status == 'OPEN'`）。

**所有比较改为 lowercase**:
```dart
r.status == 'open'
r.status == 'in_progress'
r.status == 'resolved'
r.status == 'deleted'
```

#### 5B. 扩展 `close` 支持从 IN_PROGRESS 关闭

**当前 SQL**:
```java
@Update("UPDATE repairs SET status = 'CLOSED', handled_at = now() WHERE id = #{id} AND status IN ('OPEN', 'RESOLVED')")
int close(UUID id);
```

**修改后**:
```java
@Update("UPDATE repairs SET status = 'CLOSED', handled_at = now() WHERE id = #{id} AND status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED')")
int close(UUID id);
```

#### 5C. Admin screen 增加"拒绝/直接关闭"和"删除"按钮

- **OPEN status**: 已有"直接关闭"按钮 → 保留
- **IN_PROGRESS status**: 新增"打回"按钮（使用 close）
- **DELETED status**: 已有"审批删除"按钮 → 保留
- **All non-DELETED statuses**: 新增"删除"按钮（调用 softDelete）

---

### Fix 6: DDL调整

**方案**: 检查 MyBatis 注解中定义的表结构，生成 DDL 脚本存入 `doc/database/schema.sql`。

---

## 实施步骤

### Step 1: 修复管理员自身编辑限制
- 文件: `UserServiceImpl.java` (lines 455-466)
- 修改 `updateUser` 方法中的权限校验逻辑

### Step 2: 修复离线充电桩状态滞留
- 文件: `ChargingScheduler.java` (line 56)
- 文件: `ChargingServiceImpl.java` (line 630)

### Step 3: 修复Token重置 + 充电桩列表刷新
- 文件: `api_service.dart` (lines 757-764, getChargerUsers)
- 文件: `station_charger_management_screen.dart` (新增loading guard)

### Step 4: 修复报修管理按钮不可见 + 增加打回/删除
- 文件: `repair_management_screen.dart` (all status comparisons)
- 文件: `RepairMapper.java` (close 支持 IN_PROGRESS)

### Step 5: 修复注册captcha逻辑
- 文件: `register_screen.dart` (仅在有有效captchaId时发送captcha字段)

### Step 6: DDL生成
- 分析mapper文件中定义的表结构
- 生成 `doc/database/schema.sql`

### Step 7: 验证
- 后端: `mvn test`
- Flutter: `flutter test`
- Swagger: 手动测试各端点

---

## 验证方法

```bash
# 后端测试
cd /mnt/data/charging-station-doc/code/charging-station-backend && mvn test

# Flutter测试
cd /mnt/data/charging-station-doc/code/charging-station-client && flutter test

# 编辑资料测试
curl -X PUT http://localhost:8080/api/v1/users/profile \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"测试","plateNumber":"京B·99999"}'

# 管理员编辑自己资料测试
curl -X PUT http://localhost:8080/api/v1/users/{id} \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"管理员自己修改","plateNumber":"京B·88888"}'
```

---

## Git 提交要求

- 一个 commit，末尾加 `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- 5 仓库全部提交，确保子模块指针同步