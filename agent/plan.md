# 第38轮 — 边界测试全面覆盖 + 文档同步

---

## 一、后端边界测试（新增 20+ 项）

### 1.1 CaptchaService 测试（新建 `CaptchaServiceTest.java`）
| # | 测试用例 | 预期 |
|---|---------|------|
| T1 | generateCaptcha 返回有效 captchaId 和 image | captchaId 非空，image 是 base64 或空 |
| T2 | validateCaptcha 正确验证码返回 true | 正确 code → true |
| T3 | validateCaptcha 错误验证码返回 false | 错误 code → false |
| T4 | validateCaptcha 过期验证码返回 false | 等待 TTL 后验证 → false |
| T5 | validateCaptcha 空参数返回 false | null/空字符串 → false |

### 1.2 UserService 边界测试（在 UserServiceTest 新建或补充）
| # | 测试用例 | 预期 |
|---|---------|------|
| T6 | register 空验证码抛异常 | captchaId=null → BusinessException "验证码不能为空" |
| T7 | register IP 限流超过 3 次 | 第4次 → tooManyRequests |
| T8 | register 手机号每日限流 | 第2次同手机号 → tooManyRequests |
| T9 | register 密码强度不足 | 8位纯数字 → badRequest |
| T10 | register 手机号已注册 | 重复 phone → conflict |
| T11 | login 连续失败 5 次触发验证码 | 5 次失败后需要 captcha |
| T12 | login 连续失败 10 次锁账户 | 10 次 → accountLocked |
| T13 | login 成功后重置失败计数 | 成功后 failedLoginAttempts = 0 |
| T14 | balance 恰好为 10.00 元启动充电 | 允许启动 |
| T15 | balance 为 9.99 元启动充电 | 拒绝 |
| T16 | changeRole ADMIN 不可修改 SUPER_ADMIN | 抛 forbidden |
| T17 | changeRole SUPER_ADMIN 不可修改自身 | 抛 forbidden |

### 1.3 充电调度测试（新建 `ChargingSchedulerTest.java`）
| # | 测试用例 | 预期 |
|---|---------|------|
| T18 | checkOfflineChargers 标记过期心跳为 OFFLINE | lastHeartbeatAt > 60s → OFFLINE |
| T19 | checkOfflineChargers 跳过活跃桩 | lastHeartbeatAt < 60s → 仍 ONLINE |
| T20 | checkOfflineChargers 自动停止离线桩的充电记录 | OFFLINE 且有 PROCESSING 记录 → auto-stop |
| T21 | checkInsufficientBalance 余额不足自动停 | balance < 10 → auto-stop |

### 1.4 并发测试（新建 `ConcurrentChargingTest.java`）
| # | 测试用例 | 预期 |
|---|---------|------|
| T22 | 同一桩被两个用户同时启动 | 只有一个成功，另一个收到冲突 |
| T23 | 同一用户不能同时启动两笔充电 | 第二笔抛 BusinessException |

---

## 二、Flutter 测试补充

### 2.1 Provider 测试
| # | 测试用例 | 文件 |
|---|---------|------|
| F1 | ChargingProvider 启动充电时开始轮询 | `charging_provider_test.dart` |
| F2 | ChargingProvider 停止充电时停止轮询 | `charging_provider_test.dart` |
| F3 | ChargingProvider 轮询到 COMPLETED 自动停止 | `charging_provider_test.dart` |

### 2.2 Screen 测试（补充）
| # | 测试用例 | 文件 |
|---|---------|------|
| F4 | register_screen 验证码始终显示 | `register_screen_test.dart` |
| F5 | charging_screen 充电中显示实时状态 | `charging_screen_test.dart` |

---

## 三、Swing 测试补充

| # | 测试用例 | 文件 |
|---|---------|------|
| S1 | ChargeSimulator 每秒增加 0.1kWh | `ChargeSimulatorTest.java` |
| S2 | ChargeSimulator 不超过 50.0 kWh 上限 | `ChargeSimulatorTest.java` |
| S3 | ChargerHttpServer 接收通知后触发 callback | `ChargerHttpServerTest.java`（新建） |

---

## 四、文档同步（如有实现变更）

- 时序图：补充离线自动停 + 拔枪结束场景
- 状态图：确认与充电桩状态流转一致

---

## 五、执行策略

1. **Round 1**（并行）：后端所有新增测试 + Flutter 补充测试 + Swing 补充测试
2. **Round 2**：`mvn test` 全部通过 + `flutter build web`
3. **Round 3**：文档同步 + 渲染
4. **Round 4**：失败修复循环
5. **提交**