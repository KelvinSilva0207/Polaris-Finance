import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../export/export_screen.dart';

const _monthNames = [
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

final _numberFormat = NumberFormat.decimalPatternDigits(
  locale: 'es',
  decimalDigits: 0,
);
final _amountFormat = NumberFormat.decimalPatternDigits(
  locale: 'es',
  decimalDigits: 2,
);

String _fmt(double value) => _numberFormat.format(value);

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _inUsd = false;

  void _previousMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final transactions =
        ref.watch(transactionsProvider).value ?? const <Transaction>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final rates = ref.watch(ratesProvider).value ?? const <CurrencyRate>[];

    double? rate;
    DateTime? rateDate;
    for (final entry in rates) {
      if (entry.rateCode == 'USD/VES' &&
          (rateDate == null || entry.date.isAfter(rateDate))) {
        rate = entry.rate;
        rateDate = entry.date;
      }
    }

    final target = _inUsd ? 'USD' : 'VES';
    double? conv(double amount, String currency) {
      if (currency == target) return amount;
      if (rate == null) return null;
      return _inUsd
          ? (currency == 'VES' ? amount / rate : null)
          : (currency == 'USD' ? amount * rate : null);
    }

    final monthStart = DateTime(_month.year, _month.month, 1);
    final monthEnd = DateTime(_month.year, _month.month + 1, 1);
    final monthTx = transactions
        .where(
          (transaction) =>
              !transaction.date.isBefore(monthStart) &&
              transaction.date.isBefore(monthEnd),
        )
        .toList();

    var income = 0.0;
    var expense = 0.0;
    var skipped = 0;
    for (final transaction in monthTx) {
      final type = TransactionType.fromStorage(transaction.type);
      if (type == TransactionType.transfer) continue;
      final value = conv(
        type == TransactionType.expense
            ? transaction.amount + transaction.feeAmount
            : transaction.amount,
        transaction.currency,
      );
      if (value == null) {
        skipped++;
        continue;
      }
      if (type == TransactionType.income) {
        income += value;
      } else {
        expense += value;
      }
    }
    final balance = income - expense;

    final categoryNames = {for (final category in categories) category.id: category};
    final categoryColors = {
      for (final category in categories) category.id: category.colorValue,
    };

    final byCategory = <String, double>{};
    final microTx = <Transaction>[];
    var microSum = 0.0;
    final microLimit = rate == null ? null : (_inUsd ? 5.0 : 5.0 * rate);
    for (final transaction in monthTx) {
      final type = TransactionType.fromStorage(transaction.type);
      if (type != TransactionType.expense) continue;
      final value = conv(
        transaction.amount + transaction.feeAmount,
        transaction.currency,
      );
      if (value == null) continue;
      final key = transaction.categoryId ?? '';
      byCategory.update(key, (current) => current + value,
          ifAbsent: () => value);
      if (microLimit != null && value <= microLimit) {
        microTx.add(transaction);
        microSum += value;
      }
    }
    final categoryEntries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = categoryEntries.take(6).toList();
    final categoryMax =
        topCategories.isEmpty ? 0.0 : topCategories.first.value;
    final microPercent = expense <= 0 ? 0.0 : microSum / expense * 100;

    final trendMonths = List.generate(
      6,
      (index) => DateTime(_month.year, _month.month - 5 + index),
    );
    final trendValues = <double>[];
    for (final month in trendMonths) {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);
      var total = 0.0;
      for (final transaction in transactions) {
        if (transaction.date.isBefore(start) ||
            !transaction.date.isBefore(end)) {
          continue;
        }
        if (TransactionType.fromStorage(transaction.type) !=
            TransactionType.expense) {
          continue;
        }
        total += conv(
              transaction.amount + transaction.feeAmount,
              transaction.currency,
            ) ??
            0;
      }
      trendValues.add(total);
    }
    final trendMax = trendValues.fold<double>(0, (max, value) => value > max ? value : max);

    final now = DateTime.now();
    final isCurrentMonth =
        _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analítica'),
        actions: [
          IconButton(
            tooltip: 'Exportar datos',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const ExportScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Mes anterior',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousMonth,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthNames[_month.month - 1]} ${_month.year}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mes siguiente',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: isCurrentMonth ? null : _nextMonth,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('VES'),
                selected: !_inUsd,
                onSelected: (_) => setState(() => _inUsd = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('USD'),
                selected: _inUsd,
                onSelected: (_) => setState(() => _inUsd = true),
              ),
              const SizedBox(width: 8),
              if (rate != null)
                Text(
                  'tasa ${_amountFormat.format(rate)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (monthTx.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Sin movimientos en ${_monthNames[_month.month - 1]}',
                  ),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Ingresos',
                    value: _fmt(income),
                    unit: target,
                    color: const Color(0xFF66BB6A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Egresos',
                    value: _fmt(expense),
                    unit: target,
                    color: const Color(0xFFEF5350),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Balance',
                    value: _fmt(balance),
                    unit: target,
                    color: balance >= 0
                        ? const Color(0xFF42A5F5)
                        : const Color(0xFFFFA726),
                  ),
                ),
              ],
            ),
            if (skipped > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$skipped movimiento(s) en monedas sin tasa convertibles no incluidos',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingresos vs egresos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _HBarRow(
                      label: 'Ingresos',
                      valueText: '${_fmt(income)} $target',
                      fraction: _ratio(income, income, expense),
                      color: const Color(0xFF66BB6A),
                    ),
                    const SizedBox(height: 8),
                    _HBarRow(
                      label: 'Egresos',
                      valueText: '${_fmt(expense)} $target',
                      fraction: _ratio(expense, income, expense),
                      color: const Color(0xFFEF5350),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Egresos por categoría',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (topCategories.isEmpty)
                      const Text('Sin egresos este mes')
                    else
                      for (final entry in topCategories) ...[
                        _HBarRow(
                          label: entry.key.isEmpty
                              ? 'Sin categoría'
                              : (categoryNames[entry.key]?.name ??
                                  'Sin categoría'),
                          valueText: _fmt(entry.value),
                          fraction: categoryMax <= 0
                              ? 0
                              : entry.value / categoryMax,
                          color: Color(
                            entry.key.isEmpty
                                ? 0xFF78909C
                                : (categoryColors[entry.key] ?? 0xFF78909C),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Egresos últimos 6 meses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _VBars(
                      values: trendValues,
                      labels: [
                        for (final month in trendMonths)
                          _monthNames[month.month - 1].substring(0, 3),
                      ],
                      maxValue: trendMax,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gastos hormiga',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      microLimit == null
                          ? 'Se necesitan tasas de referencia para detectar gastos hormiga.'
                          : '${microTx.length} gasto(s) ≤ 5 USD (${_fmt(microPercent)}% de los egresos) · ${_fmt(microSum)} $target',
                    ),
                    if (microTx.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final transaction in microTx.take(5))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(DateFormat('dd/MM').format(transaction.date)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  transaction.note?.isNotEmpty ?? false
                                      ? transaction.note!
                                      : 'sin nota',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${_amountFormat.format(conv(transaction.amount + transaction.feeAmount, transaction.currency) ?? 0)} $target',
                              ),
                            ],
                          ),
                        ),
                      if (microTx.length > 5)
                        Text(
                          '+ ${microTx.length - 5} más',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

double _ratio(double value, double income, double expense) {
  final max = income > expense ? income : expense;
  if (max <= 0) return 0;
  return value / max;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              '$value $unit',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HBarRow extends StatelessWidget {
  const _HBarRow({
    required this.label,
    required this.valueText,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String valueText;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 14,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _VBars extends StatelessWidget {
  const _VBars({
    required this.values,
    required this.labels,
    required this.maxValue,
  });

  final List<double> values;
  final List<String> labels;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    const chartHeight = 120.0;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: chartHeight + 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (maxValue > 0 && values[index] > 0)
                      Text(
                        _fmt(values[index]),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    const SizedBox(height: 4),
                    Container(
                      height: maxValue <= 0
                          ? 2.0
                          : (values[index] / maxValue) * chartHeight,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
