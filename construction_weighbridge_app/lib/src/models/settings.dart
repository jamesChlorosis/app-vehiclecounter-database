class AppSettings {
  AppSettings({
    required this.businessName,
    required this.salesInCharge,
    required this.googleSheetId,
    required this.darkMode,
    required this.openingBalance,
  });

  final String businessName;
  final String salesInCharge;
  final String googleSheetId;
  final bool darkMode;
  final double openingBalance;

  AppSettings copyWith({
    String? businessName,
    String? salesInCharge,
    String? googleSheetId,
    bool? darkMode,
    double? openingBalance,
  }) {
    return AppSettings(
      businessName: businessName ?? this.businessName,
      salesInCharge: salesInCharge ?? this.salesInCharge,
      googleSheetId: googleSheetId ?? this.googleSheetId,
      darkMode: darkMode ?? this.darkMode,
      openingBalance: openingBalance ?? this.openingBalance,
    );
  }

  static AppSettings defaults() => AppSettings(
        businessName: 'Quarry Gate',
        salesInCharge: '',
        googleSheetId: '',
        darkMode: true,
        openingBalance: 0,
      );
}
