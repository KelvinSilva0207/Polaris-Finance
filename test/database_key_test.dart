import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:polaris_finance/core/security/database_key.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.support);

  final String support;

  @override
  Future<String?> getApplicationSupportPath() async => support;

  @override
  Future<String?> getApplicationDocumentsPath() async => support;
}

void main() {
  late Directory support;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('polaris_key_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(support.path);
  });

  tearDown(() {
    support.deleteSync(recursive: true);
  });

  test('crea una clave aleatoria de 32 bytes y la reutiliza', () async {
    final store = DatabaseKeyStore();
    final first = await store.loadOrCreate();
    expect(base64Url.decode(first), hasLength(32));

    final second = await store.loadOrCreate();
    expect(second, first);

    final fromDisk = await DatabaseKeyStore().read();
    expect(fromDisk, first);
  });

  test('save() reemplaza la clave guardada', () async {
    final store = DatabaseKeyStore();
    final first = await store.loadOrCreate();

    const replacement = 'bm90LWVzLXVuYS1jbGF2ZS1kZS10cmVzLWJ5dGVz';
    await store.save(replacement);

    expect(await store.read(), replacement);
    expect(await store.read(), isNot(first));
  });

  test(
    'un archivo aleatorio en la carpeta de soporte no rompe la clave',
    () async {
      File('${support.path}${Platform.pathSeparator}otra-cosa.bin')
          .writeAsStringSync('contenido ajeno');

      final key = await DatabaseKeyStore().loadOrCreate();
      expect(base64Url.decode(key), hasLength(32));
    },
  );
}
