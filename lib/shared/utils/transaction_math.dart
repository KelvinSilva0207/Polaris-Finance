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

Map<String, double> balancesOf(List<Transaction> transactions) {
  final balances = <String, double>{};
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
      balances.update(
        transaction.transferToId!,
        (current) => current + transaction.amount,
        ifAbsent: () => transaction.amount,
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

CurrencyRate? latestReferenceRate(List<CurrencyRate> rates, RateProvider provider) {
  for (final rate in rates) {
    if (rate.rateCode == 'USD/VES' && rate.provider == provider.name) return rate;
  }
  return null;
}