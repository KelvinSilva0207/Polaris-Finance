import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';

void main() {
  Future<void> insertRate(
    AppDatabase database, {
    required String id,
    required DateTime date,
    required double rate,
  }) {
    return database.into(database.currencyRates).insert(
      CurrencyRatesCompanion.insert(
        id: id,
        code: 'USD',
        rateCode: 'USD/VES',
        provider: 'bcv',
        rate: rate,
        date: date,
      ),
    );
  }

  test('elimina las tasas fuera del rango y conserva la más reciente', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final now = DateTime.now();
    final old = now.subtract(const Duration(days: 400));

    await insertRate(database, id: 'old-1', date: old, rate: 10);
    await insertRate(
      database,
      id: 'old-2',
      date: old.add(const Duration(days: 1)),
      rate: 11,
    );
    await insertRate(
      database,
      id: 'recent',
      date: now.subtract(const Duration(days: 2)),
      rate: 12,
    );

    expect(await database.pruneRateHistory(), 2);
    final rows = await database.select(database.currencyRates).get();
    expect(rows.map((row) => row.id), ['recent']);
  });

  test('conserva la tasa vigente aunque quede fuera del rango', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final old = DateTime.now().subtract(const Duration(days: 400));

    await insertRate(database, id: 'old-1', date: old, rate: 10);
    await insertRate(
      database,
      id: 'old-2',
      date: old.add(const Duration(days: 1)),
      rate: 11,
    );

    expect(await database.pruneRateHistory(), 1);
    final rows = await database.select(database.currencyRates).get();
    expect(rows.single.id, 'old-2');
  });
}
