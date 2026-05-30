import 'package:flutter/material.dart';
import '../../models/station_model.dart';
import '../../models/charger_model.dart';
import '../../services/api_service.dart';

class ChargerManagementScreen extends StatefulWidget {
  const ChargerManagementScreen({super.key});

  @override
  State<ChargerManagementScreen> createState() =>
      _ChargerManagementScreenState();
}

class _ChargerManagementScreenState extends State<ChargerManagementScreen> {
  List<StationModel> _stations = [];
  List<ChargerModel> _chargers = [];
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

  Future<void> _loadChargers(String stationId) async {
    setState(() => _isLoading = true);
    try {
      _chargers = await ApiService.getChargers(stationId);
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
      appBar: AppBar(title: const Text('充电桩管理')),
      body: Column(
        children: [
          DropdownButtonFormField<StationModel>(
            decoration: const InputDecoration(
              labelText: '选择充电站',
              contentPadding: EdgeInsets.all(16),
            ),
            items: _stations
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (station) {
              if (station != null) _loadChargers(station.id);
            },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _chargers.length,
                    itemBuilder: (_, i) {
                      final c = _chargers[i];
                      return Card(
                        child: ListTile(
                          title:
                              Text('${c.chargerCode} (${c.type})'),
                          subtitle: Text('状态: ${c.status}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}