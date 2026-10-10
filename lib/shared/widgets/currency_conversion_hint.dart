import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/currencies.dart';
import '../utils/amount_format.dart';
import '../utils/transaction_math.dart';

/// Muestra el equivalente aproximado de un importe en la otra moneda de
/// referencia (Bs <-> USD) usando la tasa activa en Ajustes. No dibuja nada si
/// no hay tasa disponible o la moneda no participa del par.
class CurrencyConversionHint extends ConsumerWidget {
  const CurrencyConversionHint({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
  });

  final double? amount;
  final String currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = amount;
    if (value == null || value == 0 || !value.isFinite) {
      return const SizedBox.shrink();
    }

    if (currency != 'VES' &&
        currency != 'USD' &&
        currency != 'USDT' &&
        currency != 'EUR') {
      return const SizedBox.shrink();
    }

    final rates = ref.watch(ratesProvider).value ?? const [];
    if (rates.isEmpty) return const SizedBox.shrink();

    final provider = ref.watch(appSettingsProvider).referenceProvider;
    final vesRate = latestReferenceRate(rates, provider)?.rate;
    final eurRate = latestEurRate(rates)?.rate;
    final target = currency == 'VES' ? 'USD' : 'VES';
    final converted = convertBetween(
      value,
      currency,
      target,
      vesPerUsd: vesRate,
      eurPerUsd: eurRate,
    );
    if (converted == null || converted == 0) return const SizedBox.shrink();

    final text = '≈ ${currencySymbol(target)} ${formatVeNumber(converted.abs())}';

    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final effectiveStyle =
        (style ?? Theme.of(context).textTheme.bodySmall)?.copyWith(color: color);

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_vert, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: effectiveStyle)),
        ],
      ),
    );
  }
}
