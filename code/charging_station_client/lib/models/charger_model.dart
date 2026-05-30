class ChargerModel {
  final String id;
  final String chargerCode;
  final String type;
  final String status;
  final String stationName;

  ChargerModel({
    required this.id,
    required this.chargerCode,
    required this.type,
    required this.status,
    required this.stationName,
  });

  factory ChargerModel.fromJson(Map<String, dynamic> json) {
    return ChargerModel(
      id: json['id'] as String? ?? '',
      chargerCode: json['chargerCode'] as String? ??
          json['charger_code'] as String? ??
          '',
      type: json['type'] as String? ?? 'slow',
      status: json['status'] as String? ?? 'unknown',
      stationName: json['stationName'] as String? ??
          json['station_name'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chargerCode': chargerCode,
      'type': type,
      'status': status,
      'stationName': stationName,
    };
  }
}