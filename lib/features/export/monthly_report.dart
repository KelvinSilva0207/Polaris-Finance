import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/transaction_math.dart';

const monthlyReportMonthNames = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Agregados de un mes usados para armar el reporte impreso.
class MonthlyReportData {
  const MonthlyReportData({
    required this.month,
    required this.incomeVes,
    required this.expenseVes,
    required this.expensesByCategory,
    required this.skipped,
    required this.transactionCount,
  });

  final DateTime month;
  final double incomeVes;
  final double expenseVes;
  final List<({String label, int colorValue, double total})> expensesByCategory;
  final int skipped;
  final int transactionCount;

  double get balanceVes => incomeVes - expenseVes;

  String get monthLabel =>
      '${monthlyReportMonthNames[month.month - 1]} ${month.year}';
}

/// Calcula los totales del mes en bolívares usando las tasas indicadas.
/// Los movimientos de monedas sin tasa se cuentan en [MonthlyReportData.skipped].
MonthlyReportData computeMonthlyReport({
  required DateTime month,
  required List<Transaction> transactions,
  required List<Category> categories,
  double? vesPerUsd,
  double? eurPerUsd,
}) {
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 1);
  final names = {for (final category in categories) category.id: category};

  var income = 0.0;
  var expense = 0.0;
  var skipped = 0;
  var count = 0;
  final byCategory = <String, double>{};

  for (final transaction in transactions) {
    if (transaction.date.isBefore(monthStart) ||
        !transaction.date.isBefore(monthEnd)) {
      continue;
    }
    final type = TransactionType.fromStorage(transaction.type);
    if (type == TransactionType.transfer) continue;
    count++;
    final amount = type == TransactionType.expense
        ? transaction.amount + transaction.feeAmount
        : transaction.amount;
    final value = convertBetween(
      amount,
      transaction.currency,
      'VES',
      vesPerUsd: vesPerUsd,
      eurPerUsd: eurPerUsd,
    );
    if (value == null) {
      skipped++;
      continue;
    }
    if (type == TransactionType.income) {
      income += value;
    } else {
      expense += value;
      final key = transaction.categoryId ?? '';
      byCategory.update(key, (current) => current + value, ifAbsent: () => value);
    }
  }

  final entries = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final byCategoryList = [
    for (final entry in entries)
      (
        label: entry.key.isEmpty
            ? 'Sin categoría'
            : (names[entry.key]?.name ?? 'Sin categoría'),
        colorValue: entry.key.isEmpty
            ? 0xFF78909C
            : (names[entry.key]?.colorValue ?? 0xFF78909C),
        total: entry.value,
      ),
  ];

  return MonthlyReportData(
    month: monthStart,
    incomeVes: income,
    expenseVes: expense,
    expensesByCategory: byCategoryList,
    skipped: skipped,
    transactionCount: count,
  );
}

String _money(double value) =>
    NumberFormat('#,##0.00', 'es').format(value);

Future<List<int>> buildMonthlyReportPdf({
  required MonthlyReportData report,
  required List<Transaction> transactions,
  required List<Account> accounts,
  required List<Category> categories,
  required Map<String, double> balances,
}) async {
  final document = pw.Document();
  final accountNames = {for (final account in accounts) account.id: account.name};
  final categoryNames = {
    for (final category in categories) category.id: category.name,
  };
  final monthStart = DateTime(report.month.year, report.month.month, 1);
  final monthEnd = DateTime(report.month.year, report.month.month + 1, 1);
  final monthTx = transactions
      .where(
        (t) => !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd),
      )
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Polaris Finance',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Reporte mensual · ${report.monthLabel}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            'Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 14),
        pw.Text('Resumen', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Concepto', 'Monto (Bs)'],
          data: [
            ['Ingresos', _money(report.incomeVes)],
            ['Egresos', _money(report.expenseVes)],
            ['Balance', _money(report.balanceVes)],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {1: pw.Alignment.centerRight},
        ),
        if (report.skipped > 0)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              '${report.skipped} movimiento(s) en monedas sin tasa no incluidos en los totales.',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Egresos por categoría',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (report.expensesByCategory.isEmpty)
          pw.Text(
            'Sin egresos registrados en el mes.',
            style: const pw.TextStyle(fontSize: 9),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: ['Categoría', 'Monto (Bs)'],
            data: [
              for (final entry in report.expensesByCategory)
                [entry.label, _money(entry.total)],
            ],
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {1: pw.Alignment.centerRight},
          ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Saldos de cuentas',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Cuenta', 'Moneda', 'Saldo'],
          data: [
            for (final account in accounts)
              [
                account.name,
                account.currency,
                _money(balances[account.id] ?? 0),
              ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {2: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Movimientos del mes',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Fecha', 'Tipo', 'Monto', 'Mon.', 'Cuenta', 'Categoría', 'Nota'],
          data: [
            for (final transaction in monthTx)
              [
                DateFormat('dd/MM').format(transaction.date),
                TransactionType.fromStorage(transaction.type).label,
                _money(transaction.amount),
                transaction.currency,
                accountNames[transaction.accountId] ?? '',
                transaction.categoryId == null
                    ? ''
                    : (categoryNames[transaction.categoryId] ?? ''),
                transaction.note ?? '',
              ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 7),
          headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {2: pw.Alignment.centerRight},
          columnWidths: {
            0: const pw.FixedColumnWidth(48),
            2: const pw.FixedColumnWidth(58),
            3: const pw.FixedColumnWidth(34),
          },
        ),
      ],
    ),
  );
  return document.save();
}

class MonthlyReportDialog extends StatefulWidget {
  const MonthlyReportDialog({super.key, this.monthsBack = 12});

  final int monthsBack;

  @override
  State<MonthlyReportDialog> createState() => _MonthlyReportDialogState();
}

class _MonthlyReportDialogState extends State<MonthlyReportDialog> {
  late final List<DateTime> _months = List.generate(
    widget.monthsBack,
    (index) => DateTime(
      DateTime.now().year,
      DateTime.now().month - index,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reporte mensual (PDF)'),
      content: SizedBox(
        width: 320,
        height: 360,
        child: ListView.builder(
          itemCount: _months.length,
          itemBuilder: (context, index) {
            final month = _months[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(
                '${monthlyReportMonthNames[month.month - 1]} ${month.year}',
              ),
              onTap: () => Navigator.of(context).pop(month),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
