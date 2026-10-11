import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/shared/utils/forecast.dart';
import 'package:polaris_finance/shared/utils/transaction_math.dart';

RecurringService _service({
  required String name,
  required double amount,
  required String currency,
  required int dayOfMonth,
  bool isActive = true,
  DateTime? lastPaid,
}) {
  return RecurringService(
    id: name,
    name: name,
    amount: amount,
    currency: currency,
    dayOfMonth: dayOfMonth,
    isActive: isActive,
    lastPaidDate: lastPaid,
  );
}

Loan _loan({
  required String name,
  required double principal,
  required double paid,
  required String currency,
  DateTime? dueDate,
  bool isActive = true,
}) {
  return Loan(
    id: name,
    name: name,
    type: 'debt',
    currency: currency,
    principal: principal,
    paidAmount: paid,
    interestRate: 0,
    startDate: DateTime(2026, 1, 1),
    dueDate: dueDate,
    isActive: isActive,
  );
}

void main() {
  final from = DateTime(2026, 10, 10);

  test('resta servicios y préstamos dentro del horizonte de 30 días', () {
    final forecast = buildForecast(
      currentUsd: 1000,
      services: [
        _service(name: 'Internet', amount: 40, currency: 'USD', dayOfMonth: 20),
        _service(name: 'Netflix', amount: 15, currency: 'USD', dayOfMonth: 5),
      ],
      loans: [
        _loan(
          name: 'Préstamo banco',
          principal: 500,
          paid: 200,
          currency: 'USD',
          dueDate: DateTime(2026, 10, 25),
        ),
      ],
      from: from,
      toUsd: (amount, currency) => currency == 'USD' ? amount : null,
    );

    expect(forecast.currentUsd, 1000);
    expect(forecast.commitments, hasLength(3));
    expect(forecast.committedUsd, 40 + 15 + 300);
    expect(forecast.projectedUsd, 1000 - 355);
    expect(forecast.skippedCurrencies, isEmpty);
    expect(forecast.commitments.first.label, 'Internet');
    expect(forecast.commitments.last.label, 'Netflix');
  });

  test('excluye servicios inactivos, ya pagados y vencimientos lejanos', () {
    final forecast = buildForecast(
      currentUsd: 500,
      services: [
        _service(
          name: 'Pagado',
          amount: 10,
          currency: 'USD',
          dayOfMonth: 15,
          lastPaid: DateTime(2026, 10, 15),
        ),
        _service(
          name: 'Inactivo',
          amount: 10,
          currency: 'USD',
          dayOfMonth: 15,
          isActive: false,
        ),
      ],
      loans: [
        _loan(
          name: 'Lejano',
          principal: 100,
          paid: 0,
          currency: 'USD',
          dueDate: DateTime(2026, 12, 31),
        ),
        _loan(
          name: 'Pagado del todo',
          principal: 100,
          paid: 100,
          currency: 'USD',
          dueDate: DateTime(2026, 10, 20),
        ),
      ],
      from: from,
      toUsd: (amount, currency) => amount,
    );

    expect(forecast.commitments, isEmpty);
    expect(forecast.projectedUsd, 500);
  });

  test('reporta monedas sin tasa', () {
    final forecast = buildForecast(
      currentUsd: 100,
      services: [
        _service(name: 'COP', amount: 20000, currency: 'COP', dayOfMonth: 15),
      ],
      loans: const [],
      from: from,
      toUsd: (amount, currency) => currency == 'USD' ? amount : null,
    );

    expect(forecast.commitments, isEmpty);
    expect(forecast.skippedCurrencies, {'COP'});
  });

  group('dailyRateSeries', () {
    CurrencyRate rate({
      required String provider,
      required double value,
      required DateTime date,
    }) {
      return CurrencyRate(
        id: '$provider-${date.toIso8601String()}',
        code: 'USD',
        rateCode: 'USD/VES',
        provider: provider,
        rate: value,
        date: date,
        isManual: false,
      );
    }

    test('toma el último valor de cada día dentro de la ventana', () {
      final now = DateTime(2026, 10, 10);
      final series = dailyRateSeries(
        [
          rate(provider: 'bcv', value: 30, date: DateTime(2026, 10, 9, 8)),
          rate(provider: 'bcv', value: 31, date: DateTime(2026, 10, 9, 18)),
          rate(provider: 'bcv', value: 32, date: DateTime(2026, 10, 10, 9)),
          rate(provider: 'bcv', value: 99, date: DateTime(2026, 8, 1)),
          rate(provider: 'binance', value: 40, date: DateTime(2026, 10, 10)),
        ],
        provider: RateProvider.bcv,
        days: 30,
        now: now,
      );

      expect(series, hasLength(2));
      expect(series.first.rate, 31);
      expect(series.last.rate, 32);
    });
  });
}