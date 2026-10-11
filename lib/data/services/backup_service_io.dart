import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

/// Clave en [SharedPreferences] con la ruta del backup pendiente de restaurar.
const backupRestoreKey = 'pending_restore_path';

final _sqliteSignature = 'SQLite format 3\u0000'.codeUnits;

/// Aplica una restauración pendiente. Debe llamarse al arrancar, ANTES de
/// abrir la base de datos: copia el backup sobre el archivo de la BD y limpia
/// la marca. Lanza si el archivo no existe o no es SQLite.
Future<void> applyPendingRestore(SharedPreferences prefs) async {
  final backupPath = prefs.getString(backupRestoreKey);
  if (backupPath == null) return;

  var succeeded = false;
  try {
    final backup = File(backupPath);
    if (!await backup.exists()) {
      throw StateError('No se encuentra la copia pendiente: $backupPath');
    }
    _assertSqliteHeader(backup);
    final databasePath = await databaseFilePath();
    await File(databasePath).parent.create(recursive: true);
    await backup.copy(databasePath);
    for (final suffix in const ['.sqlite-wal', '.sqlite-shm']) {
      final sidecar = File(databasePath + suffix);
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
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

void _assertSqliteHeader(File file) {
  final raf = file.openSync();
  try {
    final bytes = raf.readSync(16);
    if (bytes.length < 16) {
      throw StateError('El archivo no es una base de datos SQLite válida');
    }
    for (var i = 0; i < _sqliteSignature.length; i++) {
      if (bytes[i] != _sqliteSignature[i]) {
        throw StateError('El archivo no es una base de datos SQLite válida');
      }
    }
  } finally {
    raf.closeSync();
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
  /// archivo, válido aunque la base esté en modo WAL). Devuelve la ruta.
  Future<String> createBackup(AppDatabase db) async {
    final directory = await _backupsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final sep = Platform.pathSeparator;
    final path = '${directory.path}${sep}polaris-backup-$stamp.sqlite';
    final quoted = path.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$quoted'");
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
  /// que el archivo es una base SQLite.
  Future<void> scheduleRestore(String backupPath) async {
    _assertSqliteHeader(File(backupPath));
    await _prefs.setString(backupRestoreKey, backupPath);
  }

  Future<void> deleteBackup(String backupPath) async {
    final file = File(backupPath);
    if (await file.exists()) {
      await file.delete();
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