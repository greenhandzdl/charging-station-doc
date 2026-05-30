import 'package:flutter/material.dart';
import '../../models/station_model.dart';
import '../../services/api_service.dart';

class StationManagementScreen extends StatefulWidget {
  const StationManagementScreen({super.key});

  @override
  State<StationManagementScreen> createState() =>
      _StationManagementScreenState();
}

class _StationManagementScreenState extends State<StationManagementScreen> {
  List<StationModel> _stations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    try {
      _stations = await ApiService.getStations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('充电站管理')),
      body: RefreshIndicator(
        onRefresh: _loadStations,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _stations.length,
                itemBuilder: (_, i) {
                  final s = _stations[i];
                  return Card(
                    child: ListTile(
                      title: Text(s.name),
                      subtitle: Text(
                          '${s.location} | ${s.chargerCount}个桩 | ${s.status}'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}