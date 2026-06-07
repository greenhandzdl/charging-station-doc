# 充值审批 + 扫码充电 — 架构设计方案

## 1. 充值审批流

### 现状
用户充值 → PENDING → 模拟网关回调 → SUCCESS → 加余额

### 新设计
用户充值 → PENDING → 管理员审核 → 模拟回调处理 → SUCCESS → 加余额

### 状态变更
`PaymentStatus` 新增 `APPROVED`：
- PENDING → APPROVED（管理员批准）
- APPROVED → SUCCESS（系统模拟回调处理成功）
- PENDING → FAILED（管理员拒绝）
- APPROVED → SUCCESS/FAILED（回调处理）

### 新增API

| 方法 | 端点 | 权限 | 说明 |
|------|------|------|------|
| GET | `/api/v1/payments/pending` | ADMIN/SUPER_ADMIN | 待审核充值列表 |
| PUT | `/api/v1/payments/{id}/approve` | ADMIN/SUPER_ADMIN | 批准充值，触发模拟回调 |
| PUT | `/api/v1/payments/{id}/reject` | ADMIN/SUPER_ADMIN | 拒绝充值 |

### 审批触发回调流程
管理员点「批准」→ 后端创建系统内部回调任务 → 验证HMAC → 标记 APPROVED → 延迟模拟 → 标记 SUCCESS → 加余额 → 自动扣欠费

## 2. 通用扫码

### Mock充电桩QR格式
```json
{
  "chargerId": "uuid",
  "stationId": "uuid",
  "stationName": "朝阳站",
  "chargerCode": "CY-A01",
  "type": "FAST"
}
```

### Flutter扫码流程
1. 打开摄像头扫码
2. 解析二维码内容：
   - JSON格式 → 提取chargerId等信息
   - 纯文本 → 调用 `/api/v1/chargers/by-code/{code}` 查询
3. 显示操作选择界面（底部弹出Sheet）：
   - ⚡ 启动充电
   - 🔧 报修
   - 📋 查看桩信息
   - ❌ 取消
4. 用户选择后跳转对应功能

### QR内容
添加 `mobile_scanner` 依赖。

## 3. 管理后台新增
- AdminDashboard 增加「充值审核」入口
- 显示待审核充值列表（用户、金额、时间）
- 批准/拒绝操作