class ChargeRecordModel {
  final String id;
  final String startTime;
  final String endTime;
  final double energyKwh;
  final double fee;
  final String status;
  final String deductionStatus;
  final String userName;
  final String plateNumber;
  final String chargerCode;
  final String stationName;

  ChargeRecordModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.energyKwh,
    required this.fee,
    required this.status,
    required this.deductionStatus,
    required this.userName,
    required this.plateNumber,
    required this.chargerCode,
    required this.stationName,
  });

  factory ChargeRecordModel.fromJson(Map<String, dynamic> json) {
    return ChargeRecordModel(
      id: json['id'] as String? ?? '',
      startTime: json['startTime'] as String? ??
          json['start_time'] as String? ??
          '',
      endTime: json['endTime'] as String? ??
          json['end_time'] as String? ??
          '',
      energyKwh: (json['energyKwh'] as num?)?.toDouble() ??
          (json['energy_kwh'] as num?)?.toDouble() ??
          0.0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'unknown',
      deductionStatus: json['deductionStatus'] as String? ??
          json['deduction_status'] as String? ??
          'pending',
      userName: json['userName'] as String? ??
          json['user_name'] as String? ??
          '',
      plateNumber: json['plateNumber'] as String? ??
          json['plate_number'] as String? ??
          '',
      chargerCode: json['chargerCode'] as String? ??
          json['charger_code'] as String? ??
          '',
      stationName: json['stationName'] as String? ??
          json['station_name'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime,
      'endTime': endTime,
      'energyKwh': energyKwh,
      'fee': fee,
      'status': status,
      'deductionStatus': deductionStatus,
      'userName': userName,
      'plateNumber': plateNumber,
      'chargerCode': chargerCode,
      'stationName': stationName,
    };
  }
}