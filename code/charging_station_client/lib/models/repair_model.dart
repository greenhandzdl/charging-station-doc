class RepairModel {
  final String id;
  final String chargerId;
  final String chargerCode;
  final String description;
  final String status;
  final String reporterName;
  final String reportedAt;

  RepairModel({
    required this.id,
    required this.chargerId,
    required this.chargerCode,
    required this.description,
    required this.status,
    required this.reporterName,
    required this.reportedAt,
  });

  factory RepairModel.fromJson(Map<String, dynamic> json) {
    return RepairModel(
      id: json['id'] as String? ?? '',
      chargerId: json['chargerId'] as String? ??
          json['charger_id'] as String? ??
          '',
      chargerCode: json['chargerCode'] as String? ??
          json['charger_code'] as String? ??
          '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      reporterName: json['reporterName'] as String? ??
          json['reporter_name'] as String? ??
          '',
      reportedAt: json['reportedAt'] as String? ??
          json['reported_at'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chargerId': chargerId,
      'chargerCode': chargerCode,
      'description': description,
      'status': status,
      'reporterName': reporterName,
      'reportedAt': reportedAt,
    };
  }
}