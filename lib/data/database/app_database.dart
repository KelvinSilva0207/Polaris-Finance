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

class Loans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('debt'))();
  TextColumn get currency => text()();
  RealColumn get principal => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  RealColumn get interestRate => real().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class LoanPayments extends Table {
  TextColumn get id => text()();
  TextColumn get loanId => text().references(Loans, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();

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
    Loans,
    LoanPayments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'polaris_finance'));

  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(transactions, transactions.transferToId);
          }
          if (from < 3) {
            await m.createTable(loans);
            await m.createTable(loanPayments);
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

  Stream<List<Loan>> watchLoans() =>
      (select(loans)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<LoanPayment>> watchLoanPayments() =>
      (select(loanPayments)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

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

  Future<SavingsGoal> addGoal({
    required String name,
    required double targetAmount,
    required String accountId,
    DateTime? deadline,
    String? note,
  }) {
    return into(savingsGoals).insertReturning(
      SavingsGoalsCompanion.insert(
        id: Uuid().v4(),
        name: name,
        targetAmount: targetAmount,
        accountId: accountId,
        deadline: Value(deadline),
        note: Value(note),
      ),
    );
  }

  Future<void> updateGoal(SavingsGoal goal) => update(savingsGoals).replace(goal);

  Future<void> deleteGoal(String id) =>
      (delete(savingsGoals)..where((t) => t.id.equals(id))).go();

  Future<void> allocateToGoal({
    required SavingsGoal goal,
    required double amount,
    required String fundingAccountId,
  }) async {
    if (fundingAccountId != goal.accountId) {
      final funding = await (select(accounts)
            ..where((t) => t.id.equals(fundingAccountId)))
          .getSingle();
      await addTransaction(
        type: TransactionType.transfer,
        accountId: fundingAccountId,
        transferToId: goal.accountId,
        amount: amount,
        currency: funding.currency,
        date: DateTime.now(),
        note: 'Aporte a meta: ${goal.name}',
      );
    }
    await (update(savingsGoals)..where((t) => t.id.equals(goal.id)))
        .write(SavingsGoalsCompanion(
      allocatedAmount: Value(goal.allocatedAmount + amount),
    ));
  }

  Future<FeeRule> addFeeRule({
    required String name,
    double fixedAmount = 0,
    double percent = 0,
    double? minAmount,
    double? maxAmount,
    bool isActive = true,
  }) {
    return into(feeRules).insertReturning(
      FeeRulesCompanion.insert(
        id: Uuid().v4(),
        name: name,
        fixedAmount: Value(fixedAmount),
        percent: Value(percent),
        minAmount: Value(minAmount),
        maxAmount: Value(maxAmount),
        isActive: Value(isActive),
      ),
    );
  }

  Future<void> updateFeeRule(FeeRule rule) => update(feeRules).replace(rule);

  Future<void> deleteFeeRule(String id) =>
      (delete(feeRules)..where((t) => t.id.equals(id))).go();

  Future<Loan> addLoan({
    required String name,
    required LoanType type,
    required String currency,
    required double principal,
    double interestRate = 0,
    required DateTime startDate,
    DateTime? dueDate,
    String? note,
  }) {
    return into(loans).insertReturning(
      LoansCompanion.insert(
        id: Uuid().v4(),
        name: name,
        type: Value(type.name),
        currency: currency,
        principal: principal,
        interestRate: Value(interestRate),
        startDate: startDate,
        dueDate: Value(dueDate),
        note: Value(note),
      ),
    );
  }

  Future<void> updateLoan(Loan loan) => update(loans).replace(loan);

  Future<void> deleteLoan(String id) async {
    await (delete(loanPayments)..where((t) => t.loanId.equals(id))).go();
    await (delete(loans)..where((t) => t.id.equals(id))).go();
  }

  Future<RecurringService> addService({
    required String name,
    required double amount,
    required String currency,
    required int dayOfMonth,
    String? accountId,
    String? categoryId,
    bool isActive = true,
    String? note,
  }) {
    return into(recurringServices).insertReturning(
      RecurringServicesCompanion.insert(
        id: Uuid().v4(),
        name: name,
        amount: amount,
        currency: currency,
        dayOfMonth: dayOfMonth,
        accountId: Value(accountId),
        categoryId: Value(categoryId),
        isActive: Value(isActive),
        note: Value(note),
      ),
    );
  }

  Future<void> updateService(RecurringService service) =>
      update(recurringServices).replace(service);

  Future<void> deleteService(String id) async {
    await (delete(recurringServices)..where((t) => t.id.equals(id))).go();
  }

  Future<Transaction> payService(
    RecurringService service, {
    required DateTime date,
    double? amountOverride,
  }) async {
    if (service.accountId == null) {
      throw StateError('Asigna una cuenta al servicio antes de pagarlo');
    }
    final transaction = await addTransaction(
      type: TransactionType.expense,
      accountId: service.accountId!,
      categoryId: service.categoryId,
      amount: amountOverride ?? service.amount,
      currency: service.currency,
      date: date,
      note: service.name,
      tags: const ['servicio'],
    );
    await (update(recurringServices)..where((t) => t.id.equals(service.id)))
        .write(RecurringServicesCompanion(lastPaidDate: Value(date)));
    return transaction;
  }

  Future<LoanPayment> addLoanPayment({
    required Loan loan,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final payment = await into(loanPayments).insertReturning(
      LoanPaymentsCompanion.insert(
        id: Uuid().v4(),
        loanId: loan.id,
        amount: amount,
        date: date,
        note: Value(note),
      ),
    );
    await (update(loans)..where((t) => t.id.equals(loan.id)))
        .write(LoansCompanion(
      paidAmount: Value(loan.paidAmount + amount),
    ));
    return payment;
  }

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