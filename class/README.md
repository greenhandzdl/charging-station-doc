# 类图

充电站管理系统核心类及其关系设计。按 **前端（Flutter/Dart Model）** 与 **后端（Spring Boot Java）** 分层组织。

## 图

### 类图总览

![充电站管理系统类图总览](img/class_diagram.svg)

展示前后端分层架构及 HTTP REST API 边界。

### 前端类图

![前端类图 (Flutter/Dart)](img/frontend_class_diagram.svg)

包含 Flutter Model 类、ApiService（HTTP 封装）、AuthProvider（认证状态管理）、ChargingProvider（充电业务状态管理）、RepairProvider（报修状态管理）。

### 后端类图

![后端类图 (Spring Boot Java)](img/backend_class_diagram.svg)

包含实体（Entity）、枚举（Enum）、服务（Service）、策略（PricingStrategy）、工厂（PaymentFactory）及完整的关系依赖。

## 核心类

### 前端层（Flutter / Dart Model）

| 类 | 层 | 职责 |
|----|----|------|
| UserModel | 前端层 | 用户信息展示（不含敏感字段） |
| StationModel | 前端层 | 充电站列表与状态展示 |
| ChargerModel | 前端层 | 充电桩状态展示 |
| ChargeRecordModel | 前端层 | 充电记录快捷视图 |
| PaymentModel | 前端层 | 支付记录展示 |
| RepairModel | 前端层 | 报修单展示 |
| ApiService | 服务层 | HTTP REST 封装，JWT 自动附加 |
| AuthProvider | 状态管理 | 认证状态，ChangeNotifier 实现 |
| ChargingProvider | 状态管理 | 充电业务状态（含充电中轮询，每5秒更新电量/费用） |
| RepairProvider | 状态管理 | 报修业务状态 |

### Mock充电机客户端（Swing）

| 类 | 层 | 职责 |
|----|----|------|
| MockChargerClient | 客户端主类 | Swing 桌面客户端主入口，包含 JFrame 主窗口，管理 ChargerUIPanel、ChargeSimulator 和 ChargerHttpServer |
| ChargerUIPanel | Swing 面板 | 提供插枪/拔枪按钮 (JButton)、充电进度条 (JProgressBar)、状态标签 (JLabel)、电量/费用/时长显示标签等 UI 组件，模拟充电机显示屏 |
| ChargeSimulator | 模拟引擎 | 模拟电量增长（0.1kWh/秒），记录充电时长，提供启动/停止/查询接口，支持峰谷定价 |
| ChargerHttpServer | 嵌入式 HTTP 服务 | 监听 localhost:8081，接收 Spring 后端推送的 notifyStart/notifyStop 通知 |

### 后端层（Spring Boot Java）

| 类 | 层 | 职责 |
|----|----|------|
| Station | 实体 | 充电站信息与运营状态 |
| Charger | 实体 | 充电桩信息与运行状态（含 onlineStatus/lastHeartbeatAt 在线检测字段） |
| User | 实体 | 用户信息、角色、余额（含 passwordHash） |
| ChargeRecord | 实体 | 充电记录与扣费状态 |
| Payment | 实体 | 支付流水与回调数据 |
| Repair | 实体 | 报修单流转 |
| AuditLog | 实体 | 关键操作审计记录 |
| ChargerUser | 实体 | 充电桩站设备身份，三级权限体系（CHARGER/STATION/STATION_GLOBAL） |
| ChargingService | 服务接口 | 充电业务逻辑（启动/结束/计费/强制结束） |
| ChargingServiceImpl | 服务实现 | ChargingService 实现类 |
| PaymentService | 服务接口 | 支付业务逻辑（充值/回调/自动扣费） |
| PaymentServiceImpl | 服务实现 | PaymentService 实现类 |
| RepairService | 服务接口 | 报修业务逻辑（提交/指派/处理） |
| RepairServiceImpl | 服务实现 | RepairService 实现类 |
| UserService | 服务接口 | 用户业务逻辑（登录/注册/充值） |
| UserServiceImpl | 服务实现 | UserService 实现类 |
| StatisticsService | 服务接口 | 统计业务（报表/使用率分析） |
| StatisticsServiceImpl | 服务实现 | StatisticsService 实现类 |
| PricingStrategy | 策略 | 计费策略接口 |
| StandardPricing | 策略 | 标准计费（1.5元/度） |
| PaymentFactory | 工厂 | 支付方式工厂 |
| PaymentChannel | 工厂 | 支付通道接口 |
| CaptchaService | 服务接口 | 验证码生成与校验接口 |
| RedisCaptchaService | 服务实现 | Redis 存储的验证码服务实现（含 AWT 图片生成） |
| SmsService | 服务接口 | 短信验证码服务接口 |
| RedisSmsService | 服务实现 | Redis 存储的短信验证码服务实现 |
| ChargerUserService | 服务接口 | 充电桩站设备身份业务逻辑（登录/Token重置/列表查询） |
| ChargerUserServiceImpl | 服务实现 | ChargerUserService 实现类 |

## 枚举

| 枚举 | 用途 | 值 |
|----|------|-----|
| StationStatus | 充电站运营状态 | NORMAL / MAINTENANCE |
| ChargerType | 充电桩类型 | FAST / SLOW |
| ChargerStatus | 充电桩运行状态 | IDLE / CHARGING / FAULT |
| UserRole | 用户角色 | USER / MAINTAINER / ADMIN / SUPER_ADMIN |
| RecordStatus | 充电过程状态 | PROCESSING / COMPLETED |
| DeductionStatus | 扣费状态 | PENDING / PAID / ARREARS |
| PaymentStatus | 支付状态 | PENDING / APPROVED / SUCCESS / FAILED |
| RepairStatus | 报修单状态 | OPEN / IN_PROGRESS / RESOLVED / CLOSED / DELETED |

## 核心关系

- Station 1:N Charger（充电站包含充电桩）
- User 1:N ChargeRecord（用户发起充电）
- Charger 1:N ChargeRecord（充电桩被使用）
- User 1:N Payment（用户支付）
- User 1:N Repair（用户报修/处理）
- ChargeRecord 1:0..1 Payment（充电产生支付）
- User 1:N AuditLog（用户操作记录）
- ChargerUser --> Charger（设备身份绑定充电桩）
- ChargerUser --> Station（站级权限管理充电站）
- ChargerUser 1:0..1 ChargerUser（上级权限链 parent_id）
- MockChargerClient --> ChargerUIPanel（包含 Swing 面板）
- MockChargerClient --> ChargeSimulator（模拟引擎）
- MockChargerClient --> ChargerHttpServer（内嵌 HTTP 服务接收通知）
- ChargerHttpServer ..> ChargerUIPanel（回调更新 UI：电量/费用/进度条）
- MockChargerClient --> ChargingController（HTTP调用后端 API）
- 后端 ChargerConnector -- POST/通知 --> Swing ChargerHttpServer（充电启停推送）
- 前端 Model ←→ API 后端通过 HTTP REST JSON 传输
- Service 类 ..> 实体类（服务依赖实体）
- ChargingService --> PricingStrategy（策略模式）
- PaymentFactory ..> PaymentChannel（工厂模式）
- CaptchaService ..> RedisTemplate（验证码 Redis 存储校验）
- SmsService ..> RedisTemplate（短信验证码 Redis 存储校验）

## 设计模式

- **策略模式**：PricingStrategy 接口与 StandardPricing/PeakPricing 实现，用于灵活切换计费策略（标准/峰谷定价）
- **工厂模式**：PaymentFactory 根据支付方式类型创建不同的支付通道（微信/支付宝/系统自动扣费）
- **三级权限链**：ChargerUser 通过 parent_id 和 token_version 实现设备身份的层级授权与 Token 失效传播

## 设计要点

- **前后端分离**：前端通过 HTTP REST API 与后端通信，通过 JSON 交换数据，JWT Token 认证。
- **Flutter 状态管理**：AuthProvider/ChargingProvider/RepairProvider 基于 ChangeNotifier 模式，驱动 UI 重建。
- **ApiService 单例**：统一管理 HTTP 请求、Token 附加、错误处理，所有请求返回 Future 异步模型。
- **实体完整字段**：后端实体包含所有持久化字段（外键、哈希值、时间戳），并引入 DeductionStatus 枚举独立追踪扣费状态。
- **Service 层**：封装业务逻辑，不直接暴露实体给 Controller。
- **枚举独立包**：所有枚举集中管理，便于跨实体复用。

## 源文件

- `src/class_diagram.puml` — 类图总览 PlantUML 源文件
- `src/frontend_class_diagram.puml` — 前端类图 PlantUML 源文件
- `src/backend_class_diagram.puml` — 后端类图 PlantUML 源文件

## 相关文档

- [用例总览](../usecase/docs/overview/usecases.md) — 用例定义与参与者
- [数据库设计](../usecase/docs/database/db.md) — 表结构对应类属性