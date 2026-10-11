import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/features/export/csv_import.dart';
import 'package:polaris_finance/features/export/export_screen.dart';

void main() {
  test('roundtrip: exporta CSV y lo reimporta conservando el detalle', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final account = await db.addAccount(
      name: 'Banesco',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 1,
      openingBalance: 0,
    );
    final category = await db.addCategory(
      name: 'Comida',
      icon: 'restaurant',
      colorValue: 2,
      isIncome: false,
    );
    await db.addTransaction(
      accountId: account.id,
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 25.5,
      currency: 'VES',
      date: DateTime(2026, 10, 10, 12, 30),
      note: 'almuerzo con ; y "comillas"',
      tags: const ['comida', 'fuera'],
      feeAmount: 1.5,
    );
    await db.addTransaction(
      accountId: account.id,
      type: TransactionType.income,
      amount: 100,
      currency: 'VES',
      date: DateTime(2026, 10, 11, 8),
      note: 'sueldo',
    );

    final accounts = await db.select(db.accounts).get();
    final categories = await db.select(db.categories).get();
    final transactions = await db.select(db.transactions).get();

    final csv = buildTransactionsCsv(transactions, accounts, categories);
    final result = await importTransactionsCsv(
      csv: csv,
      db: db,
      accounts: accounts,
      categories: categories,
    );

    expect(result.imported, 2);
    expect(result.skipped, 0);
    expect(result.errors, isEmpty);

    final after = await db.select(db.transactions).get();
    expect(after, hasLength(4));

    final importedExpense = after.firstWhere(
      (t) => t.amount == 25.5 && t.type == TransactionType.expense.name,
    );
    expect(importedExpense.note, 'almuerzo con ; y "comillas"');
    expect(importedExpense.feeAmount, 1.5);
    expect(importedExpense.tags, 'comida,fuera');
  });

  test('omite transferencias, valida cuentas, categorías, fechas y montos', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.addAccount(
      name: 'Cuenta A',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 1,
      openingBalance: 0,
    );

    final csv = [
      'fecha;tipo;monto;moneda;comision;cuenta;categoria;nota;etiquetas',
      '2026-10-01 10:00;Transferencia;50;VES;0;Cuenta A;;movimiento interno;',
      '2026-10-02 10:00;Egreso;20;VES;0;No Existe;Cafe;sin cuenta;',
      '2026-10-02 10:00;Egreso;20;VES;0;Cuenta A;Categoria Inexistente;;',
      'zzzz;Egreso;20;VES;0;Cuenta A;;fecha mala;',
      '2026-10-04 10:00;Egreso;abc;VES;0;Cuenta A;;monto malo;',
      '2026-10-05 10:00;Cosas;10;VES;0;Cuenta A;;tipo malo;',
      '2026-10-06 10:00;Ingreso;500;VES;0;Cuenta A;;valido;',
    ].join('\n');

    final accounts = await db.select(db.accounts).get();
    final categories = await db.select(db.categories).get();
    final result = await importTransactionsCsv(
      csv: csv,
      db: db,
      accounts: accounts,
      categories: categories,
    );

    expect(result.imported, 1);
    expect(result.skipped, 1);
    expect(result.errors, hasLength(5));

    final after = await db.select(db.transactions).get();
    expect(after, hasLength(1));
    expect(after.single.amount, 500);
    expect(after.single.type, TransactionType.income.name);
  });

  test('acepta fechas dd/MM/yyyy y montos con coma decimal', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.addAccount(
      name: 'Banco X',
      type: AccountType.bank,
      currency: 'USD',
      colorValue: 1,
      openingBalance: 0,
    );

    final csv = [
      '10/10/2026 09:00;Egreso;12,50;USD;0;Banco X;;compra;',
      '11/10/2026;Ingreso;1.000,00;USD;0;Banco X;;decimal europeo;',
    ].join('\n');

    final accounts = await db.select(db.accounts).get();
    final result = await importTransactionsCsv(
      csv: csv,
      db: db,
      accounts: accounts,
      categories: const [],
    );

    expect(result.imported, 2);
    expect(result.errors, isEmpty);

    final after = await db.select(db.transactions).get();
    expect(after, hasLength(2));
    expect(after.first.amount, 12.5);
    expect(after.last.amount, 1000);
  });
}