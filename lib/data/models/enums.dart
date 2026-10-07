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
  transfer('Transferencia');

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

enum FeeType {
  fixed,
  percent,
  mixed;
}

enum LoanType {
  debt('Debo', Icons.trending_down),
  lend('Me deben', Icons.trending_up);

  const LoanType(this.label, this.icon);

  final String label;
  final IconData icon;

  static LoanType fromStorage(String? value) =>
      LoanType.values.firstWhere((e) => e.name == value, orElse: () => LoanType.debt);
}