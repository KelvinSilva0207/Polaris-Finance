import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/month_compare.dart';
import '../../shared/utils/transaction_math.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../budgets/budgets_screen.dart';
import '../export/export_screen.dart';
import '../export/file_saver.dart';
import '../export/monthly_report.dart';
import '../export/statistics_report.dart';
import 'cash_flow_screen.dart';
import 'inflation_screen.dart';
import 'net_worth_screen.dart';

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
  bool _exporting = false;

  /// Categoría resaltada en el donut de egresos.
  String? _selectedCategoryKey;

  Future<void> _exportStatistics() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final transactions =
          ref.read(transactionsProvider).value ?? const <Transaction>[];
      final categories =
          ref.read(categoriesProvider).value ?? const <Category>[];
      final accounts = ref.read(accountsProvider).value ?? const <Account>[];
      final rates = ref.read(ratesProvider).value ?? const <CurrencyRate>[];
      final vesPerUsd = latestReferenceRate(rates, RateProvider.bcv)?.rate;
      final eurPerUsd = latestEurRate(rates)?.rate;
      final months = [
        for (var index = 5; index >= 0; index--)
          computeMonthlyReport(
            month: DateTime(_month.year, _month.month - index),
            transactions: transactions,
            categories: categories,
            vesPerUsd: vesPerUsd,
            eurPerUsd: eurPerUsd,
          ),
      ];
      final bytes = await buildStatisticsPdf(
        months: months,
        accounts: accounts,
        balances: balancesOf(transactions, accounts: accounts),
        transactions: transactions,
        categories: categories,
      );
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final saved = await saveBackupFile(
        'polaris_estadisticas_$stamp.pdf',
        bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Estadísticas guardadas: $saved')));
    } on SaveCanceledException {
      return;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _previousMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
      _selectedCategoryKey = null;
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _month = next;
      _selectedCategoryKey = null;
    });
  }

  /// Convierte un toque sobre el donut en la categoría correspondiente.
  void _selectCategoryAt(
    Offset local,
    double size,
    List<_CategorySlice> slices,
  ) {
    final center = Offset(size / 2, size / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    // Solo el anillo responde; el centro y el exterior se ignoran.
    if (distance < size * 0.27 || distance > size * 0.5) return;
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    if (total <= 0) return;
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    var start = 0.0;
    for (final slice in slices) {
      final sweep = slice.value / total * 2 * math.pi;
      if (angle >= start && angle < start + sweep) {
        setState(() {
          _selectedCategoryKey = _selectedCategoryKey == slice.key
              ? null
              : slice.key;
        });
        return;
      }
      start += sweep;
    }
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

    final comparison = buildMonthComparison(
      transactions: transactions,
      month: _month,
      convert: conv,
    );

    final categoryNames = {
      for (final category in categories) category.id: category,
    };
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
      byCategory.update(
        key,
        (current) => current + value,
        ifAbsent: () => value,
      );
      if (microLimit != null && value <= microLimit) {
        microTx.add(transaction);
        microSum += value;
      }
    }

    final categoryEntries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = categoryEntries.take(6).toList();
    final microPercent = expense <= 0 ? 0.0 : microSum / expense * 100;

    final slices = [
      for (final entry in topCategories)
        _CategorySlice(
          key: entry.key,
          label: entry.key.isEmpty
              ? 'Sin categoría'
              : (categoryNames[entry.key]?.name ?? 'Sin categoría'),
          value: entry.value,
          color: Color(
            entry.key.isEmpty
                ? 0xFF78909C
                : (categoryColors[entry.key] ?? 0xFF78909C),
          ),
        ),
    ];
    final slicesTotal = slices.fold<double>(
      0,
      (sum, slice) => sum + slice.value,
    );
    _CategorySlice? selectedSlice;
    for (final slice in slices) {
      if (slice.key == _selectedCategoryKey) {
        selectedSlice = slice;
        break;
      }
    }

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
        total +=
            conv(
              transaction.amount + transaction.feeAmount,
              transaction.currency,
            ) ??
            0;
      }
      trendValues.add(total);
    }
    final trendMax = trendValues.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final previousMonth = DateTime(_month.year, _month.month - 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analítica'),
        actions: [
          IconButton(
            tooltip: 'Presupuestos',
            icon: const Icon(Icons.donut_large_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const BudgetsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Exportar estadísticas (PDF)',
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting ? null : _exportStatistics,
          ),
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
          PopupMenuButton<String>(
            tooltip: 'Más herramientas',
            onSelected: (value) {
              switch (value) {
                case 'inflation':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const InflationScreen(),
                    ),
                  );
                case 'netWorth':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const NetWorthScreen(),
                    ),
                  );
                case 'cashFlow':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const CashFlowScreen(),
                    ),
                  );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'inflation',
                child: ListTile(
                  leading: Icon(Icons.trending_down_outlined),
                  title: Text('Inflación y valor real'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'netWorth',
                child: ListTile(
                  leading: Icon(Icons.account_balance_outlined),
                  title: Text('Patrimonio neto'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'cashFlow',
                child: ListTile(
                  leading: Icon(Icons.stacked_line_chart),
                  title: Text('Flujo de caja proyectado'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeSlideIn(
            child: Card(
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
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Row(
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
          ),
          const SizedBox(height: 8),
          if (monthTx.isEmpty)
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Sin movimientos en ${_monthNames[_month.month - 1]}',
                    ),
                  ),
                ),
              ),
            )
          else ...[
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Ingresos',
                      amount: income,
                      unit: '',
                      color: const Color(0xFF66BB6A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      label: 'Egresos',
                      amount: expense,
                      unit: '',
                      color: const Color(0xFFEF5350),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      label: 'Balance',
                      amount: balance,
                      unit: '',
                      color: balance >= 0
                          ? const Color(0xFF42A5F5)
                          : const Color(0xFFFFA726),
                    ),
                  ),
                ],
              ),
            ),
            if (skipped > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$skipped movimiento(s) en monedas sin tasa convertibles no incluidos',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 160),
              child: Card(
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
                      if (income <= 0 && expense <= 0)
                        const Text('Sin datos para mostrar el gráfico')
                      else
                        SizedBox(
                          height: 190,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = math.min(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: Size(size, size),
                                    painter: _DonutPainter(
                                      income: income,
                                      expense: expense,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Balance',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                      Text(
                                        '${_fmt(balance)} $target',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: balance >= 0
                                                  ? const Color(0xFF66BB6A)
                                                  : const Color(0xFFEF5350),
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      _HBarRow(
                        label: 'Ingresos',
                        valueText: '${_fmt(income)} $target',
                        fraction: income <= 0 && expense <= 0
                            ? 0
                            : (income / (income + expense)).clamp(0.0, 1.0),
                        color: const Color(0xFF66BB6A),
                      ),
                      const SizedBox(height: 8),
                      _HBarRow(
                        label: 'Egresos',
                        valueText: '${_fmt(expense)} $target',
                        fraction: income <= 0 && expense <= 0
                            ? 0
                            : (expense / (income + expense)).clamp(0.0, 1.0),
                        color: const Color(0xFFEF5350),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 220),
              child: Card(
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
                      else ...[
                        SizedBox(
                          height: 220,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = math.min(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return Center(
                                child: SizedBox(
                                  width: size,
                                  height: size,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapUp: (details) =>
                                              _selectCategoryAt(
                                                details.localPosition,
                                                size,
                                                slices,
                                              ),
                                          child: CustomPaint(
                                            painter: _CategoryDonutPainter(
                                              slices: slices,
                                              selectedKey: _selectedCategoryKey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IgnorePointer(
                                        child: Padding(
                                          padding: const EdgeInsets.all(40),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                selectedSlice?.label ??
                                                    'Total egresos',
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${_fmt(selectedSlice?.value ?? expense)} $target',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              if (selectedSlice != null)
                                                Text(
                                                  slicesTotal <= 0
                                                      ? ''
                                                      : '${(selectedSlice.value / slicesTotal * 100).toStringAsFixed(1)}%',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            selectedSlice.color,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final slice in slices) ...[
                          _CategoryLegendRow(
                            label: slice.label,
                            valueText: '${_fmt(slice.value)} $target',
                            percent: slicesTotal <= 0
                                ? 0
                                : slice.value / slicesTotal * 100,
                            color: slice.color,
                            selected: slice.key == _selectedCategoryKey,
                            onTap: () => setState(() {
                              _selectedCategoryKey =
                                  _selectedCategoryKey == slice.key
                                  ? null
                                  : slice.key;
                            }),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 280),
              child: _MonthCompareCard(
                comparison: comparison,
                target: target,
                previousLabel:
                    '${_monthNames[previousMonth.month - 1]} ${previousMonth.year}',
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 340),
              child: Card(
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
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: Card(
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
                            : '${microTx.length} gasto(s) = 5 USD (${_fmt(microPercent)}% de los egresos) · ${_fmt(microSum)} $target',
                      ),
                      if (microTx.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final transaction in microTx.take(5))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  DateFormat('dd/MM').format(transaction.date),
                                ),
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
                            '+ ${microTx.length - 5} Más',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.amount,
    required this.unit,
    required this.color,
  });

  final String label;
  final double amount;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium
        ?.copyWith(color: color, fontWeight: FontWeight.bold);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: amount),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Text(
                  '${_fmt(value)} $unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                );
              },
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
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 14,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  color: color,
                );
              },
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
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: maxValue <= 0
                            ? 2.0
                            : (values[index] / maxValue) * chartHeight,
                      ),
                      duration: const Duration(milliseconds: 850),
                      curve: Interval(
                        (index * 0.09).clamp(0.0, 0.7),
                        1,
                        curve: Curves.easeOutCubic,
                      ),
                      builder: (context, height, child) {
                        return Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
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

class _MonthCompareCard extends StatelessWidget {
  const _MonthCompareCard({
    required this.comparison,
    required this.target,
    required this.previousLabel,
  });

  final MonthComparison comparison;
  final String target;
  final String previousLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comparación mensual', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('vs $previousLabel', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            _CompareRow(
              label: 'Ingresos',
              current: comparison.current.income,
              delta: comparison.incomeDelta,
              percent: comparison.incomePercent,
              goodWhenUp: true,
              target: target,
            ),
            const SizedBox(height: 10),
            _CompareRow(
              label: 'Egresos',
              current: comparison.current.expense,
              delta: comparison.expenseDelta,
              percent: comparison.expensePercent,
              goodWhenUp: false,
              target: target,
            ),
            const Divider(height: 24),
            _CompareRow(
              label: 'Balance',
              current: comparison.current.balance,
              delta: comparison.balanceDelta,
              percent: comparison.balancePercent,
              goodWhenUp: true,
              target: target,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.current,
    required this.delta,
    required this.percent,
    required this.goodWhenUp,
    required this.target,
    this.bold = false,
  });

  final String label;
  final double current;
  final double delta;
  final double? percent;
  final bool goodWhenUp;
  final String target;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unchanged = delta.abs() < 0.01;
    final good = goodWhenUp ? delta > 0 : delta < 0;
    final color = unchanged
        ? theme.colorScheme.onSurfaceVariant
        : (good ? const Color(0xFF66BB6A) : const Color(0xFFEF5350));
    final icon = unchanged
        ? Icons.remove
        : (delta > 0 ? Icons.arrow_upward : Icons.arrow_downward);
    final percentText = percent == null
        ? ''
        : ' (${percent!.abs().toStringAsFixed(0)}%)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              '${_fmt(current)} $target',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${unchanged ? 'Sin cambios' : '${delta > 0 ? '+' : '-'}${_fmt(delta.abs())} $target$percentText'} '
                'vs mes anterior',
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  void paint(Canvas canvas, Size size) {
    final total = income + expense;
    if (total <= 0) {
      final paint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14;
      final rect = Rect.fromLTWH(7, 7, size.width - 14, size.height - 14);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, paint);
      return;
    }
    final rect = Rect.fromLTWH(7, 7, size.width - 14, size.height - 14);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.butt;

    var start = -math.pi / 2;
    if (income > 0) {
      final sweep = (income / total) * 2 * math.pi;
      stroke.color = const Color(0xFF66BB6A);
      canvas.drawArc(rect, start, sweep, false, stroke);
      start += sweep;
    }
    if (expense > 0) {
      final sweep = (expense / total) * 2 * math.pi;
      stroke.color = const Color(0xFFEF5350);
      canvas.drawArc(rect, start, sweep, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.income != income || oldDelegate.expense != expense;
  }
}

/// Una porción del donut de egresos por categoría.
class _CategorySlice {
  const _CategorySlice({
    required this.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String key;
  final String label;
  final double value;
  final Color color;
}

class _CategoryDonutPainter extends CustomPainter {
  _CategoryDonutPainter({required this.slices, required this.selectedKey});

  final List<_CategorySlice> slices;
  final String? selectedKey;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    final rect = Rect.fromLTWH(14, 14, size.width - 28, size.height - 28);
    if (total <= 0) {
      final paint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, paint);
      return;
    }
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = slice.value / total * 2 * math.pi;
      final selected = slice.key == selectedKey;
      final dimmed = selectedKey != null && !selected;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 24 : 16
        ..strokeCap = StrokeCap.butt
        ..color = dimmed ? slice.color.withValues(alpha: 0.35) : slice.color;
      final gap = slices.length > 1 ? 0.018 : 0.0;
      canvas.drawArc(
        rect,
        start + gap,
        math.max(sweep - gap * 2, 0.005),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.selectedKey != selectedKey;
  }
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({
    required this.label,
    required this.valueText,
    required this.percent,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final double percent;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              valueText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
