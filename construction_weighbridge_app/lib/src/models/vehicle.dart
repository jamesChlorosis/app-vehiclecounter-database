class Vehicle {
  Vehicle({
    required this.plate,
    required this.partyName,
    required this.defaultItem,
    required this.lastQty,
    required this.currentRate,
    required this.companyBody,
    required this.extraBody,
    required this.isPickup,
    required this.bodyRemarks,
    required this.updatedAt,
  });

  final String plate;
  final String partyName;
  final String defaultItem;
  final double lastQty;
  final double currentRate;
  final bool companyBody;
  final bool extraBody;
  final bool isPickup;
  final String bodyRemarks;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'plate': plate,
        'party_name': partyName,
        'default_item': defaultItem,
        'last_qty': lastQty,
        'current_rate': currentRate,
        'company_body': companyBody ? 1 : 0,
        'extra_body': extraBody ? 1 : 0,
        'is_pickup': isPickup ? 1 : 0,
        'body_remarks': bodyRemarks,
        'updated_at': updatedAt.toIso8601String(),
      };

  static Vehicle fromMap(Map<String, Object?> map) => Vehicle(
        plate: map['plate'] as String,
        partyName: map['party_name'] as String,
        defaultItem: map['default_item'] as String,
        lastQty: (map['last_qty'] as num).toDouble(),
        currentRate: ((map['current_rate'] ?? 0) as num).toDouble(),
        companyBody: ((map['company_body'] ?? 0) as int) == 1,
        extraBody: ((map['extra_body'] ?? 0) as int) == 1,
        isPickup: ((map['is_pickup'] ?? 0) as int) == 1,
        bodyRemarks: (map['body_remarks'] as String?) ?? '',
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
