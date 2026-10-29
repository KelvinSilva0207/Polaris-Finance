import 'package:flutter/material.dart';

enum AccountType {
  bank('Banco', Icons.account_balance_outlined),
  wallet('Billetera', Icons.account_balance_wallet_outlined),
  crypto('Cripto', Icons.currency_bitcoin),
  cash('Efectivo', Icons.payments_outlined),
  other('Otro', Icons.more_horiz);

  const AccountType(this.label, this.icon);

  final String label;
  final IconData icon;

  static AccountType fromStorage(String? value) => AccountType.values
      .firstWhere((e) => e.name == value, orElse: () => AccountType.other);
}

enum TransactionType {
  income('Ingreso'),
  expense('Egreso'),
  transfer('Transferencia'),
  pagoMovil('Pago Móvil');

  const TransactionType(this.label);

  final String label;

  static TransactionType fromStorage(String? value) =>
      TransactionType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TransactionType.expense,
      );
}

enum RateProvider {
  bcv('BCV', 'Banco Central de Venezuela'),
  binance('Binance P2P', 'Tasa P2P USD/VES'),
  manual('Manual', 'Tasa definida por el usuario');

  const RateProvider(this.label, this.description);

  final String label;
  final String description;

  static RateProvider fromStorage(String? value) => RateProvider.values
      .firstWhere((e) => e.name == value, orElse: () => RateProvider.bcv);
}

/// Tipos de transacción a los que aplica una regla de comisión, serializados
/// como una lista separada por comas.
const _feeRuleTypeSeparator = ',';

/// Serializa los tipos a los que aplica una regla de comisión.
String encodeFeeRuleTypes(Iterable<TransactionType> types) =>
    types.map((t) => t.name).join(_feeRuleTypeSeparator);

/// Lee los tipos a los que aplica una regla de comisión. Si el valor está
/// vacío o es desconocido, se asume que aplica a los tipos de salida de
/// dinero (egreso, pago móvil y transferencia).
Set<TransactionType> decodeFeeRuleTypes(String? value) {
  final names = (value ?? '')
      .split(_feeRuleTypeSeparator)
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();
  if (names.isEmpty) {
    return {
      TransactionType.expense,
      TransactionType.pagoMovil,
      TransactionType.transfer,
    };
  }
  final types = <TransactionType>{};
  for (final name in names) {
    final match = TransactionType.values.where((t) => t.name == name);
    if (match.isNotEmpty) types.add(match.first);
  }
  return types.isEmpty
      ? {
          TransactionType.expense,
          TransactionType.pagoMovil,
          TransactionType.transfer,
        }
      : types;
}

/// Tipos de transacción que admiten comisión por defecto.
///
/// Las comisiones bancarias (pago móvil) solo se descuentan cuando el
/// movimiento es explícitamente de tipo [TransactionType.pagoMovil]. Nunca se
/// aplican a egresos generales ni a transferencias.
const defaultFeeRuleTypes = <TransactionType>[TransactionType.pagoMovil];

/// Como se calcula la comisión de una regla.
///
/// * [simple]: monto fijo + porcentaje sobre el monto de la operación.
/// * [tiered]: por tramos, como el cobro del Banco de Venezuela en pago
///   móvil: un monto fijo por debajo de un umbral y un porcentaje a partir
///   de ese umbral.
enum FeeType {
  simple('Simple', 'Monto fijo + % sobre el monto'),
  tiered('Por tramos', 'Monto fijo hasta un límite y % a partir del límite');

  const FeeType(this.label, this.description);

  final String label;
  final String description;

  static FeeType fromStorage(String? value) => FeeType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => FeeType.simple,
  );
}

enum LoanType {
  debt('Debo', Icons.trending_down),
  lend('Me deben', Icons.trending_up);

  const LoanType(this.label, this.icon);

  final String label;
  final IconData icon;

  static LoanType fromStorage(String? value) => LoanType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => LoanType.debt,
  );
}
