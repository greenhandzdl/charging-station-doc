class StationModel {
  final String id;
  final String name;
  final String location;
  final int chargerCount;
  final String status;

  StationModel({
    required this.id,
    required this.name,
    required this.location,
    required this.chargerCount,
    required this.status,
  });

  factory StationModel.fromJson(Map<String, dynamic> json) {
    return StationModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      chargerCount: (json['chargerCount'] as num?)?.toInt() ??
          (json['charger_count'] as num?)?.toInt() ??
          0,
      status: json['status'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'chargerCount': chargerCount,
      'status': status,
    };
  }
}