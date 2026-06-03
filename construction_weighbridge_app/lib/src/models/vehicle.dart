class Vehicle {
  Vehicle({
    required this.plate,
    required this.partyName,
    required this.defaultItem,
    required this.lastQty,
    required this.updatedAt,
  });

  final String plate;
  final String partyName;
  final String defaultItem;
  final double lastQty;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'plate': plate,
        'party_name': partyName,
        'default_item': defaultItem,
        'last_qty': lastQty,
        'updated_at': updatedAt.toIso8601String(),
      };

  static Vehicle fromMap(Map<String, Object?> map) => Vehicle(
        plate: map['plate'] as String,
        partyName: map['party_name'] as String,
        defaultItem: map['default_item'] as String,
        lastQty: (map['last_qty'] as num).toDouble(),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
