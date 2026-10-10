import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_finance/app.dart';
import 'package:polaris_finance/core/providers.dart';
import 'package:polaris_finance/core/settings/app_settings.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/features/export/export_screen.dart';

void main() {
  Future<void> openFromMore(WidgetTester tester, String label) async {
    await tester.tap(find.text('Más'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('Se crea un presupuesto desde Analítica',
      (WidgetTester tester) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          initialSettingsProvider.overrideWithValue(AppSettingsState.defaults),
        ],
        child: const PolarisFinanceApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await openFromMore(tester, 'Analítica');

    await tester.tap(find.byTooltip('Presupuestos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay presupuestos'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(DropdownMenuItem<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField).first, '200');
    await tester.pump();

    await tester.tap(find.text('Crear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay presupuestos'), findsNothing);
    expect(find.textContaining('de 200'), findsOneWidget);

    final budgets = await database.select(database.budgets).get();
    expect(budgets, hasLength(1));
    expect(budgets.first.amount, 200);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  test('El respaldo se restaura en una base vacía', () async {
    final source = AppDatabase.memory();
    addTearDown(source.close);
    final account = await source.addAccount(
      name: 'Banesco',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
    );
    final category = await source.addCategory(
      name: 'Comida',
      icon: 'restaurant',
      colorValue: 0xFFEF5350,
      isIncome: false,
    );
    await source.addTransaction(
      accountId: account.id,
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 25,
      currency: 'VES',
      date: DateTime(2026, 10, 7),
      note: 'Almuerzo',
    );
    final budget = await source.addBudget(
      categoryId: category.id,
      amount: 300,
      currency: 'VES',
    );

    final backup = buildExportJson(
      accounts: await source.select(source.accounts).get(),
      categories: await source.select(source.categories).get(),
      transactions: await source.select(source.transactions).get(),
      feeRules: await source.select(source.feeRules).get(),
      goals: await source.select(source.savingsGoals).get(),
      services: await source.select(source.recurringServices).get(),
      rates: await source.select(source.currencyRates).get(),
      loans: await source.select(source.loans).get(),
      loanPayments: await source.select(source.loanPayments).get(),
      budgets: await source.select(source.budgets).get(),
    );
    expect(backup, contains('"budgets"'));

    final target = AppDatabase.memory();
    addTearDown(target.close);
    await target.restoreBackup(jsonDecode(backup) as Map<String, dynamic>);

    final restoredAccounts = await target.select(target.accounts).get();
    final restoredTransactions = await target.select(target.transactions).get();
    final restoredBudgets = await target.select(target.budgets).get();

    expect(restoredAccounts.single.name, 'Banesco');
    expect(restoredTransactions.single.note, 'Almuerzo');
    expect(restoredBudgets.single.amount, 300);
    expect(restoredBudgets.single.id, budget.id);

    expect(
      () => target.restoreBackup(const {'app': 'Otra app'}),
      throwsA(isA<FormatException>()),
    );
  });
}
