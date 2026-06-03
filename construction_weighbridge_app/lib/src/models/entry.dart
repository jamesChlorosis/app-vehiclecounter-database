import 'package:intl/intl.dart';

enum PaymentType { cash, bank, gpay, credit, mixed }

enum DiscountType { none, percentage, fixedAmount }

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
    required this.grossAmount,
    required this.discountType,
    this.discountValue,
    required this.discountAmount,
    required this.netAmount,
    required this.paymentType,
    required this.cashAmount,
    required this.bankAmount,
    required this.gpayAmount,
    required this.creditAmount,
    required this.pageSlipNo,
    required this.slipNumber,
    required this.driverName,
    required this.companyBody,
    required this.extraBody,
    required this.isPickup,
    required this.bodyRemarks,
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
  final double grossAmount;
  final DiscountType discountType;
  final double? discountValue;
  final double discountAmount;
  final double netAmount;
  final PaymentType paymentType;
  final double cashAmount;
  final double bankAmount;
  final double gpayAmount;
  final double creditAmount;
  final int pageSlipNo;
  final String slipNumber;
  final String driverName;
  final bool companyBody;
  final bool extraBody;
  final bool isPickup;
  final String bodyRemarks;
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
    double? grossAmount,
    DiscountType? discountType,
    double? discountValue,
    double? discountAmount,
    double? netAmount,
    PaymentType? paymentType,
    double? cashAmount,
    double? bankAmount,
    double? gpayAmount,
    double? creditAmount,
    int? pageSlipNo,
    String? slipNumber,
    String? driverName,
    bool? companyBody,
    bool? extraBody,
    bool? isPickup,
    String? bodyRemarks,
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
      grossAmount: grossAmount ?? this.grossAmount,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountAmount: discountAmount ?? this.discountAmount,
      netAmount: netAmount ?? this.netAmount,
      paymentType: paymentType ?? this.paymentType,
      cashAmount: cashAmount ?? this.cashAmount,
      bankAmount: bankAmount ?? this.bankAmount,
      gpayAmount: gpayAmount ?? this.gpayAmount,
      creditAmount: creditAmount ?? this.creditAmount,
      pageSlipNo: pageSlipNo ?? this.pageSlipNo,
      slipNumber: slipNumber ?? this.slipNumber,
      driverName: driverName ?? this.driverName,
      companyBody: companyBody ?? this.companyBody,
      extraBody: extraBody ?? this.extraBody,
      isPickup: isPickup ?? this.isPickup,
      bodyRemarks: bodyRemarks ?? this.bodyRemarks,
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
        'gross_amount': grossAmount,
        'discount_type': discountType.name,
        'discount_value': discountValue,
        'discount_amount': discountAmount,
        'net_amount': netAmount,
        'payment_type': paymentType.name,
        'cash_amount': cashAmount,
        'bank_amount': bankAmount,
        'gpay_amount': gpayAmount,
        'credit_amount': creditAmount,
        'page_slip_no': pageSlipNo,
        'slip_number': slipNumber,
        'driver_name': driverName,
        'company_body': companyBody ? 1 : 0,
        'extra_body': extraBody ? 1 : 0,
        'is_pickup': isPickup ? 1 : 0,
        'body_remarks': bodyRemarks,
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
        grossAmount: ((map['gross_amount'] ?? map['amount']) as num).toDouble(),
        discountType: DiscountType.values.byName((map['discount_type'] as String?) ?? 'none'),
        discountValue: (map['discount_value'] as num?)?.toDouble(),
        discountAmount: ((map['discount_amount'] ?? 0) as num).toDouble(),
        netAmount: ((map['net_amount'] ?? map['amount']) as num).toDouble(),
        paymentType: PaymentType.values.byName(map['payment_type'] as String),
        cashAmount: (map['cash_amount'] as num).toDouble(),
        bankAmount: ((map['bank_amount'] ?? 0) as num).toDouble(),
        gpayAmount: ((map['gpay_amount'] ?? 0) as num).toDouble(),
        creditAmount: (map['credit_amount'] as num).toDouble(),
        pageSlipNo: map['page_slip_no'] as int,
        slipNumber: (map['slip_number'] as String?) ?? '',
        driverName: (map['driver_name'] as String?) ?? '',
        companyBody: ((map['company_body'] ?? 0) as int) == 1,
        extraBody: ((map['extra_body'] ?? 0) as int) == 1,
        isPickup: ((map['is_pickup'] ?? 0) as int) == 1,
        bodyRemarks: (map['body_remarks'] as String?) ?? '',
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
        netAmount,
        cashAmount,
        bankAmount + gpayAmount,
        creditAmount,
      ];
}
