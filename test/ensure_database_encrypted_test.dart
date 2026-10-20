import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/ensure_database_encrypted.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  const key = 'Y2xhdmUtcHJ1ZWJhLWNsaXZl';
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('polaris_enc_test_');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  String path(String name) => '${temp.path}${Platform.pathSeparator}$name';

  test('convierte una base en texto plano y conserva user_version', () async {
    final file = File(path('plano.sqlite'));
    final db = sqlite3.open(file.path);
    db.execute('CREATE TABLE datos (nota TEXT NOT NULL)');
    db.execute("INSERT INTO datos VALUES ('hola')");
    db.execute('PRAGMA user_version = 6');
    db.close();

    expect(await isPlainSqliteFile(file), isTrue);
    expect(await ensureDatabaseEncrypted(file.path, key), isTrue);
    expect(await isPlainSqliteFile(file), isFalse);

    final encrypted = sqlite3.open(file.path);
    encrypted.execute("PRAGMA key = '$key'");
    expect(encrypted.select('PRAGMA user_version').single.values.first, 6);
    expect(encrypted.select('SELECT nota FROM datos').single['nota'], 'hola');
    encrypted.close();

    final withoutKey = sqlite3.open(file.path);
    expect(
      () => withoutKey.select('SELECT nota FROM datos'),
      throwsA(isA<SqliteException>()),
    );
    withoutKey.close();

    expect(File('${file.path}.plain').existsSync(), isFalse);
    expect(File('${file.path}.encrypting').existsSync(), isFalse);
  });

  test('no vuelve a tocar una base ya cifrada', () async {
    final file = File(path('cifrada.sqlite'));
    final created = sqlite3.open(file.path);
    created.execute("PRAGMA key = '$key'");
    created.execute('CREATE TABLE datos (nota TEXT NOT NULL)');
    created.close();

    final before = file.readAsBytesSync();
    expect(await ensureDatabaseEncrypted(file.path, key), isTrue);
    expect(file.readAsBytesSync(), before);
  });

  test('devuelve true sin hacer nada si el archivo no existe', () async {
    expect(await ensureDatabaseEncrypted(path('nueva.sqlite'), key), isTrue);
    expect(File(path('nueva.sqlite')).existsSync(), isFalse);
  });

  test('devuelve false si el archivo no es SQLite', () async {
    final file = File(path('basura.sqlite'));
    await file.writeAsString('esto no es una base de datos');

    expect(await ensureDatabaseEncrypted(file.path, key), isFalse);
    expect(file.readAsStringSync(), 'esto no es una base de datos');
  });
}
