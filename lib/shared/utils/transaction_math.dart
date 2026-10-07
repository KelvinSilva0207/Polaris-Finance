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
    final signed = signedAmount(transaction);
    balances.update(
      transaction.accountId,
      (current) => current + signed,
      ifAbsent: () => signed,
    );
  }
  return balances;
}