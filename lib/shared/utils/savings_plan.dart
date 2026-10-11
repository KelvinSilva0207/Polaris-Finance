import '../../data/database/app_database.dart';

const _daysPerMonth = 30.4375;

class SavingsPlan {
  const SavingsPlan({
    required this.remaining,
    required this.progress,
    required this.reached,
    required this.daysLeft,
    required this.requiredMonthly,
    required this.requiredWeekly,
  });

  /// Falta por ahorrar (nunca negativo).
  final double remaining;

  /// Progreso 0..1.
  final double progress;
  final bool reached;

  /// Días hasta la fecha límite (null si la meta no tiene fecha). Puede ser
  /// negativo si la fecha ya pasó.
  final int? daysLeft;

  /// Aportes necesarios para llegar a tiempo (null si no hay fecha o ya llegó).
  final double? requiredMonthly;
  final double? requiredWeekly;

  bool get hasDeadline => daysLeft != null;
  bool get overdue => daysLeft != null && daysLeft! < 0 && !reached;
  bool get onTime => hasDeadline && !reached && !overdue;
}

SavingsPlan buildSavingsPlan(SavingsGoal goal, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final rawRemaining = goal.targetAmount - goal.allocatedAmount;
  final remaining = rawRemaining < 0 ? 0.0 : rawRemaining;
  final progress = goal.targetAmount <= 0
      ? 0.0
      : (goal.allocatedAmount / goal.targetAmount).clamp(0.0, 1.0);
  final reached = goal.allocatedAmount >= goal.targetAmount;

  final deadline = goal.deadline;
  if (deadline == null) {
    return SavingsPlan(
      remaining: remaining,
      progress: progress,
      reached: reached,
      daysLeft: null,
      requiredMonthly: null,
      requiredWeekly: null,
    );
  }

  final daysLeft = deadline.difference(reference).inDays;
  double? requiredMonthly;
  double? requiredWeekly;
  if (daysLeft > 0 && !reached) {
    requiredMonthly = remaining / (daysLeft / _daysPerMonth);
    requiredWeekly = remaining / (daysLeft / 7);
  }

  return SavingsPlan(
    remaining: remaining,
    progress: progress,
    reached: reached,
    daysLeft: daysLeft,
    requiredMonthly: requiredMonthly,
    requiredWeekly: requiredWeekly,
  );
}

/// Meses estimados para completar [remaining] ahorrando [perMonth] al mes.
/// Devuelve null si [perMonth] es <= 0 y aún falta por ahorrar.
double? monthsToComplete(double remaining, double perMonth) {
  if (remaining <= 0) return 0;
  if (perMonth <= 0) return null;
  return remaining / perMonth;
}

/// Fecha estimada de finalización ahorrando [perMonth] mensual desde [from].
DateTime? estimatedCompletionDate(
  double remaining,
  double perMonth, {
  DateTime? from,
}) {
  final months = monthsToComplete(remaining, perMonth);
  if (months == null) return null;
  final base = from ?? DateTime.now();
  if (months == 0) return base;
  return base.add(Duration(days: (months * _daysPerMonth).round()));
}
