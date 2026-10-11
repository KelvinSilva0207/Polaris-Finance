import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../core/settings/app_settings.dart';
import '../../shared/utils/net_worth.dart';
import '../../shared/utils/transaction_math.dart';

final _usdFormat = NumberFormat('#,##0.00', 'es');

class NetWorthScreen extends ConsumerStatefulWidget {
  const NetWorthScreen({super.key});

  @override
  ConsumerState<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends ConsumerState<NetWorthScreen> {
  int _months = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions =
        ref.watch(transactionsProvider).value ?? const <Transaction>[];
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final loans = ref.watch(loansProvider).value ?? const <Loan>[];
    final rates = ref.watch(ratesProvider).value ?? const <CurrencyRate>[];
    final provider = ref.watch(appSettingsProvider).referenceProvider;
    final eurRate = latestEurRate(rates)?.rate;

    final series = buildNetWorthSeries(
      transactions: transactions,
      accounts: accounts,
      loans: loans,
      months: _months,
      eurPerUsd: eurRate,
      vesPerUsdAt: (date) =>
          rateOnOrBefore(rates, date, provider: provider),
    );

    final latest = series.latest;
    final changePercent = series.changePercent;

    return Scaffold(
      appBar: AppBar(title: const Text('Patrimonio neto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patrimonio neto actual',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    '\$ ${_usdFormat.format(latest?.netUsd ?? 0)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (changePercent != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          series.changeUsd >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 16,
                          color: series.changeUsd >= 0
                              ? const Color(0xFF66BB6A)
                              : const Color(0xFFEF5350),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${changePercent >= 0 ? '+' : ''}'
                          '${changePercent.toStringAsFixed(1)}% '
                          'en $_months ${_months == 1 ? 'mes' : 'meses'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: series.changeUsd >= 0
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFFEF5350),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 6, label: Text('6M')),
                      ButtonSegment(value: 12, label: Text('12M')),
                      ButtonSegment(value: 24, label: Text('24M')),
                    ],
                    selected: {_months},
                    onSelectionChanged: (selection) =>
                        setState(() => _months = selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 180,
                child: series.isEmpty
                    ? Center(
                        child: Text('Sin datos',
                            style: theme.textTheme.bodySmall),
                      )
                    : CustomPaint(
                        painter: _NetWorthChartPainter(series.points),
                        size: Size.infinite,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _BreakdownRow(
                    label: 'Activos (cuentas + por cobrar)',
                    value: '\$ ${_usdFormat.format(latest?.assetsUsd ?? 0)}',
                  ),
                  const SizedBox(height: 8),
                  _BreakdownRow(
                    label: 'Pasivos (deudas)',
                    value: '-\$ ${_usdFormat.format(latest?.liabilitiesUsd ?? 0)}',
                    color: const Color(0xFFEF5350),
                  ),
                  const Divider(height: 24),
                  _BreakdownRow(
                    label: 'Patrimonio neto',
                    value: '\$ ${_usdFormat.format(latest?.netUsd ?? 0)}',
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          if ((latest?.skippedCurrencies.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sin tasa para: ${latest!.skippedCurrencies.join(', ')}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: style)),
        const SizedBox(width: 8),
        Text(
          value,
          style: style?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _NetWorthChartPainter extends CustomPainter {
  _NetWorthChartPainter(this.points);

  final List<NetWorthPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var min = points.first.netUsd;
    var max = points.first.netUsd;
    for (final point in points) {
      if (point.netUsd < min) min = point.netUsd;
      if (point.netUsd > max) max = point.netUsd;
    }
    if (max <= min) max = min + 1;
    final range = max - min;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double xFor(int i) => size.width * i / (points.length - 1);
    double yFor(double value) =>
        size.height * (1 - (value - min) / range);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xFor(i);
      final y = yFor(points[i].netUsd);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF9C6BFF).withValues(alpha: 0.35),
            const Color(0xFF9C6BFF).withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF9C6BFF)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NetWorthChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
