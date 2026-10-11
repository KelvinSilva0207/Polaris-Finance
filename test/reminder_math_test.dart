import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/services/reminder_service_io.dart';

void main() {
  group('dateInMonth', () {
    test('usa el último día del mes si el día no existe', () {
      expect(dateInMonth(2026, 2, 31), DateTime(2026, 2, 28, 9));
      expect(dateInMonth(2028, 2, 31), DateTime(2028, 2, 29, 9));
      expect(dateInMonth(2026, 4, 31), DateTime(2026, 4, 30, 9));
    });

    test('respeta el día normal dentro del mes', () {
      expect(dateInMonth(2026, 10, 15), DateTime(2026, 10, 15, 9));
      expect(dateInMonth(2026, 12, 31), DateTime(2026, 12, 31, 9));
    });
  });

  group('nextServiceDue', () {
    final today = DateTime(2026, 10, 10);

    test('aún no vence este mes: usa este mes', () {
      expect(
        nextServiceDue(15, today, null),
        DateTime(2026, 10, 15, 9),
      );
    });

    test('ya pasó el día este mes: pasa al siguiente mes', () {
      expect(
        nextServiceDue(5, today, null),
        DateTime(2026, 11, 5, 9),
      );
    });

    test('si ya se pagó este mes, avisa el próximo mes', () {
      expect(
        nextServiceDue(15, today, DateTime(2026, 10, 15)),
        DateTime(2026, 11, 15, 9),
      );
    });

    test('el último día del año pasa a enero del año siguiente', () {
      final endOfYear = DateTime(2026, 12, 31);
      expect(
        nextServiceDue(5, endOfYear, null),
        DateTime(2027, 1, 5, 9),
      );
    });
  });
}