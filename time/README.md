# 时序图

充电业务核心流程的对象交互时序设计。

## 图

### 启动充电

![启动充电时序图](img/sequence_charging.svg)

**流程：** 用户选择充电桩 → 校验用户身份与余额（>= 10元）→ 校验桩状态（空闲）→ 乐观锁锁定桩 → 创建充电记录 → 审计日志。

### 结束充电与自动扣费

![结束充电时序图](img/sequence_stop_charge.svg)

**流程：** 用户结束充电 → 计算充电量与费用 → 事务内（更新记录 + 扣减余额 + 记录支付 + 释放桩）→ 余额不足则标记欠费。

## 源文件

- `src/sequence_charging.puml` — 启动充电时序图源文件
- `src/sequence_stop_charge.puml` — 结束充电时序图源文件

## 相关文档

- [充电流程用例](../usecase/docs/backend/charging-flow.md) — 充电流程场景描述
- [数据库设计](../usecase/docs/database/db.md) — charge_records/payments 表结构