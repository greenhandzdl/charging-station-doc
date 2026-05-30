import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class RepairProvider extends ChangeNotifier {
  List<RepairModel> _repairs = [];

  List<RepairModel> get repairs => _repairs;

  Future<void> fetchRepairs() async {
    try {
      _repairs = await ApiService.getRepairs();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitRepair(String chargerId, String description) async {
    try {
      await ApiService.submitRepair(chargerId, description);
      await fetchRepairs();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> assignRepair(String repairId, String maintainerId) async {
    try {
      await ApiService.assignRepair(repairId, maintainerId);
      await fetchRepairs();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resolveRepair(String repairId) async {
    try {
      await ApiService.resolveRepair(repairId);
      await fetchRepairs();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> closeRepair(String repairId) async {
    try {
      await ApiService.closeRepair(repairId);
      await fetchRepairs();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectRepair(String repairId, String reason) async {
    try {
      await ApiService.rejectRepair(repairId, reason);
      await fetchRepairs();
    } catch (e) {
      rethrow;
    }
  }
}