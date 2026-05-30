import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class StatisticsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _chargeStats = [];
  List<Map<String, dynamic>> _stationAnalysis = [];
  Map<String, dynamic> _chargerUtilization = {};
  List<Map<String, dynamic>> _faultChargers = [];

  List<Map<String, dynamic>> get chargeStats => _chargeStats;
  List<Map<String, dynamic>> get stationAnalysis => _stationAnalysis;
  Map<String, dynamic> get chargerUtilization => _chargerUtilization;
  List<Map<String, dynamic>> get faultChargers => _faultChargers;

  Future<void> fetchUserChargeStats() async {
    try {
      _chargeStats = await ApiService.getUserChargeStats();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchStationAnalysis() async {
    try {
      _stationAnalysis = await ApiService.getStationAnalysis();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchChargerUtilization() async {
    try {
      _chargerUtilization = await ApiService.getChargerUtilization();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchFaultChargers() async {
    try {
      _faultChargers = await ApiService.getFaultChargers();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}