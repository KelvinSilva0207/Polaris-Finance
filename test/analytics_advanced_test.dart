import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/shared/utils/analytics_advanced.dart';

Transaction _tx({required DateTime date, double amount = 10, String currency = 'USD', String type = 'expense', String? categoryId, String? accountId}) {
  return Transaction(id: 't-$date', accountId: accountId ?? 'a', type: type, amount: amount, currency: currency, date: date, feeAmount: 0, categoryId: categoryId);
}

double? _id(double a, String c) => a;

void main() {
  final m = DateTime(2026, 6);
  test('spendByDayOfWeek agrupa por weekday', () {
    final data = spendByDayOfWeek(transactions: [_tx(date: DateTime(2026, 6, 1)), _tx(date: DateTime(2026, 6, 1), amount: 5)], month: m, convert: _id);
    expect(data.firstWhere((d) => d.day == DateTime.monday).amount, 15);
  });
  test('spendByHour', () {
    final data = spendByHour(transactions: [_tx(date: DateTime(2026,6,2,14), amount: 20)], month: m, convert: _id);
    expect(data[14].amount, 20);
  });
  test('spendByCategory top', () {
    final data = spendByCategory(transactions: [_tx(date: DateTime(2026,6,2), amount: 30, categoryId: 'food'), _tx(date: DateTime(2026,6,3), amount: 10, categoryId: 'gas')], month: m, convert: _id, limit: 1);
    expect(data.first.categoryId, 'food');
  });
  test('spendByAccount', () {
    final data = spendByAccount(transactions: [_tx(date: DateTime(2026,6,2), amount: 5, accountId: 'b')], month: m, convert: _id);
    expect(data.first.amount, 5);
  });
  test('compareYearOverYear', () {
    final yo = compareYearOverYear(transactions: [_tx(date: DateTime(2026,6,2), amount: 100), _tx(date: DateTime(2025,6,2), amount: 50)], month: m, convert: _id);
    expect(yo.current, 100);
    expect(yo.previous, 50);
    expect(yo.delta, 50);
    expect(yo.percent, 100);
  });
}
