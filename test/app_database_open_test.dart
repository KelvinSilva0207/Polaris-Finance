import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:polaris_finance/core/security/database_key.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/database/app_database_open_io.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.support);

  final String support;

  @override
  Future<String?> getApplicationSupportPath() async => support;

  @override
  Future<String?> getApplicationDocumentsPath() async => support;

  @override
  Future<String?> getTemporaryPath() async => support;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String support;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final temp = await Directory.systemTemp.createTemp('polaris_open_test_');
    support = '${temp.path}${Platform.pathSeparator}support';
    Directory(support).createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(support);
    SharedPreferences.setMockInitialValues({});
  });

  String dbPath() =>
      '$support${Platform.pathSeparator}polaris_finance'
      '${Platform.pathSeparator}polaris_finance.sqlite';

  test('openAppDatabase crea y abre la base cifrada tras migrar', () async {
    // Simula una instalación previa en texto plano con datos.
    final directory = Directory(
      '$support${Platform.pathSeparator}polaris_finance',
    );
    directory.createSync(recursive: true);
    final legacy = sqlite3.open(dbPath());
    legacy.execute(
      'CREATE TABLE accounts ('
      'id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, '
      'currency TEXT NOT NULL, color_value INTEGER NOT NULL, '
      'icon TEXT NOT NULL DEFAULT \'account_balance\', '
      'is_default INTEGER NOT NULL DEFAULT 0, '
      'opening_balance REAL NOT NULL DEFAULT 0, '
      'created_at INTEGER NOT NULL DEFAULT 0)',
    );
    legacy.execute(
      'INSERT INTO accounts (id, name, type, currency, color_value) '
      "VALUES ('a1', 'Vieja', 'bank', 'VES', 1)",
    );
    legacy.execute(
      'CREATE TABLE fee_rules ('
      'id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, bank_type TEXT, '
      'fixed_amount REAL NOT NULL DEFAULT 0, '
      'percent REAL NOT NULL DEFAULT 0, min_amount REAL, max_amount REAL, '
      'is_active INTEGER NOT NULL DEFAULT 1)',
    );
    legacy.execute('PRAGMA user_version = 6');
    legacy.close();

    final db = openAppDatabase();
    final accounts = await db.select(db.accounts).get();
    expect(accounts.where((account) => account.name == 'Vieja'), hasLength(1));

    // La migración de la v7 deja el perfil de pago móvil del BDV.
    final rules = await db.select(db.feeRules).get();
    expect(rules.where((rule) => rule.id == defaultFeeRuleId), hasLength(1));
    expect(rules.first.appliesTo, 'pagoMovil');
    expect(rules.first.tierThreshold, 5000);
    expect(rules.first.tierPercent, 0.3);

    await db.addAccount(
      name: 'Nueva',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 1,
      openingBalance: 100,
    );
    await db.close();

    // En disco quedó cifrada con la clave del equipo.
    final key = await DatabaseKeyStore().loadOrCreate();
    final bytes = File(dbPath()).readAsBytesSync();
    expect(bytes.sublist(0, 16), isNot('SQLite format 3\u0000'.codeUnits));

    final reopened = sqlite3.open(dbPath());
    reopened.execute("PRAGMA key = '${key.replaceAll("'", "''")}'");
    expect(reopened.select('PRAGMA user_version').single.values.first, 7);
    expect(
      reopened
          .select('SELECT name FROM accounts ORDER BY name')
          .map((row) => row['name']),
      containsAll(<String>['Vieja', 'Nueva']),
    );
    reopened.close();
  });
}
