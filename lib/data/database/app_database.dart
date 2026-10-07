import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  int get schemaVersion => 1;

  Stream<List<Account>> watchAccounts() =>
      (select(accounts)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Stream<List<Category>> watchCategories() =>
      (select(categories)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  Stream<List<Transaction>> watchTransactions() =>
      (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Stream<List<CurrencyRate>> watchRates() =>
      (select(currencyRates)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Stream<List<FeeRule>> watchFeeRules() => select(feeRules).watch();

  Stream<List<SavingsGoal>> watchGoals() => select(savingsGoals).watch();

  Stream<List<RecurringService>> watchServices() => select(recurringServices).watch();
}