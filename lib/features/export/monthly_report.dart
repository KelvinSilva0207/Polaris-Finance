import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/transaction_math.dart';
import 'statistics_report.dart';

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
    required this.feeVes,
    required this.expensesByCategory,
    required this.skipped,
    required this.transactionCount,
  });

  final DateTime month;
  final double incomeVes;
  final double expenseVes;

  /// Comisiones bancarias del periodo convertidas a bolívares.
  final double feeVes;
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
  var fees = 0.0;
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
    if (transaction.feeAmount > 0) {
      fees +=
          convertBetween(
            transaction.feeAmount,
            transaction.currency,
            'VES',
            vesPerUsd: vesPerUsd,
            eurPerUsd: eurPerUsd,
          ) ??
          0;
    }
    if (type == TransactionType.income) {
      income += value;
    } else {
      expense += value;
      final key = transaction.categoryId ?? '';
      byCategory.update(
        key,
        (current) => current + value,
        ifAbsent: () => value,
      );
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
    feeVes: fees,
    expensesByCategory: byCategoryList,
    skipped: skipped,
    transactionCount: count,
  );
}

Future<List<int>> buildMonthlyReportPdf({
  required MonthlyReportData report,
  required List<Transaction> transactions,
  required List<Account> accounts,
  required List<Category> categories,
  required Map<String, double> balances,
}) {
  return buildStatisticsPdf(
    months: [report],
    accounts: accounts,
    balances: balances,
    transactions: transactions,
    categories: categories,
  );
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
    (index) => DateTime(DateTime.now().year, DateTime.now().month - index),
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
