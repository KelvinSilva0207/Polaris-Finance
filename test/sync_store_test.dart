import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:polaris_finance/data/sync/sync_models.dart';
import 'package:polaris_finance/data/sync/sync_store.dart';

void main() {
  SyncDocument document({
    String id = 'categories:1',
    String collection = 'categories',
    String recordId = '1',
  }) {
    return SyncDocument(
      id: id,
      collection: collection,
      recordId: recordId,
      updatedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      updatedAtMs: DateTime.utc(2026, 1, 2, 3, 4, 5).millisecondsSinceEpoch,
      deleted: false,
      deviceId: 'device-a',
      payload: {'id': recordId, 'name': 'Vuelos'},
    );
  }

  test('El store REST envía los cambios en JSON', () async {
    late http.Request captured;
    final store = RestSyncStore(
      baseUrl: 'https://sync.ejemplo.com',
      token: 'secreto',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      }),
    );

    await store.push([document()]);

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'https://sync.ejemplo.com/sync/push');
    expect(captured.headers['Authorization'], 'Bearer secreto');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect((body['documents'] as List).length, 1);
  });

  test('El store REST recibe los cambios del servidor', () async {
    late Uri captured;
    final store = RestSyncStore(
      baseUrl: 'https://sync.ejemplo.com',
      client: MockClient((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({
            'documents': [document().toJson()],
          }),
          200,
        );
      }),
    );

    final documents = await store.pull(since: DateTime.utc(2026, 1, 1));

    expect(documents.length, 1);
    expect(documents.first.collection, 'categories');
    expect(documents.first.payload['name'], 'Vuelos');
    expect(captured.queryParameters['since'], '2026-01-01T00:00:00.000Z');
  });

  test('El store REST informa de los errores del servidor', () async {
    final store = RestSyncStore(
      baseUrl: 'https://sync.ejemplo.com',
      client: MockClient((request) async => http.Response('error', 500)),
    );

    expect(() => store.push([document()]), throwsA(isA<SyncException>()));
    expect(() => store.pull(), throwsA(isA<SyncException>()));
  });

  test('El store REST rechaza respuestas que no son JSON', () async {
    final store = RestSyncStore(
      baseUrl: 'https://sync.ejemplo.com',
      client: MockClient((request) async => http.Response('no json', 200)),
    );

    expect(() => store.pull(), throwsA(isA<SyncException>()));
  });

  test('El store en memoria conserva el cambio más reciente', () async {
    final store = MemorySyncStore();
    final older = SyncDocument(
      id: 'categories:1',
      collection: 'categories',
      recordId: '1',
      updatedAt: DateTime.utc(2026),
      updatedAtMs: DateTime.utc(2026).millisecondsSinceEpoch,
      deleted: false,
      deviceId: 'device-a',
      payload: const {},
    );
    final newer = SyncDocument(
      id: 'categories:1',
      collection: 'categories',
      recordId: '1',
      updatedAt: DateTime.utc(2026, 5),
      updatedAtMs: DateTime.utc(2026, 5).millisecondsSinceEpoch,
      deleted: false,
      deviceId: 'device-b',
      payload: const {},
    );

    await store.push([newer]);
    await store.push([older]);

    final documents = await store.pull();
    expect(documents.length, 1);
    expect(documents.first.deviceId, 'device-b');
  });
}
