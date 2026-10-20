import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../shared/utils/cash_flow.dart';
import '../../shared/utils/transaction_math.dart';

final _usdFormat = NumberFormat('#,##0.00', 'es');
final _dayFormat = DateFormat('dd/MM');

class CashFlowScreen extends ConsumerWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions =
        ref.watch(transactionsProvider).value ?? const <Transaction>[];
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final loans = ref.watch(loansProvider).value ?? const <Loan>[];
    final services =
        ref.watch(servicesProvider).value ?? const <RecurringService>[];
    final rates = ref.watch(ratesProvider).value ?? const <CurrencyRate>[];
    final provider = ref.watch(appSettingsProvider).referenceProvider;

    var rate = 0.0;
    DateTime? rateDate;
    for (final entry in rates) {
      if (entry.rateCode == 'USD/VES' &&
          entry.provider == provider.name &&
          (rateDate == null || entry.date.isAfter(rateDate))) {
        rate = entry.rate;
        rateDate = entry.date;
      }
    }
    final eurRate = latestEurRate(rates)?.rate;

    final balances = balancesOf(transactions, accounts: accounts);
    final totalUsd = rate <= 0
        ? null
        : totalUsdOf(balances, accounts, rate, eurPerUsd: eurRate);
    double? toUsd(double amount, String currency) {
      final factor = usdFactor(
        currency,
        vesPerUsd: rate <= 0 ? null : rate,
        eurPerUsd: eurRate,
      );
      return factor == null ? null : amount * factor;
    }

    final projection = buildCashFlowProjection(
      startBalanceUsd: totalUsd?.total ?? 0,
      transactions: transactions,
      services: services,
      loans: loans,
      from: DateTime.now(),
      toUsd: toUsd,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Flujo de caja proyectado')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo proyectado a 8 semanas',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$ ${_usdFormat.format(projection.endBalanceUsd)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MiniStat(
                        label: 'Ingresos/sem',
                        value: projection.avgWeeklyIncomeUsd,
                        color: const Color(0xFF66BB6A),
                      ),
                      const SizedBox(width: 16),
                      _MiniStat(
                        label: 'Egresos/sem',
                        value: projection.avgWeeklyExpenseUsd,
                        color: const Color(0xFFEF5350),
                      ),
                      const SizedBox(width: 16),
                      _MiniStat(
                        label: 'Compromisos',
                        value: projection.totalCommitmentsUsd,
                        color: const Color(0xFFFFA726),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (projection.firstNegativeWeek != null) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFEF5350).withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF5350)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El saldo cae por debajo de cero la semana del '
                        '${_dayFormat.format(projection.firstNegativeWeek!.start)}.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: _CashFlowChartPainter(projection.weeks),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < projection.weeks.length; i++)
                  _WeekRow(
                    week: projection.weeks[i],
                    isLast: i == projection.weeks.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Proyección estimada con el promedio de los últimos 90 días y los '
            'vencimientos conocidos. No es un consejo financiero.',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            _usdFormat.format(value),
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.week, required this.isLast});

  final CashFlowWeek week;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = week.endBalanceUsd < 0;
    return Column(
      children: [
        ListTile(
          dense: true,
          title: Text('Semana del ${_dayFormat.format(week.start)}'),
          subtitle: Text(
            'Ingresos ${_usdFormat.format(week.incomeUsd)} · '
            'Egresos ${_usdFormat.format(week.expenseUsd)}'
            '${week.commitmentsUsd > 0 ? ' · compromisos ${_usdFormat.format(week.commitmentsUsd)}' : ''}',
            style: theme.textTheme.labelSmall,
          ),
          trailing: Text(
            '\$ ${_usdFormat.format(week.endBalanceUsd)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: negative ? const Color(0xFFEF5350) : null,
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

class _CashFlowChartPainter extends CustomPainter {
  _CashFlowChartPainter(this.weeks);

  final List<CashFlowWeek> weeks;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) return;

    var max = 0.0;
    var min = 0.0;
    for (final week in weeks) {
      max = week.endBalanceUsd > max ? week.endBalanceUsd : max;
      min = week.endBalanceUsd < min ? week.endBalanceUsd : min;
    }
    if (max == min) max = min + 1;
    final range = max - min;

    double yFor(double value) => size.height * (1 - (value - min) / range);

    final zeroY = yFor(0);
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1,
    );

    final paint = Paint()
      ..color = const Color(0xFF9C6BFF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final fill = Path();
    final line = Path();
    for (var i = 0; i < weeks.length; i++) {
      final x = size.width * i / (weeks.length - 1);
      final y = yFor(weeks[i].endBalanceUsd);
      if (i == 0) {
        line.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF9C6BFF).withValues(alpha: 0.3),
            const Color(0xFF9C6BFF).withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(line, paint);
  }

  @override
  bool shouldRepaint(covariant _CashFlowChartPainter oldDelegate) =>
      oldDelegate.weeks != weeks;
}
