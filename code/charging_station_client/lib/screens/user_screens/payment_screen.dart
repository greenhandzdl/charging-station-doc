import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/payment_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _amountController = TextEditingController();
  List<PaymentModel> _payments = [];
  bool _isLoading = false;
  bool _isRecharging = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      _payments = await ApiService.getPayments();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _recharge() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }
    setState(() => _isRecharging = true);
    try {
      final idempotencyKey = DateTime.now().millisecondsSinceEpoch.toString();
      await ApiService.recharge(amount, 'wechat', idempotencyKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('充值 $amount 元成功')),
        );
        _amountController.clear();
        _loadPayments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('充值失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecharging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('充值')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('当前余额: ',
                      style: TextStyle(fontSize: 16)),
                  Text('${auth.currentUser?.balance ?? 0.0} 元',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: '充值金额',
              prefixText: '¥ ',
              border: OutlineInputBorder(),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isRecharging ? null : _recharge,
            child: _isRecharging
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('充值'),
          ),
          const SizedBox(height: 24),
          const Text('充值记录',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_payments.isEmpty)
            const Center(child: Text('暂无充值记录'))
          else
            ..._payments.map((p) => Card(
                  child: ListTile(
                    title: Text('${p.amount} 元'),
                    subtitle: Text('${p.method} - ${p.status}'),
                  ),
                )),
        ],
      ),
    );
  }
}