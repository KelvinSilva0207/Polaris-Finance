import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/security/backup_passphrase.dart';
import '../../core/security/database_key.dart';
import '../database/app_database.dart';
import '../database/ensure_database_encrypted.dart';
import 'backup_exceptions.dart';

/// Clave en [SharedPreferences] con la ruta del backup pendiente de restaurar.
const backupRestoreKey = 'pending_restore_path';

/// Aplica una restauración pendiente. Debe llamarse al arrancar, ANTES de
/// abrir la base de datos: copia el backup sobre el archivo de la BD y limpia
/// la marca. Lanza si el archivo no existe o no se puede abrir.
Future<void> applyPendingRestore(SharedPreferences prefs) async {
  final backupPath = prefs.getString(backupRestoreKey);
  if (backupPath == null) return;

  var succeeded = false;
  try {
    final backup = File(backupPath);
    if (!await backup.exists()) {
      throw StateError('No se encuentra la copia pendiente: $backupPath');
    }
    await _assertRestorable(backup);
    final databasePath = await databaseFilePath();
    await File(databasePath).parent.create(recursive: true);
    await backup.copy(databasePath);
    await _deleteJournalSiblings(databasePath);
    succeeded = true;
  } finally {
    await prefs.remove(backupRestoreKey);
    if (!succeeded) {
      throw StateError('No se pudo restaurar la copia pendiente');
    }
  }
}

/// Ruta del archivo de la base de datos principal (coincide con la que abre
/// `openAppDatabase` de `app_database_open_io.dart`).
Future<String> databaseFilePath() async {
  final support = await getApplicationSupportDirectory();
  final sep = Platform.pathSeparator;
  return '${support.path}${sep}polaris_finance${sep}polaris_finance.sqlite';
}

/// Comprueba que [file] sea una copia restaurable: texto plano, cifrada con la
/// clave de este equipo o con frase (en cuyo caso se lanza
/// [BackupPassphraseRequired] para que la pantalla la pida).
Future<void> _assertRestorable(File file) async {
  if (!await file.exists()) {
    throw StateError('No se encuentra la copia: ${file.path}');
  }
  if (await file.length() < 16) {
    throw StateError('El archivo no es una base de datos SQLite válida');
  }
  if (await isPlainSqliteFile(file)) return;
  if (await _opensWithStoredKey(file)) return;
  if (await File(backupKeyFilePath(file.path)).exists()) {
    throw const BackupPassphraseRequired();
  }
  throw StateError(
    'La copia está cifrada con una clave que no corresponde a este equipo',
  );
}

Future<bool> _opensWithStoredKey(File file) async {
  final key = await DatabaseKeyStore().read();
  if (key == null) return false;
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
    debugPrint('La copia no se abre con la clave del equipo: $error');
    return false;
  }
}

Future<void> _deleteJournalSiblings(String path) async {
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('$path$suffix');
    if (await sidecar.exists()) {
      await sidecar.delete();
    }
  }
}

/// Servicio de copia de seguridad para plataformas con `dart:io`.
class BackupService {
  BackupService(this._prefs);

  final SharedPreferences _prefs;

  Future<Directory> _backupsDirectory() async {
    Directory base;
    try {
      base =
          (await getDownloadsDirectory()) ??
          await getApplicationSupportDirectory();
    } on Exception {
      base = await getApplicationSupportDirectory();
    }
    final sep = Platform.pathSeparator;
    final directory = Directory('${base.path}${sep}PolarisFinance');
    await directory.create(recursive: true);
    return directory;
  }

  /// Crea una copia consistente de la base con `VACUUM INTO` (un solo
  /// archivo, válido aunque la base esté en modo WAL) y la deja cifrada con
  /// la clave del equipo. Si se pasa [passphrase], además se escribe un
  /// archivo lateral `*.key.json` con la clave envuelta por la frase para que
  /// la copia pueda restaurarse en otro dispositivo. Devuelve la ruta.
  Future<String> createBackup(AppDatabase db, {String? passphrase}) async {
    final directory = await _backupsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final sep = Platform.pathSeparator;
    final path = '${directory.path}${sep}polaris-backup-$stamp.sqlite';
    final quoted = path.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$quoted'");

    final keyStore = DatabaseKeyStore();
    final deviceKey = await keyStore.loadOrCreate();
    final encrypted = await ensureDatabaseEncrypted(path, deviceKey);

    if (passphrase != null && passphrase.isNotEmpty) {
      if (!encrypted) {
        throw StateError('No se pudo cifrar la copia con la clave del equipo');
      }
      final contents = await wrapBackupKey(
        deviceKey: deviceKey,
        passphrase: passphrase,
      );
      await File(backupKeyFilePath(path)).writeAsString(contents, flush: true);
    }
    return path;
  }

  /// Copias disponibles, ordenadas de la más reciente a la más antigua.
  Future<List<String>> listBackups() async {
    final directory = await _backupsDirectory();
    final backups = <String>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.sqlite')) {
        backups.add(entity.path);
      }
    }
    backups.sort((a, b) => b.compareTo(a));
    return backups;
  }

  /// Marca [backupPath] para restaurarse en el próximo arranque, tras validar
  /// que el archivo se puede abrir. Si la copia está protegida con frase hay
  /// que pasarla en [passphrase]; si falta se lanza [BackupPassphraseRequired]
  /// y no se programa nada.
  Future<void> scheduleRestore(String backupPath, {String? passphrase}) async {
    final keyFile = File(backupKeyFilePath(backupPath));
    if (await keyFile.exists()) {
      if (passphrase == null || passphrase.isEmpty) {
        throw const BackupPassphraseRequired();
      }
      final deviceKey = await unwrapBackupKey(
        keyFileContents: await keyFile.readAsString(),
        passphrase: passphrase,
      );
      await DatabaseKeyStore().save(deviceKey);
    }
    await _assertRestorable(File(backupPath));
    await _prefs.setString(backupRestoreKey, backupPath);
  }

  Future<void> deleteBackup(String backupPath) async {
    for (final path in [backupPath, backupKeyFilePath(backupPath)]) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// En escritorio relanza la app para aplicar el backup pendiente en el
  /// próximo arranque. Devuelve true si la app se reinició sola.
  Future<bool> restartNow() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await Process.start(Platform.resolvedExecutable, const []);
      exit(0);
    }
    return false;
  }
}
