import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:polaris_finance/core/security/backup_passphrase.dart';
import 'package:polaris_finance/core/security/database_key.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/database/ensure_database_encrypted.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/data/services/backup_exceptions.dart';
import 'package:polaris_finance/data/services/backup_service_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({required this.support, required this.downloads});

  final String support;
  final String downloads;

  @override
  Future<String?> getApplicationSupportPath() async => support;

  @override
  Future<String?> getApplicationDocumentsPath() async => support;

  @override
  Future<String?> getDownloadsPath() async => downloads;
}

void main() {
  const passphrase = 'frase-de-respaldo-123';
  late String support;
  late String downloads;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final temp = await Directory.systemTemp.createTemp('polaris_cipher_test_');
    support = '${temp.path}${Platform.pathSeparator}support';
    downloads = '${temp.path}${Platform.pathSeparator}downloads';
    Directory(support).createSync(recursive: true);
    Directory(downloads).createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      support: support,
      downloads: downloads,
    );
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'la copia se crea cifrada y con frase, y se restaura en otro equipo',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db.addAccount(
        name: 'Banesco',
        type: AccountType.bank,
        currency: 'VES',
        colorValue: 1,
        openingBalance: 1500,
      );

      final prefs = await SharedPreferences.getInstance();
      final service = BackupService(prefs);
      final backupPath = await service.createBackup(db, passphrase: passphrase);

      final file = File(backupPath);
      expect(file.existsSync(), isTrue);
      expect(await isPlainSqliteFile(file), isFalse);
      expect(File(backupKeyFilePath(backupPath)).existsSync(), isTrue);

      // "Otro equipo": sin la clave local, la copia exige la frase.
      final keyFile = File('$support${Platform.pathSeparator}.polaris_db_key');
      expect(keyFile.existsSync(), isTrue);
      keyFile.deleteSync();

      await expectLater(
        service.scheduleRestore(backupPath),
        throwsA(isA<BackupPassphraseRequired>()),
      );
      expect(prefs.getString(backupRestoreKey), isNull);

      await expectLater(
        service.scheduleRestore(backupPath, passphrase: 'otra-frase'),
        throwsA(isA<InvalidPassphrase>()),
      );
      expect(prefs.getString(backupRestoreKey), isNull);

      await service.scheduleRestore(backupPath, passphrase: passphrase);
      expect(prefs.getString(backupRestoreKey), backupPath);

      await applyPendingRestore(prefs);
      expect(prefs.getString(backupRestoreKey), isNull);

      // La clave quedó instalada desde el archivo lateral y la copia abre.
      final restoredPath = await databaseFilePath();
      expect(File(restoredPath).existsSync(), isTrue);
      expect(await isPlainSqliteFile(File(restoredPath)), isFalse);

      final deviceKey = await DatabaseKeyStore().loadOrCreate();
      final restored = sqlite3.open(restoredPath);
      restored.execute("PRAGMA key = '$deviceKey'");
      final names = restored
          .select('SELECT name FROM sqlite_master WHERE type = \'table\'')
          .map((row) => row['name'])
          .toList();
      expect(names, isNotEmpty);
      restored.close();

      final accounts = AppDatabase(
        NativeDatabase(
          File(restoredPath),
          setup: (raw) => raw.execute("PRAGMA key = '$deviceKey'"),
        ),
      );
      addTearDown(accounts.close);
      final rows = await accounts.select(accounts.accounts).get();
      expect(rows, hasLength(1));
      expect(rows.single.openingBalance, 1500);
    },
  );

  test(
    'una copia con frase conserva su archivo lateral al eliminarse',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final prefs = await SharedPreferences.getInstance();
      final service = BackupService(prefs);

      final backupPath = await service.createBackup(db, passphrase: passphrase);
      final sidecar = File(backupKeyFilePath(backupPath));
      expect(sidecar.existsSync(), isTrue);
      expect(jsonDecode(await sidecar.readAsString())['kdf'], 'pbkdf2-sha256');

      await service.deleteBackup(backupPath);
      expect(File(backupPath).existsSync(), isFalse);
      expect(sidecar.existsSync(), isFalse);
    },
  );

  test('sin frase la copia sigue cifrada con la clave del equipo', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.addAccount(
      name: 'Efectivo',
      type: AccountType.cash,
      currency: 'VES',
      colorValue: 2,
      openingBalance: 10,
    );

    final prefs = await SharedPreferences.getInstance();
    final service = BackupService(prefs);
    final backupPath = await service.createBackup(db);

    expect(await isPlainSqliteFile(File(backupPath)), isFalse);
    expect(File(backupKeyFilePath(backupPath)).existsSync(), isFalse);

    await service.scheduleRestore(backupPath);
    expect(prefs.getString(backupRestoreKey), backupPath);

    await applyPendingRestore(prefs);
    final deviceKey = await DatabaseKeyStore().loadOrCreate();
    final restored = sqlite3.open(await databaseFilePath());
    restored.execute("PRAGMA key = '$deviceKey'");
    final accounts = restored.select('SELECT count(*) AS n FROM accounts');
    expect(accounts.single['n'], 1);
    restored.close();
  });
}
