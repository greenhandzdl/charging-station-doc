# 类图

充电站管理系统核心类及其关系设计。

## 图

![充电站管理系统类图](img/class_diagram.svg)

## 核心类

| 类 | 所属包 | 职责 |
|----|--------|------|
| Station | 基础信息 | 充电站信息与状态 |
| Charger | 基础信息 | 充电桩信息与状态 |
| User | 用户与权限 | 用户信息与余额 |
| ChargeRecord | 充电业务 | 充电记录 |
| Payment | 支付 | 支付流水 |
| Repair | 报修 | 报修单流转 |
| AuditLog | 审计 | 关键操作审计记录 |
| ChargingService | 业务服务 | 充电业务逻辑（启动/结束/计费） |
| PaymentService | 业务服务 | 支付业务逻辑（充值/回调/自动扣费） |
| RepairService | 业务服务 | 报修业务逻辑（提交/指派/处理） |
| UserService | 业务服务 | 用户业务逻辑（登录/注册/充值） |
| PricingStrategy | 策略 | 计费策略接口 |
| StandardPricing | 策略 | 标准计费（1.5元/度） |
| PaymentFactory | 工厂 | 支付方式工厂 |
| PaymentChannel | 工厂 | 支付通道接口 |

## 核心关系

- Station 1:N Charger（充电站包含充电桩）
- Station --> StationStatus
- Charger --> ChargerType / ChargerStatus
- User 1:N ChargeRecord（用户发起充电）
- Charger 1:N ChargeRecord（充电桩被使用）
- ChargeRecord 1:0..1 Payment（充电产生支付）
- User 1:N Repair（用户报修/处理）
- User 1:N AuditLog（用户操作记录）
- ChargingService ..> ChargeRecord / Charger（服务使用实体）
- PaymentService ..> Payment（服务使用实体）
- UserService ..> User（服务使用实体）
- RepairService ..> Repair（服务使用实体）
- ChargingService --> PricingStrategy（策略模式）
- StandardPricing ..|> PricingStrategy（策略实现）
- PaymentFactory ..> Payment（工厂创建支付）
- PaymentFactory ..> PaymentChannel（工厂依赖通道接口）

## 设计模式

- **策略模式**：PricingStrategy 接口与 StandardPricing 实现，用于灵活切换计费策略
- **工厂模式**：PaymentFactory 根据支付方式类型创建不同的支付通道

## 源文件

- `src/class_diagram.puml` — PlantUML 源文件

## 相关文档

- [用例总览](../usecase/docs/overview/usecases.md) — 用例定义与参与者
- [数据库设计](../usecase/docs/database/db.md) — 表结构对应类属性