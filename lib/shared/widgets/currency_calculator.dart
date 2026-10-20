import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/currencies.dart';
import '../utils/amount_format.dart';
import '../utils/transaction_math.dart';

/// Conversor entre VES, USD, USDT (Binance) y EUR usando las tasas guardadas.
/// Muestra el resultado principal y todos los equivalentes del monto ingresado.
class CurrencyCalculator extends ConsumerStatefulWidget {
  const CurrencyCalculator({super.key});

  @override
  ConsumerState<CurrencyCalculator> createState() => _CurrencyCalculatorState();
}

class _CurrencyCalculatorState extends ConsumerState<CurrencyCalculator> {
  static const _currencies = ['VES', 'USD', 'USDT', 'EUR'];

  final _controller = TextEditingController();
  String _from = 'VES';
  String _to = 'USD';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _currencyLabel(String code) => switch (code) {
    'VES' => 'Bolívares',
    'USD' => 'Dólares',
    'USDT' => 'Binance',
    'EUR' => 'Euros',
    _ => code,
  };

  void _swap() {
    setState(() {
      final from = _from;
      _from = _to;
      _to = from;
    });
  }

  String? _missingMessage(
    String from,
    String to, {
    double? vesPerUsd,
    double? eurPerUsd,
  }) {
    if (from == to) return null;
    if ((from == 'VES' || to == 'VES') &&
        (vesPerUsd == null || vesPerUsd <= 0)) {
      return 'Agrega una tasa de referencia para convertir a VES.';
    }
    if ((from == 'EUR' || to == 'EUR') &&
        (eurPerUsd == null || eurPerUsd <= 0)) {
      return 'Agrega la tasa del Euro para convertir a EUR.';
    }
    return null;
  }

  Widget _dropdown({
    required String value,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('calculator-$label-$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final code in _currencies)
          DropdownMenuItem(value: code, child: Text(_currencyLabel(code))),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rates = ref.watch(ratesProvider).value ?? const [];
    final settings = ref.watch(appSettingsProvider);
    final vesPerUsd = latestReferenceRate(
      rates,
      settings.referenceProvider,
    )?.rate;
    final eurPerUsd = latestEurRate(rates)?.rate;
    final amount = parseAmountInput(_controller.text);
    final result = amount == null
        ? null
        : convertBetween(
            amount,
            _from,
            _to,
            vesPerUsd: vesPerUsd,
            eurPerUsd: eurPerUsd,
          );

    final missing = <String>{};
    if (amount != null) {
      for (final code in _currencies) {
        final message = _missingMessage(
          _from,
          code,
          vesPerUsd: vesPerUsd,
          eurPerUsd: eurPerUsd,
        );
        if (message != null) missing.add(message);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Calculadora de monedas',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [veAmountFormatter()],
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: '${currencySymbol(_from)} ',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dropdown(
                    value: _from,
                    label: 'De',
                    onChanged: (value) => setState(() => _from = value),
                  ),
                ),
                IconButton(
                  onPressed: _swap,
                  tooltip: 'Invertir monedas',
                  icon: const Icon(Icons.swap_horiz),
                ),
                Expanded(
                  child: _dropdown(
                    value: _to,
                    label: 'A',
                    onChanged: (value) => setState(() => _to = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (result != null)
              Text(
                '${formatVeNumber(result)} ${currencySymbol(_to)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Text(
                amount == null
                    ? 'Ingresa un monto para convertir.'
                    : (_missingMessage(
                            _from,
                            _to,
                            vesPerUsd: vesPerUsd,
                            eurPerUsd: eurPerUsd,
                          ) ??
                          'No se pudo convertir.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (amount != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final code in _currencies)
                    if (convertBetween(
                          amount,
                          _from,
                          code,
                          vesPerUsd: vesPerUsd,
                          eurPerUsd: eurPerUsd,
                        )
                        case final double value)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_currencyLabel(code)} · ${currencySymbol(code)} '
                          '${formatVeNumber(value)}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                ],
              ),
              if (missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    missing.join(' '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
