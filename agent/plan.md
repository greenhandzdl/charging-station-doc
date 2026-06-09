# 第37轮 — 交互逻辑完善 + Captcha Service抽取 + 测试闭环

---

## 第一阶段：基础设施抽取（并行）

### 1.1 验证码 Service 抽取 + 必填校验

**文件：** `CaptchaService.java`, `RedisCaptchaService.java`, `CaptchaController.java`, `UserServiceImpl.java`

- `CaptchaService` 接口：`generateCaptcha(): CaptchaResult`, `validateCaptcha(captchaId, captchaCode): boolean`
- `RedisCaptchaService` 实现：Redis 存储/校验逻辑从 Controller 剥离
- `CaptchaController` 注入 Service，精简
- `UserServiceImpl.register()`：`validateCaptcha` 改为必填（空值抛 BusinessException）
- 文档标注 captcha 为 mock 实现

### 1.2 Swing HTTP Server 接收通知

**文件：** `ChargerHttpServer.java`（新建）, `MockChargerClient.java`, `ChargerUIPanel.java`

- 嵌入式 `HttpServer`，监听 `localhost:8081`
- `POST /api/notify/start`：连接 ChargeSimulator + 更新 UI 进度条/电量/费用
- `POST /api/notify/stop`：停止模拟 + 显示结算结果
- Swing 标题栏显示 HTTP Server 状态
- `ChargeSimulator` 接入 UI（每秒 tick 更新）

### 1.3 Flutter 验证码必填

**文件：** `register_screen.dart`, `login_screen.dart`

- 验证码输入框始终显示（移除条件判断）
- `(mock)` 标签保留

---

## 第二阶段：交互逻辑核心（并行）

### 2.1 Swing 拔枪 → 自动结束充电

**文件：** `MockChargerClient.java`, `ChargerUIPanel.java`, `ApiClient.java`

- 拔枪时检查是否有 PROCESSING 充电记录
- 有则调用 `POST /charges/stop` 通知 Spring
- 显示结算结果（电量、费用）

### 2.2 Flutter 充电中轮询

**文件：** `charging_screen.dart`, `charging_provider.dart`

- 充电中每 5 秒 `GET /charges?recordId=xxx`
- 更新 energyKwh/fee 显示
- COMPLETED 停止轮询，显示结果

### 2.3 Spring 离线自动停

**文件：** `ChargingScheduler.java`, `ChargingServiceImpl.java`

- `checkOfflineChargers()`：标记 OFFLINE 前检查是否有 PROCESSING 记录
- 有则调用 `forceStop()`（actor_type=SYSTEM）

---

## 第三阶段：验证 + 文档

### 3.1 测试验证
- `mvn test`（后端 62+ 项）
- `flutter build web`
- Swing `mvn package`

### 3.2 文档更新
- 类图补 Swing HttpServer
- 时序图补拔枪结束 + 离线自动停
- 文档标注 captcha mock

### 3.3 清理 + 提交

---

## 验证标准

| 场景 | 预期 |
|------|------|
| Swing 选桩 → 插枪 → 生成 QR | QR 含 chargerId JSON |
| Flutter 扫码 → 启动充电 | Spring 创建记录，Swing 收到 notifyStart |
| Swing 充电中显示 | 进度条 + 电量 + 费用实时更新 |
| Flutter 充电中轮询 | 每 5 秒更新电量/费用 |
| Swing 拔枪 | 自动调用 stopCharge，显示结算 |
| 充电桩断连 > 60s | Spring 自动停止充电 + 标记 OFFLINE |
| 注册验证码为空 | 返回 400，不静默通过 |
| mvn test | 全部通过 |
| flutter build web | 构建成功 |