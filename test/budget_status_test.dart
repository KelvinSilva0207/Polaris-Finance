import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/shared/utils/budget_status.dart';

Budget _budget({
  required double amount,
  String categoryId = 'c1',
  String currency = 'VES',
  bool isActive = true,
}) {
  return Budget(
    id: 'b-$categoryId',
    categoryId: categoryId,
    amount: amount,
    currency: currency,
    isActive: isActive,
  );
}

Transaction _tx({
  required double amount,
  String categoryId = 'c1',
  String currency = 'VES',
  String type = 'expense',
  double fee = 0,
  required DateTime date,
}) {
  return Transaction(
    id: 't-${date.toIso8601String()}-$amount',
    accountId: 'a',
    type: type,
    amount: amount,
    currency: currency,
    date: date,
    categoryId: categoryId,
    feeAmount: fee,
  );
}

void main() {
  final now = DateTime(2026, 6, 15);

  test('budgetSpent suma egresos de la categoria, moneda y mes', () {
    final spent = budgetSpent(
      budget: _budget(amount: 1000),
      transactions: [
        _tx(amount: 100, date: DateTime(2026, 6, 5), fee: 5),
        _tx(amount: 200, date: DateTime(2026, 6, 20)),
        _tx(amount: 999, date: DateTime(2026, 5, 30)), // otro mes
        _tx(amount: 999, date: DateTime(2026, 6, 6), categoryId: 'otro'),
        _tx(amount: 999, date: DateTime(2026, 6, 7), currency: 'USD'),
        _tx(amount: 999, date: DateTime(2026, 6, 8), type: 'income'),
      ],
      month: now,
    );
    expect(spent, 305);
  });

  test('nivel de presupuesto segun el ratio', () {
    BudgetStatus statusAt(double spent) => buildBudgetStatus(
      budget: _budget(amount: 1000),
      transactions: [_tx(amount: spent, date: DateTime(2026, 6, 10))],
      now: now,
    );

    expect(statusAt(500).level, BudgetLevel.ok);
    expect(statusAt(800).level, BudgetLevel.warning);
    expect(statusAt(1200).level, BudgetLevel.exceeded);
    expect(statusAt(1200).remaining, lessThan(0));
  });

  test('resumen separa excedidos y en alerta y omite inactivos', () {
    final summary = buildBudgetAlerts(
      budgets: [
        _budget(amount: 100, categoryId: 'a'),
        _budget(amount: 100, categoryId: 'b'),
        _budget(amount: 100, categoryId: 'c', isActive: false),
      ],
      transactions: [
        _tx(amount: 90, categoryId: 'a', date: DateTime(2026, 6, 10)),
        _tx(amount: 150, categoryId: 'b', date: DateTime(2026, 6, 10)),
        _tx(amount: 999, categoryId: 'c', date: DateTime(2026, 6, 10)),
      ],
      now: now,
    );
    expect(summary.warning.length, 1);
    expect(summary.exceeded.length, 1);
    expect(summary.warning.single.budget.categoryId, 'a');
    expect(summary.exceeded.single.budget.categoryId, 'b');
    expect(summary.hasAlerts, isTrue);
  });

  test('sin presupuestos en riesgo no hay alertas', () {
    final summary = buildBudgetAlerts(
      budgets: [_budget(amount: 1000)],
      transactions: [_tx(amount: 100, date: DateTime(2026, 6, 10))],
      now: now,
    );
    expect(summary.hasAlerts, isFalse);
  });
}
