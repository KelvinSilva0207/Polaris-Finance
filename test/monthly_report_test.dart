import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/features/export/monthly_report.dart';

Transaction _tx({
  required String type,
  required double amount,
  required String currency,
  required DateTime date,
  String? categoryId,
  double fee = 0,
}) {
  return Transaction(
    id: 't-${date.toIso8601String()}-$amount-$type',
    accountId: 'acc',
    type: type,
    amount: amount,
    currency: currency,
    date: date,
    feeAmount: fee,
    categoryId: categoryId,
    tags: null,
    transferToId: null,
    note: null,
    credAmount: null,
    credCurrency: null,
  );
}

Category _category(String id, String name) {
  return Category(
    id: id,
    name: name,
    icon: 'restaurant',
    colorValue: 0xFF112233,
    isBuiltIn: false,
    isIncome: false,
    sortOrder: 0,
  );
}

void main() {
  final month = DateTime(2026, 10);

  test('suma ingresos y egresos del mes en VES', () {
    final report = computeMonthlyReport(
      month: month,
      transactions: [
        _tx(
          type: 'income',
          amount: 1000,
          currency: 'VES',
          date: DateTime(2026, 10, 5),
        ),
        _tx(
          type: 'expense',
          amount: 100,
          currency: 'VES',
          date: DateTime(2026, 10, 6),
          categoryId: 'c1',
          fee: 5,
        ),
        _tx(
          type: 'expense',
          amount: 200,
          currency: 'VES',
          date: DateTime(2026, 9, 30),
        ),
      ],
      categories: [_category('c1', 'Comida')],
    );

    expect(report.incomeVes, 1000);
    expect(report.expenseVes, 105);
    expect(report.feeVes, 5);
    expect(report.balanceVes, 895);
    expect(report.transactionCount, 2);
    expect(report.expensesByCategory.single.label, 'Comida');
    expect(report.expensesByCategory.single.total, 105);
  });

  test('convierte movimientos en USD usando la tasa', () {
    final report = computeMonthlyReport(
      month: month,
      transactions: [
        _tx(
          type: 'expense',
          amount: 10,
          currency: 'USD',
          date: DateTime(2026, 10, 2),
        ),
      ],
      categories: const [],
      vesPerUsd: 40,
    );

    expect(report.expenseVes, 400);
    expect(report.skipped, 0);
  });

  test(
    'cuenta movimientos sin tasa como omitidos y excluye transferencias',
    () {
      final report = computeMonthlyReport(
        month: month,
        transactions: [
          _tx(
            type: 'expense',
            amount: 10,
            currency: 'USD',
            date: DateTime(2026, 10, 2),
          ),
          _tx(
            type: 'transfer',
            amount: 50,
            currency: 'VES',
            date: DateTime(2026, 10, 3),
          ),
        ],
        categories: const [],
      );

      expect(report.expenseVes, 0);
      expect(report.skipped, 1);
      expect(report.transactionCount, 1);
    },
  );
}
