import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api/v1';

  static String? _accessToken;

  static void setAccessToken(String? token) {
    _accessToken = token;
  }

  static Map<String, String> _headers({bool withAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (withAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> _handleResponse(
      http.Response response) async {
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: body['error'] as String? ??
          body['message'] as String? ??
          '请求失败 ($response.statusCode)',
    );
  }

  // ---- Auth ----
  static Future<LoginResponse> login(String phone, String password,
      {String? captchaId, String? captchaCode}) async {
    final body = <String, dynamic>{
      'phone': phone,
      'password': password,
    };
    if (captchaId != null) body['captchaId'] = captchaId;
    if (captchaCode != null) body['captchaCode'] = captchaCode;

    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(withAuth: false),
      body: jsonEncode(body),
    );
    final data = await _handleResponse(response);
    return LoginResponse.fromJson(data);
  }

  static Future<void> register(
    String name,
    String phone,
    String password,
    String plateNumber, {
    required String captchaId,
    required String captchaCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers(withAuth: false),
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
        'plateNumber': plateNumber,
        'captchaId': captchaId,
        'captchaCode': captchaCode,
      }),
    );
    await _handleResponse(response);
  }

  static Future<LoginResponse> refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: _headers(withAuth: false),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    final data = await _handleResponse(response);
    return LoginResponse.fromJson(data);
  }

  static Future<String> getCaptcha() async {
    final response = await http.get(
      Uri.parse('$baseUrl/captcha'),
      headers: _headers(withAuth: false),
    );
    final data = await _handleResponse(response);
    return data['captchaId'] as String? ?? '';
  }

  // ---- Password ----
  static Future<void> changePassword(
      String oldPwd, String newPwd) async {
    final response = await http.put(
      Uri.parse('$baseUrl/auth/password'),
      headers: _headers(),
      body: jsonEncode({'oldPassword': oldPwd, 'newPassword': newPwd}),
    );
    await _handleResponse(response);
  }

  static Future<void> resetPassword(
    String phone,
    String captchaId,
    String captchaCode,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/password-reset'),
      headers: _headers(withAuth: false),
      body: jsonEncode({
        'phone': phone,
        'captchaId': captchaId,
        'captchaCode': captchaCode,
      }),
    );
    await _handleResponse(response);
  }

  static Future<void> confirmPasswordReset(
    String token,
    String smsCode,
    String newPassword, {
    required String captchaId,
    required String captchaCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/password-reset/confirm'),
      headers: _headers(withAuth: false),
      body: jsonEncode({
        'token': token,
        'smsCode': smsCode,
        'newPassword': newPassword,
        'captchaId': captchaId,
        'captchaCode': captchaCode,
      }),
    );
    await _handleResponse(response);
  }

  // ---- Charging ----
  static Future<ChargeRecordModel> startCharge(String chargerId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/charges/start'),
      headers: _headers(),
      body: jsonEncode({'chargerId': chargerId}),
    );
    final data = await _handleResponse(response);
    return ChargeRecordModel.fromJson(data);
  }

  static Future<ChargeRecordModel> stopCharge(String recordId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/charges/stop'),
      headers: _headers(),
      body: jsonEncode({'recordId': recordId}),
    );
    final data = await _handleResponse(response);
    return ChargeRecordModel.fromJson(data);
  }

  static Future<Map<String, dynamic>> forceStop(
      String recordId, String reason) async {
    final response = await http.post(
      Uri.parse('$baseUrl/charges/$recordId/force-stop'),
      headers: _headers(),
      body: jsonEncode({'reason': reason}),
    );
    return await _handleResponse(response);
  }

  static Future<List<ChargeRecordModel>> getChargingRecords() async {
    final response = await http.get(
      Uri.parse('$baseUrl/charges'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    final list = data['records'] as List<dynamic>? ??
        data['charges'] as List<dynamic>? ??
        [];
    return list
        .map((e) =>
            ChargeRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Station / Charger ----
  static Future<List<StationModel>> getStations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/stations'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    final list = data['stations'] as List<dynamic>? ?? [];
    return list
        .map((e) => StationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ChargerModel>> getChargers(String stationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chargers?stationId=$stationId'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    final list = data['chargers'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChargerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Balance ----
  static Future<double> getBalance() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/balance'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    return (data['balance'] as num?)?.toDouble() ?? 0.0;
  }

  // ---- Payments (Recharge) ----
  static Future<PaymentModel> recharge(
    double amount,
    String method,
    String idempotencyKey,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/recharge'),
      headers: _headers(),
      body: jsonEncode({
        'amount': amount,
        'method': method,
        'idempotencyKey': idempotencyKey,
      }),
    );
    final data = await _handleResponse(response);
    return PaymentModel.fromJson(data);
  }

  static Future<List<PaymentModel>> getPayments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/payments'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    final list = data['payments'] as List<dynamic>? ?? [];
    return list
        .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Repairs ----
  static Future<RepairModel> submitRepair(
      String chargerId, String description) async {
    final response = await http.post(
      Uri.parse('$baseUrl/repairs'),
      headers: _headers(),
      body: jsonEncode({'chargerId': chargerId, 'description': description}),
    );
    final data = await _handleResponse(response);
    return RepairModel.fromJson(data);
  }

  static Future<List<RepairModel>> getRepairs() async {
    final response = await http.get(
      Uri.parse('$baseUrl/repairs'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    final list = data['repairs'] as List<dynamic>? ?? [];
    return list
        .map((e) => RepairModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> assignRepair(
      String repairId, String maintainerId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/repairs/$repairId/assign'),
      headers: _headers(),
      body: jsonEncode({'handledBy': maintainerId}),
    );
    await _handleResponse(response);
  }

  static Future<void> resolveRepair(String repairId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/repairs/$repairId/resolve'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  static Future<void> closeRepair(String repairId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/repairs/$repairId/close'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  static Future<void> rejectRepair(
      String repairId, String reason) async {
    final response = await http.put(
      Uri.parse('$baseUrl/repairs/$repairId/reject'),
      headers: _headers(),
      body: jsonEncode({'reason': reason}),
    );
    await _handleResponse(response);
  }

  // ---- Analytics ----
  static Future<List<Map<String, dynamic>>> getUserChargeStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/user-charges'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    final list = data['stats'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getStationAnalysis() async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/charges'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    final list = data['analysis'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getChargerUtilization() async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/utilization'),
      headers: _headers(),
    );
    return await _handleResponse(response);
  }

  static Future<List<Map<String, dynamic>>> getFaultChargers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/fault-chargers'),
      headers: _headers(),
    );
    final data = await _handleResponse(response);
    final list = data['chargers'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> exportCsv(
      String type, Map<String, String> params) async {
    final uri = Uri.parse('$baseUrl/analytics/export')
        .replace(queryParameters: {'type': type, ...params});
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: '导出失败',
      );
    }
  }

  // ---- User Management (Admin) ----
  static Future<void> changeRole(
      String userId, String newRole) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/role'),
      headers: _headers(),
      body: jsonEncode({'role': newRole}),
    );
    await _handleResponse(response);
  }

  static Future<void> deleteUser(String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers(),
    );
    await _handleResponse(response);
  }

  static Future<void> updateUser(
      String userId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    await _handleResponse(response);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}