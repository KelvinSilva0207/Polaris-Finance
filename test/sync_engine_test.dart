import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/data/sync/sync_engine.dart';
import 'package:polaris_finance/data/sync/sync_models.dart';
import 'package:polaris_finance/data/sync/sync_store.dart';

void main() {
  Future<AppDatabase> prepareDatabase() async {
    final database = AppDatabase.memory();
    await database.addAccount(
      name: 'Banesco',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
    );
    return database;
  }

  SyncEngine engineFor(AppDatabase database, SyncStore store, String deviceId) {
    database.syncDeviceId = deviceId;
    return SyncEngine(database: database, store: store, deviceId: deviceId);
  }

  Map<String, dynamic> categoryPayload(String id, String name) => {
    'id': id,
    'name': name,
    'icon': 'star',
    'colorValue': 0xFF9C6BFF,
    'isBuiltIn': false,
    'isIncome': false,
    'sortOrder': 1,
  };

  test('Un cambio local se sube al almacén remoto', () async {
    final database = await prepareDatabase();
    addTearDown(database.close);
    final store = MemorySyncStore();
    final engine = engineFor(database, store, 'device-a');

    await database.addCategory(
      name: 'Vuelos',
      icon: 'flight',
      colorValue: 0xFF00ACC1,
      isIncome: false,
    );

    final summary = await engine.syncNow();
    expect(summary.pushed, greaterThan(0));
    expect(store.documents.any((d) => d.collection == 'categories'), isTrue);
  });

  test('Un cambio remoto se aplica en la base local', () async {
    final database = await prepareDatabase();
    addTearDown(database.close);
    final store = MemorySyncStore();

    final remote = SyncDocument(
      id: SyncDocument.buildId('categories', 'cat-remota'),
      collection: 'categories',
      recordId: 'cat-remota',
      updatedAt: DateTime.now(),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      deleted: false,
      deviceId: 'device-b',
      payload: categoryPayload('cat-remota', 'Suscripciones'),
    );
    await store.push([remote]);

    final engine = engineFor(database, store, 'device-a');
    final summary = await engine.mergeDocuments(await store.pull());

    expect(summary.applied, 1);
    final categories = await database.watchCategories().first;
    expect(categories.any((c) => c.name == 'Suscripciones'), isTrue);
  });

  test('Gana el cambio más reciente', () async {
    final database = await prepareDatabase();
    addTearDown(database.close);
    final store = MemorySyncStore();
    final engine = engineFor(database, store, 'device-a');

    final local = await database.addCategory(
      name: 'Local',
      icon: 'star',
      colorValue: 0xFF9C6BFF,
      isIncome: false,
    );

    // Un cambio remoto más antiguo no debe pisar el local.
    final older = SyncDocument(
      id: SyncDocument.buildId('categories', local.id),
      collection: 'categories',
      recordId: local.id,
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAtMs: DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch,
      deleted: false,
      deviceId: 'device-b',
      payload: categoryPayload(local.id, 'Remoto viejo'),
    );
    final skipped = await engine.mergeDocuments([older]);
    expect(skipped.skipped, 1);
    expect(skipped.applied, 0);
    var categories = await database.watchCategories().first;
    expect(categories.firstWhere((c) => c.id == local.id).name, 'Local');

    // Un cambio remoto más nuevo sí se aplica.
    final newer = SyncDocument(
      id: SyncDocument.buildId('categories', local.id),
      collection: 'categories',
      recordId: local.id,
      updatedAt: DateTime.now().add(const Duration(hours: 2)),
      updatedAtMs: DateTime.now()
          .add(const Duration(hours: 2))
          .millisecondsSinceEpoch,
      deleted: false,
      deviceId: 'device-b',
      payload: categoryPayload(local.id, 'Remoto nuevo'),
    );
    final applied = await engine.mergeDocuments([newer]);
    expect(applied.applied, 1);
    categories = await database.watchCategories().first;
    expect(categories.firstWhere((c) => c.id == local.id).name, 'Remoto nuevo');
  });

  test('Un borrado se propaga a los demás dispositivos', () async {
    final first = await prepareDatabase();
    addTearDown(first.close);
    final second = await prepareDatabase();
    addTearDown(second.close);
    final store = MemorySyncStore();
    final engineA = engineFor(first, store, 'device-a');
    final engineB = engineFor(second, store, 'device-b');

    final category = await first.addCategory(
      name: 'Temporal',
      icon: 'star',
      colorValue: 0xFF9C6BFF,
      isIncome: false,
    );

    // El segundo dispositivo recibe el alta.
    await engineB.mergeDocuments(await engineA.pendingDocuments());
    var categories = await second.watchCategories().first;
    expect(categories.any((c) => c.id == category.id), isTrue);

    // Y después el borrado.
    await first.deleteCategory(category.id);
    final summary = await engineB.mergeDocuments(
      await engineA.pendingDocuments(),
    );
    expect(summary.applied, greaterThan(0));
    categories = await second.watchCategories().first;
    expect(categories.any((c) => c.id == category.id), isFalse);
  });

  test('Dos dispositivos terminan con los mismos datos', () async {
    final store = MemorySyncStore();
    final first = await prepareDatabase();
    addTearDown(first.close);
    final second = await prepareDatabase();
    addTearDown(second.close);

    final engineA = engineFor(first, store, 'device-a');
    final engineB = engineFor(second, store, 'device-b');

    await first.addCategory(
      name: 'Viajes',
      icon: 'flight',
      colorValue: 0xFF00ACC1,
      isIncome: false,
    );
    await engineA.syncNow();

    await engineB.syncNow();
    var categories = await second.watchCategories().first;
    expect(categories.any((c) => c.name == 'Viajes'), isTrue);

    // Y ahora al revés: el segundo crea algo y lo recibe el primero.
    await second.addCategory(
      name: 'Suscripciones',
      icon: 'subscriptions',
      colorValue: 0xFF26A69A,
      isIncome: false,
    );
    await engineB.syncNow();
    await engineA.syncNow();
    categories = await first.watchCategories().first;
    expect(categories.any((c) => c.name == 'Suscripciones'), isTrue);
  });

  test('Un cambio propio que vuelve del servidor no se reaplica', () async {
    final database = await prepareDatabase();
    addTearDown(database.close);
    final store = MemorySyncStore();
    final engine = engineFor(database, store, 'device-a');

    await database.addCategory(
      name: 'Propia',
      icon: 'star',
      colorValue: 0xFF9C6BFF,
      isIncome: false,
    );
    await engine.syncNow();

    // El servidor devuelve el mismo cambio: no debe aplicarse otra vez.
    final documents = await store.pull();
    final summary = await engine.mergeDocuments(documents);
    expect(summary.applied, 0);
    expect(summary.skipped, documents.length);
  });

  test('La bitácora registra altas, cambios y borrados', () async {
    final database = await prepareDatabase();
    addTearDown(database.close);

    final category = await database.addCategory(
      name: 'Temporal',
      icon: 'star',
      colorValue: 0xFF9C6BFF,
      isIncome: false,
    );
    var records = await database.pendingChanges();
    expect(
      records.any(
        (r) => r.collection == 'categories' && r.recordId == category.id,
      ),
      isTrue,
    );

    await database.deleteCategory(category.id);
    records = await database.pendingChanges();
    final record = records.firstWhere(
      (r) => r.collection == 'categories' && r.recordId == category.id,
    );
    expect(record.deleted, isTrue);
  });
}
