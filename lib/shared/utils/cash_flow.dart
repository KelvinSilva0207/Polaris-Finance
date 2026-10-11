import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import 'schedule.dart';

class CashFlowWeek {
  const CashFlowWeek({
    required this.start,
    required this.incomeUsd,
    required this.expenseUsd,
    required this.commitmentsUsd,
    required this.endBalanceUsd,
  });

  final DateTime start;
  final double incomeUsd;
  final double expenseUsd;
  final double commitmentsUsd;
  final double endBalanceUsd;

  double get netUsd => incomeUsd - expenseUsd - commitmentsUsd;
}

class CashFlowProjection {
  const CashFlowProjection({
    required this.startBalanceUsd,
    required this.weeks,
    required this.avgWeeklyIncomeUsd,
    required this.avgWeeklyExpenseUsd,
  });

  final double startBalanceUsd;
  final List<CashFlowWeek> weeks;
  final double avgWeeklyIncomeUsd;
  final double avgWeeklyExpenseUsd;

  bool get isEmpty => weeks.isEmpty;

  double get endBalanceUsd =>
      weeks.isEmpty ? startBalanceUsd : weeks.last.endBalanceUsd;

  double get totalCommitmentsUsd => weeks.fold(
        0.0,
        (sum, week) => sum + week.commitmentsUsd,
      );

  /// Saldo más bajo proyectado (para detectar semanas en rojo).
  double get lowestBalanceUsd {
    var lowest = startBalanceUsd;
    for (final week in weeks) {
      if (week.endBalanceUsd < lowest) lowest = week.endBalanceUsd;
    }
    return lowest;
  }

  /// Primera semana en la que el saldo proyectado cae por debajo de cero.
  CashFlowWeek? get firstNegativeWeek {
    for (final week in weeks) {
      if (week.endBalanceUsd < 0) return week;
    }
    return null;
  }
}

/// Proyecta el flujo de caja a [weeks] semanas vista. Estima el ingreso y el
/// egreso semanal promedio con los últimos [historyDays] días y les resta los
/// vencimientos conocidos (servicios y préstamos).
///
/// [toUsd] traduce un importe de su moneda a USD (o null si no hay tasa).
CashFlowProjection buildCashFlowProjection({
  required double startBalanceUsd,
  required Iterable<Transaction> transactions,
  required List<RecurringService> services,
  required List<Loan> loans,
  required DateTime from,
  required double? Function(double amount, String currency) toUsd,
  int weeks = 8,
  int historyDays = 90,
}) {
  final historyStart = from.subtract(Duration(days: historyDays));
  var incomeSum = 0.0;
  var expenseSum = 0.0;
  for (final transaction in transactions) {
    if (transaction.date.isBefore(historyStart) ||
        transaction.date.isAfter(from)) {
      continue;
    }
    final type = TransactionType.fromStorage(transaction.type);
    if (type == TransactionType.transfer) continue;
    final amount = type == TransactionType.expense
        ? transaction.amount + transaction.feeAmount
        : transaction.amount;
    final usd = toUsd(amount, transaction.currency);
    if (usd == null) continue;
    if (type == TransactionType.income) {
      incomeSum += usd;
    } else {
      expenseSum += usd;
    }
  }
  final weeksOfHistory = historyDays / 7;
  final avgIncome = weeksOfHistory > 0 ? incomeSum / weeksOfHistory : 0.0;
  final avgExpense = weeksOfHistory > 0 ? expenseSum / weeksOfHistory : 0.0;

  final horizon = from.add(Duration(days: weeks * 7));
  final events = <({DateTime date, double amountUsd})>[];

  for (final service in services) {
    if (!service.isActive) continue;
    final usd = toUsd(service.amount, service.currency);
    if (usd == null) continue;
    var due = nextServiceDue(service.dayOfMonth, from, service.lastPaidDate);
    while (due.isBefore(horizon)) {
      if (!due.isBefore(from)) events.add((date: due, amountUsd: usd));
      due = dateInMonth(due.year, due.month + 1, service.dayOfMonth);
    }
  }

  for (final loan in loans) {
    if (!loan.isActive || loan.dueDate == null) continue;
    final due = loan.dueDate!;
    if (due.isBefore(from) || !due.isBefore(horizon)) continue;
    final outstanding = loan.principal - loan.paidAmount;
    if (outstanding <= 0) continue;
    final usd = toUsd(outstanding, loan.currency);
    if (usd == null) continue;
    events.add((date: due, amountUsd: usd));
  }

  final result = <CashFlowWeek>[];
  var balance = startBalanceUsd;
  for (var index = 0; index < weeks; index++) {
    final start = from.add(Duration(days: index * 7));
    final end = start.add(const Duration(days: 7));
    var commitments = 0.0;
    for (final event in events) {
      if (!event.date.isBefore(start) && event.date.isBefore(end)) {
        commitments += event.amountUsd;
      }
    }
    balance += avgIncome - avgExpense - commitments;
    result.add(
      CashFlowWeek(
        start: start,
        incomeUsd: avgIncome,
        expenseUsd: avgExpense,
        commitmentsUsd: commitments,
        endBalanceUsd: balance,
      ),
    );
  }

  return CashFlowProjection(
    startBalanceUsd: startBalanceUsd,
    weeks: result,
    avgWeeklyIncomeUsd: avgIncome,
    avgWeeklyExpenseUsd: avgExpense,
  );
}
