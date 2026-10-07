import 'package:flutter/widgets.dart';
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
}