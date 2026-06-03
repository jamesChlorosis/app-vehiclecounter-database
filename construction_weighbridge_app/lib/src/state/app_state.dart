import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/account_row.dart';
import '../models/daily_totals.dart';
import '../models/entry.dart';
import '../models/purchase_entry.dart';
import '../models/settings.dart';
import '../models/vehicle.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/sheets_sync_service.dart';

class AppState extends ChangeNotifier {
  final database = DatabaseService();
  late final SheetsSyncService sheetsSync = SheetsSyncService(database);
  final exportService = ExportService();

  AppSettings settings = AppSettings.defaults();
  List<String> itemTypes = DatabaseService.defaultItems;
  Map<String, double> materialRates = {};
  List<String> partyNames = [];
  List<Entry> todayEntries = [];
  List<PurchaseEntry> todayPurchases = [];
  List<AccountRow> accounts = [];
  int unsyncedCount = 0;
  bool busy = false;
  bool syncing = false;
  String today = Entry.dateFormat.format(DateTime.now());

  DailyTotals get totals => DailyTotals.fromEntries(todayEntries);

  double get accountDebitTotal => accounts.fold(0, (sum, row) => sum + row.debit);
  double get accountCreditTotal => accounts.fold(0, (sum, row) => sum + row.credit);
  double get closingBalance => settings.openingBalance + totals.cashTotal - accountDebitTotal;

  Future<void> bootstrap() async {
    settings = await database.settings();
    itemTypes = await database.itemTypes();
    materialRates = await database.materialRates();
    partyNames = await database.partyNames();
    await refresh();
  }

  Future<void> refresh() async {
    today = Entry.dateFormat.format(DateTime.now());
    todayEntries = await database.entriesForDate(today);
    todayPurchases = await database.purchaseEntriesForDate(today);
    accounts = await database.accountsForDate(today);
    partyNames = await database.partyNames();
    materialRates = await database.materialRates();
    unsyncedCount = (await database.unsyncedEntries()).length;
    notifyListeners();
  }

  Future<Vehicle?> findVehicle(String plate) => database.vehicle(plate);

  Future<int> nextSlipNo() => database.nextSlipNo(today);

  Future<void> saveEntry(Entry entry) async {
    busy = true;
    notifyListeners();
    await database.saveEntry(entry);
    await refresh();
    busy = false;
    notifyListeners();
  }

  Future<void> deleteEntry(Entry entry) async {
    await database.deleteEntry(entry);
    await refresh();
  }

  Future<void> saveSettings(AppSettings next) async {
    settings = next.copyWith(googleSheetId: extractSpreadsheetId(next.googleSheetId));
    await database.saveSettings(settings);
    notifyListeners();
  }

  Future<void> addItemType(String item) async {
    final cleaned = item.trim();
    if (cleaned.isEmpty) return;
    await database.addItemType(cleaned);
    itemTypes = await database.itemTypes();
    materialRates = await database.materialRates();
    notifyListeners();
  }

  Future<void> removeItemType(String item) async {
    await database.removeItemType(item);
    itemTypes = await database.itemTypes();
    materialRates = await database.materialRates();
    notifyListeners();
  }

  Future<void> saveMaterialRate(String item, double rate) async {
    await database.saveMaterialRate(item, rate);
    materialRates = await database.materialRates();
    notifyListeners();
  }

  Future<void> addPartyName(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;
    await database.addPartyName(cleaned);
    partyNames = await database.partyNames();
    notifyListeners();
  }

  Future<void> removePartyName(String name) async {
    await database.removePartyName(name);
    partyNames = await database.partyNames();
    notifyListeners();
  }

  Future<void> addAccount(AccountRow row) async {
    await database.addAccount(row);
    accounts = await database.accountsForDate(today);
    notifyListeners();
  }

  Future<void> savePurchaseEntry(PurchaseEntry entry) async {
    await database.savePurchaseEntry(entry);
    await refresh();
  }

  Future<void> updateAccount(AccountRow row) async {
    await database.updateAccount(row);
    accounts = await database.accountsForDate(today);
    notifyListeners();
  }

  Future<void> deleteAccount(AccountRow row) async {
    await database.deleteAccount(row);
    accounts = await database.accountsForDate(today);
    notifyListeners();
  }

  Future<int> syncToSheets() async {
    syncing = true;
    notifyListeners();
    try {
      final count = await sheetsSync.sync(settings.googleSheetId);
      await refresh();
      return count;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<File> exportExcel() => exportService.exportExcel(today, todayEntries);

  Future<File> exportPdf() => exportService.exportPdf(today, todayEntries, settings);

  static String extractSpreadsheetId(String input) {
    final trimmed = input.trim();
    final match = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(trimmed);
    return match?.group(1) ?? trimmed;
  }
}
