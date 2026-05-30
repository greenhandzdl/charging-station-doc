import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/repair_provider.dart';

class RepairManagementScreen extends StatefulWidget {
  const RepairManagementScreen({super.key});

  @override
  State<RepairManagementScreen> createState() =>
      _RepairManagementScreenState();
}

class _RepairManagementScreenState extends State<RepairManagementScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RepairProvider>().fetchRepairs();
  }

  Future<void> _handleAction(
      String repairId, RepairAction action, {String? reason}) async {
    try {
      final provider = context.read<RepairProvider>();
      switch (action) {
        case RepairAction.assign:
          // In a real app, show user picker
          await provider.assignRepair(repairId, 'maintainer-id');
        case RepairAction.resolve:
          await provider.resolveRepair(repairId);
        case RepairAction.close:
          await provider.closeRepair(repairId);
        case RepairAction.reject:
          if (reason != null) {
            await provider.rejectRepair(repairId, reason);
          }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RepairProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('报修管理')),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchRepairs(),
        child: provider.repairs.isEmpty
            ? const Center(child: Text('暂无报修记录'))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: provider.repairs.length,
                itemBuilder: (_, i) {
                  final r = provider.repairs[i];
                  return Card(
                    child: ExpansionTile(
                      title: Text('${r.chargerCode} - ${r.status}'),
                      subtitle: Text(r.description),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Text('报修人: ${r.reporterName}'),
                              Text('时间: ${r.reportedAt}'),
                              const SizedBox(height: 8),
                              if (r.status == 'open') ...[
                                ElevatedButton(
                                  onPressed: () =>
                                      _handleAction(r.id,
                                          RepairAction.assign),
                                  child: const Text('分配维修人员'),
                                ),
                                const SizedBox(height: 4),
                                ElevatedButton(
                                  onPressed: () =>
                                      _handleAction(r.id,
                                          RepairAction.close),
                                  child:
                                      const Text('直接关闭'),
                                ),
                              ],
                              if (r.status == 'in_progress')
                                ElevatedButton(
                                  onPressed: () =>
                                      _handleAction(r.id,
                                          RepairAction.resolve),
                                  child:
                                      const Text('标记维修完成'),
                                ),
                              if (r.status == 'resolved') ...[
                                ElevatedButton(
                                  onPressed: () =>
                                      _handleAction(r.id,
                                          RepairAction.close),
                                  child:
                                      const Text('审核通过 (关闭)'),
                                ),
                                const SizedBox(height: 4),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  onPressed: () =>
                                      _showRejectDialog(r.id),
                                  child: const Text('退回'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showRejectDialog(String repairId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退回报修'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '退回原因',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleAction(repairId, RepairAction.reject,
                  reason: controller.text);
            },
            child: const Text('确认退回'),
          ),
        ],
      ),
    );
  }
}

enum RepairAction { assign, resolve, close, reject }