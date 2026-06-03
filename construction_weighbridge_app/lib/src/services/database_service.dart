import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account_row.dart';
import '../models/entry.dart';
import '../models/purchase_entry.dart';
import '../models/settings.dart';
import '../models/vehicle.dart';

class DatabaseService {
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'quarry_gate.sqlite');
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _db!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_number TEXT NOT NULL,
        party_name TEXT NOT NULL,
        remarks TEXT NOT NULL,
        item_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        time_in TEXT NOT NULL,
        time_out TEXT,
        unit_rate REAL,
        amount REAL NOT NULL,
        gross_amount REAL NOT NULL DEFAULT 0,
        discount_type TEXT NOT NULL DEFAULT 'none',
        discount_value REAL,
        discount_amount REAL NOT NULL DEFAULT 0,
        net_amount REAL NOT NULL DEFAULT 0,
        payment_type TEXT NOT NULL,
        cash_amount REAL NOT NULL,
        bank_amount REAL NOT NULL DEFAULT 0,
        gpay_amount REAL NOT NULL DEFAULT 0,
        credit_amount REAL NOT NULL,
        page_slip_no INTEGER NOT NULL,
        slip_number TEXT NOT NULL DEFAULT '',
        driver_name TEXT NOT NULL DEFAULT '',
        company_body INTEGER NOT NULL DEFAULT 0,
        extra_body INTEGER NOT NULL DEFAULT 0,
        is_pickup INTEGER NOT NULL DEFAULT 0,
        body_remarks TEXT NOT NULL DEFAULT '',
        extra_info TEXT NOT NULL,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE vehicles (
        plate TEXT PRIMARY KEY,
        party_name TEXT NOT NULL,
        default_item TEXT NOT NULL,
        last_qty REAL NOT NULL,
        current_rate REAL NOT NULL DEFAULT 0,
        company_body INTEGER NOT NULL DEFAULT 0,
        extra_body INTEGER NOT NULL DEFAULT 0,
        is_pickup INTEGER NOT NULL DEFAULT 0,
        body_remarks TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE daily_summary (
        date TEXT PRIMARY KEY,
        total_vehicles INTEGER NOT NULL,
        item_totals TEXT NOT NULL,
        cash_total REAL NOT NULL,
        credit_total REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        party_name TEXT NOT NULL,
        category TEXT NOT NULL,
        debit REAL NOT NULL,
        credit REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE item_types (
        name TEXT PRIMARY KEY
      )
    ''');
    await db.execute('''
      CREATE TABLE party_names (
        name TEXT PRIMARY KEY
      )
    ''');
    await db.execute('''
      CREATE TABLE material_rates (
        name TEXT PRIMARY KEY,
        current_rate REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE purchase_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        vehicle_number TEXT NOT NULL,
        supplier_name TEXT NOT NULL,
        material TEXT NOT NULL,
        quantity REAL NOT NULL,
        rate REAL NOT NULL,
        amount REAL NOT NULL,
        remarks TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    for (final item in defaultItems) {
      await db.insert('item_types', {'name': item});
      await db.insert('material_rates', {'name': item, 'current_rate': defaultRates[item] ?? 0});
    }
    final defaults = AppSettings.defaults();
    await _putSetting(db, 'business_name', defaults.businessName);
    await _putSetting(db, 'sales_in_charge', defaults.salesInCharge);
    await _putSetting(db, 'google_sheet_id', defaults.googleSheetId);
    await _putSetting(db, 'dark_mode', defaults.darkMode ? '1' : '0');
    await _putSetting(db, 'opening_balance', defaults.openingBalance.toString());
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS party_names (
          name TEXT PRIMARY KEY
        )
      ''');
    }
    if (oldVersion < 3) {
      for (final sql in [
        'ALTER TABLE entries ADD COLUMN gross_amount REAL NOT NULL DEFAULT 0',
        "ALTER TABLE entries ADD COLUMN discount_type TEXT NOT NULL DEFAULT 'none'",
        'ALTER TABLE entries ADD COLUMN discount_value REAL',
        'ALTER TABLE entries ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0',
        'ALTER TABLE entries ADD COLUMN net_amount REAL NOT NULL DEFAULT 0',
        'ALTER TABLE entries ADD COLUMN bank_amount REAL NOT NULL DEFAULT 0',
        'ALTER TABLE entries ADD COLUMN gpay_amount REAL NOT NULL DEFAULT 0',
        "ALTER TABLE entries ADD COLUMN slip_number TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE entries ADD COLUMN driver_name TEXT NOT NULL DEFAULT ''",
        'ALTER TABLE entries ADD COLUMN company_body INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE entries ADD COLUMN extra_body INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE entries ADD COLUMN is_pickup INTEGER NOT NULL DEFAULT 0',
        "ALTER TABLE entries ADD COLUMN body_remarks TEXT NOT NULL DEFAULT ''",
        'ALTER TABLE vehicles ADD COLUMN current_rate REAL NOT NULL DEFAULT 0',
        'ALTER TABLE vehicles ADD COLUMN company_body INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE vehicles ADD COLUMN extra_body INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE vehicles ADD COLUMN is_pickup INTEGER NOT NULL DEFAULT 0',
        "ALTER TABLE vehicles ADD COLUMN body_remarks TEXT NOT NULL DEFAULT ''",
      ]) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS material_rates (
          name TEXT PRIMARY KEY,
          current_rate REAL NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          time TEXT NOT NULL,
          vehicle_number TEXT NOT NULL,
          supplier_name TEXT NOT NULL,
          material TEXT NOT NULL,
          quantity REAL NOT NULL,
          rate REAL NOT NULL,
          amount REAL NOT NULL,
          remarks TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      for (final item in defaultItems) {
        await db.insert('item_types', {'name': item}, conflictAlgorithm: ConflictAlgorithm.ignore);
        await db.insert(
          'material_rates',
          {'name': item, 'current_rate': defaultRates[item] ?? 0, 'is_active': 1},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await db.execute('UPDATE entries SET gross_amount = amount WHERE gross_amount = 0');
      await db.execute('UPDATE entries SET net_amount = amount WHERE net_amount = 0');
    }
  }

  static const defaultItems = [
    '6mm',
    '20mm',
    '40mm',
    'M-Sand',
    'P-Sand',
    'Dust',
    'PS',
    'GSB',
  ];

  static const defaultRates = {
    '6mm': 0.0,
    '20mm': 0.0,
    '40mm': 0.0,
    'M-Sand': 0.0,
    'P-Sand': 0.0,
    'Dust': 0.0,
    'PS': 0.0,
    'GSB': 0.0,
  };

  Future<void> _putSetting(DatabaseExecutor db, String key, String value) {
    return db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppSettings> settings() async {
    final rows = await (await db).query('settings');
    final values = {for (final row in rows) row['key'] as String: row['value'] as String};
    return AppSettings(
      businessName: values['business_name'] ?? AppSettings.defaults().businessName,
      salesInCharge: values['sales_in_charge'] ?? '',
      googleSheetId: values['google_sheet_id'] ?? '',
      darkMode: (values['dark_mode'] ?? '1') == '1',
      openingBalance: double.tryParse(values['opening_balance'] ?? '0') ?? 0,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final database = await db;
    await database.transaction((txn) async {
      await _putSetting(txn, 'business_name', settings.businessName);
      await _putSetting(txn, 'sales_in_charge', settings.salesInCharge);
      await _putSetting(txn, 'google_sheet_id', settings.googleSheetId);
      await _putSetting(txn, 'dark_mode', settings.darkMode ? '1' : '0');
      await _putSetting(txn, 'opening_balance', settings.openingBalance.toString());
    });
  }

  Future<List<String>> itemTypes() async {
    final rows = await (await db).query('item_types', orderBy: 'name');
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<void> addItemType(String name) async {
    await (await db).insert(
      'item_types',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await (await db).insert(
      'material_rates',
      {'name': name, 'current_rate': 0, 'is_active': 1},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeItemType(String name) async {
    await (await db).delete('item_types', where: 'name = ?', whereArgs: [name]);
    await (await db).update('material_rates', {'is_active': 0}, where: 'name = ?', whereArgs: [name]);
  }

  Future<Map<String, double>> materialRates() async {
    final rows = await (await db).query('material_rates', where: 'is_active = 1');
    return {
      for (final row in rows) row['name'] as String: (row['current_rate'] as num).toDouble(),
    };
  }

  Future<void> saveMaterialRate(String name, double rate) async {
    await (await db).insert(
      'material_rates',
      {'name': name, 'current_rate': rate, 'is_active': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> partyNames() async {
    final rows = await (await db).query('party_names', orderBy: 'name');
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<void> addPartyName(String name) async {
    await (await db).insert(
      'party_names',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removePartyName(String name) async {
    await (await db).delete('party_names', where: 'name = ?', whereArgs: [name]);
  }

  Future<Vehicle?> vehicle(String plate) async {
    final rows = await (await db).query(
      'vehicles',
      where: 'plate = ?',
      whereArgs: [normalizePlate(plate)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Vehicle.fromMap(rows.first);
  }

  Future<int> nextSlipNo(String date) async {
    final rows = await (await db).rawQuery(
      'SELECT MAX(page_slip_no) AS max_slip FROM entries WHERE date = ?',
      [date],
    );
    final maxSlip = rows.first['max_slip'] as num?;
    return (maxSlip?.toInt() ?? 0) + 1;
  }

  Future<List<Entry>> entriesForDate(String date) async {
    final rows = await (await db).query(
      'entries',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'page_slip_no DESC, id DESC',
    );
    return rows.map(Entry.fromMap).toList();
  }

  Future<List<Entry>> searchEntries({
    String? date,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (date != null) {
      clauses.add('date = ?');
      args.add(date);
    }
    if (query != null && query.trim().isNotEmpty) {
      clauses.add('(vehicle_number LIKE ? OR party_name LIKE ?)');
      args.add('%${query.trim().toUpperCase()}%');
      args.add('%${query.trim()}%');
    }
    if (from != null) {
      clauses.add('created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      clauses.add('created_at <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await (await db).query(
      'entries',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: clauses.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(Entry.fromMap).toList();
  }

  Future<List<Entry>> unsyncedEntries() async {
    final rows = await (await db).query(
      'entries',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(Entry.fromMap).toList();
  }

  Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await (await db).rawUpdate(
      'UPDATE entries SET synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<int> saveEntry(Entry entry) async {
    final database = await db;
    return database.transaction((txn) async {
      final id = entry.id == null
          ? await txn.insert('entries', entry.toMap())
          : await txn.update(
              'entries',
              entry.toMap(),
              where: 'id = ?',
              whereArgs: [entry.id],
            ).then((_) => entry.id!);

      await txn.insert(
        'vehicles',
        Vehicle(
          plate: normalizePlate(entry.vehicleNumber),
          partyName: entry.partyName,
          defaultItem: entry.itemType,
          lastQty: entry.quantity,
          currentRate: entry.unitRate ?? 0,
          companyBody: entry.companyBody,
          extraBody: entry.extraBody,
          isPickup: entry.isPickup,
          bodyRemarks: entry.bodyRemarks,
          updatedAt: DateTime.now(),
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (entry.partyName.trim().isNotEmpty) {
        await txn.insert(
          'party_names',
          {'name': entry.partyName.trim()},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await _refreshDailySummary(txn, entry.date);
      return id;
    });
  }

  Future<void> deleteEntry(Entry entry) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('entries', where: 'id = ?', whereArgs: [entry.id]);
      await _refreshDailySummary(txn, entry.date);
    });
  }

  Future<void> _refreshDailySummary(Transaction txn, String date) async {
    final rows = await txn.query('entries', where: 'date = ?', whereArgs: [date]);
    final entries = rows.map(Entry.fromMap).toList();
    final itemTotals = <String, double>{};
    var cash = 0.0;
    var credit = 0.0;
    for (final entry in entries) {
      itemTotals[entry.itemType] = (itemTotals[entry.itemType] ?? 0) + entry.quantity;
      cash += entry.cashAmount + entry.bankAmount + entry.gpayAmount;
      credit += entry.creditAmount;
    }
    await txn.insert(
      'daily_summary',
      {
        'date': date,
        'total_vehicles': entries.length,
        'item_totals': itemTotals.entries.map((e) => '${e.key}:${e.value}').join('|'),
        'cash_total': cash,
        'credit_total': credit,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AccountRow>> accountsForDate(String date) async {
    final rows = await (await db).query(
      'accounts',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'id DESC',
    );
    return rows.map(AccountRow.fromMap).toList();
  }

  Future<void> addAccount(AccountRow row) async {
    await (await db).insert('accounts', row.toMap());
  }

  Future<List<PurchaseEntry>> purchaseEntriesForDate(String date) async {
    final rows = await (await db).query(
      'purchase_entries',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'time DESC, id DESC',
    );
    return rows.map(PurchaseEntry.fromMap).toList();
  }

  Future<void> savePurchaseEntry(PurchaseEntry entry) async {
    await (await db).insert('purchase_entries', entry.toMap());
    if (entry.supplierName.trim().isNotEmpty) {
      await addPartyName(entry.supplierName.trim());
    }
  }

  Future<void> updateAccount(AccountRow row) async {
    if (row.id == null) return;
    await (await db).update(
      'accounts',
      row.toMap(),
      where: 'id = ?',
      whereArgs: [row.id],
    );
  }

  Future<void> deleteAccount(AccountRow row) async {
    if (row.id == null) return;
    await (await db).delete('accounts', where: 'id = ?', whereArgs: [row.id]);
  }

  static String normalizePlate(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
