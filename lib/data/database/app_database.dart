import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import 'memory_database.dart'
    if (dart.library.js_interop) 'memory_database_stub.dart';

part 'app_database.g.dart';

/// Factor para llevar un importe de [currency] a USD (USDT vale como USD).
double? _usdFactor(String currency, {double? vesPerUsd, double? eurPerUsd}) {
  switch (currency) {
    case 'USD' || 'USDT':
      return 1;
    case 'VES':
      if (vesPerUsd == null || vesPerUsd <= 0) return null;
      return 1 / vesPerUsd;
    case 'EUR':
      if (eurPerUsd == null || eurPerUsd <= 0) return null;
      return 1 / eurPerUsd;
    default:
      return null;
  }
}

/// Convierte [amount] de [from] a [to] pasando por USD; null si falta tasa.
double? _convertBetween(
  double amount,
  String from,
  String to, {
  double? vesPerUsd,
  double? eurPerUsd,
}) {
  if (from == to) return amount;
  final fromFactor = _usdFactor(
    from,
    vesPerUsd: vesPerUsd,
    eurPerUsd: eurPerUsd,
  );
  final toFactor = _usdFactor(to, vesPerUsd: vesPerUsd, eurPerUsd: eurPerUsd);
  if (fromFactor == null || toFactor == null) return null;
  return amount * fromFactor / toFactor;
}

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get currency => text()();
  IntColumn get colorValue => integer()();
  TextColumn get icon =>
      text().withDefault(const Constant('account_balance'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  RealColumn get openingBalance => real().withDefault(const Constant(0))();
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
  RealColumn get credAmount => real().nullable()();
  TextColumn get credCurrency => text().nullable()();

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

  /// Tipo de cálculo: `simple` o `tiered` (ver [FeeType]).
  TextColumn get feeType => text().withDefault(const Constant('simple'))();

  /// Tipos de transacción a los que aplica, separados por coma.
  TextColumn get appliesTo =>
      text().withDefault(const Constant('expense,pagoMovil,transfer'))();

  /// Tramos: desde este monto (inclusive) se cobra el porcentaje.
  RealColumn get tierThreshold => real().nullable()();

  /// Tramos: monto fijo que se cobra por debajo del umbral.
  RealColumn get tierFixedAmount => real().nullable()();

  /// Tramos: porcentaje que se cobra a partir del umbral.
  RealColumn get tierPercent => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Identificador del perfil de comisión por defecto del pago móvil.
const defaultFeeRuleId = 'seed_fee_pago_movil_bdv';

/// Nombre del perfil de comisión por defecto del pago móvil.
const defaultFeeRuleName = 'Pago móvil (BDV)';

/// Monto límite de los tramos del perfil por defecto (a partir de aquí se
/// cobra el porcentaje en vez del monto fijo).
const defaultFeeRuleThreshold = 5000.0;

/// Monto fijo del perfil por defecto por debajo del límite.
const defaultFeeRuleFixedAmount = 14.0;

/// Porcentaje del perfil por defecto a partir del límite.
const defaultFeeRulePercent = 0.3;

/// Perfil de comisión por defecto del pago móvil (Banco de Venezuela):
/// 14 Bs fijos por debajo de 5.000 Bs y 0,30 % a partir de ese monto.
/// El usuario puede editarlo o eliminarlo desde Comisiones.
FeeRulesCompanion buildDefaultFeeRule() => FeeRulesCompanion.insert(
  id: defaultFeeRuleId,
  name: defaultFeeRuleName,
  feeType: const Value('tiered'),
  appliesTo: const Value('pagoMovil'),
  tierThreshold: const Value(defaultFeeRuleThreshold),
  tierFixedAmount: const Value(defaultFeeRuleFixedAmount),
  tierPercent: const Value(defaultFeeRulePercent),
);

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

class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('VES'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bitácora de sincronización: una fila por elemento modificado.
///
/// La clave primaria es `coleccion:idDelRegistro`, de modo que cada
/// elemento tiene una sola entrada que se va actualizando. `deleted` marca
/// las lápidas (borrados) que hay que propagar al resto de dispositivos.
///
/// `seq` es un contador local estrictamente creciente: la base de datos
/// guarda las fechas con precisión de segundos, así que dos cambios
/// seguidos dentro del mismo segundo serían indistinguibles. El contador
/// permite saber exactamente qué falta por enviar.
///
/// `updatedAtMs` guarda la fecha del cambio en milisegundos, que sí es
/// comparable entre dispositivos, y `originSeq` el número de secuencia que
/// tuvo el cambio en el dispositivo que lo originó.
class SyncRecords extends Table {
  TextColumn get id => text()();
  TextColumn get collection => text()();
  TextColumn get recordId => text()();
  IntColumn get seq => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get updatedAtMs => integer().withDefault(const Constant(0))();
  IntColumn get originSeq => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  TextColumn get payload => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Estado de la sincronización en este dispositivo (una sola fila).
class SyncStates extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  IntColumn get lastPushedSeq => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

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
    Budgets,
    SyncRecords,
    SyncStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'polaris_finance',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  factory AppDatabase.memory() => createMemoryDatabase();

  @override
  int get schemaVersion => 8;

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
      if (from < 4) {
        await m.createTable(budgets);
      }
      if (from < 5) {
        await m.addColumn(accounts, accounts.openingBalance);
      }
      if (from < 6) {
        await m.addColumn(transactions, transactions.credAmount);
        await m.addColumn(transactions, transactions.credCurrency);
      }
      if (from < 7) {
        await m.addColumn(feeRules, feeRules.feeType);
        await m.addColumn(feeRules, feeRules.appliesTo);
        await m.addColumn(feeRules, feeRules.tierThreshold);
        await m.addColumn(feeRules, feeRules.tierFixedAmount);
        await m.addColumn(feeRules, feeRules.tierPercent);
        // Perfil de comisión por defecto del pago móvil (Banco de Venezuela).
        await customStatement(
          'INSERT OR IGNORE INTO fee_rules (id, name, fee_type, applies_to, '
          'tier_threshold, tier_fixed_amount, tier_percent, is_active) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            defaultFeeRuleId,
            defaultFeeRuleName,
            'tiered',
            'pagoMovil',
            defaultFeeRuleThreshold,
            defaultFeeRuleFixedAmount,
            defaultFeeRulePercent,
            true,
          ],
        );
      }
      if (from < 8) {
        // Base de la sincronización: bitácora de cambios y estado local.
        await m.createTable(syncRecords);
        await m.createTable(syncStates);
      }
    },
  );

  Stream<List<Account>> watchAccounts() => (select(
    accounts,
  )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

  Stream<List<Category>> watchCategories() =>
      (select(categories)..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
          .watch();

  Stream<List<Transaction>> watchTransactions() => (select(
    transactions,
  )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Stream<List<CurrencyRate>> watchRates() => (select(
    currencyRates,
  )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Stream<List<FeeRule>> watchFeeRules() => select(feeRules).watch();

  Stream<List<SavingsGoal>> watchGoals() => select(savingsGoals).watch();

  Stream<List<RecurringService>> watchServices() =>
      select(recurringServices).watch();

  Stream<List<Loan>> watchLoans() =>
      (select(loans)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<LoanPayment>> watchLoanPayments() => (select(
    loanPayments,
  )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Future<Account> addAccount({
    required String name,
    required AccountType type,
    required String currency,
    required int colorValue,
    String icon = 'account_balance',
    bool isDefault = false,
    double openingBalance = 0,
  }) async {
    final account = await into(accounts).insertReturning(
      AccountsCompanion.insert(
        id: Uuid().v4(),
        name: name,
        type: type.name,
        currency: currency,
        colorValue: colorValue,
        icon: Value(icon),
        isDefault: Value(isDefault),
        openingBalance: Value(openingBalance),
      ),
    );
    await _logChange('accounts', account.id, account.toJson());
    return account;
  }

  Future<void> updateAccount(Account account) async {
    await update(accounts).replace(account);
    await _logChange('accounts', account.id, account.toJson());
  }

  Future<void> deleteAccount(String id) async {
    final used = await (select(
      transactions,
    )..where((t) => t.accountId.equals(id) | t.transferToId.equals(id))).get();
    if (used.isNotEmpty) {
      throw StateError('La cuenta tiene movimientos asociados');
    }
    await (delete(accounts)..where((t) => t.id.equals(id))).go();
    await _logChange('accounts', id, const {}, deleted: true);
  }

  Future<int> transactionsForAccountCount(String id) =>
      (select(transactions)
            ..where((t) => t.accountId.equals(id) | t.transferToId.equals(id)))
          .get()
          .then((rows) => rows.length);

  Future<Category> addCategory({
    required String name,
    required String icon,
    required int colorValue,
    required bool isIncome,
  }) async {
    // Las categorías nuevas se colocan al final de su sección (ingresos o
    // egresos) para que la lista no se reordene al crearlas.
    final siblings = await (select(
      categories,
    )..where((c) => c.isIncome.equals(isIncome))).get();
    var nextOrder = 0;
    for (final category in siblings) {
      if (category.sortOrder > nextOrder) nextOrder = category.sortOrder;
    }
    final category = await into(categories).insertReturning(
      CategoriesCompanion.insert(
        id: Uuid().v4(),
        name: name,
        icon: icon,
        colorValue: colorValue,
        isBuiltIn: const Value(false),
        isIncome: Value(isIncome),
        sortOrder: Value(nextOrder + 1),
      ),
    );
    await _logChange('categories', category.id, category.toJson());
    return category;
  }

  Future<void> updateCategory(Category category) async {
    await update(categories).replace(category);
    await _logChange('categories', category.id, category.toJson());
  }

  Future<void> deleteCategory(String id) async {
    final used = await (select(
      transactions,
    )..where((t) => t.categoryId.equals(id))).get();
    if (used.isNotEmpty) {
      throw StateError('La categoría está en uso por algún movimiento');
    }
    await (delete(categories)..where((t) => t.id.equals(id))).go();
    await _logChange('categories', id, const {}, deleted: true);
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
    double? creditedAmount,
    String? creditedCurrency,
  }) async {
    final transaction = await into(transactions).insertReturning(
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
        credAmount: Value(creditedAmount),
        credCurrency: Value(creditedCurrency),
      ),
    );
    await _logChange('transactions', transaction.id, transaction.toJson());
    return transaction;
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await update(transactions).replace(transaction);
    await _logChange('transactions', transaction.id, transaction.toJson());
  }

  Future<void> deleteTransaction(String id) async {
    await (delete(transactions)..where((t) => t.id.equals(id))).go();
    await _logChange('transactions', id, const {}, deleted: true);
  }

  Future<SavingsGoal> addGoal({
    required String name,
    required double targetAmount,
    required String accountId,
    DateTime? deadline,
    String? note,
  }) async {
    final goal = await into(savingsGoals).insertReturning(
      SavingsGoalsCompanion.insert(
        id: Uuid().v4(),
        name: name,
        targetAmount: targetAmount,
        accountId: accountId,
        deadline: Value(deadline),
        note: Value(note),
      ),
    );
    await _logChange('goals', goal.id, goal.toJson());
    return goal;
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    await update(savingsGoals).replace(goal);
    await _logChange('goals', goal.id, goal.toJson());
  }

  Future<void> deleteGoal(String id) async {
    await (delete(savingsGoals)..where((t) => t.id.equals(id))).go();
    await _logChange('goals', id, const {}, deleted: true);
  }

  Future<void> allocateToGoal({
    required SavingsGoal goal,
    required double amount,
    required String fundingAccountId,
  }) async {
    if (fundingAccountId != goal.accountId) {
      final funding = await (select(
        accounts,
      )..where((t) => t.id.equals(fundingAccountId))).getSingle();
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
    await (update(savingsGoals)..where((t) => t.id.equals(goal.id))).write(
      SavingsGoalsCompanion(
        allocatedAmount: Value(goal.allocatedAmount + amount),
      ),
    );
    final updated = await (select(
      savingsGoals,
    )..where((t) => t.id.equals(goal.id))).getSingle();
    await _logChange('goals', updated.id, updated.toJson());
  }

  Future<FeeRule> addFeeRule({
    required String name,
    double fixedAmount = 0,
    double percent = 0,
    double? minAmount,
    double? maxAmount,
    bool isActive = true,
    FeeType feeType = FeeType.simple,
    Iterable<TransactionType> appliesTo = defaultFeeRuleTypes,
    double? tierThreshold,
    double? tierFixedAmount,
    double? tierPercent,
  }) async {
    final rule = await into(feeRules).insertReturning(
      FeeRulesCompanion.insert(
        id: Uuid().v4(),
        name: name,
        fixedAmount: Value(fixedAmount),
        percent: Value(percent),
        minAmount: Value(minAmount),
        maxAmount: Value(maxAmount),
        isActive: Value(isActive),
        feeType: Value(feeType.name),
        appliesTo: Value(encodeFeeRuleTypes(appliesTo)),
        tierThreshold: Value(tierThreshold),
        tierFixedAmount: Value(tierFixedAmount),
        tierPercent: Value(tierPercent),
      ),
    );
    await _logChange('feeRules', rule.id, rule.toJson());
    return rule;
  }

  Future<void> updateFeeRule(FeeRule rule) async {
    await update(feeRules).replace(rule);
    await _logChange('feeRules', rule.id, rule.toJson());
  }

  Future<void> deleteFeeRule(String id) async {
    await (delete(feeRules)..where((t) => t.id.equals(id))).go();
    await _logChange('feeRules', id, const {}, deleted: true);
  }

  Future<Loan> addLoan({
    required String name,
    required LoanType type,
    required String currency,
    required double principal,
    double interestRate = 0,
    required DateTime startDate,
    DateTime? dueDate,
    String? note,
  }) async {
    final loan = await into(loans).insertReturning(
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
    await _logChange('loans', loan.id, loan.toJson());
    return loan;
  }

  Future<void> updateLoan(Loan loan) async {
    await update(loans).replace(loan);
    await _logChange('loans', loan.id, loan.toJson());
  }

  Future<void> deleteLoan(String id) async {
    final payments = await (select(
      loanPayments,
    )..where((t) => t.loanId.equals(id))).get();
    await (delete(loanPayments)..where((t) => t.loanId.equals(id))).go();
    await (delete(loans)..where((t) => t.id.equals(id))).go();
    for (final payment in payments) {
      await _logChange('loanPayments', payment.id, const {}, deleted: true);
    }
    await _logChange('loans', id, const {}, deleted: true);
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
  }) async {
    final service = await into(recurringServices).insertReturning(
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
    await _logChange('services', service.id, service.toJson());
    return service;
  }

  Future<void> updateService(RecurringService service) async {
    await update(recurringServices).replace(service);
    await _logChange('services', service.id, service.toJson());
  }

  Future<void> deleteService(String id) async {
    await (delete(recurringServices)..where((t) => t.id.equals(id))).go();
    await _logChange('services', id, const {}, deleted: true);
  }

  Future<Transaction> payService(
    RecurringService service, {
    required DateTime date,
    double? amountOverride,
  }) async {
    if (service.accountId == null) {
      throw StateError('Asigna una cuenta al servicio antes de pagarlo');
    }
    final account = await (select(
      accounts,
    )..where((t) => t.id.equals(service.accountId!))).getSingle();
    var amount = amountOverride ?? service.amount;
    if (service.currency != account.currency) {
      final vesRate = await latestVesRate();
      if (vesRate == null) {
        throw StateError(
          'Guarda una tasa de referencia en Monedas para pagar en otra moneda',
        );
      }
      final eurRate = await latestRateFor('USD/EUR', 'api');
      final converted = _convertBetween(
        amount,
        service.currency,
        account.currency,
        vesPerUsd: vesRate.rate,
        eurPerUsd: eurRate?.rate,
      );
      if (converted == null) {
        throw StateError(
          'No se puede pagar ${service.currency} desde una cuenta ${account.currency} '
          '(usa VES, USD o EUR con sus tasas actualizadas)',
        );
      }
      amount = converted;
    }
    final transaction = await addTransaction(
      type: TransactionType.expense,
      accountId: service.accountId!,
      categoryId: service.categoryId,
      amount: amount,
      currency: account.currency,
      date: date,
      note: service.name,
      tags: const ['servicio'],
    );
    await (update(recurringServices)..where((t) => t.id.equals(service.id)))
        .write(RecurringServicesCompanion(lastPaidDate: Value(date)));
    final updated = await (select(
      recurringServices,
    )..where((t) => t.id.equals(service.id))).getSingle();
    await _logChange('services', updated.id, updated.toJson());
    return transaction;
  }

  Future<CurrencyRate?> latestRate() async {
    final rows =
        await (select(currencyRates)
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Última tasa VES guardada (cualquier proveedor del par `USD/VES`), sin
  /// mezclar con otras monedas como el euro.
  Future<CurrencyRate?> latestVesRate() async {
    final rows =
        await (select(currencyRates)
              ..where((t) => t.rateCode.equals('USD/VES'))
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Última tasa guardada para un [rateCode] de un [provider] concreto.
  Future<CurrencyRate?> latestRateFor(String rateCode, String provider) async {
    final rows =
        await (select(currencyRates)
              ..where(
                (t) =>
                    t.rateCode.equals(rateCode) & t.provider.equals(provider),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
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
    await (update(loans)..where((t) => t.id.equals(loan.id))).write(
      LoansCompanion(paidAmount: Value(loan.paidAmount + amount)),
    );
    final updated = await (select(
      loans,
    )..where((t) => t.id.equals(loan.id))).getSingle();
    await _logChange('loans', updated.id, updated.toJson());
    await _logChange('loanPayments', payment.id, payment.toJson());
    return payment;
  }

  Stream<List<Budget>> watchBudgets() => (select(
    budgets,
  )..orderBy([(t) => OrderingTerm.asc(t.categoryId)])).watch();

  Future<Budget> addBudget({
    required String categoryId,
    required double amount,
    required String currency,
  }) async {
    final budget = await into(budgets).insertReturning(
      BudgetsCompanion.insert(
        id: Uuid().v4(),
        categoryId: categoryId,
        amount: amount,
        currency: Value(currency),
      ),
    );
    await _logChange('budgets', budget.id, budget.toJson());
    return budget;
  }

  Future<void> updateBudget(Budget budget) async {
    await update(budgets).replace(budget);
    await _logChange('budgets', budget.id, budget.toJson());
  }

  Future<void> deleteBudget(String id) async {
    await (delete(budgets)..where((t) => t.id.equals(id))).go();
    await _logChange('budgets', id, const {}, deleted: true);
  }

  Future<void> restoreBackup(Map<String, dynamic> json) async {
    if (json['app'] != 'Polaris Finance') {
      throw const FormatException(
        'El archivo no es un respaldo de Polaris Finance',
      );
    }
    List<Map<String, dynamic>> rows(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

    final accountRows = rows('accounts');
    for (final row in accountRows) {
      row.putIfAbsent('openingBalance', () => 0);
    }

    // Reglas de comisión guardadas antes de que existieran el tipo de
    // cálculo por tramos y el alcance por tipo de transacción.
    final feeRuleRows = rows('feeRules');
    for (final row in feeRuleRows) {
      row.putIfAbsent('feeType', () => 'simple');
      row.putIfAbsent(
        'appliesTo',
        () => encodeFeeRuleTypes(defaultFeeRuleTypes),
      );
    }

    await transaction(() async {
      await delete(loanPayments).go();
      await delete(loans).go();
      await delete(transactions).go();
      await delete(savingsGoals).go();
      await delete(recurringServices).go();
      await delete(budgets).go();
      await delete(feeRules).go();
      await delete(currencyRates).go();
      await delete(accounts).go();
      await delete(categories).go();

      await batch((batch) {
        batch.insertAll(
          categories,
          rows('categories').map(Category.fromJson).toList(),
        );
        batch.insertAll(accounts, accountRows.map(Account.fromJson).toList());
        batch.insertAll(
          transactions,
          rows('transactions').map(Transaction.fromJson).toList(),
        );
        batch.insertAll(
          feeRules,
          rows('feeRules').map(FeeRule.fromJson).toList(),
        );
        batch.insertAll(
          savingsGoals,
          rows('goals').map(SavingsGoal.fromJson).toList(),
        );
        batch.insertAll(
          recurringServices,
          rows('services').map(RecurringService.fromJson).toList(),
        );
        batch.insertAll(
          currencyRates,
          rows('rates').map(CurrencyRate.fromJson).toList(),
        );
        batch.insertAll(loans, rows('loans').map(Loan.fromJson).toList());
        batch.insertAll(
          loanPayments,
          rows('loanPayments').map(LoanPayment.fromJson).toList(),
        );
        batch.insertAll(budgets, rows('budgets').map(Budget.fromJson).toList());
      });
    });
    // Tras restaurar se reconstruye la bitácora para subir el estado nuevo.
    await logAllRecords();
  }

  Future<void> insertRate({
    required String code,
    required String rateCode,
    required String provider,
    required double rate,
    bool isManual = false,
  }) async {
    final row = await into(currencyRates).insertReturning(
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
    await _logChange('rates', row.id, row.toJson());
    // La tasa se consulta cada minuto: sin poda el historial crecería sin
    // límite. Se conservan los últimos [keepDays] días y la fila más reciente
    // de cada combinación aunque sea más antigua.
    await pruneRateHistory();
  }

  /// Elimina tasas antiguas para mantener la base de datos ligera.
  ///
  /// Conserva los últimos [keepDays] días de historial y, para cada
  /// combinación `código + proveedor + rateCode`, la fila más reciente aunque
  /// quede fuera del rango (así el valor vigente nunca se pierde).
  Future<int> pruneRateHistory({int keepDays = 180}) async {
    if (keepDays <= 0) return 0;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    final all = await select(currencyRates).get();
    if (all.isEmpty) return 0;

    final latestByGroup = <String, CurrencyRate>{};
    for (final row in all) {
      final key = '${row.code}|${row.rateCode}|${row.provider}';
      final current = latestByGroup[key];
      if (current == null || row.date.isAfter(current.date)) {
        latestByGroup[key] = row;
      }
    }

    final stale = all.where((row) {
      if (!row.date.isBefore(cutoff)) return false;
      final key = '${row.code}|${row.rateCode}|${row.provider}';
      return latestByGroup[key]?.id != row.id;
    }).toList();
    if (stale.isEmpty) return 0;

    await transaction(() async {
      for (final row in stale) {
        await (delete(currencyRates)..where((t) => t.id.equals(row.id))).go();
        await _logChange('rates', row.id, const {}, deleted: true);
      }
    });
    return stale.length;
  }

  Future<void> deleteRates() async {
    final rows = await select(currencyRates).get();
    await delete(currencyRates).go();
    for (final row in rows) {
      await _logChange('rates', row.id, const {}, deleted: true);
    }
  }

  // ---------------------------------------------------------------------
  // Sincronización
  // ---------------------------------------------------------------------

  /// Colecciones de datos que viajan entre dispositivos.
  static const syncCollections = <String>[
    'accounts',
    'categories',
    'transactions',
    'feeRules',
    'goals',
    'services',
    'rates',
    'loans',
    'loanPayments',
    'budgets',
  ];

  /// Identificador del dispositivo que origina los cambios locales.
  String syncDeviceId = 'local';

  /// Registra (o actualiza) un cambio local en la bitácora de sincronización.
  Future<void> _logChange(
    String collection,
    String recordId,
    Map<String, dynamic> payload, {
    bool deleted = false,
  }) async {
    final now = DateTime.now();
    final seq = await _nextSeq();
    await into(syncRecords).insertOnConflictUpdate(
      SyncRecordsCompanion.insert(
        id: '$collection:$recordId',
        collection: collection,
        recordId: recordId,
        seq: Value(seq),
        updatedAt: now,
        updatedAtMs: Value(now.millisecondsSinceEpoch),
        originSeq: Value(seq),
        deleted: Value(deleted),
        deviceId: Value(syncDeviceId),
        payload: Value(jsonEncode(payload)),
      ),
    );
  }

  /// Registra un cambio con la fecha y el dispositivo de origen dados.
  ///
  /// Se usa al aplicar cambios remotos: así la bitácora local conserva la
  /// marca de tiempo del otro dispositivo y el cambio no vuelve a subirse
  /// como si fuera local.
  Future<void> logRemoteChange({
    required String collection,
    required String recordId,
    required DateTime updatedAt,
    required int updatedAtMs,
    required int originSeq,
    required String deviceId,
    required Map<String, dynamic> payload,
    required bool deleted,
  }) async {
    await into(syncRecords).insertOnConflictUpdate(
      SyncRecordsCompanion.insert(
        id: '$collection:$recordId',
        collection: collection,
        recordId: recordId,
        seq: Value(await _nextSeq()),
        updatedAt: updatedAt,
        updatedAtMs: Value(updatedAtMs),
        originSeq: Value(originSeq),
        deleted: Value(deleted),
        deviceId: Value(deviceId),
        payload: Value(jsonEncode(payload)),
      ),
    );
  }

  /// Siguiente número de secuencia de la bitácora.
  Future<int> _nextSeq() async {
    final row = await (selectOnly(
      syncRecords,
    )..addColumns([syncRecords.seq.max()])).getSingle();
    return (row.read(syncRecords.seq.max()) ?? 0) + 1;
  }

  /// Vuelca todos los registros actuales en la bitácora.
  ///
  /// Se usa la primera vez que se activa la sincronización para que el
  /// dispositivo suba su estado completo al resto.
  Future<int> logAllRecords() async {
    var count = 0;
    Future<void> log(String collection, List<Map<String, dynamic>> rows) async {
      for (final row in rows) {
        final id = row['id'];
        if (id is! String) continue;
        await _logChange(collection, id, row);
        count++;
      }
    }

    await log(
      'accounts',
      (await select(accounts).get()).map((e) => e.toJson()).toList(),
    );
    await log(
      'categories',
      (await select(categories).get()).map((e) => e.toJson()).toList(),
    );
    await log(
      'transactions',
      (await select(transactions).get()).map((e) => e.toJson()).toList(),
    );
    await log(
      'feeRules',
      (await select(feeRules).get()).map((e) => e.toJson()).toList(),
    );
    await log(
      'goals',
      (await select(savingsGoals).get()).map((e) => e.toJson()).toList(),
    );
    await log(
      'services',
      (await select(recurringServices).get()).map((e) => e.toJson()).toList(),
    );
    await log(
      'rates',
      (await select(currencyRates).get()).map((e) => e.toJson()).toList(),
    );
    await log(
      'loans',
      (await select(loans).get()).map((e) => e.toJson()).toList(),
    );
    await log(
      'loanPayments',
      (await select(loanPayments).get()).map((e) => e.toJson()).toList(),
    );
    await log(
      'budgets',
      (await select(budgets).get()).map((e) => e.toJson()).toList(),
    );
    return count;
  }

  /// Cambios locales pendientes de subir, ordenados por secuencia.
  Future<List<SyncRecord>> pendingChanges({int afterSeq = 0, int limit = 500}) {
    final query = select(syncRecords)
      ..where((t) => t.seq.isBiggerThanValue(afterSeq))
      ..orderBy([(t) => OrderingTerm.asc(t.seq)])
      ..limit(limit);
    return query.get();
  }

  /// Registro de la bitácora para un elemento concreto.
  Future<SyncRecord?> findSyncRecord(String collection, String recordId) =>
      (select(
        syncRecords,
      )..where((t) => t.id.equals('$collection:$recordId'))).getSingleOrNull();

  /// Aplica un cambio recibido de otro dispositivo.
  ///
  /// Devuelve `true` si el cambio se aplicó y `false` si se descartó por
  /// estar desactualizado (gana el cambio más reciente).
  Future<bool> applyRemoteChange({
    required String collection,
    required String recordId,
    required Map<String, dynamic> payload,
    required bool deleted,
  }) async {
    switch (collection) {
      case 'accounts':
        if (deleted) {
          await (delete(accounts)..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(accounts)
              .insertOnConflictUpdate(Account.fromJson(payload));
        }
      case 'categories':
        if (deleted) {
          await (delete(categories)..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(categories)
              .insertOnConflictUpdate(Category.fromJson(payload));
        }
      case 'transactions':
        if (deleted) {
          await (delete(
            transactions,
          )..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(transactions)
              .insertOnConflictUpdate(Transaction.fromJson(payload));
        }
      case 'feeRules':
        if (deleted) {
          await (delete(feeRules)..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(feeRules)
              .insertOnConflictUpdate(FeeRule.fromJson(payload));
        }
      case 'goals':
        if (deleted) {
          await (delete(
            savingsGoals,
          )..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(savingsGoals)
              .insertOnConflictUpdate(SavingsGoal.fromJson(payload));
        }
      case 'services':
        if (deleted) {
          await (delete(
            recurringServices,
          )..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(recurringServices)
              .insertOnConflictUpdate(RecurringService.fromJson(payload));
        }
      case 'rates':
        if (deleted) {
          await (delete(
            currencyRates,
          )..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(currencyRates)
              .insertOnConflictUpdate(CurrencyRate.fromJson(payload));
        }
      case 'loans':
        if (deleted) {
          await (delete(loans)..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(loans).insertOnConflictUpdate(Loan.fromJson(payload));
        }
      case 'loanPayments':
        if (deleted) {
          await (delete(
            loanPayments,
          )..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(loanPayments)
              .insertOnConflictUpdate(LoanPayment.fromJson(payload));
        }
      case 'budgets':
        if (deleted) {
          await (delete(budgets)..where((t) => t.id.equals(recordId))).go();
        } else {
          await into(budgets).insertOnConflictUpdate(Budget.fromJson(payload));
        }
      default:
        return false;
    }
    return true;
  }

  /// Estado de sincronización guardado en este dispositivo.
  Future<SyncState?> readSyncState() => (select(
    syncStates,
  )..where((t) => t.id.equals('default'))).getSingleOrNull();

  /// Guarda el estado de sincronización de este dispositivo.
  Future<void> writeSyncState({
    required String deviceId,
    int? lastPushedSeq,
    DateTime? lastPulledAt,
    DateTime? lastSyncAt,
  }) async {
    final current = await readSyncState();
    await into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion.insert(
        id: 'default',
        deviceId: Value(deviceId),
        lastPushedSeq: Value(lastPushedSeq ?? current?.lastPushedSeq ?? 0),
        lastPulledAt: Value(lastPulledAt ?? current?.lastPulledAt),
        lastSyncAt: Value(lastSyncAt ?? current?.lastSyncAt),
      ),
    );
  }
}
