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
import 'package:polaris_finance/shared/widgets/account_card.dart';

void main() {
  testWidgets('La cuenta muestra el saldo fijado sin movimientos',
      (WidgetTester tester) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    await database.addAccount(
      name: 'Efectivo',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
      openingBalance: 500,
    );

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

    expect(find.text('500,00 VES'), findsWidgets);
    final transactions = await database.select(database.transactions).get();
    expect(transactions, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Editar el saldo fijado recalcula el saldo sin crear ingresos',
      (WidgetTester tester) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final account = await database.addAccount(
      name: 'Banesco',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
      openingBalance: 500,
    );
    await database.addTransaction(
      accountId: account.id,
      type: TransactionType.expense,
      amount: 100,
      currency: 'VES',
      date: DateTime(2026, 10, 7),
      note: 'Compra',
    );

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

    expect(find.text('400,00 VES'), findsWidgets);

    await tester.tap(find.byType(AccountCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Editar cuenta'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    final balanceField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller != null,
    );
    final controllers = tester
        .widgetList<TextField>(balanceField)
        .map((field) => field.controller!)
        .toList();
    expect(controllers[1].text, '400');

    await tester.enterText(find.byType(TextField).at(1), '1000');
    await tester.pump();

    final saveButton = find.text('Guardar cambios');
    await tester.scrollUntilVisible(
      saveButton,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('1.000,00 VES'), findsWidgets);

    final accounts = await database.select(database.accounts).get();
    expect(accounts.single.openingBalance, 1100);
    final transactions = await database.select(database.transactions).get();
    expect(transactions, hasLength(1));
    expect(transactions.first.type, TransactionType.expense.name);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('El saldo solo admite números y permite negativos',
      (WidgetTester tester) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    await database.addAccount(
      name: 'Efectivo',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
    );

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

    await tester.tap(find.byType(AccountCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final controllers = tester
        .widgetList<TextField>(
          find.byWidgetPredicate(
            (widget) => widget is TextField && widget.controller != null,
          ),
        )
        .map((field) => field.controller!)
        .toList();
    expect(controllers[1].text, '0');

    await tester.enterText(find.byType(TextField).at(1), 'abc');
    expect(controllers[1].text, '0');

    await tester.enterText(find.byType(TextField).at(1), '12.5x');
    expect(controllers[1].text, '0');

    await tester.enterText(find.byType(TextField).at(1), '-250.5');
    expect(controllers[1].text, '-250.5');

    final saveButton = find.text('Guardar cambios');
    await tester.scrollUntilVisible(
      saveButton,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('-250,50 VES'), findsWidgets);
    final accounts = await database.select(database.accounts).get();
    expect(accounts.single.openingBalance, -250.5);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  test('Un respaldo antiguo sin saldo inicial se restaura con 0', () async {
    final source = AppDatabase.memory();
    addTearDown(source.close);
    await source.addAccount(
      name: 'Banesco',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
      openingBalance: 750,
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
    final decoded = jsonDecode(backup) as Map<String, dynamic>;
    for (final row in decoded['accounts'] as List<dynamic>) {
      (row as Map<String, dynamic>).remove('openingBalance');
    }

    final target = AppDatabase.memory();
    addTearDown(target.close);
    await target.restoreBackup(decoded);

    final restored = await target.select(target.accounts).get();
    expect(restored.single.name, 'Banesco');
    expect(restored.single.openingBalance, 0);
  });
}
