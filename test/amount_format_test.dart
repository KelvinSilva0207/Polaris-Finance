import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_finance/shared/utils/amount_format.dart';

void main() {
  group('formatVeNumber', () {
    test('aplica miles con punto y decimales con coma', () {
      expect(formatVeNumber(1234567.89), '1.234.567,89');
      expect(formatVeNumber(1000), '1.000,00');
      expect(formatVeNumber(0), '0,00');
      expect(formatVeNumber(-250.5), '-250,50');
    });
  });

  group('parseAmountInput', () {
    test('interpreta miles con punto y decimal con coma', () {
      expect(parseAmountInput('1.234.567,89'), 1234567.89);
      expect(parseAmountInput('1.234'), 1234);
      expect(parseAmountInput('12,5'), 12.5);
      expect(parseAmountInput('1.000,00'), 1000);
      expect(parseAmountInput('-1.234,56'), -1234.56);
      expect(parseAmountInput('0'), 0);
    });

    test('devuelve null para vacío o inválido', () {
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('  '), isNull);
      expect(parseAmountInput('-'), isNull);
      expect(parseAmountInput('abc'), isNull);
    });
  });

  group('VeAmountFormatter', () {
    TextEditingValue update(String raw, {bool allowNegative = false}) {
      return veAmountFormatter(allowNegative: allowNegative).formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: raw,
          selection: TextSelection.collapsed(offset: raw.length),
        ),
      );
    }

    test('agrupa miles mientras se escribe', () {
      expect(update('1').text, '1');
      expect(update('12').text, '12');
      expect(update('123').text, '123');
      expect(update('1234').text, '1.234');
      expect(update('1234567').text, '1.234.567');
      expect(update('000000').text, '000.000');
    });

    test('el punto digitado se muestra como coma decimal', () {
      expect(update('12.5').text, '12,5');
      expect(update('0.00').text, '0,00');
    });

    test('acepta máximo dos decimales', () {
      expect(update('12,345').text, '12,34');
      expect(update('1234,5').text, '1.234,5');
    });

    test('descarta caracteres no numéricos', () {
      expect(update('abc').text, '');
      expect(update('a1b2c3').text, '123');
    });

    test('negativo solo si allowNegative', () {
      expect(update('-500').text, '500');
      expect(update('-500.5', allowNegative: true).text, '-500,5');
    });

    test('el cursor se conserva sobre el texto formateado', () {
      final result = veAmountFormatter().formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: '1234567',
          selection: const TextSelection.collapsed(offset: 4),
        ),
      );
      expect(result.text, '1.234.567');
      expect(result.selection.baseOffset, greaterThan(0));
    });

    test('permite escribir cifras grandes (miles, millones, billones)', () {
      final formatter = veAmountFormatter();
      TextEditingValue value(String text) => TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
      var previous = value('');
      const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
      const expected = [
        '1',
        '12',
        '123',
        '1.234',
        '12.345',
        '123.456',
        '1.234.567',
        '12.345.678',
        '123.456.789',
        '1.234.567.890',
      ];
      for (var index = 0; index < digits.length; index++) {
        final typed = value(previous.text + digits[index]);
        final next = formatter.formatEditUpdate(previous, typed);
        expect(next.text, expected[index], reason: 'dígito ${index + 1}');
        previous = next;
      }
    });

    test('el punto seguido de 0-2 dígitos es decimal, si no, es miles', () {
      final formatter = veAmountFormatter();
      TextEditingValue value(String text) => TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
      expect(
        formatter.formatEditUpdate(value('1234'), value('1.234')).text,
        '1.234',
      );
      expect(
        formatter.formatEditUpdate(value('1.234'), value('1.2345')).text,
        '12.345',
      );
      expect(
        formatter.formatEditUpdate(value('1234'), value('1.234.')).text,
        '1.234,',
      );
      expect(
        formatter.formatEditUpdate(value('12'), value('12.50')).text,
        '12,50',
      );
      expect(
        formatter.formatEditUpdate(value('12,5'), value('12,50')).text,
        '12,50',
      );
    });
  });
}