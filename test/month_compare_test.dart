import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/shared/utils/month_compare.dart';

Transaction _tx({
  required String type,
  required double amount,
  required DateTime date,
  double fee = 0,
}) {
  return Transaction(
    id: 't-${date.toIso8601String()}-$amount-$type',
    accountId: 'a',
    type: type,
    amount: amount,
    currency: 'USD',
    date: date,
    feeAmount: fee,
  );
}

double? _identity(double amount, String currency) => amount;

void main() {
  test('monthTotalsOf suma ingresos y egresos y omite transferencias', () {
    final totals = monthTotalsOf(
      transactions: [
        _tx(type: 'income', amount: 100, date: DateTime(2026, 3, 5)),
        _tx(type: 'expense', amount: 40, date: DateTime(2026, 3, 6), fee: 5),
        _tx(type: 'transfer', amount: 999, date: DateTime(2026, 3, 7)),
        _tx(type: 'income', amount: 50, date: DateTime(2026, 4, 1)),
      ],
      month: DateTime(2026, 3),
      convert: _identity,
    );
    expect(totals.income, 100);
    expect(totals.expense, 45);
    expect(totals.balance, 55);
  });

  test('cuenta los movimientos sin tasa como omitidos', () {
    double? noRate(double amount, String currency) => null;
    final totals = monthTotalsOf(
      transactions: [
        _tx(type: 'expense', amount: 10, date: DateTime(2026, 3, 6)),
      ],
      month: DateTime(2026, 3),
      convert: noRate,
    );
    expect(totals.expense, 0);
    expect(totals.skipped, 1);
  });

  test('buildMonthComparison calcula deltas y porcentajes', () {
    final comparison = buildMonthComparison(
      transactions: [
        _tx(type: 'income', amount: 100, date: DateTime(2026, 2, 5)),
        _tx(type: 'expense', amount: 50, date: DateTime(2026, 2, 6)),
        _tx(type: 'income', amount: 150, date: DateTime(2026, 3, 5)),
        _tx(type: 'expense', amount: 40, date: DateTime(2026, 3, 6)),
      ],
      month: DateTime(2026, 3),
      convert: _identity,
    );
    expect(comparison.current.income, 150);
    expect(comparison.previous.income, 100);
    expect(comparison.incomeDelta, 50);
    expect(comparison.incomePercent, 50);
    expect(comparison.expenseDelta, -10);
    expect(comparison.expensePercent, -20);
    expect(comparison.balanceDelta, 60);
  });

  test('el porcentaje es null cuando el mes anterior es cero', () {
    final comparison = buildMonthComparison(
      transactions: [
        _tx(type: 'income', amount: 80, date: DateTime(2026, 3, 5)),
      ],
      month: DateTime(2026, 3),
      convert: _identity,
    );
    expect(comparison.incomePercent, isNull);
  });

  test('compara correctamente al cruzar de año (enero vs diciembre)', () {
    final comparison = buildMonthComparison(
      transactions: [
        _tx(type: 'income', amount: 60, date: DateTime(2025, 12, 15)),
        _tx(type: 'income', amount: 90, date: DateTime(2026, 1, 15)),
      ],
      month: DateTime(2026, 1),
      convert: _identity,
    );
    expect(comparison.previous.income, 60);
    expect(comparison.current.income, 90);
  });
}
