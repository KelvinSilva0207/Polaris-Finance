import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';

/// Totales de un mes en la moneda de referencia (ya convertidos).
class MonthTotals {
  const MonthTotals({
    required this.income,
    required this.expense,
    required this.skipped,
  });

  final double income;
  final double expense;

  /// Movimientos que quedaron fuera por falta de tasa convertible.
  final int skipped;

  double get balance => income - expense;
}

/// Suma ingresos y egresos de [month]. [convert] traduce un importe de su
/// moneda a la de referencia y devuelve null si no hay tasa.
///
/// Las transferencias se ignoran (no son ingreso ni egreso). Solo los egresos
/// suman la comisión ([Transaction.feeAmount]).
MonthTotals monthTotalsOf({
  required Iterable<Transaction> transactions,
  required DateTime month,
  required double? Function(double amount, String currency) convert,
}) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  var income = 0.0;
  var expense = 0.0;
  var skipped = 0;

  for (final transaction in transactions) {
    if (transaction.date.isBefore(start) || !transaction.date.isBefore(end)) {
      continue;
    }
    final type = TransactionType.fromStorage(transaction.type);
    if (type == TransactionType.transfer) continue;
    final isExpense = type != TransactionType.income;
    final amount = type == TransactionType.expense
        ? transaction.amount + transaction.feeAmount
        : transaction.amount;
    final value = convert(amount, transaction.currency);
    if (value == null) {
      skipped++;
      continue;
    }
    if (isExpense) {
      expense += value;
    } else {
      income += value;
    }
  }

  return MonthTotals(income: income, expense: expense, skipped: skipped);
}

class MonthComparison {
  const MonthComparison({required this.current, required this.previous});

  final MonthTotals current;
  final MonthTotals previous;

  double get incomeDelta => current.income - previous.income;
  double get expenseDelta => current.expense - previous.expense;
  double get balanceDelta => current.balance - previous.balance;

  double? get incomePercent => _percent(current.income, previous.income);
  double? get expensePercent => _percent(current.expense, previous.expense);
  double? get balancePercent => _percent(current.balance, previous.balance);
}

/// Compara un mes con el inmediatamente anterior.
MonthComparison buildMonthComparison({
  required Iterable<Transaction> transactions,
  required DateTime month,
  required double? Function(double amount, String currency) convert,
}) {
  final previousMonth = DateTime(month.year, month.month - 1);
  return MonthComparison(
    current: monthTotalsOf(
      transactions: transactions,
      month: month,
      convert: convert,
    ),
    previous: monthTotalsOf(
      transactions: transactions,
      month: previousMonth,
      convert: convert,
    ),
  );
}

double? _percent(double current, double previous) {
  if (previous.abs() < 0.01) return null;
  return (current - previous) / previous.abs() * 100;
}
