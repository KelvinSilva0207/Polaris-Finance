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
  testWidgets('Servicio recurrente se crea y se paga', (WidgetTester tester) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    await database.addAccount(
      name: 'Banesco',
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

    await tester.tap(find.text('Servicios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay servicios'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).at(0), 'Netflix');
    await tester.enterText(find.byType(TextField).at(1), '10');

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Banesco').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Crear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Pagar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Pagar Netflix'), findsOneWidget);
    await tester.tap(find.text('Registrar pago'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Pago registrado'), findsOneWidget);
    expect(find.textContaining('último pago'), findsOneWidget);

    final rows = await database.select(database.transactions).get();
    expect(rows, hasLength(1));
    expect(rows.first.amount, 10);
    expect(rows.first.type, TransactionType.expense.name);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Analítica muestra métricas y abre exportación',
      (WidgetTester tester) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final account = await database.addAccount(
      name: 'Efectivo',
      type: AccountType.cash,
      currency: 'VES',
      colorValue: 0xFF66BB6A,
    );
    await database.addTransaction(
      accountId: account.id,
      type: TransactionType.income,
      amount: 100,
      currency: 'VES',
      date: DateTime.now(),
      note: 'Sueldo',
    );
    await database.addTransaction(
      accountId: account.id,
      type: TransactionType.expense,
      amount: 50,
      currency: 'VES',
      date: DateTime.now(),
      note: 'Mercado',
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

    await tester.tap(find.text('Analítica'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Ingresos vs egresos'), findsOneWidget);
    expect(find.text('Egresos por categoría'), findsOneWidget);
    expect(find.textContaining('VES'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Gastos hormiga'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Gastos hormiga'), findsOneWidget);
    expect(find.text('Egresos últimos 6 meses'), findsOneWidget);

    await tester.tap(find.byTooltip('Exportar datos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Movimientos (CSV)'), findsOneWidget);
    expect(find.text('Respaldo completo (JSON)'), findsOneWidget);
    expect(find.text('Estado de cuentas (PDF)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  test('Los exportadores CSV, JSON y PDF se generan', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final account = await database.addAccount(
      name: 'Banesco',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
    );
    final category = await database.addCategory(
      name: 'Comida',
      icon: 'restaurant',
      colorValue: 0xFFEF5350,
      isIncome: false,
    );
    await database.addTransaction(
      accountId: account.id,
      type: TransactionType.expense,
      categoryId: category.id,
      amount: 12.5,
      currency: 'VES',
      date: DateTime(2026, 10, 7, 12, 30),
      note: 'Almuerzo; "especial"',
    );

    final transactions = await database.select(database.transactions).get();
    final accounts = await database.select(database.accounts).get();
    final categories = await database.select(database.categories).get();

    final csv = buildTransactionsCsv(transactions, accounts, categories);
    expect(csv, contains('fecha;tipo;monto;moneda'));
    expect(csv, contains('Egreso'));
    expect(csv, contains('Comida'));
    expect(csv, contains('"Almuerzo; ""especial"""'));

    final json = buildExportJson(
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      feeRules: const [],
      goals: const [],
      services: const [],
      rates: const [],
      loans: const [],
      loanPayments: const [],
    );
    expect(json, contains('"app": "Polaris Finance"'));
    expect(json, contains('Banesco'));

    final bytes = await buildExportPdf(
      transactions: transactions,
      accounts: accounts,
      categories: categories,
    );
    expect(bytes, isNotEmpty);
  });
}
