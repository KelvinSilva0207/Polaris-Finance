import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Verifica que package:sqlite3 se esté compilando como SQLCipher (pubspec →
/// hooks: user_defines: sqlite3: source: sqlcipher) y no como SQLite plano.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('polaris_sqlcipher_');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  test('PRAGMA key cifra el archivo y sin clave no se puede leer', () {
    final path = '${temp.path}${Platform.pathSeparator}enc.sqlite';

    final created = sqlite3.open(path);
    created.execute("PRAGMA key = 'clave-de-prueba'");
    created.execute('CREATE TABLE datos (nota TEXT NOT NULL)');
    created.execute("INSERT INTO datos VALUES ('secreto')");
    created.close();

    final bytes = File(path).readAsBytesSync();
    expect(bytes.length, greaterThan(16));
    expect(bytes.sublist(0, 16), isNot('SQLite format 3\u0000'.codeUnits));

    final withoutKey = sqlite3.open(path);
    expect(
      () => withoutKey.select('SELECT nota FROM datos'),
      throwsA(isA<SqliteException>()),
    );
    withoutKey.close();

    final withKey = sqlite3.open(path);
    withKey.execute("PRAGMA key = 'clave-de-prueba'");
    expect(withKey.select('SELECT nota FROM datos').single['nota'], 'secreto');
    withKey.close();
  });

  test('con una clave incorrecta la base no se puede leer', () {
    final path = '${temp.path}${Platform.pathSeparator}otra.sqlite';

    final created = sqlite3.open(path);
    created.execute("PRAGMA key = 'correcta'");
    created.execute('CREATE TABLE datos (n INTEGER)');
    created.close();

    final wrong = sqlite3.open(path);
    wrong.execute("PRAGMA key = 'incorrecta'");
    expect(
      () => wrong.select('SELECT * FROM datos'),
      throwsA(isA<SqliteException>()),
    );
    wrong.close();
  });

  test('sin PRAGMA key el archivo queda en texto plano', () {
    final path = '${temp.path}${Platform.pathSeparator}plano.sqlite';

    final db = sqlite3.open(path);
    db.execute('CREATE TABLE datos (n INTEGER)');
    db.close();

    final bytes = File(path).readAsBytesSync();
    expect(bytes.sublist(0, 16), 'SQLite format 3\u0000'.codeUnits);
  });
}
