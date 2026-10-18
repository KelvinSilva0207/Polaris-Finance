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

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final formatted = _formatEntry(text);
    if (formatted == text) return newValue;

    final offset = _caretOffset(
      text,
      newValue.selection.extentOffset,
      formatted,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  String _formatEntry(String raw) {
    final negative = allowNegative && raw.startsWith('-');
    final working = raw.replaceAll('-', '');
    final separatorIndex = _findSeparatorIndex(working);
    final hasSeparator = separatorIndex >= 0;

    final String integer;
    var decimals = '';
    if (hasSeparator) {
      integer = working
          .substring(0, separatorIndex)
          .replaceAll(RegExp(r'[^0-9]'), '');
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

  /// Índice del separador decimal dentro de [body] (ya sin el signo), o -1 si
  /// no hay parte decimal. La coma siempre es decimal; el punto solo lo es si
  /// va al final o seguido de uno o dos dígitos; en otro caso es separador de
  /// miles.
  int _findSeparatorIndex(String body) {
    if (body.contains(',')) return body.indexOf(',');
    if (body.contains('.')) {
      final lastDot = body.lastIndexOf('.');
      final after = body.substring(lastDot + 1);
      final digitsAfter = after.replaceAll(RegExp(r'[^0-9]'), '');
      if (after.isEmpty ||
          (digitsAfter.isNotEmpty && digitsAfter.length <= 2)) {
        return lastDot;
      }
    }
    return -1;
  }

  String _groupThousands(String digits) {
    final result = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) result.write('.');
      result.write(digits[i]);
    }
    return result.toString();
  }

  /// Calcula la posición del cursor tras reformatear, tomando como referencia
  /// los dígitos (y la posición respecto al separador decimal) que había antes
  /// del cursor. Los puntos de miles que inserta el formateador no cuentan, así
  /// que el cursor no se desplaza al escribirlos (p.ej. `1000`+`,`).
  int _caretOffset(String raw, int cursor, String formatted) {
    final negative = allowNegative && raw.startsWith('-');
    final bodyStart = negative ? 1 : 0;
    final body = raw.substring(bodyStart);
    final separatorIndex = _findSeparatorIndex(body);
    final separatorOffset = separatorIndex < 0
        ? -1
        : separatorIndex + bodyStart;

    var intDigits = 0;
    var decDigits = 0;
    for (var i = 0; i < cursor && i < raw.length; i++) {
      final code = raw.codeUnitAt(i);
      if (code < 48 || code > 57) continue;
      if (separatorOffset >= 0 && i > separatorOffset) {
        decDigits++;
      } else {
        intDigits++;
      }
    }
    final afterSeparator = separatorOffset >= 0 && cursor > separatorOffset;

    return _offsetFor(
      formatted,
      intDigits: intDigits,
      decDigits: decDigits,
      afterSeparator: afterSeparator,
    );
  }

  int _offsetFor(
    String formatted, {
    required int intDigits,
    required int decDigits,
    required bool afterSeparator,
  }) {
    var index = 0;
    if (index < formatted.length && formatted[index] == '-') index++;

    // El formateador antepone un `0` a la coma cuando no hay dígitos enteros;
    // ese cero no debe consumir una posición de dígito del cursor.
    if (intDigits == 0 &&
        index + 1 < formatted.length &&
        formatted[index] == '0' &&
        formatted[index + 1] == ',') {
      return _consumeDecimals(formatted, index + 2, decDigits);
    }

    var counted = 0;
    while (index < formatted.length && counted < intDigits) {
      final ch = formatted[index];
      if (ch == ',') break;
      index++;
      if (ch != '.') counted++;
    }

    if (afterSeparator || decDigits > 0) {
      if (index < formatted.length && formatted[index] == ',') {
        return _consumeDecimals(formatted, index + 1, decDigits);
      }
    }
    return index;
  }

  int _consumeDecimals(String formatted, int index, int decDigits) {
    var counted = 0;
    while (index < formatted.length && counted < decDigits) {
      if (formatted[index] != '.') counted++;
      index++;
    }
    return index;
  }
}

TextInputFormatter veAmountFormatter({bool allowNegative = false}) =>
    VeAmountFormatter(allowNegative: allowNegative);
