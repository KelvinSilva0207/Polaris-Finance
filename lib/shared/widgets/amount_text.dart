import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    super.key,
    this.currency,
    this.hidden = false,
    this.style,
  });

  final double amount;
  final String? currency;
  final bool hidden;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (hidden) return Text('••••', style: style);
    final formatted = NumberFormat.decimalPatternDigits(
      locale: 'es',
      decimalDigits: 2,
    ).format(amount.abs());
    final sign = amount < 0 ? '-' : '';
    final suffix = currency == null ? '' : ' $currency';
    return Text('$sign$formatted$suffix', style: style);
  }
}