import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/daily_totals.dart';
import '../models/entry.dart';
import '../models/settings.dart';

class ExportService {
  Future<File> exportExcel(String date, List<Entry> entries) async {
    final sorted = _sortedForReport(entries);
    final book = Excel.createExcel();
    final sheet = book['Daily Log'];
    sheet.appendRow(_headers.map(TextCellValue.new).toList());
    for (var i = 0; i < sorted.length; i++) {
      sheet.appendRow(
        sorted[i].toSheetRow(i + 1).map((value) => TextCellValue('$value')).toList(),
      );
    }
    final file = await _reportFile(date, 'xlsx');
    await file.writeAsBytes(book.encode()!);
    await OpenFilex.open(file.path);
    return file;
  }

  Future<File> exportPdf(
    String date,
    List<Entry> entries,
    AppSettings settings,
  ) async {
    final sorted = _sortedForReport(entries);
    final totals = DailyTotals.fromEntries(sorted);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(settings.businessName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: $date'),
                  pw.Text('Sales In Charge: ${settings.salesInCharge}'),
                ],
              ),
              pw.Text('Page No: ${sorted.isEmpty ? '-' : sorted.last.pageSlipNo}'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: _headers,
            data: sorted.asMap().entries.map((row) => row.value.toSheetRow(row.key + 1)).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Totals: Qty ${totals.totalQty.toStringAsFixed(2)} | Cash Rs ${totals.cashTotal.toStringAsFixed(2)} | Credit Rs ${totals.creditTotal.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(_bottomSummary(totals)),
        ],
      ),
    );
    final file = await _reportFile(date, 'pdf');
    await file.writeAsBytes(await doc.save());
    await OpenFilex.open(file.path);
    return file;
  }

  Future<void> share(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  static const _headers = [
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
    'Credit',
  ];

  List<Entry> _sortedForReport(List<Entry> entries) {
    return [...entries]..sort((a, b) => a.pageSlipNo.compareTo(b.pageSlipNo));
  }

  Future<File> _reportFile(String date, String ext) async {
    final baseDir = await _safeDownloadsDirectory() ??
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(baseDir.path, 'QuarryGateReports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safeDate = date.replaceAll('/', '-');
    final stamp = DateFormat('HHmmss').format(DateTime.now());
    return File(p.join(dir.path, 'quarry_report_${safeDate}_$stamp.$ext'));
  }

  Future<Directory?> _safeDownloadsDirectory() async {
    try {
      return getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }

  String _bottomSummary(DailyTotals totals) {
    String qty(String item) => (totals.itemQty[item] ?? 0).toStringAsFixed(2);
    return '40mm=${qty('40mm')} 20mm=${qty('20mm')} 12mm=${qty('12mm')} 6mm=${qty('6mm')} Dust=${qty('Dust')} Ms=${qty('Sand')}';
  }
}
