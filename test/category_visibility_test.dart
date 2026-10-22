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

  test('Las categorías nuevas quedan al final de su sección', () async {
    final database = await prepareDatabase();
    addTearDown(database.close);

    final created = await database.addCategory(
      name: 'Vuelos',
      icon: 'flight',
      colorValue: 0xFF00ACC1,
      isIncome: false,
    );
    expect(created.sortOrder, greaterThan(0));

    final categories = await database.watchCategories().first;
    final expenses = categories.where((c) => !c.isIncome).toList();
    expect(expenses.last.name, 'Vuelos');

    // La de ingresos no se mezcla con la de egresos.
    final income = categories.where((c) => c.isIncome).toList();
    expect(income.any((c) => c.name == 'Vuelos'), isFalse);
  });

  testWidgets(
    'La categoría creada desde el formulario aparece en el desplegable',
    (tester) async {
      final database = await prepareDatabase();
      addTearDown(database.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            initialSettingsProvider.overrideWithValue(
              AppSettingsState.defaults,
            ),
          ],
          child: const MaterialApp(home: TransactionFormScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Llevar el desplegable de categoría a la vista.
      await tester.dragUntilVisible(
        find.text('Sin categoría'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final categoryField = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Categoría',
      );
      expect(categoryField, findsOneWidget);

      // Elegir la opción "Nueva categoría…" (valor interno `_new`).
      final field = tester.widget<DropdownButtonFormField<String>>(
        categoryField,
      );
      field.onChanged!('_new');
      await tester.pumpAndSettle();

      // Crear la categoría desde la hoja inferior.
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre'),
        'Vuelos',
      );
      await tester.pump();
      await tester.tap(find.text('Crear categoría'));
      await tester.pumpAndSettle();

      // La categoría recién creada debe verse ya en el desplegable.
      final created = (await database.select(database.categories).get())
          .firstWhere((category) => category.name == 'Vuelos');
      final rebuilt = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.widgetWithText(DropdownButtonFormField<String>, 'Categoría'),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(
        rebuilt.items!.any((item) => item.value == created.id),
        isTrue,
        reason: 'La categoría nueva debe estar en la lista del desplegable',
      );
      expect(rebuilt.value, created.id);
      expect(find.text('Vuelos'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
