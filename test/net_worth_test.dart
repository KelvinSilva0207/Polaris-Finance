import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/shared/utils/net_worth.dart';

Account _account({
  required String id,
  String currency = 'USD',
  double opening = 0,
}) {
  return Account(
    id: id,
    name: id,
    type: 'cash',
    currency: currency,
    colorValue: 0xFF112233,
    icon: 'wallet',
    isDefault: false,
    openingBalance: opening,
    createdAt: DateTime(2020, 1, 1),
  );
}

Transaction _tx({
  required String accountId,
  required String type,
  required double amount,
  String currency = 'USD',
  required DateTime date,
}) {
  return Transaction(
    id: 't-${date.toIso8601String()}-$amount',
    accountId: accountId,
    type: type,
    amount: amount,
    currency: currency,
    date: date,
    feeAmount: 0,
  );
}

Loan _loan({
  required String type,
  required double principal,
  double paid = 0,
  String currency = 'USD',
  DateTime? start,
}) {
  return Loan(
    id: 'l-$type-$principal',
    name: 'loan',
    type: type,
    currency: currency,
    principal: principal,
    paidAmount: paid,
    interestRate: 0,
    startDate: start ?? DateTime(2020, 1, 1),
    isActive: true,
  );
}

void main() {
  final now = DateTime(2026, 10, 15);

  test('patrimonio neto suma activos y resta deudas', () {
    final series = buildNetWorthSeries(
      transactions: [
        _tx(
          accountId: 'a',
          type: 'income',
          amount: 500,
          date: DateTime(2026, 5, 10),
        ),
      ],
      accounts: [_account(id: 'a', opening: 1000)],
      loans: [_loan(type: 'debt', principal: 300)],
      vesPerUsdAt: (_) => 40,
      months: 6,
      now: now,
    );

    final latest = series.latest!;
    expect(latest.assetsUsd, 1500);
    expect(latest.liabilitiesUsd, 300);
    expect(latest.netUsd, 1200);
    // El último punto es la fecha "now".
    expect(latest.date, now);
  });

  test('los prestamos tipo lend suman a los activos', () {
    final series = buildNetWorthSeries(
      transactions: const [],
      accounts: [_account(id: 'a', opening: 100)],
      loans: [_loan(type: 'lend', principal: 250)],
      vesPerUsdAt: (_) => 40,
      months: 1,
      now: now,
    );

    final latest = series.latest!;
    expect(latest.assetsUsd, 350);
    expect(latest.liabilitiesUsd, 0);
    expect(latest.netUsd, 350);
  });

  test('convierte saldos en VES usando la tasa de la fecha', () {
    final series = buildNetWorthSeries(
      transactions: const [],
      accounts: [_account(id: 'a', currency: 'VES', opening: 4000)],
      loans: const [],
      vesPerUsdAt: (_) => 40,
      months: 1,
      now: now,
    );
    expect(series.latest!.assetsUsd, 100);
  });

  test('marca monedas sin tasa y las excluye', () {
    final series = buildNetWorthSeries(
      transactions: const [],
      accounts: [_account(id: 'a', currency: 'VES', opening: 4000)],
      loans: const [],
      vesPerUsdAt: (_) => null,
      months: 1,
      now: now,
    );
    final latest = series.latest!;
    expect(latest.assetsUsd, 0);
    expect(latest.skippedCurrencies, contains('VES'));
  });

  test('genera months+1 puntos y calcula el cambio', () {
    final series = buildNetWorthSeries(
      transactions: const [],
      accounts: [_account(id: 'a', opening: 100)],
      loans: const [],
      vesPerUsdAt: (_) => 40,
      months: 12,
      now: now,
    );
    expect(series.points.length, 13);
    expect(series.first!.netUsd, 100);
    expect(series.changeUsd, 0);
    expect(series.changePercent, 0);
  });
}
