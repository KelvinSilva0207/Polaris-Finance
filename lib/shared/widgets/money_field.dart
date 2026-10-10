import 'package:flutter/material.dart';

import '../../data/models/currencies.dart';
import '../utils/amount_format.dart';
import 'currency_conversion_hint.dart';

/// Campo de texto para importes de dinero: muestra el símbolo de la moneda,
/// agrupa los miles mientras se escribe, admite decimales con coma y, por
/// defecto, enseña debajo el equivalente aproximado en la otra moneda.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.label = 'Monto',
    this.hintText,
    this.currency = 'VES',
    this.allowNegative = false,
    this.enabled = true,
    this.autofocus = false,
    this.helperText,
    this.showEquivalent = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String currency;
  final bool allowNegative;
  final bool enabled;
  final bool autofocus;
  final String? helperText;
  final bool showEquivalent;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      onChanged: onChanged,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: allowNegative,
      ),
      inputFormatters: [veAmountFormatter(allowNegative: allowNegative)],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixText: '${currencySymbol(currency)} ',
      ),
    );

    if (!showEquivalent) return field;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => CurrencyConversionHint(
            amount: parseAmountInput(controller.text),
            currency: currency,
          ),
        ),
      ],
    );
  }
}
