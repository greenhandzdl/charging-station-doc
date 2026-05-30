class PaymentModel {
  final String id;
  final String chargeRecordId;
  final String method;
  final double amount;
  final String status;

  PaymentModel({
    required this.id,
    required this.chargeRecordId,
    required this.method,
    required this.amount,
    required this.status,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      chargeRecordId: json['chargeRecordId'] as String? ??
          json['charge_record_id'] as String? ??
          '',
      method: json['method'] as String? ?? 'unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chargeRecordId': chargeRecordId,
      'method': method,
      'amount': amount,
      'status': status,
    };
  }
}