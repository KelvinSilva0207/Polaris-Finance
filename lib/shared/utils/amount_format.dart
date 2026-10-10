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
/// acepta un único separador decimal (mostrado como `,`) y hasta dos decimales.
/// Un `.` se interpreta como decimal solo si es el último y tiene 0-2 dígitos
/// después; en cualquier otro caso se trata como separador de miles, de modo
/// que se pueden escribir cifras largas (millones, billones, etc.). Si
/// [allowNegative] es true admite un `-` inicial.
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
    final negative = allowNegative && raw.startsWith('-');
    final working = raw.replaceAll('-', '');

    int? separatorIndex;
    if (working.contains(',')) {
      separatorIndex = working.indexOf(',');
    } else if (working.contains('.')) {
      final lastDot = working.lastIndexOf('.');
      final after = working.substring(lastDot + 1);
      // Un `.` es decimal solo si va al final o va seguido de 0-2 dígitos
      // (ignorando basura que se descartará, p.ej. `12.5x`); si no, es miles.
      final digitsAfter = after.replaceAll(RegExp(r'[^0-9]'), '');
      if (after.isEmpty ||
          (digitsAfter.isNotEmpty && digitsAfter.length <= 2)) {
        separatorIndex = lastDot;
      }
    }

    final hasSeparator = separatorIndex != null;
    final String integer;
    var decimals = '';
    if (hasSeparator) {
      integer = working.substring(0, separatorIndex).replaceAll(RegExp(r'[^0-9]'), '');
      decimals = working
          .substring(separatorIndex + 1)
          .replaceAll(RegExp(r'[^0-9]'), '');
      if (decimals.length > 2) decimals = decimals.substring(0, 2);
    } else {
      integer = working.replaceAll(RegExp(r'[^0-9]'), '');
    }

    final grouped = _groupThousands(integer);
    if (grouped.isEmpty && decimals.isEmpty && !hasSeparator) {
      return negative ? '-' : '';
    }

    final buffer = StringBuffer();
    if (negative) buffer.write('-');
    buffer.write(grouped.isEmpty && hasSeparator ? '0' : grouped);
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