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

/// Texto de un porcentaje sin el símbolo `%` (ej. `0.3` → `0,30`).
String vePercentText(double value) {
  final rounded = double.parse(value.toStringAsFixed(4));
  var text = rounded.toString();
  if (!text.contains('.')) text = '$text.00';
  final parts = text.split('.');
  if (parts[1].length == 1) text = '${parts[0]}.${parts[1]}0';
  return text.replaceAll('.', ',');
}

/// Formatea un porcentaje como texto: `0.3` → `0,30 %`, `0.305` → `0,305 %`.
String formatVePercent(double value) => '${vePercentText(value)} %';

/// Parsea un texto de porcentaje a [double].
///
/// A diferencia de los montos, aquí **no hay separador de miles**: el punto
/// es un decimal, de modo que `0.30` y `0,30` valen `0.30` (y no `30`).
/// Se aceptan hasta 4 decimales. Devuelve `null` si el texto no es un
/// porcentaje válido.
double? parsePercentInput(String raw) {
  var text = raw.trim().replaceAll(' ', '').replaceAll('%', '');
  if (text.isEmpty) return null;
  if (text.startsWith('-')) return null;

  if (text.contains(',')) {
    // La coma es el separador decimal; los puntos son separadores de miles.
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (text.contains('.')) {
    // El último punto es el separador decimal; los anteriores son de miles.
    final lastDot = text.lastIndexOf('.');
    final head = text.substring(0, lastDot).replaceAll('.', '');
    final tail = text.substring(lastDot + 1);
    text = '$head.$tail';
  }
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  if (text.isEmpty) return null;

  final parsed = double.tryParse(text);
  if (parsed == null || parsed < 0) return null;
  return double.parse(parsed.toStringAsFixed(4));
}

/// Formateador de entrada para campos de porcentaje.
///
/// * Solo admite dígitos y un separador decimal (`,` o `.`), que se
///   normaliza a `,`.
/// * Un segundo separador se descarta y se aceptan hasta 4 decimales.
class VePercentFormatter extends TextInputFormatter {
  VePercentFormatter({this.maxDecimals = 4});

  final int maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final source = newValue.text;
    final buffer = StringBuffer();
    var seenSeparator = false;
    var decimals = 0;
    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      final code = ch.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        if (seenSeparator) {
          decimals++;
          if (decimals > maxDecimals) continue;
        }
        buffer.write(ch);
      } else if ((ch == ',' || ch == '.') && !seenSeparator) {
        seenSeparator = true;
        buffer.write(',');
      }
    }
    final formatted = buffer.toString();
    if (formatted == source) return newValue;

    // La posición del cursor se cuenta en caracteres conservados, que se
    // mantienen en el mismo orden dentro del texto formateado.
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, source.length)
        : source.length;
    var keptBefore = 0;
    var seen = false;
    for (var i = 0; i < cursor; i++) {
      final ch = source[i];
      final code = ch.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        keptBefore++;
      } else if ((ch == ',' || ch == '.') && !seen) {
        seen = true;
        keptBefore++;
      }
    }
    var offset = 0;
    var counted = 0;
    var seenFormatted = false;
    while (offset < formatted.length && counted < keptBefore) {
      final ch = formatted[offset];
      offset++;
      if (ch == ',') {
        if (!seenFormatted) {
          seenFormatted = true;
          counted++;
        }
      } else {
        counted++;
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

TextInputFormatter vePercentFormatter({int maxDecimals = 4}) =>
    VePercentFormatter(maxDecimals: maxDecimals);

/// Formateador de entrada de montos con comportamiento tipo caja registradora
/// (igual que las apps bancarias, p. ej. Banco de Venezuela):
///
/// * El valor se interpreta siempre como una secuencia de dígitos donde los
///   **últimos dos son los centavos**; el resto son enteros.
/// * Al teclear un dígito con el cursor al final, la secuencia crece y los
///   centavos se desplazan: `1.234,56` + `7` → `12.345,67`.
/// * Al borrar desde el final se elimina el último dígito de la secuencia.
/// * Los puntos de miles y la coma decimal se insertan automáticamente y no
///   desplazan la posición lógica del cursor.
///
/// El cursor se maneja por número de dígitos (no por índice de carácter), de
/// modo que escribir al final nunca bloquea el campo ni pierde pulsaciones.
/// Si [allowNegative] es true admite un `-` inicial.
class VeAmountFormatter extends TextInputFormatter {
  VeAmountFormatter({this.allowNegative = false});

  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawDigits = _digitsOf(newValue.text);
    final negative = allowNegative && newValue.text.contains('-');

    // Sin dígitos: el campo queda vacío (o solo el signo).
    if (rawDigits.isEmpty) {
      final text = negative ? '-' : '';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    final formatted = _render(rawDigits, negative);

    // Posición lógica del cursor: cuántos dígitos hay antes de él.
    final digitsBefore = _countDigitsBefore(newValue.text, newValue.selection);
    final offset = _caretFor(
      formatted,
      digitsBefore: digitsBefore,
      totalDigits: rawDigits.length,
      negative: negative,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  /// Extrae solo los dígitos del texto (ignora puntos, comas, signos, etc.).
  String _digitsOf(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

  /// Construye el texto formateado a partir de la secuencia de dígitos.
  /// Los dos últimos dígitos son los centavos.
  String _render(String digits, bool negative) {
    String intPart;
    String decPart;
    if (digits.length <= 2) {
      // Menos de tres dígitos: todo son centavos y no hay parte entera visible
      // hasta tener al menos un dígito que no sea decimal. Aun así, estilo
      // banco clásico: con 1-2 dígitos se muestran como enteros sin decimales.
      intPart = digits;
      decPart = '';
    } else {
      intPart = digits.substring(0, digits.length - 2);
      decPart = digits.substring(digits.length - 2);
    }

    final grouped = _groupThousands(intPart);
    final buffer = StringBuffer();
    if (negative) buffer.write('-');
    buffer.write(grouped);
    if (decPart.isNotEmpty) {
      buffer.write(',');
      buffer.write(decPart);
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

  /// Cuenta cuántos dígitos hay antes de la posición del cursor en [text].
  int _countDigitsBefore(String text, TextSelection selection) {
    final cursor = selection.isValid ? selection.extentOffset : text.length;
    var count = 0;
    final limit = cursor.clamp(0, text.length);
    for (var i = 0; i < limit; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 48 && code <= 57) count++;
    }
    return count;
  }

  /// Traduce "dígitos antes del cursor" a un índice de carácter en el texto
  /// formateado, ignorando los separadores automáticos.
  int _caretFor(
    String formatted, {
    required int digitsBefore,
    required int totalDigits,
    required bool negative,
  }) {
    // Cursor al final: se coloca al final del texto (caso más común al teclear).
    if (digitsBefore >= totalDigits) return formatted.length;

    var index = negative ? 1 : 0;
    var counted = 0;
    while (index < formatted.length && counted < digitsBefore) {
      final ch = formatted[index];
      index++;
      if (ch != '.' && ch != ',') counted++;
    }
    return index;
  }
}

TextInputFormatter veAmountFormatter({bool allowNegative = false}) =>
    VeAmountFormatter(allowNegative: allowNegative);
