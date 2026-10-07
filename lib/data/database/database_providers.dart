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

final seedProvider = FutureProvider<void>((ref) {
  return seedDatabase(ref.watch(appDatabaseProvider));
});