import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_finance/core/providers.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/sync/sync_config.dart';
import 'package:polaris_finance/data/sync/sync_providers.dart';
import 'package:polaris_finance/features/settings/sync_screen.dart';

void main() {
  Future<void> pumpSyncScreen(
    WidgetTester tester,
    AppDatabase database,
    SyncConfig config,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          initialSyncConfigProvider.overrideWithValue(config),
        ],
        child: const MaterialApp(home: SyncScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'La pantalla de sincronización muestra el estado y las acciones',
    (tester) async {
      final database = AppDatabase.memory();
      addTearDown(database.close);

      await pumpSyncScreen(
        tester,
        database,
        const SyncConfig(deviceId: 'device-a', deviceName: 'Mi móvil'),
      );

      expect(find.text('Sincronización'), findsOneWidget);
      expect(find.text('Sincronizar ahora'), findsOneWidget);
      expect(find.text('Sin sincronizar'), findsOneWidget);
      expect(find.textContaining('Cambios pendientes'), findsOneWidget);

      // El resto de secciones están más abajo en la lista.
      await tester.dragUntilVisible(
        find.text('Exportar para otro dispositivo'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Exportar para otro dispositivo'), findsOneWidget);
      expect(find.text('Recibir de otro dispositivo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets('Sin servidor configurado la sincronización avisa', (
    tester,
  ) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);

    await pumpSyncScreen(
      tester,
      database,
      const SyncConfig(deviceId: 'device-a', enabled: true),
    );

    expect(find.text('Sin sincronizar'), findsOneWidget);
    expect(find.text('Sincronización en la nube'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
