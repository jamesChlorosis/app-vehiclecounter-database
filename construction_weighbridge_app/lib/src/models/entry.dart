import 'package:intl/intl.dart';

enum PaymentType { cash, credit }

class Entry {
  Entry({
    this.id,
    required this.vehicleNumber,
    required this.partyName,
    required this.remarks,
    required this.itemType,
    required this.quantity,
    required this.timeIn,
    this.timeOut,
    this.unitRate,
    required this.amount,
    required this.paymentType,
    required this.cashAmount,
    required this.creditAmount,
    required this.pageSlipNo,
    required this.extraInfo,
    required this.date,
    required this.createdAt,
    this.synced = false,
  });

  final int? id;
  final String vehicleNumber;
  final String partyName;
  final String remarks;
  final String itemType;
  final double quantity;
  final DateTime timeIn;
  final DateTime? timeOut;
  final double? unitRate;
  final double amount;
  final PaymentType paymentType;
  final double cashAmount;
  final double creditAmount;
  final int pageSlipNo;
  final String extraInfo;
  final String date;
  final DateTime createdAt;
  final bool synced;

  static final dateFormat = DateFormat('dd/MM/yyyy');
  static final timeFormat = DateFormat('HH:mm');

  Entry copyWith({
    int? id,
    String? vehicleNumber,
    String? partyName,
    String? remarks,
    String? itemType,
    double? quantity,
    DateTime? timeIn,
    DateTime? timeOut,
    double? unitRate,
    double? amount,
    PaymentType? paymentType,
    double? cashAmount,
    double? creditAmount,
    int? pageSlipNo,
    String? extraInfo,
    String? date,
    DateTime? createdAt,
    bool? synced,
  }) {
    return Entry(
      id: id ?? this.id,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      partyName: partyName ?? this.partyName,
      remarks: remarks ?? this.remarks,
      itemType: itemType ?? this.itemType,
      quantity: quantity ?? this.quantity,
      timeIn: timeIn ?? this.timeIn,
      timeOut: timeOut ?? this.timeOut,
      unitRate: unitRate ?? this.unitRate,
      amount: amount ?? this.amount,
      paymentType: paymentType ?? this.paymentType,
      cashAmount: cashAmount ?? this.cashAmount,
      creditAmount: creditAmount ?? this.creditAmount,
      pageSlipNo: pageSlipNo ?? this.pageSlipNo,
      extraInfo: extraInfo ?? this.extraInfo,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle_number': vehicleNumber,
        'party_name': partyName,
        'remarks': remarks,
        'item_type': itemType,
        'quantity': quantity,
        'time_in': timeIn.toIso8601String(),
        'time_out': timeOut?.toIso8601String(),
        'unit_rate': unitRate,
        'amount': amount,
        'payment_type': paymentType.name,
        'cash_amount': cashAmount,
        'credit_amount': creditAmount,
        'page_slip_no': pageSlipNo,
        'extra_info': extraInfo,
        'date': date,
        'created_at': createdAt.toIso8601String(),
        'synced': synced ? 1 : 0,
      };

  static Entry fromMap(Map<String, Object?> map) => Entry(
        id: map['id'] as int?,
        vehicleNumber: map['vehicle_number'] as String,
        partyName: map['party_name'] as String,
        remarks: map['remarks'] as String,
        itemType: map['item_type'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        timeIn: DateTime.parse(map['time_in'] as String),
        timeOut: map['time_out'] == null
            ? null
            : DateTime.parse(map['time_out'] as String),
        unitRate: (map['unit_rate'] as num?)?.toDouble(),
        amount: (map['amount'] as num).toDouble(),
        paymentType: PaymentType.values.byName(map['payment_type'] as String),
        cashAmount: (map['cash_amount'] as num).toDouble(),
        creditAmount: (map['credit_amount'] as num).toDouble(),
        pageSlipNo: map['page_slip_no'] as int,
        extraInfo: map['extra_info'] as String,
        date: map['date'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        synced: (map['synced'] as int) == 1,
      );

  List<Object?> toSheetRow(int serialNo) => [
        serialNo,
        vehicleNumber,
        partyName,
        remarks,
        itemType,
        quantity,
        timeFormat.format(timeIn),
        timeOut == null ? '' : timeFormat.format(timeOut!),
        unitRate ?? '',
        amount,
        cashAmount,
        creditAmount,
      ];
}
