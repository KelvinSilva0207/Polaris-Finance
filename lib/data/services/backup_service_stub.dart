import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';

/// Clave en [SharedPreferences] con la ruta del backup pendiente de restaurar.
const backupRestoreKey = 'pending_restore_path';

/// Aplicado al arrancar en plataformas sin `dart:io` (web): no hace nada.
Future<void> applyPendingRestore(SharedPreferences prefs) async {}

/// Servicio de copia de seguridad sin soporte en plataformas sin `dart:io`.
class BackupService {
  BackupService(SharedPreferences prefs);

  Future<String> createBackup(AppDatabase db) =>
      throw UnsupportedError('Backups no disponibles en esta plataforma');

  Future<List<String>> listBackups() =>
      throw UnsupportedError('Backups no disponibles en esta plataforma');

  Future<void> scheduleRestore(String backupPath) =>
      throw UnsupportedError('Backups no disponibles en esta plataforma');

  Future<void> deleteBackup(String backupPath) =>
      throw UnsupportedError('Backups no disponibles en esta plataforma');

  /// Devuelve true si la app se reinició sola.
  Future<bool> restartNow() async => false;
}
