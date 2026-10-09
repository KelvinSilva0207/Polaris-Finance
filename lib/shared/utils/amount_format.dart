import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatea un número como texto de importe estilo bancos venezolanos:
/// miles con `.` y decimales con `,` (ej. 1.234.567,89).
String formatVeNumber(double value) {
  return NumberFormat.decimalPatternDigits(
    locale: 'es',
    decimalDigits: 2,
  ).format(value);
}

/// Parsea un texto de importe (miles con `.`, decimal con `,` o `.`) a [double].
double? parseAmountInput(String raw) {
  var text = raw.trim().replaceAll(' ', '');
  if (text.isEmpty) return null;
  var negative = text.startsWith('-');
  final body = negative ? text.substring(1) : text;
  if (body.isEmpty) return null;

  var normalized = body;
  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  } else {
    // Sin coma: los puntos que haya son separadores de miles.
    normalized = normalized.replaceAll('.', '');
  }
  final parsed = double.tryParse(negative ? '-$normalized' : normalized);
  if (parsed == null) return null;
  return double.parse(parsed.toStringAsFixed(2));
}

/// Formatea el texto mientras se escribe: inserta los separadores de miles,
/// acepta un único separador decimal (`,` o `.`, mostrado como `,`) y hasta
/// dos decimales. Si [allowNegative] es true admite un `-` inicial.
class VeAmountFormatter extends TextInputFormatter {
  VeAmountFormatter({this.allowNegative = false});

  final bool allowNegative;

  static bool _isNumericChar(String ch) =>
      ch == ',' || ch == '.' || (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final selection = newValue.selection;

    var numericBefore = 0;
    for (var i = 0; i < selection.extentOffset && i < text.length; i++) {
      if (_isNumericChar(text[i])) numericBefore++;
    }

    final formatted = _formatEntry(text);
    if (formatted == text) return newValue;

    final newOffset = _offsetForNumericIndex(formatted, numericBefore);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  String _formatEntry(String raw) {
    var buffer = StringBuffer();
    var sign = '';
    var integer = '';
    var decimals = '';
    var hasSeparator = false;
    var afterSeparator = false;

    for (final ch in raw.split('')) {
      if (ch == '-' && allowNegative && buffer.isEmpty && sign.isEmpty) {
        sign = '-';
        continue;
      }
      if (ch == ',' || ch == '.') {
        if (!afterSeparator) {
          hasSeparator = true;
          afterSeparator = true;
        }
        continue;
      }
      if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        if (afterSeparator) {
          if (decimals.length < 2) decimals += ch;
        } else {
          integer += ch;
        }
      }
    }

    if (integer.isEmpty && decimals.isEmpty && !afterSeparator) return '';

    final grouped = _groupThousands(integer);
    buffer.write(sign);
    buffer.write(grouped);
    if (hasSeparator) {
      buffer.write(',');
      buffer.write(decimals);
    }
    return buffer.toString();
  }

  String _groupThousands(String digits) {
    final result = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) result.write('.');
      result.write(digits[i]);
    }
    return result.toString();
  }

  int _offsetForNumericIndex(String formatted, int targetNumeric) {
    var count = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (_isNumericChar(formatted[i])) count++;
      if (count >= targetNumeric) return i + 1;
    }
    return formatted.length;
  }
}

TextInputFormatter veAmountFormatter({bool allowNegative = false}) =>
    VeAmountFormatter(allowNegative: allowNegative);