class AccountRow {
  AccountRow({
    this.id,
    required this.date,
    required this.partyName,
    required this.category,
    required this.debit,
    required this.credit,
  });

  final int? id;
  final String date;
  final String partyName;
  final String category;
  final double debit;
  final double credit;

  Map<String, Object?> toMap() => {
        'id': id,
        'date': date,
        'party_name': partyName,
        'category': category,
        'debit': debit,
        'credit': credit,
      };

  static AccountRow fromMap(Map<String, Object?> map) => AccountRow(
        id: map['id'] as int?,
        date: map['date'] as String,
        partyName: map['party_name'] as String,
        category: map['category'] as String,
        debit: (map['debit'] as num).toDouble(),
        credit: (map['credit'] as num).toDouble(),
      );
}
