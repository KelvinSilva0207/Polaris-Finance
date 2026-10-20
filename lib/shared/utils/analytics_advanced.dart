import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';

class DayOfWeekData {
  const DayOfWeekData({required this.day, required this.amount});
  final int day; // 1=Monday? Flutter DateTime: 1=monday? DateTime.monday=1
  final double amount;
}

class HourData {
  const HourData({required this.hour, required this.amount});
  final int hour;
  final double amount;
}

class CategorySpend {
  const CategorySpend({required this.categoryId, required this.amount});
  final String categoryId;
  final double amount;
}

class AccountSpend {
  const AccountSpend({required this.accountId, required this.amount});
  final String accountId;
  final double amount;
}

class YearOverYear {
  const YearOverYear({
    required this.current,
    required this.previous,
    required this.delta,
    required this.percent,
  });
  final double current;
  final double previous;
  final double delta;
  final double? percent;
}

/// Gasto por día de la semana (DateTime.weekday: 1=lunes, 7=domingo según ISO)
List<DayOfWeekData> spendByDayOfWeek({
  required Iterable<Transaction> transactions,
  required DateTime month,
  required double? Function(double amount, String currency) convert,
}) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final sums = <int, double>{};
  for (final tx in transactions) {
    if (tx.date.isBefore(start) || !tx.date.isBefore(end)) continue;
    final type = TransactionType.fromStorage(tx.type);
    if (type != TransactionType.expense) continue;
    final amount = tx.amount + tx.feeAmount;
    final value = convert(amount, tx.currency);
    if (value == null) continue;
    final w = tx.date.weekday;
    sums[w] = (sums[w] ?? 0) + value;
  }
  final result = <DayOfWeekData>[];
  for (var w = 1; w <= 7; w++) {
    result.add(DayOfWeekData(day: w, amount: sums[w] ?? 0));
  }
  return result;
}

List<HourData> spendByHour({
  required Iterable<Transaction> transactions,
  required DateTime month,
  required double? Function(double amount, String currency) convert,
}) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final sums = <int, double>{};
  for (final tx in transactions) {
    if (tx.date.isBefore(start) || !tx.date.isBefore(end)) continue;
    final type = TransactionType.fromStorage(tx.type);
    if (type != TransactionType.expense) continue;
    final amount = tx.amount + tx.feeAmount;
    final value = convert(amount, tx.currency);
    if (value == null) continue;
    sums[tx.date.hour] = (sums[tx.date.hour] ?? 0) + value;
  }
  final result = <HourData>[];
  for (var h = 0; h <= 23; h++) {
    result.add(HourData(hour: h, amount: sums[h] ?? 0));
  }
  return result;
}

List<CategorySpend> spendByCategory({
  required Iterable<Transaction> transactions,
  required DateTime month,
  required double? Function(double amount, String currency) convert,
  int limit = 10,
}) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final sums = <String, double>{};
  for (final tx in transactions) {
    if (tx.date.isBefore(start) || !tx.date.isBefore(end)) continue;
    final type = TransactionType.fromStorage(tx.type);
    if (type != TransactionType.expense) continue;
    final amount = tx.amount + tx.feeAmount;
    final value = convert(amount, tx.currency);
    if (value == null) continue;
    final key = tx.categoryId ?? '';
    sums[key] = (sums[key] ?? 0) + value;
  }
  final list = sums.entries
      .map((e) => CategorySpend(categoryId: e.key, amount: e.value))
      .toList();
  list.sort((a, b) => b.amount.compareTo(a.amount));
  return list.take(limit).toList();
}

List<AccountSpend> spendByAccount({
  required Iterable<Transaction> transactions,
  required DateTime month,
  required double? Function(double amount, String currency) convert,
}) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final sums = <String, double>{};
  for (final tx in transactions) {
    if (tx.date.isBefore(start) || !tx.date.isBefore(end)) continue;
    final type = TransactionType.fromStorage(tx.type);
    if (type != TransactionType.expense) continue;
    final amount = tx.amount + tx.feeAmount;
    final value = convert(amount, tx.currency);
    if (value == null) continue;
    sums[tx.accountId] = (sums[tx.accountId] ?? 0) + value;
  }
  final list = sums.entries
      .map((e) => AccountSpend(accountId: e.key, amount: e.value))
      .toList();
  list.sort((a, b) => b.amount.compareTo(a.amount));
  return list;
}

double _sumExpense(
  Iterable<Transaction> transactions,
  DateTime month,
  double? Function(double, String) convert,
) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  var total = 0.0;
  for (final tx in transactions) {
    if (tx.date.isBefore(start) || !tx.date.isBefore(end)) continue;
    final type = TransactionType.fromStorage(tx.type);
    if (type != TransactionType.expense) continue;
    final amount = tx.amount + tx.feeAmount;
    final value = convert(amount, tx.currency);
    if (value != null) total += value;
  }
  return total;
}

YearOverYear compareYearOverYear({
  required Iterable<Transaction> transactions,
  required DateTime month,
  required double? Function(double amount, String currency) convert,
}) {
  final current = _sumExpense(transactions, month, convert);
  final prev = _sumExpense(
    transactions,
    DateTime(month.year - 1, month.month),
    convert,
  );
  final delta = current - prev;
  double? pct;
  if (prev.abs() >= 0.01) pct = delta / prev.abs() * 100;
  return YearOverYear(
    current: current,
    previous: prev,
    delta: delta,
    percent: pct,
  );
}
