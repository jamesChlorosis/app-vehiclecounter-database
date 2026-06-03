class PurchaseEntry {
  PurchaseEntry({
    this.id,
    required this.date,
    required this.time,
    required this.vehicleNumber,
    required this.supplierName,
    required this.material,
    required this.quantity,
    required this.rate,
    required this.amount,
    required this.remarks,
    required this.createdAt,
  });

  final int? id;
  final String date;
  final DateTime time;
  final String vehicleNumber;
  final String supplierName;
  final String material;
  final double quantity;
  final double rate;
  final double amount;
  final String remarks;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'time': time.toIso8601String(),
        'vehicle_number': vehicleNumber,
        'supplier_name': supplierName,
        'material': material,
        'quantity': quantity,
        'rate': rate,
        'amount': amount,
        'remarks': remarks,
        'created_at': createdAt.toIso8601String(),
      };

  static PurchaseEntry fromMap(Map<String, Object?> map) => PurchaseEntry(
        id: map['id'] as int?,
        date: map['date'] as String,
        time: DateTime.parse(map['time'] as String),
        vehicleNumber: map['vehicle_number'] as String,
        supplierName: map['supplier_name'] as String,
        material: map['material'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        rate: (map['rate'] as num).toDouble(),
        amount: (map['amount'] as num).toDouble(),
        remarks: map['remarks'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
