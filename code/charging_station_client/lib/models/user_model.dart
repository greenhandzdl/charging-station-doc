class UserModel {
  final String id;
  final String name;
  final String phone;
  final String plateNumber;
  final String role;
  final double balance;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.plateNumber,
    required this.role,
    required this.balance,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      plateNumber: json['plateNumber'] as String? ?? json['plate_number'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'plateNumber': plateNumber,
      'role': role,
      'balance': balance,
    };
  }
}