import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'app_database.dart';
import 'seeds.dart';

final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(appDatabaseProvider).watchAccounts();
});

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(appDatabaseProvider).watchTransactions();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(appDatabaseProvider).watchCategories();
});

final ratesProvider = StreamProvider<List<CurrencyRate>>((ref) {
  return ref.watch(appDatabaseProvider).watchRates();
});

final goalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  return ref.watch(appDatabaseProvider).watchGoals();
});

final feeRulesProvider = StreamProvider<List<FeeRule>>((ref) {
  return ref.watch(appDatabaseProvider).watchFeeRules();
});

final loansProvider = StreamProvider<List<Loan>>((ref) {
  return ref.watch(appDatabaseProvider).watchLoans();
});

final loanPaymentsProvider = StreamProvider<List<LoanPayment>>((ref) {
  return ref.watch(appDatabaseProvider).watchLoanPayments();
});

final servicesProvider = StreamProvider<List<RecurringService>>((ref) {
  return ref.watch(appDatabaseProvider).watchServices();
});

final seedProvider = FutureProvider<void>((ref) {
  return seedDatabase(ref.watch(appDatabaseProvider));
});