import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/statistics_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<StatisticsProvider>();
    provider.fetchUserChargeStats();
    provider.fetchStationAnalysis();
    provider.fetchChargerUtilization();
    provider.fetchFaultChargers();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StatisticsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('统计报表')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('用户充电统计',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (provider.chargeStats.isEmpty)
            const Card(child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无数据'),
            ))
          else
            ...provider.chargeStats.map((s) => Card(
                  child: ListTile(
                    title: Text(s['userName']?.toString() ?? ''),
                    subtitle: Text('充电次数: ${s['count'] ?? 0}'),
                  ),
                )),
          const SizedBox(height: 16),
          const Text('运营分析',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (provider.stationAnalysis.isEmpty)
            const Card(child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无数据'),
            ))
          else
            ...provider.stationAnalysis.map((a) => Card(
                  child: ListTile(
                    title:
                        Text(a['stationName']?.toString() ?? ''),
                    subtitle: Text('充电量: ${a['totalKwh'] ?? 0} kWh'),
                  ),
                )),
          const SizedBox(height: 16),
          const Text('充电桩使用率',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('空闲: ${provider.chargerUtilization['idle'] ?? 0}%'),
                  Text('使用中: ${provider.chargerUtilization['charging'] ?? 0}%'),
                  Text('故障: ${provider.chargerUtilization['fault'] ?? 0}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('故障充电桩',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (provider.faultChargers.isEmpty)
            const Card(child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无故障桩'),
            ))
          else
            ...provider.faultChargers.map((f) => Card(
                  child: ListTile(
                    title: Text(f['chargerCode']?.toString() ?? ''),
                    subtitle: Text(f['stationName']?.toString() ?? ''),
                  ),
                )),
        ],
      ),
    );
  }
}