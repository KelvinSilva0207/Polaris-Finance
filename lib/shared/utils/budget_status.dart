import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';

enum BudgetLevel { ok, warning, exceeded }

class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.spent,
  });

  final Budget budget;
  final double spent;

  double get remaining => budget.amount - spent;

  double get ratio => budget.amount <= 0 ? 0 : spent / budget.amount;

  BudgetLevel get level {
    if (ratio >= 1) return BudgetLevel.exceeded;
    if (ratio >= 0.8) return BudgetLevel.warning;
    return BudgetLevel.ok;
  }

  bool get isExceeded => level == BudgetLevel.exceeded;
  bool get isWarning => level == BudgetLevel.warning;
}

class BudgetAlertSummary {
  const BudgetAlertSummary(this.statuses);

  final List<BudgetStatus> statuses;

  List<BudgetStatus> get exceeded =>
      statuses.where((status) => status.isExceeded).toList();

  List<BudgetStatus> get warning =>
      statuses.where((status) => status.isWarning).toList();

  bool get hasAlerts => exceeded.isNotEmpty || warning.isNotEmpty;
}

/// Gasto del mes en [budget] ya en la moneda del presupuesto. Suma la comisión
/// solo en movimientos de tipo egreso y solo si categoría y moneda coinciden.
double budgetSpent({
  required Budget budget,
  required Iterable<Transaction> transactions,
  required DateTime month,
}) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  var spent = 0.0;
  for (final transaction in transactions) {
    if (transaction.categoryId != budget.categoryId) continue;
    if (transaction.currency != budget.currency) continue;
    if (TransactionType.fromStorage(transaction.type) !=
        TransactionType.expense) {
      continue;
    }
    if (transaction.date.isBefore(start) ||
        !transaction.date.isBefore(end)) {
      continue;
    }
    spent += transaction.amount + transaction.feeAmount;
  }
  return spent;
}

BudgetStatus buildBudgetStatus({
  required Budget budget,
  required Iterable<Transaction> transactions,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  return BudgetStatus(
    budget: budget,
    spent: budgetSpent(
      budget: budget,
      transactions: transactions,
      month: reference,
    ),
  );
}

/// Resumen de alertas para el conjunto de [budgets]: los que superaron el
/// límite y los que están al menos al 80%.
BudgetAlertSummary buildBudgetAlerts({
  required Iterable<Budget> budgets,
  required Iterable<Transaction> transactions,
  DateTime? now,
}) {
  final list = [
    for (final budget in budgets)
      if (budget.isActive && budget.amount > 0)
        buildBudgetStatus(
          budget: budget,
          transactions: transactions,
          now: now,
        ),
  ];
  return BudgetAlertSummary(list);
}
