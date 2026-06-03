import 'entry.dart';

class DailyTotals {
  DailyTotals({
    required this.vehicleCount,
    required this.totalQty,
    required this.cashTotal,
    required this.creditTotal,
    required this.itemQty,
  });

  final int vehicleCount;
  final double totalQty;
  final double cashTotal;
  final double creditTotal;
  final Map<String, double> itemQty;

  static DailyTotals fromEntries(List<Entry> entries) {
    final itemQty = <String, double>{};
    double totalQty = 0;
    double cash = 0;
    double credit = 0;
    for (final entry in entries) {
      totalQty += entry.quantity;
      cash += entry.cashAmount + entry.bankAmount + entry.gpayAmount;
      credit += entry.creditAmount;
      itemQty[entry.itemType] = (itemQty[entry.itemType] ?? 0) + entry.quantity;
    }
    return DailyTotals(
      vehicleCount: entries.length,
      totalQty: totalQty,
      cashTotal: cash,
      creditTotal: credit,
      itemQty: itemQty,
    );
  }
}
