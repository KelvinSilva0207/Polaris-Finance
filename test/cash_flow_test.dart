import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/shared/utils/cash_flow.dart';

Transaction _tx({
  required String type,
  required double amount,
  required DateTime date,
}) {
  return Transaction(
    id: 't-${date.toIso8601String()}-$amount-$type',
    accountId: 'a',
    type: type,
    amount: amount,
    currency: 'USD',
    date: date,
    feeAmount: 0,
  );
}

RecurringService _service({
  required double amount,
  required int day,
  DateTime? lastPaid,
  bool isActive = true,
}) {
  return RecurringService(
    id: 's-$day',
    name: 'servicio',
    amount: amount,
    currency: 'USD',
    dayOfMonth: day,
    isActive: isActive,
    lastPaidDate: lastPaid,
  );
}

Loan _loan({
  required double principal,
  double paid = 0,
  DateTime? due,
  bool isActive = true,
}) {
  return Loan(
    id: 'l',
    name: 'prestamo',
    type: 'debt',
    currency: 'USD',
    principal: principal,
    paidAmount: paid,
    interestRate: 0,
    startDate: DateTime(2020, 1, 1),
    dueDate: due,
    isActive: isActive,
  );
}

double? _identity(double amount, String currency) => amount;

void main() {
  final from = DateTime(2026, 6, 1);

  test('promedia ingresos y egresos semanales del historial', () {
    final projection = buildCashFlowProjection(
      startBalanceUsd: 1000,
      transactions: [
        // 90 dias de historial: 3 ingresos de 100 y 3 egresos de 50.
        for (var week = 0; week < 3; week++) ...[
          _tx(
            type: 'income',
            amount: 100,
            date: from.subtract(Duration(days: week * 7 + 1)),
          ),
          _tx(
            type: 'expense',
            amount: 50,
            date: from.subtract(Duration(days: week * 7 + 2)),
          ),
        ],
      ],
      services: const [],
      loans: const [],
      from: from,
      toUsd: _identity,
      weeks: 4,
    );

    // 300 USD de ingreso / (90/7 = 12.857 semanas) = ~23.33 USD/semana.
    expect(projection.avgWeeklyIncomeUsd, closeTo(300 / (90 / 7), 0.01));
    expect(projection.avgWeeklyExpenseUsd, closeTo(150 / (90 / 7), 0.01));
    expect(projection.weeks.length, 4);
  });

  test('resta los vencimientos de servicios en la semana correcta', () {
    final projection = buildCashFlowProjection(
      startBalanceUsd: 0,
      transactions: const [],
      services: [_service(amount: 200, day: 10)],
      loans: const [],
      from: from,
      toUsd: _identity,
      weeks: 8,
    );

    expect(projection.totalCommitmentsUsd, 400); // dia 10 de junio y julio
    // Semana 1 (1-8 jun) sin vencimiento, semana 2 (8-15) con 200.
    expect(projection.weeks[1].commitmentsUsd, 200);
    expect(projection.weeks[0].commitmentsUsd, 0);
  });

  test('incluye prestamos con vencimiento en el horizonte', () {
    final projection = buildCashFlowProjection(
      startBalanceUsd: 500,
      transactions: const [],
      services: const [],
      loans: [_loan(principal: 300, paid: 100, due: DateTime(2026, 6, 20))],
      from: from,
      toUsd: _identity,
      weeks: 4,
    );
    expect(projection.totalCommitmentsUsd, 200);
    expect(projection.endBalanceUsd, 300);
  });

  test('detecta la primera semana con saldo negativo', () {
    final projection = buildCashFlowProjection(
      startBalanceUsd: 100,
      transactions: const [],
      services: const [],
      loans: [_loan(principal: 500, due: DateTime(2026, 6, 3))],
      from: from,
      toUsd: _identity,
      weeks: 4,
    );
    expect(projection.firstNegativeWeek, isNotNull);
    expect(projection.lowestBalanceUsd, lessThan(0));
    expect(projection.endBalanceUsd, -400);
  });

  test('omite movimientos en monedas sin tasa', () {
    final projection = buildCashFlowProjection(
      startBalanceUsd: 0,
      transactions: [
        _tx(type: 'income', amount: 1000, date: DateTime(2026, 5, 20)),
      ],
      services: const [],
      loans: const [],
      from: from,
      toUsd: (amount, currency) => null,
      weeks: 2,
    );
    expect(projection.avgWeeklyIncomeUsd, 0);
  });
}
