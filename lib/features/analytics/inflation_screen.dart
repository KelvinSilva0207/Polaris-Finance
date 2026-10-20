import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/inflation.dart';
import '../../shared/utils/transaction_math.dart';

class InflationScreen extends ConsumerStatefulWidget {
  const InflationScreen({super.key});

  @override
  ConsumerState<InflationScreen> createState() => _InflationScreenState();
}

class _InflationScreenState extends ConsumerState<InflationScreen> {
  final _amountController = TextEditingController(text: '1.000,00');
  RateProvider _provider = RateProvider.bcv;
  int _months = 12;
  double? _rateOverride;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rates = ref.watch(ratesProvider).value ?? const <CurrencyRate>[];
    final series = dailyRateSeries(rates, provider: _provider, days: 90);
    final derived = impliedMonthlyInflation(series);
    final change = periodChangePercent(series);

    final amount = parseAmountInput(_amountController.text) ?? 0;
    final monthlyRate = _rateOverride ?? derived ?? 0;
    final usingEstimate = _rateOverride == null && derived != null;
    final sim = simulateInflation(
      value: amount,
      monthlyRatePercent: monthlyRate,
      months: _months,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Inflación y valor real')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Estima cuánto pierde el poder de compra de tus bolívares con el '
            'tiempo y cuánto necesitarías para igualarlo.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('Fuente de la tasa', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<RateProvider>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: RateProvider.bcv, label: Text('BCV')),
              ButtonSegment(
                value: RateProvider.binance,
                label: Text('Binance'),
              ),
            ],
            selected: {_provider},
            onSelectionChanged: (selection) {
              setState(() {
                _provider = selection.first;
                _rateOverride = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inflación implícita (90 días)',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (derived == null)
                    Text(
                      'Sin datos suficientes de la tasa ${_provider.label} '
                      'para estimar la inflación.',
                      style: theme.textTheme.bodySmall,
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${derived.toStringAsFixed(1)}%',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEF5350),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'mensual estimado',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    if (change != null)
                      Text(
                        'Variación de la tasa USD/VES en 90 días: '
                        '${change.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [veAmountFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Monto en bolívares',
              prefixText: 'Bs ',
            ),
          ),
          const SizedBox(height: 8),
          _SliderRow(
            label: 'Horizonte',
            value: '$_months ${_months == 1 ? 'mes' : 'meses'}',
            slider: Slider(
              value: _months.toDouble(),
              min: 1,
              max: 24,
              divisions: 23,
              label: '$_months',
              onChanged: (value) => setState(() => _months = value.round()),
            ),
          ),
          _SliderRow(
            label: 'Tasa mensual',
            value:
                '${monthlyRate.toStringAsFixed(1)}%'
                '${usingEstimate ? ' (estimada)' : ''}',
            slider: Slider(
              value: monthlyRate.clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 200,
              label: '${monthlyRate.toStringAsFixed(1)}%',
              onChanged: (value) => setState(() => _rateOverride = value),
            ),
          ),
          if (_rateOverride != null && derived != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _rateOverride = null),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Usar tasa estimada'),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Proyección', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: CustomPaint(
                      painter: _InflationChartPainter(
                        requiredNominal: sim.requiredNominal,
                        realValue: sim.realValue,
                        months: sim.months,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Legend(
                    color: const Color(0xFFEF5350),
                    label: 'Necesario para igualar el poder de compra',
                  ),
                  const SizedBox(height: 6),
                  _Legend(
                    color: const Color(0xFF42A5F5),
                    label:
                        'Valor real de ${formatVeNumber(sim.startValue)} Bs sin ajustar',
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
                  _ResultRow(
                    label: 'Hoy',
                    value: 'Bs ${formatVeNumber(sim.startValue)}',
                  ),
                  const SizedBox(height: 8),
                  _ResultRow(
                    label:
                        'En $_months ${_months == 1 ? 'mes' : 'meses'} '
                        'necesitarías',
                    value: 'Bs ${formatVeNumber(sim.finalRequired)}',
                    color: const Color(0xFFEF5350),
                  ),
                  const SizedBox(height: 8),
                  _ResultRow(
                    label: 'Tus Bs de hoy valdrán',
                    value: 'Bs ${formatVeNumber(sim.finalReal)}',
                    color: const Color(0xFF42A5F5),
                  ),
                  const Divider(height: 24),
                  _ResultRow(
                    label: 'Poder de compra perdido',
                    value:
                        '${sim.purchasingPowerLossPercent.toStringAsFixed(1)}%',
                    bold: true,
                    color: const Color(0xFFEF5350),
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

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.slider,
  });

  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        slider,
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
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
        Text(value, style: style?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _InflationChartPainter extends CustomPainter {
  _InflationChartPainter({
    required this.requiredNominal,
    required this.realValue,
    required this.months,
  });

  final List<double> requiredNominal;
  final List<double> realValue;
  final int months;

  @override
  void paint(Canvas canvas, Size size) {
    if (requiredNominal.length < 2) return;

    var min = requiredNominal.first;
    var max = requiredNominal.first;
    for (final value in [...requiredNominal, ...realValue]) {
      if (value < min) min = value;
      if (value > max) max = value;
    }
    if (max <= min) max = min + 1;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    void drawLine(List<double> data, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final x = size.width * i / (data.length - 1);
        final y = size.height * (1 - (data[i] - min) / (max - min));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    drawLine(requiredNominal, const Color(0xFFEF5350));
    drawLine(realValue, const Color(0xFF42A5F5));
  }

  @override
  bool shouldRepaint(covariant _InflationChartPainter oldDelegate) {
    return oldDelegate.requiredNominal != requiredNominal ||
        oldDelegate.realValue != realValue ||
        oldDelegate.months != months;
  }
}
