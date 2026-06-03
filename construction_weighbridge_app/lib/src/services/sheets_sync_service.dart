import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../models/daily_totals.dart';
import '../models/entry.dart';
import 'database_service.dart';

class SheetsSyncService {
  SheetsSyncService(this._database);

  final DatabaseService _database;

  final _googleSignIn = GoogleSignIn(
    scopes: [sheets.SheetsApi.spreadsheetsScope],
  );

  Future<int> sync(String spreadsheetId) async {
    if (spreadsheetId.trim().isEmpty) {
      throw StateError('Add a Google Sheet ID in Settings first.');
    }
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw StateError('Google sign-in was cancelled.');
    }
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw StateError('Could not create Google API client.');
    }
    final api = sheets.SheetsApi(client);
    final unsynced = await _database.unsyncedEntries();
    if (unsynced.isEmpty) return 0;

    final byDate = <String, List<Entry>>{};
    for (final entry in unsynced) {
      byDate.putIfAbsent(entry.date, () => []).add(entry);
    }

    for (final group in byDate.entries) {
      final sheetTitle = _sheetTitleForDate(group.key);
      await _ensureSheet(api, spreadsheetId, sheetTitle);
      final existingRows = await _rowCount(api, spreadsheetId, sheetTitle);
      final startSerial = existingRows == 0 ? 1 : existingRows;
      final values = <List<Object?>>[
        if (existingRows == 0) _columns.cast<Object?>(),
        ...group.value
            .asMap()
            .entries
            .map((row) => row.value.toSheetRow(startSerial + row.key)),
      ];
      await api.spreadsheets.values.append(
        sheets.ValueRange(values: values),
        spreadsheetId,
        "'$sheetTitle'!A1",
        valueInputOption: 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
      );
      final allForDate = await _database.entriesForDate(group.key);
      await _updateSummary(api, spreadsheetId, group.key, DailyTotals.fromEntries(allForDate));
    }

    await _database.markSynced(unsynced.where((e) => e.id != null).map((e) => e.id!).toList());
    return unsynced.length;
  }

  static const _columns = [
    'Sl.No',
    'Vehicle No',
    'Party Name',
    'Remarks',
    'Item',
    'Qty',
    'Time In',
    'Time Out',
    'Rate',
    'Amount',
    'Cash',
    'Bank/GPay',
    'Credit',
  ];

  Future<void> _ensureSheet(
    sheets.SheetsApi api,
    String spreadsheetId,
    String title,
  ) async {
    final doc = await api.spreadsheets.get(spreadsheetId);
    final exists = doc.sheets?.any((s) => s.properties?.title == title) ?? false;
    if (exists) return;
    await api.spreadsheets.batchUpdate(
      sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(title: title),
            ),
          ),
        ],
      ),
      spreadsheetId,
    );
  }

  Future<int> _rowCount(
    sheets.SheetsApi api,
    String spreadsheetId,
    String title,
  ) async {
    try {
      final values = await api.spreadsheets.values.get(spreadsheetId, "'$title'!A:A");
      return values.values?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _updateSummary(
    sheets.SheetsApi api,
    String spreadsheetId,
    String date,
    DailyTotals totals,
  ) async {
    await _ensureSheet(api, spreadsheetId, 'Summary');
    final rows = await _summaryRows(api, spreadsheetId);
    final dailyRow = <Object?>[
      date,
      totals.vehicleCount,
      totals.totalQty,
      totals.cashTotal,
      totals.creditTotal,
      totals.itemQty.entries.map((entry) => '${entry.key}:${entry.value}').join(', '),
    ];
    final existingIndex = rows.indexWhere((row) => row.isNotEmpty && row.first == date);
    if (existingIndex == -1) {
      rows.add(dailyRow);
    } else {
      rows[existingIndex] = dailyRow;
    }
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: rows),
      spreadsheetId,
      "'Summary'!A1",
      valueInputOption: 'USER_ENTERED',
    );
  }

  Future<List<List<Object?>>> _summaryRows(
    sheets.SheetsApi api,
    String spreadsheetId,
  ) async {
    const header = ['Date', 'Vehicles', 'Total Qty', 'Cash', 'Credit', 'Item Totals'];
    try {
      final values = await api.spreadsheets.values.get(spreadsheetId, "'Summary'!A:F");
      final rows = values.values?.map((row) => row.cast<Object?>()).toList() ?? [];
      if (rows.isEmpty || rows.first.isEmpty || rows.first.first != 'Date') {
        return [header.cast<Object?>(), ...rows];
      }
      return rows;
    } catch (_) {
      return [header.cast<Object?>()];
    }
  }

  String _sheetTitleForDate(String date) {
    return date.replaceAll('/', '-');
  }
}
