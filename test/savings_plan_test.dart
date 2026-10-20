import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/shared/utils/savings_plan.dart';

SavingsGoal _goal({
  required double target,
  double allocated = 0,
  DateTime? deadline,
}) {
  return SavingsGoal(
    id: 'g',
    name: 'Meta',
    targetAmount: target,
    accountId: 'acc',
    allocatedAmount: allocated,
    deadline: deadline,
  );
}

void main() {
  final now = DateTime(2026, 1, 1);

  test('sin fecha limite no calcula aportes requeridos', () {
    final plan = buildSavingsPlan(
      _goal(target: 1000, allocated: 250),
      now: now,
    );
    expect(plan.remaining, 750);
    expect(plan.progress, 0.25);
    expect(plan.hasDeadline, isFalse);
    expect(plan.requiredMonthly, isNull);
  });

  test('calcula el aporte mensual necesario para una fecha limite', () {
    final plan = buildSavingsPlan(
      _goal(target: 1200, allocated: 0, deadline: DateTime(2026, 7, 1)),
      now: now,
    );
    expect(plan.daysLeft, 181);
    expect(plan.requiredMonthly, closeTo(1200 / (181 / 30.4375), 0.01));
    expect(plan.onTime, isTrue);
  });

  test('meta vencida sin completar se marca como atrasada', () {
    final plan = buildSavingsPlan(
      _goal(target: 1000, allocated: 400, deadline: DateTime(2025, 12, 1)),
      now: now,
    );
    expect(plan.overdue, isTrue);
    expect(plan.requiredMonthly, isNull);
  });

  test('meta completada no exige aportes y remaining es 0', () {
    final plan = buildSavingsPlan(
      _goal(target: 500, allocated: 600, deadline: DateTime(2025, 12, 1)),
      now: now,
    );
    expect(plan.reached, isTrue);
    expect(plan.remaining, 0);
    expect(plan.progress, 1);
    expect(plan.overdue, isFalse);
  });

  test('monthsToComplete y estimatedCompletionDate', () {
    expect(monthsToComplete(600, 100), 6);
    expect(monthsToComplete(600, 0), isNull);
    expect(monthsToComplete(0, 100), 0);

    final date = estimatedCompletionDate(600, 100, from: now)!;
    expect(date.difference(now).inDays, (6 * 30.4375).round());
  });
}
