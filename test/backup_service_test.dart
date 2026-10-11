import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/data/services/backup_service_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late String root;
  late String support;
  late String downloads;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final temp = await Directory.systemTemp.createTemp('polaris_backup_test_');
    root = temp.path;
    support = '$root${Platform.pathSeparator}support';
    downloads = '$root${Platform.pathSeparator}downloads';
    Directory(support).createSync(recursive: true);
    Directory(downloads).createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      support: support,
      downloads: downloads,
    );
    SharedPreferences.setMockInitialValues({});
  });

  test('crea backup con VACUUM INTO y lo restaura al arrancar', () async {
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
    final backupPath = await service.createBackup(db);
    expect(File(backupPath).existsSync(), isTrue);
    expect(File(backupPath).lengthSync(), greaterThan(16));

    // Una "sesión posterior": se restaura y se aplica antes de abrir la BD.
    await service.scheduleRestore(backupPath);
    expect(prefs.getString(backupRestoreKey), backupPath);

    await applyPendingRestore(prefs);

    final restoredPath = await databaseFilePath();
    expect(File(restoredPath).existsSync(), isTrue);
    final restored = AppDatabase(NativeDatabase(File(restoredPath)));
    addTearDown(restored.close);
    final accounts = await restored.select(restored.accounts).get();
    expect(accounts, hasLength(1));
    expect(accounts.single.name, 'Banesco');
    expect(accounts.single.openingBalance, 1500);

    await restored.close();
    final prefsAfter = await SharedPreferences.getInstance();
    expect(prefsAfter.getString(backupRestoreKey), isNull);
  });

  test('rechaza un archivo que no es una base SQLite', () async {
    final bad = File('$downloads${Platform.pathSeparator}malo.sqlite');
    await bad.create();

    final prefs = await SharedPreferences.getInstance();
    final service = BackupService(prefs);
    await expectLater(service.scheduleRestore(bad.path), throwsStateError);
  });

  test('borra la marca pendiente si el backup ya no existe', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      backupRestoreKey,
      '$downloads${Platform.pathSeparator}noexiste.sqlite',
    );

    await expectLater(applyPendingRestore(prefs), throwsStateError);

    final prefsAfter = await SharedPreferences.getInstance();
    expect(prefsAfter.getString(backupRestoreKey), isNull);
  });
}
