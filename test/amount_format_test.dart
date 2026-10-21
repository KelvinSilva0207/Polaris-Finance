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

  group('parsePercentInput', () {
    test('el punto es decimal, no separador de miles', () {
      expect(parsePercentInput('0.30'), 0.3);
      expect(parsePercentInput('0,30'), 0.3);
      expect(parsePercentInput('0.305'), 0.305);
      expect(parsePercentInput('30'), 30);
      expect(parsePercentInput('1,5'), 1.5);
      expect(parsePercentInput(' 0,30 '), 0.3);
      expect(parsePercentInput('0,30%'), 0.3);
    });

    test('devuelve null para vacío, inválido o negativo', () {
      expect(parsePercentInput(''), isNull);
      expect(parsePercentInput('  '), isNull);
      expect(parsePercentInput('abc'), isNull);
      expect(parsePercentInput('-0,30'), isNull);
    });
  });

  group('formatVePercent', () {
    test('muestra el porcentaje con coma y decimales', () {
      expect(formatVePercent(0.3), '0,30 %');
      expect(formatVePercent(0.305), '0,305 %');
      expect(formatVePercent(30), '30,00 %');
      expect(formatVePercent(0), '0,00 %');
    });
  });

  group('VePercentFormatter', () {
    TextEditingValue update(String raw) {
      return vePercentFormatter().formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: raw,
          selection: TextSelection.collapsed(offset: raw.length),
        ),
      );
    }

    test('normaliza el separador decimal a coma', () {
      expect(update('0.30').text, '0,30');
      expect(update('0,30').text, '0,30');
      expect(update('30').text, '30');
    });

    test('descarta un segundo separador y letras', () {
      expect(update('0.3.0').text, '0,30');
      expect(update('0,30,5').text, '0,305');
      expect(update('abc').text, '');
    });

    test('acepta hasta 4 decimales', () {
      expect(update('0,123456').text, '0,1234');
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

    test('interpreta la secuencia como caja registradora (2 centavos)', () {
      expect(update('1').text, '1');
      expect(update('12').text, '12');
      expect(update('123').text, '1,23');
      expect(update('1234').text, '12,34');
      expect(update('12345').text, '123,45');
      expect(update('123456').text, '1.234,56');
      expect(update('1234567890').text, '12.345.678,90');
    });

    test('agrupa miles y separa centavos automáticamente', () {
      expect(update('100000').text, '1.000,00');
      expect(update('100000000').text, '1.000.000,00');
    });

    test('descarta caracteres no numéricos', () {
      expect(update('abc').text, '');
      expect(update('a1b2c3').text, '1,23');
    });

    test('negativo solo si allowNegative', () {
      expect(update('-500').text, '5,00');
      expect(update('-500', allowNegative: true).text, '-5,00');
      expect(update('-12345', allowNegative: true).text, '-123,45');
    });

    test('el cursor se conserva sobre el texto formateado', () {
      final result = veAmountFormatter().formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: '1234567',
          selection: const TextSelection.collapsed(offset: 4),
        ),
      );
      expect(result.text, '12.345,67');
      expect(result.selection.baseOffset, greaterThan(0));
    });

    test('al teclear al final el dígito entra y desplaza los centavos', () {
      final formatter = veAmountFormatter();
      TextEditingValue value(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      // 1234 → 12,34 ; añadir 5 al final → 123,45 (NO se bloquea).
      var previous = formatter.formatEditUpdate(
        TextEditingValue.empty,
        value('1234'),
      );
      expect(previous.text, '12,34');
      expect(previous.selection.extentOffset, previous.text.length);

      previous = formatter.formatEditUpdate(previous, value('12,345'));
      expect(previous.text, '123,45');
      expect(previous.selection.extentOffset, previous.text.length);

      previous = formatter.formatEditUpdate(previous, value('123,456'));
      expect(previous.text, '1.234,56');
      expect(previous.selection.extentOffset, previous.text.length);
    });

    test('al borrar desde el final se elimina el último dígito', () {
      final formatter = veAmountFormatter();
      TextEditingValue value(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      var previous = formatter.formatEditUpdate(
        TextEditingValue.empty,
        value('123456'),
      );
      expect(previous.text, '1.234,56');
      previous = formatter.formatEditUpdate(previous, value('1.234,5'));
      expect(previous.text, '123,45');
      previous = formatter.formatEditUpdate(previous, value('123,4'));
      expect(previous.text, '12,34');
      previous = formatter.formatEditUpdate(previous, value('12,3'));
      expect(previous.text, '1,23');
    });

    group('cursor al escribir dígito a dígito', () {
      /// Simula teclear [keys] al final del campo y devuelve el valor final,
      /// comprobando en cada pulsación que el cursor queda al final.
      TextEditingValue type(TextInputFormatter formatter, String keys) {
        var value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
        for (var i = 0; i < keys.length; i++) {
          final newText = value.text + keys[i];
          final next = formatter.formatEditUpdate(
            value,
            TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: newText.length),
            ),
          );
          expect(
            next.selection.baseOffset,
            next.text.length,
            reason: 'cursor tras escribir "$keys" (dígito ${i + 1})',
          );
          value = next;
        }
        return value;
      }

      test('nunca bloquea y mantiene el cursor al final', () {
        final formatter = veAmountFormatter();
        expect(type(formatter, '12345').text, '123,45');
        expect(type(formatter, '1000000').text, '10.000,00');
        expect(type(formatter, '1234567890').text, '12.345.678,90');
      });

      test('los ceros a la derecha no rompen el valor', () {
        final formatter = veAmountFormatter();
        expect(type(formatter, '100000').text, '1.000,00');
        expect(type(formatter, '1200').text, '12,00');
        expect(type(formatter, '5').text, '5');
      });

      test('el valor final es el esperado', () {
        final formatter = veAmountFormatter();
        expect(parseAmountInput(type(formatter, '125000').text), 1250);
        expect(parseAmountInput(type(formatter, '100000').text), 1000);
        expect(parseAmountInput(type(formatter, '1234').text), 12.34);
      });
    });

    test('al borrar el último dígito no corrompe ni bloquea el campo', () {
      final formatter = veAmountFormatter();
      TextEditingValue value(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      var previous = formatter.formatEditUpdate(
        TextEditingValue.empty,
        value('100000'),
      );
      expect(previous.text, '1.000,00');
      previous = formatter.formatEditUpdate(previous, value('1.000,0'));
      expect(previous.text, '100,00');
      previous = formatter.formatEditUpdate(previous, value('100,0'));
      expect(previous.text, '10,00');
      previous = formatter.formatEditUpdate(previous, value('10,0'));
      expect(previous.text, '1,00');
    });

    test('borrar desde un millón no reduce drásticamente el monto', () {
      final formatter = veAmountFormatter();
      TextEditingValue value(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      var previous = formatter.formatEditUpdate(
        TextEditingValue.empty,
        value('1000000'),
      );
      expect(previous.text, '10.000,00');
      previous = formatter.formatEditUpdate(previous, value('10.000,0'));
      expect(previous.text, '1.000,00');
      previous = formatter.formatEditUpdate(previous, value('1.000,0'));
      expect(previous.text, '100,00');
    });
  });
}
