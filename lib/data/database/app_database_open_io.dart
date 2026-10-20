import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../core/security/database_key.dart';
import 'app_database.dart';
import 'ensure_database_encrypted.dart';

/// Abre la base local cifrada con SQLCipher.
///
/// La clave se resuelve de forma perezosa (al primer acceso real) y se captura
/// en el `setup` que drift envía al aislante de fondo: ese callback corre
/// justo después de `sqlite3.open` y antes de que se lea el esquema, que es
/// el único lugar donde `PRAGMA key` puede aplicarse.
AppDatabase openAppDatabase() =>
    AppDatabase(DatabaseConnection.delayed(_openConnection()));

Future<DatabaseConnection> _openConnection() async {
  final directory = await _databaseDirectory();
  final sep = Platform.pathSeparator;
  final file = File('${directory.path}${sep}polaris_finance.sqlite');
  final tempDirectory = await _configureSqliteTempDirectory();

  final key = await DatabaseKeyStore().loadOrCreate();
  final encrypted = await ensureDatabaseEncrypted(file.path, key);
  // Si la conversión falló, la base queda en texto plano y se abre sin clave
  // para no dejar la app inutilizable; el intento se repite al arrancar.
  final usableKey = encrypted ? key : null;

  return NativeDatabase.createBackgroundConnection(
    file,
    isolateSetup: () => sqlite.sqlite3.tempDirectory = tempDirectory,
    setup: usableKey == null
        ? null
        : (db) => db.execute("PRAGMA key = '${_escapeKey(usableKey)}'"),
  );
}

String _escapeKey(String key) => key.replaceAll("'", "''");

/// Guarda la base de datos dentro de la carpeta de datos de la app
/// (AppData en Windows) en lugar de Documentos, y migra una vez el archivo
/// antiguo si existía en Documentos.
Future<Directory> _databaseDirectory() async {
  final support = await getApplicationSupportDirectory();
  final sep = Platform.pathSeparator;
  final directory = Directory('${support.path}${sep}polaris_finance');
  await directory.create(recursive: true);

  final newFile = File('${directory.path}${sep}polaris_finance.sqlite');
  if (!await newFile.exists()) {
    final documents = await getApplicationDocumentsDirectory();
    final legacy = File('${documents.path}${sep}polaris_finance.sqlite');
    if (await legacy.exists()) {
      await legacy.copy(newFile.path);
    }
  }
  return directory;
}

/// sqlite3 usa el directorio temporal del sistema, que en Android está
/// inaccesible: se lo apuntamos a la carpeta temporal de la app.
Future<String> _configureSqliteTempDirectory() async {
  final temp = await getTemporaryDirectory();
  sqlite.sqlite3.tempDirectory = temp.path;
  return temp.path;
}
