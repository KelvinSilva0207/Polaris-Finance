import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/features/loans/loan_progress.dart';

Loan _loan({double principal = 1000, double paid = 0}) {
  return Loan(
    id: 'loan',
    name: 'Préstamo',
    type: 'debt',
    currency: 'USD',
    principal: principal,
    paidAmount: paid,
    interestRate: 0,
    startDate: DateTime(2026, 1, 1),
    dueDate: null,
    note: null,
    isActive: true,
  );
}

void main() {
  test('calcula el porcentaje pagado', () {
    final loan = _loan(paid: 250);
    expect(loanProgress(loan), closeTo(0.25, 1e-9));
    expect(loanProgressPercent(loan), 25);
    expect(loanProgressLabel(loan), '25.0% pagado');
    expect(isLoanSettled(loan), isFalse);
  });

  test('muestra el porcentaje con un decimal', () {
    final loan = _loan(paid: 755);
    expect(loanProgressPercentValue(loan), 75.5);
    expect(loanProgressLabel(loan), '75.5% pagado');
  });

  test('redondea el porcentaje al entero más cercano', () {
    expect(loanProgressPercent(_loan(paid: 666)), 67);
  });

  test('marca el préstamo como liquidado al cubrir el total', () {
    final exact = _loan(paid: 1000);
    expect(loanProgress(exact), 1);
    expect(isLoanSettled(exact), isTrue);
    expect(loanProgressLabel(exact), 'Liquidado');

    final overpaid = _loan(paid: 1200);
    expect(loanProgress(overpaid), 1);
    expect(loanProgressLabel(overpaid), 'Liquidado');
  });

  test('no se desborda con montos negativos o sin principal', () {
    expect(loanProgress(_loan(principal: 0, paid: 0)), 0);
    expect(loanProgress(_loan(principal: 0, paid: 10)), 1);
    expect(loanProgress(_loan(paid: -50)), 0);
  });
}
