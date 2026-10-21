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
