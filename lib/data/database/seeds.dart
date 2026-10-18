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
  // Ingresos
  SeedCategory('Salario', 'payments', 0xFF4CAF50, true, 1),
  SeedCategory('Freelance', 'work_outline', 0xFF66BB6A, true, 2),
  SeedCategory('Negocio', 'storefront', 0xFF43A047, true, 3),
  SeedCategory('Ventas', 'sell', 0xFF81C784, true, 4),
  SeedCategory('Regalos', 'card_giftcard', 0xFFA5D6A7, true, 5),
  SeedCategory('Quincena', 'payments', 0xFF2E7D32, true, 6),
  SeedCategory('Bonos y aguinaldos', 'celebration', 0xFF00695C, true, 7),
  SeedCategory('Comisiones', 'sell', 0xFF1B5E20, true, 8),
  SeedCategory('Intereses', 'savings', 0xFF33691E, true, 9),
  SeedCategory('Dividendos', 'trending_up', 0xFF004D40, true, 10),
  SeedCategory('Alquiler cobrado', 'home', 0xFF00838F, true, 11),
  SeedCategory('Reembolsos', 'receipt_long', 0xFF01579B, true, 12),
  SeedCategory('Regalías', 'attach_money', 0xFF4527A0, true, 13),
  SeedCategory('Subsidios', 'account_balance', 0xFF6A1B9A, true, 14),
  SeedCategory('Herencia', 'card_giftcard', 0xFF4E342E, true, 15),
  SeedCategory('Otros ingresos', 'more_horiz', 0xFF37474F, true, 16),
  // Egresos
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
  SeedCategory('Delivery y cafeterías', 'restaurant', 0xFFFF8A65, false, 13),
  SeedCategory('Farmacia', 'local_hospital', 0xFFF06292, false, 14),
  SeedCategory('Gimnasio y deporte', 'fitness_center', 0xFF00796B, false, 15),
  SeedCategory('Belleza', 'favorite', 0xFFC2185B, false, 16),
  SeedCategory('Ropa y calzado', 'shopping_bag', 0xFF26C6DA, false, 17),
  SeedCategory('Hogar y muebles', 'home', 0xFF5D4037, false, 18),
  SeedCategory('Alquiler', 'home', 0xFF5C6BC0, false, 19),
  SeedCategory('Internet y telefonía', 'phone_iphone', 0xFF0277BD, false, 20),
  SeedCategory('Tecnología', 'laptop', 0xFF039BE5, false, 21),
  SeedCategory('Streaming', 'movie', 0xFFD32F2F, false, 22),
  SeedCategory('Suscripciones', 'receipt_long', 0xFF7B1FA2, false, 23),
  SeedCategory('Seguros', 'account_balance', 0xFF455A64, false, 24),
  SeedCategory('Impuestos', 'receipt_long', 0xFF546E7A, false, 25),
  SeedCategory('Comisiones bancarias', 'account_balance', 0xFF263238, false, 26),
  SeedCategory('Viajes', 'flight', 0xFF00ACC1, false, 27),
  SeedCategory('Vacaciones', 'beach_access', 0xFF0097A7, false, 28),
  SeedCategory('Mascotas', 'pets', 0xFFA1887F, false, 29),
  SeedCategory('Libros', 'menu_book', 0xFF6D4C41, false, 30),
  SeedCategory('Donaciones', 'favorite', 0xFFE91E63, false, 31),
  SeedCategory('Cuidado de niños', 'celebration', 0xFFFFB300, false, 32),
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
  await _insertBuiltInCategories(database, builtInCategories);
}

/// Reinserta, de forma idempotente, las categorías sugeridas que falten.
/// Devuelve cuántas categorías se restauraron.
Future<int> restoreBuiltInCategories(AppDatabase database) async {
  final existing = await database.select(database.categories).get();
  final existingIds = existing.map((category) => category.id).toSet();
  final missing = [
    for (final category in builtInCategories)
      if (!existingIds.contains('seed_${_slug(category.name)}')) category,
  ];
  if (missing.isEmpty) return 0;
  await _insertBuiltInCategories(database, missing);
  return missing.length;
}

Future<void> _insertBuiltInCategories(
  AppDatabase database,
  List<SeedCategory> categories,
) {
  return database.batch((batch) {
    batch.insertAll(database.categories, [
      for (final category in categories)
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