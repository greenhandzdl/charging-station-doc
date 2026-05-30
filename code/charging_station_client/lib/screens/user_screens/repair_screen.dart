import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/repair_provider.dart';

class RepairScreen extends StatefulWidget {
  const RepairScreen({super.key});

  @override
  State<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends State<RepairScreen> {
  final _descriptionController = TextEditingController();
  final _chargerCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<RepairProvider>().fetchRepairs();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _chargerCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitRepair() async {
    final chargerCode = _chargerCodeController.text.trim();
    final description = _descriptionController.text.trim();
    if (chargerCode.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整信息')),
      );
      return;
    }
    try {
      await context
          .read<RepairProvider>()
          .submitRepair(chargerCode, description);
      _chargerCodeController.clear();
      _descriptionController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('报修已提交')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RepairProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('报修')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('提交报修',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _chargerCodeController,
            decoration: const InputDecoration(
              labelText: '充电桩编号',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '故障描述',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitRepair,
            child: const Text('提交报修'),
          ),
          const SizedBox(height: 24),
          const Text('我的报修记录',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (provider.repairs.isEmpty)
            const Center(child: Text('暂无报修记录'))
          else
            ...provider.repairs.map((r) => Card(
                  child: ListTile(
                    title: Text(r.chargerCode),
                    subtitle: Text(
                        '${r.description}\n${r.status} | ${r.reportedAt}'),
                    isThreeLine: true,
                  ),
                )),
        ],
      ),
    );
  }
}