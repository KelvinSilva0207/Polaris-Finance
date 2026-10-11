import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../data/services/rate_service.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/transaction_math.dart';

class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  final Set<RateProvider> _busy = {};
  bool _euroBusy = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshLive(silent: true),
    );
    _refreshLive(silent: true);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLive({bool silent = true}) async {
    final service = ref.read(rateServiceProvider);
    for (final provider in [RateProvider.bcv, RateProvider.binance]) {
      if (_busy.contains(provider)) continue;
      setState(() => _busy.add(provider));
      final result = await service.refresh(provider);
      if (!mounted) return;
      setState(() => _busy.remove(provider));
      if (!silent) _notify(result);
    }
    await _refreshEuro(silent: silent);
  }

  Future<void> _refreshEuro({bool silent = true}) async {
    if (_euroBusy) return;
    setState(() => _euroBusy = true);
    final result = await ref.read(rateServiceProvider).refreshEuro();
    if (!mounted) return;
    setState(() => _euroBusy = false);
    if (!silent) _notify(result);
  }

  Future<void> _refresh(RateProvider provider) => _refreshLive(silent: false);

  void _notify(RateResult result) {
    if (result.error == null) {
      final isEuro = result.source == 'Euro';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEuro
                ? 'Euro: ${formatVeNumber(result.rate)} EUR/USD'
                    '${result.unchanged ? ' (sin cambios)' : ''}'
                : 'Tasa ${result.source}: ${formatVeNumber(result.rate)} VES/USD'
                    '${result.unchanged ? ' (sin cambios)' : ''}',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error!)),
    );
  }

  Future<void> _refreshManual() async {
    final controller = TextEditingController();
    final input = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tasa manual (VES por USD)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [veAmountFormatter()],
          decoration: const InputDecoration(labelText: 'Tasa'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = parseAmountInput(controller.text);
              Navigator.of(context).pop(value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (input != null && input > 0) {
      await ref.read(rateServiceProvider).refresh(
            RateProvider.manual,
            manualRate: input,
          );
    }
  }

  Widget _liveRow({
    required String title,
    required String subtitle,
    required String debugLabel,
    required CurrencyRate? rate,
    required bool busy,
    required bool isManual,
    String unit = 'VES',
  }) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(
        isManual ? Icons.edit_outlined : Icons.currency_exchange,
        color: theme.colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              rate == null
                  ? '—'
                  : '${formatVeNumber(rate.rate)} $unit'
                      '\n${DateFormat('HH:mm:ss').format(rate.date)}',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(ratesProvider);
    final settings = ref.watch(appSettingsProvider);
    final rates = ratesAsync.value ?? const [];
    final bcv = latestReferenceRate(rates, RateProvider.bcv);
    final binance = latestReferenceRate(rates, RateProvider.binance);
    final eur = latestEurRate(rates);

    return Scaffold(
      appBar: AppBar(title: const Text('Monedas')),
      body: ratesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (_) {
          final now = DateFormat('HH:mm:ss').format(DateTime.now());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.sensors, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Tasas en vivo · se actualizan cada 60 s',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      _liveRow(
                        title: 'BCV',
                        subtitle: 'Banco Central de Venezuela',
                        debugLabel: 'bcv',
                        rate: bcv,
                        busy: _busy.contains(RateProvider.bcv),
                        isManual: bcv?.isManual == true,
                      ),
                      _liveRow(
                        title: 'Binance P2P',
                        subtitle: 'Tasa P2P USD/VES',
                        debugLabel: 'binance',
                        rate: binance,
                        busy: _busy.contains(RateProvider.binance),
                        isManual: binance?.isManual == true,
                      ),
                      _liveRow(
                        title: 'Euro',
                        subtitle: 'open.er-api.com · USD/EUR',
                        debugLabel: 'eur',
                        rate: eur,
                        busy: _euroBusy,
                        isManual: false,
                        unit: 'EUR',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Última comprobación: $now',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Referencia activa: ${settings.referenceProvider.label}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.referenceProvider.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy.contains(RateProvider.bcv)
                                ? null
                                : () => _refresh(RateProvider.bcv),
                            icon: _busy.contains(RateProvider.bcv)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 18),
                            label: const Text('Actualizar BCV'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy.contains(RateProvider.binance)
                                ? null
                                : () => _refresh(RateProvider.binance),
                            icon: _busy.contains(RateProvider.binance)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 18),
                            label: const Text('Actualizar Binance'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy.contains(RateProvider.manual)
                                ? null
                                : _refreshManual,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Manual'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _euroBusy
                                ? null
                                : () => _refreshEuro(silent: false),
                            icon: _euroBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 18),
                            label: const Text('Actualizar EUR'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (rates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Sin tasas guardadas todavía.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Variación últimos 30 días',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _LegendDot(
                              color: const Color(0xFF42A5F5),
                              label: 'BCV',
                            ),
                            const SizedBox(width: 12),
                            _LegendDot(
                              color: const Color(0xFFFFA726),
                              label: 'Binance',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _RateChart(
                          primary: dailyRateSeries(
                            rates,
                            provider: RateProvider.bcv,
                          ),
                          secondary: dailyRateSeries(
                            rates,
                            provider: RateProvider.binance,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text('Historial', style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final rate in rates.take(20))
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.currency_exchange),
                      title: Text('${rate.rateCode} · ${rate.provider}'),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(rate.date),
                      ),
                      trailing: Text(
                        '${formatVeNumber(rate.rate)} → ${rate.isManual ? 'manual' : 'auto'}',
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _RateChart extends StatelessWidget {
  const _RateChart({required this.primary, required this.secondary});

  final List<({DateTime date, double rate})> primary;
  final List<({DateTime date, double rate})> secondary;

  @override
  Widget build(BuildContext context) {
    if (primary.isEmpty && secondary.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Aún no hay suficientes datos para graficar.'),
      );
    }
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _RateChartPainter(
          primary: primary,
          secondary: secondary,
          primaryColor: const Color(0xFF42A5F5),
          secondaryColor: const Color(0xFFFFA726),
          gridColor: Theme.of(context).colorScheme.outlineVariant,
          labelStyle: Theme.of(context).textTheme.labelSmall ?? const TextStyle(),
          labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _RateChartPainter extends CustomPainter {
  _RateChartPainter({
    required this.primary,
    required this.secondary,
    required this.primaryColor,
    required this.secondaryColor,
    required this.gridColor,
    required this.labelStyle,
    required this.labelColor,
  });

  final List<({DateTime date, double rate})> primary;
  final List<({DateTime date, double rate})> secondary;
  final Color primaryColor;
  final Color secondaryColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...primary, ...secondary];
    if (all.isEmpty) return;

    final dates = all.map((p) => p.date).toList()..sort();
    final start = dates.first;
    final end = dates.last;
    final span = end.difference(start).inDays;
    var minRate = all.first.rate;
    var maxRate = all.first.rate;
    for (final point in all) {
      if (point.rate < minRate) minRate = point.rate;
      if (point.rate > maxRate) maxRate = point.rate;
    }
    if (maxRate == minRate) {
      maxRate += maxRate == 0 ? 1 : maxRate * 0.05;
      minRate -= minRate == 0 ? 0 : minRate * 0.05;
    } else {
      final pad = (maxRate - minRate) * 0.1;
      maxRate += pad;
      minRate -= pad;
    }

    const leftPad = 52.0;
    const bottomPad = 22.0;
    const topPad = 6.0;
    final chartWidth = size.width - leftPad;
    final chartHeight = size.height - bottomPad - topPad;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = topPad + chartHeight * i / 4;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final value = maxRate - (maxRate - minRate) * i / 4;
      _drawText(
        canvas,
        formatVeNumber(value),
        Offset(0, y - 7),
        labelStyle.copyWith(color: labelColor),
        maxWidth: leftPad - 6,
        alignRight: true,
      );
    }

    void paintSeries(List<({DateTime date, double rate})> points, Color color) {
      if (points.isEmpty) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = span == 0
            ? leftPad + chartWidth / 2
            : leftPad +
                chartWidth *
                    (points[i].date.difference(start).inDays / span);
        final y = topPad +
            chartHeight * (maxRate - points[i].rate) / (maxRate - minRate);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = color);
      }
      canvas.drawPath(path, paint);
    }

    paintSeries(primary, primaryColor);
    paintSeries(secondary, secondaryColor);

    _drawText(
      canvas,
      DateFormat('dd/MM').format(start),
      Offset(leftPad, size.height - bottomPad + 6),
      labelStyle.copyWith(color: labelColor),
    );
    _drawText(
      canvas,
      DateFormat('dd/MM').format(end),
      Offset(size.width - 34, size.height - bottomPad + 6),
      labelStyle.copyWith(color: labelColor),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double? maxWidth,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    final dx = alignRight ? offset.dx + (maxWidth ?? 0) - painter.width : offset.dx;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _RateChartPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.secondary != secondary;
  }
}