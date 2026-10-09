import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';

double signedAmount(Transaction transaction) {
  final type = TransactionType.fromStorage(transaction.type);
  return switch (type) {
    TransactionType.income => transaction.amount,
    TransactionType.expense ||
    TransactionType.transfer => -(transaction.amount + transaction.feeAmount),
  };
}

Map<String, double> balancesOf(
  List<Transaction> transactions, {
  Iterable<Account> accounts = const [],
}) {
  final balances = <String, double>{
    for (final account in accounts) account.id: account.openingBalance,
  };
  for (final transaction in transactions) {
    final type = TransactionType.fromStorage(transaction.type);
    final delta = switch (type) {
      TransactionType.income => transaction.amount,
      TransactionType.expense ||
      TransactionType.transfer => -(transaction.amount + transaction.feeAmount),
    };
    balances.update(
      transaction.accountId,
      (current) => current + delta,
      ifAbsent: () => delta,
    );
    if (type == TransactionType.transfer && transaction.transferToId != null) {
      final credit = transaction.credAmount ?? transaction.amount;
      balances.update(
        transaction.transferToId!,
        (current) => current + credit,
        ifAbsent: () => credit,
      );
    }
  }
  return balances;
}

double? convertedAmount(double amount, String currency, double? vesPerUsd) {
  if (vesPerUsd == null) return null;
  if (currency == 'VES') return amount / vesPerUsd;
  if (currency == 'USD') return amount * vesPerUsd;
  return null;
}

double? usdEquivalent(double balance, String currency, double vesPerUsd) {
  if (currency == 'VES') return balance / vesPerUsd;
  if (currency == 'USD') return balance;
  return null;
}

({double total, Set<String> currenciesExcluded})? totalUsdOf(
  Map<String, double> balances,
  Iterable<Account> accounts,
  double vesPerUsd,
) {
  var total = 0.0;
  final excluded = <String>{};
  var any = false;
  for (final account in accounts) {
    final usd = usdEquivalent(balances[account.id] ?? 0, account.currency, vesPerUsd);
    if (usd == null) {
      excluded.add(account.currency);
    } else {
      total += usd;
      any = true;
    }
  }
  return any ? (total: total, currenciesExcluded: excluded) : null;
}

CurrencyRate? latestReferenceRate(List<CurrencyRate> rates, RateProvider provider) {
  for (final rate in rates) {
    if (rate.rateCode == 'USD/VES' && rate.provider == provider.name) return rate;
  }
  return null;
}

double feeFor(FeeRule rule, double amount) {
  var fee = rule.fixedAmount + amount * rule.percent / 100;
  if (rule.minAmount != null && fee < rule.minAmount!) fee = rule.minAmount!;
  if (rule.maxAmount != null && fee > rule.maxAmount!) fee = rule.maxAmount!;
  if (fee <= 0) return 0;
  return double.parse(fee.toStringAsFixed(2));
}