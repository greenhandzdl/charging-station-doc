import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ChargingProvider extends ChangeNotifier {
  List<StationModel> _stations = [];
  List<ChargerModel> _chargers = [];
  ChargeRecordModel? _currentRecord;

  List<StationModel> get stations => _stations;
  List<ChargerModel> get chargers => _chargers;
  ChargeRecordModel? get currentRecord => _currentRecord;

  Future<void> fetchStations() async {
    try {
      _stations = await ApiService.getStations();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchChargers(String stationId) async {
    try {
      _chargers = await ApiService.getChargers(stationId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> startCharge(String chargerId) async {
    try {
      _currentRecord = await ApiService.startCharge(chargerId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> stopCharge(String recordId) async {
    try {
      _currentRecord = await ApiService.stopCharge(recordId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}