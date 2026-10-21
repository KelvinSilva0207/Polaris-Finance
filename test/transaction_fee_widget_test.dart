import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_finance/core/providers.dart';
import 'package:polaris_finance/core/settings/app_settings.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/database/seeds.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/features/transactions/transaction_form_screen.dart';

void main() {
  Future<AppDatabase> prepareDatabase() async {
    final database = AppDatabase.memory();
    await database.addAccount(
      name: 'Banesco',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
    );
    await seedDatabase(database);
    return database;
  }

  testWidgets('Al marcar Pago Móvil aparece el campo de comisión', (
    tester,
  ) async {
    final database = await prepareDatabase();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          initialSettingsProvider.overrideWithValue(AppSettingsState.defaults),
        ],
        child: const MaterialApp(home: TransactionFormScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // El perfil del BDV solo aplica a pago móvil: en un egreso no aparece.
    expect(find.text('Comisión'), findsNothing);

    await tester.ensureVisible(find.text('Pago Móvil'));
    await tester.pump();
    await tester.tap(find.text('Pago Móvil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Comisión'), findsOneWidget);
    expect(find.text('Pago móvil (BDV)'), findsOneWidget);

    // 1.000 Bs → 14 Bs de comisión (monto fijo por debajo de 5.000).
    // El campo es caja registradora: 100000 son 1.000,00.
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '100000');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('14,00'), findsOneWidget);

    // 10.000 Bs → 0,30 % de la operación.
    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '1000000');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('30,00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
