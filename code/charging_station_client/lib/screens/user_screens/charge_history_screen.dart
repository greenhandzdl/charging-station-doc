import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class ChargeHistoryScreen extends StatefulWidget {
  const ChargeHistoryScreen({super.key});

  @override
  State<ChargeHistoryScreen> createState() => _ChargeHistoryScreenState();
}

class _ChargeHistoryScreenState extends State<ChargeHistoryScreen> {
  List<ChargeRecordModel> _records = [];
  bool _isLoading = false;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      _records = await ApiService.getChargingRecords();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载记录失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ChargeRecordModel> get _filteredRecords {
    if (_statusFilter.isEmpty) return _records;
    return _records.where((r) => r.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('充电记录'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('全部')),
              const PopupMenuItem(value: 'completed', child: Text('已完成')),
              const PopupMenuItem(value: 'processing', child: Text('充电中')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecords,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredRecords.isEmpty
                ? const Center(child: Text('暂无充电记录'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredRecords.length,
                    itemBuilder: (_, i) {
                      final record = _filteredRecords[i];
                      return Card(
                        child: ListTile(
                          title: Text(
                              '${record.stationName} - ${record.chargerCode}'),
                          subtitle: Text(
                            '${record.startTime}\n'
                            '${record.energyKwh}kWh | ${record.fee}元 | ${record.status}',
                          ),
                          trailing: Text(record.deductionStatus),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}