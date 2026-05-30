import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/charging_provider.dart';

class ChargingScreen extends StatefulWidget {
  const ChargingScreen({super.key});

  @override
  State<ChargingScreen> createState() => _ChargingScreenState();
}

class _ChargingScreenState extends State<ChargingScreen> {
  StationModel? _selectedStation;
  ChargerModel? _selectedCharger;
  bool _isLoadingStations = false;
  bool _isLoadingChargers = false;
  bool _isCharging = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      await context.read<ChargingProvider>().fetchStations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载站点失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _loadChargers(String stationId) async {
    setState(() => _isLoadingChargers = true);
    try {
      await context.read<ChargingProvider>().fetchChargers(stationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载充电桩失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingChargers = false);
    }
  }

  Future<void> _startCharge() async {
    if (_selectedCharger == null) return;
    setState(() => _isCharging = true);
    try {
      await context
          .read<ChargingProvider>()
          .startCharge(_selectedCharger!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('充电已启动')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动充电失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCharging = false);
    }
  }

  Future<void> _stopCharge() async {
    final provider = context.read<ChargingProvider>();
    final record = provider.currentRecord;
    if (record == null) return;
    setState(() => _isCharging = true);
    try {
      await provider.stopCharge(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('充电已结束')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('结束充电失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCharging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChargingProvider>();
    final currentRecord = provider.currentRecord;

    return Scaffold(
      appBar: AppBar(title: const Text('充电')),
      body: RefreshIndicator(
        onRefresh: _loadStations,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('选择充电站',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isLoadingStations)
              const Center(child: CircularProgressIndicator())
            else
              ...provider.stations.map((station) => Card(
                    child: ListTile(
                      title: Text(station.name),
                      subtitle: Text('${station.location} | ${station.chargerCount}个桩'),
                      trailing: Text(station.status),
                      selected: _selectedStation?.id == station.id,
                      onTap: () {
                        setState(() {
                          _selectedStation = station;
                          _selectedCharger = null;
                        });
                        _loadChargers(station.id);
                      },
                    ),
                  )),
            if (_selectedStation != null) ...[
              const SizedBox(height: 16),
              const Text('选择充电桩',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_isLoadingChargers)
                const Center(child: CircularProgressIndicator())
              else
                ...provider.chargers.map((charger) => Card(
                      child: ListTile(
                        title: Text('${charger.chargerCode} (${charger.type})'),
                        subtitle: Text('状态: ${charger.status}'),
                        selected: _selectedCharger?.id == charger.id,
                        onTap: charger.status == 'idle'
                            ? () => setState(
                                    () => _selectedCharger = charger)
                            : null,
                      ),
                    )),
            ],
            const SizedBox(height: 24),
            if (currentRecord != null && currentRecord.status == 'processing')
              ElevatedButton.icon(
                onPressed: _isCharging ? null : _stopCharge,
                icon: const Icon(Icons.stop),
                label: Text(_isCharging ? '处理中...' : '结束充电'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              )
            else
              ElevatedButton.icon(
                onPressed: (_selectedCharger == null || _isCharging)
                    ? null
                    : _startCharge,
                icon: const Icon(Icons.play_arrow),
                label: Text(_isCharging ? '启动中...' : '启动充电'),
              ),
            if (currentRecord != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('当前充电信息',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('状态: ${currentRecord.status}'),
                      Text('电量: ${currentRecord.energyKwh} kWh'),
                      Text('费用: ${currentRecord.fee} 元'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}