import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// Cabecera de un archivo SQLite en texto plano.
const _sqliteSignature = 'SQLite format 3\u0000';

/// Garantiza que la base en [path] esté cifrada con SQLCipher usando [key] y
/// devuelve `true` si la base puede abrirse con esa clave.
///
/// - Si el archivo no existe (primera ejecución) devuelve `true`: SQLCipher la
///   crea cifrada al aplicar `PRAGMA key`.
/// - Si está en texto plano la convierte con `ATTACH ... KEY` +
///   `sqlcipher_export()` (el único camino soportado por SQLCipher; `rekey`
///   sobre texto plano no existe) y preserva `user_version` para que drift no
///   vuelva a crear las tablas.
/// - Si ya está cifrada comprueba que abre con [key] sin modificarla.
///
/// Devuelve `false` si la conversión falla (la base se queda en texto plano y
/// el intento se repite en el próximo arranque) o si el archivo ni siquiera
/// es una base nuestra: en ese caso se abrirá sin clave y drift mostrará el
/// error real del archivo.
Future<bool> ensureDatabaseEncrypted(String path, String key) async {
  final file = File(path);
  if (!await file.exists()) return true;
  if (await file.length() < 16) return true;

  if (await _isPlainText(file)) {
    try {
      await _encryptInPlace(file, key);
      return true;
    } catch (error) {
      debugPrint('No se pudo cifrar la base de datos: $error');
      return false;
    }
  }
  return _opensWithKey(file, key);
}

Future<bool> _opensWithKey(File file, String key) async {
  try {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      db.execute("PRAGMA key = '${key.replaceAll("'", "''")}'");
      db.select('SELECT count(*) FROM sqlite_master');
      return true;
    } finally {
      db.close();
    }
  } catch (error) {
    debugPrint('La base no se abre con la clave del equipo: $error');
    return false;
  }
}

/// Devuelve `true` si [file] tiene la cabecera de SQLite en texto plano.
Future<bool> isPlainSqliteFile(File file) => _isPlainText(file);

Future<bool> _isPlainText(File file) async {
  final raf = await file.open();
  try {
    final bytes = await raf.read(16);
    if (bytes.length < 16) return false;
    for (var i = 0; i < _sqliteSignature.length; i++) {
      if (bytes[i] != _sqliteSignature.codeUnitAt(i)) return false;
    }
    return true;
  } finally {
    await raf.close();
  }
}

Future<void> _encryptInPlace(File file, String key) async {
  final path = file.path;
  final temp = File('$path.encrypting');
  final previous = File('$path.plain');
  await _deleteWithSiblings(temp);
  await _deleteWithSiblings(previous);

  final db = sqlite3.open(path);
  final version = db.select('PRAGMA user_version').single.values.first;
  try {
    db.execute(
      "ATTACH DATABASE '${_escape(temp.path)}' AS cifrada KEY "
      "'${_escape(key)}'",
    );
    try {
      db.select("SELECT sqlcipher_export('cifrada')");
      // sqlcipher_export no copia el número de versión de esquema.
      db.execute('PRAGMA cifrada.user_version = $version');
      db.execute('DETACH DATABASE cifrada');
    } catch (error) {
      db.execute('DETACH DATABASE cifrada');
      rethrow;
    }
  } finally {
    db.close();
  }

  // Intercambio atómico: si algo falla, el original vuelve a su sitio.
  await file.rename(previous.path);
  try {
    await temp.rename(path);
  } catch (error) {
    await previous.rename(path);
    rethrow;
  }
  await _deleteWithSiblings(previous);
}

Future<void> _deleteWithSiblings(File file) async {
  for (final sibling in [
    file,
    File('${file.path}-wal'),
    File('${file.path}-shm'),
  ]) {
    if (await sibling.exists()) {
      await sibling.delete();
    }
  }
}

String _escape(String value) => value.replaceAll("'", "''");
