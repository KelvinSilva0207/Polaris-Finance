import 'package:drift/drift.dart';

import '../models/enums.dart';
import 'app_database.dart';

class SeedCategory {
  const SeedCategory(this.name, this.icon, this.colorValue, this.isIncome, this.sortOrder);

  final String name;
  final String icon;
  final int colorValue;
  final bool isIncome;
  final int sortOrder;
}

const builtInCategories = <SeedCategory>[
  SeedCategory('Salario', 'payments', 0xFF4CAF50, true, 1),
  SeedCategory('Freelance', 'work_outline', 0xFF66BB6A, true, 2),
  SeedCategory('Negocio', 'storefront', 0xFF43A047, true, 3),
  SeedCategory('Ventas', 'sell', 0xFF81C784, true, 4),
  SeedCategory('Regalos', 'card_giftcard', 0xFFA5D6A7, true, 5),
  SeedCategory('Comida', 'restaurant', 0xFFEF5350, false, 1),
  SeedCategory('Mercado', 'shopping_cart', 0xFFE53935, false, 2),
  SeedCategory('Transporte', 'directions_car', 0xFF42A5F5, false, 3),
  SeedCategory('Gasolina', 'local_gas_station', 0xFF1E88E5, false, 4),
  SeedCategory('Vivienda', 'home', 0xFFAB47BC, false, 5),
  SeedCategory('Servicios', 'receipt_long', 0xFFFF7043, false, 6),
  SeedCategory('Salud', 'local_hospital', 0xFFEC407A, false, 7),
  SeedCategory('Educación', 'school', 0xFF8D6E63, false, 8),
  SeedCategory('Entretenimiento', 'movie', 0xFFFFA726, false, 9),
  SeedCategory('Compras', 'shopping_bag', 0xFF26A69A, false, 10),
  SeedCategory('Ahorro', 'savings', 0xFF7E57C2, false, 11),
  SeedCategory('Otros', 'more_horiz', 0xFF78909C, false, 12),
];

class SeedInstitution {
  const SeedInstitution(this.name, this.type, this.currency, this.colorValue, this.icon);

  final String name;
  final AccountType type;
  final String currency;
  final int colorValue;
  final String icon;
}

const venezuelaInstitutions = <SeedInstitution>[
  SeedInstitution('Banco de Venezuela', AccountType.bank, 'VES', 0xFF0D47A1, 'account_balance'),
  SeedInstitution('Mercantil', AccountType.bank, 'VES', 0xFFB71C1C, 'account_balance'),
  SeedInstitution('Banesco', AccountType.bank, 'VES', 0xFF1B5E20, 'account_balance'),
  SeedInstitution('Provincial', AccountType.bank, 'VES', 0xFF4A148C, 'account_balance'),
  SeedInstitution('BNC', AccountType.bank, 'VES', 0xFF00695C, 'account_balance'),
  SeedInstitution('Banco Exterior', AccountType.bank, 'VES', 0xFFE65100, 'account_balance'),
  SeedInstitution('Binance', AccountType.crypto, 'USDT', 0xFFF9A825, 'currency_bitcoin'),
  SeedInstitution('PayPal', AccountType.wallet, 'USD', 0xFF003087, 'account_balance_wallet'),
  SeedInstitution('Zinli', AccountType.wallet, 'USD', 0xFFAD1457, 'account_balance_wallet'),
  SeedInstitution('Efectivo (VES)', AccountType.cash, 'VES', 0xFF33691E, 'cash'),
  SeedInstitution('Efectivo (USD)', AccountType.cash, 'USD', 0xFF004D40, 'cash'),
];

Future<void> seedDatabase(AppDatabase database) async {
  final existing = await database.select(database.categories).get();
  if (existing.isNotEmpty) return;
  await database.batch((batch) {
    batch.insertAll(database.categories, [
      for (final category in builtInCategories)
        CategoriesCompanion.insert(
          id: 'seed_${_slug(category.name)}',
          name: category.name,
          icon: category.icon,
          colorValue: category.colorValue,
          isBuiltIn: const Value(true),
          isIncome: Value(category.isIncome),
          sortOrder: Value(category.sortOrder),
        ),
    ]);
  });
}

String _slug(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');