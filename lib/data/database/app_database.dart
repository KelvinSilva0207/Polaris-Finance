import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';

part 'app_database.g.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get currency => text()();
  IntColumn get colorValue => integer()();
  TextColumn get icon => text().withDefault(const Constant('account_balance'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get colorValue => integer()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get transferToId => text().nullable().references(Accounts, #id)();
  TextColumn get type => text()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get tags => text().nullable()();
  RealColumn get feeAmount => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class FeeRules extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get bankType => text().nullable()();
  RealColumn get fixedAmount => real().withDefault(const Constant(0))();
  RealColumn get percent => real().withDefault(const Constant(0))();
  RealColumn get minAmount => real().nullable()();
  RealColumn get maxAmount => real().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  TextColumn get accountId => text().references(Accounts, #id)();
  RealColumn get allocatedAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RecurringServices extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  IntColumn get dayOfMonth => integer()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastPaidDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CurrencyRates extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get rateCode => text()();
  TextColumn get provider => text()();
  RealColumn get rate => real()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    FeeRules,
    SavingsGoals,
    RecurringServices,
    CurrencyRates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'polaris_finance'));

  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(transactions, transactions.transferToId);
          }
        },
      );

  Stream<List<Account>> watchAccounts() =>
      (select(accounts)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Stream<List<Category>> watchCategories() => (select(categories)
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.name)]))
      .watch();

  Stream<List<Transaction>> watchTransactions() =>
      (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Stream<List<CurrencyRate>> watchRates() =>
      (select(currencyRates)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Stream<List<FeeRule>> watchFeeRules() => select(feeRules).watch();

  Stream<List<SavingsGoal>> watchGoals() => select(savingsGoals).watch();

  Stream<List<RecurringService>> watchServices() => select(recurringServices).watch();

  Future<Account> addAccount({
    required String name,
    required AccountType type,
    required String currency,
    required int colorValue,
    String icon = 'account_balance',
    bool isDefault = false,
  }) {
    return into(accounts).insertReturning(
      AccountsCompanion.insert(
        id: Uuid().v4(),
        name: name,
        type: type.name,
        currency: currency,
        colorValue: colorValue,
        icon: Value(icon),
        isDefault: Value(isDefault),
      ),
    );
  }

  Future<void> updateAccount(Account account) => update(accounts).replace(account);

  Future<void> deleteAccount(String id) async {
    final used = await (select(transactions)
          ..where((t) => t.accountId.equals(id) | t.transferToId.equals(id)))
        .get();
    if (used.isNotEmpty) {
      throw StateError('La cuenta tiene movimientos asociados');
    }
    await (delete(accounts)..where((t) => t.id.equals(id))).go();
  }

  Future<int> transactionsForAccountCount(String id) =>
      (select(transactions)..where((t) => t.accountId.equals(id) | t.transferToId.equals(id)))
          .get()
          .then((rows) => rows.length);

  Future<Category> addCategory({
    required String name,
    required String icon,
    required int colorValue,
    required bool isIncome,
  }) {
    return into(categories).insertReturning(
      CategoriesCompanion.insert(
        id: Uuid().v4(),
        name: name,
        icon: icon,
        colorValue: colorValue,
        isBuiltIn: const Value(false),
        isIncome: Value(isIncome),
      ),
    );
  }

  Future<void> updateCategory(Category category) => update(categories).replace(category);

  Future<void> deleteCategory(String id) async {
    final used = await (select(transactions)..where((t) => t.categoryId.equals(id))).get();
    if (used.isNotEmpty) {
      throw StateError('La categoría está en uso por algún movimiento');
    }
    await (delete(categories)..where((t) => t.id.equals(id))).go();
  }

  Future<Transaction> addTransaction({
    required String accountId,
    String? transferToId,
    required TransactionType type,
    String? categoryId,
    required double amount,
    required String currency,
    required DateTime date,
    String? note,
    List<String> tags = const [],
    double feeAmount = 0,
  }) {
    return into(transactions).insertReturning(
      TransactionsCompanion.insert(
        id: Uuid().v4(),
        accountId: accountId,
        transferToId: Value(transferToId),
        type: type.name,
        categoryId: Value(categoryId),
        amount: amount,
        currency: currency,
        date: date,
        note: Value(note),
        tags: Value(tags.join(',')),
        feeAmount: Value(feeAmount),
      ),
    );
  }

  Future<void> updateTransaction(Transaction transaction) =>
      update(transactions).replace(transaction);

  Future<void> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<void> insertRate({
    required String code,
    required String rateCode,
    required String provider,
    required double rate,
    bool isManual = false,
  }) {
    return into(currencyRates).insert(
      CurrencyRatesCompanion.insert(
        id: Uuid().v4(),
        code: code,
        rateCode: rateCode,
        provider: provider,
        rate: rate,
        date: DateTime.now(),
        isManual: Value(isManual),
      ),
    );
  }

  Future<void> deleteRates() => delete(currencyRates).go();
}