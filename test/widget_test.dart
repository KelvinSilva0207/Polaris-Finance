import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_finance/app.dart';
import 'package:polaris_finance/core/providers.dart';
import 'package:polaris_finance/core/settings/app_settings.dart';
import 'package:polaris_finance/data/database/app_database.dart';

void main() {
  testWidgets('La app arranca y muestra el dashboard', (WidgetTester tester) async {
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
    await tester.pumpAndSettle();

    expect(find.text('Polaris Finance'), findsOneWidget);
    expect(find.text('Bienvenido a Polaris Finance'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Se crea una cuenta y se registra un egreso', (WidgetTester tester) async {
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear mi primera cuenta'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Banesco'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.scrollUntilVisible(
      find.text('Crear cuenta'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Banesco'), findsOneWidget);

    await tester.tap(find.text('Movimientos'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Banesco').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Registrar'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('Registrar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Banesco'), findsWidgets);
    expect(find.textContaining('100,00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}