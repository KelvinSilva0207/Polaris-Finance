import 'package:flutter/material.dart';

class FeatureModule {
  const FeatureModule({
    required this.id,
    required this.label,
    required this.route,
    required this.icon,
    this.core = false,
  });

  final String id;
  final String label;
  final String route;
  final IconData icon;
  final bool core;

  static const dashboard = FeatureModule(
    id: 'dashboard',
    label: 'Inicio',
    route: '/dashboard',
    icon: Icons.home_outlined,
    core: true,
  );

  static const transactions = FeatureModule(
    id: 'transactions',
    label: 'Movimientos',
    route: '/transactions',
    icon: Icons.swap_horiz_outlined,
    core: true,
  );

  static const accounts = FeatureModule(
    id: 'accounts',
    label: 'Cuentas',
    route: '/accounts',
    icon: Icons.account_balance_wallet_outlined,
    core: true,
  );

  static const rates = FeatureModule(
    id: 'rates',
    label: 'Monedas',
    route: '/rates',
    icon: Icons.currency_exchange_outlined,
    core: true,
  );

  static const loans = FeatureModule(
    id: 'loans',
    label: 'Préstamos',
    route: '/loans',
    icon: Icons.request_quote_outlined,
  );

  static const goals = FeatureModule(
    id: 'goals',
    label: 'Metas',
    route: '/goals',
    icon: Icons.savings_outlined,
  );

  static const services = FeatureModule(
    id: 'services',
    label: 'Servicios',
    route: '/services',
    icon: Icons.receipt_long_outlined,
  );

  static const analytics = FeatureModule(
    id: 'analytics',
    label: 'Analítica',
    route: '/analytics',
    icon: Icons.insert_chart_outlined,
  );

  static const settings = FeatureModule(
    id: 'settings',
    label: 'Ajustes',
    route: '/settings',
    icon: Icons.settings_outlined,
    core: true,
  );

  /// Orden de la navegación. Los cuatro primeros aparecen en la barra
  /// inferior; el resto se agrupa en «Más».
  ///
  /// «Analítica» va antes que «Cuentas» porque se consulta mucho más a menudo
  /// que la creación de cuentas, que ya tiene su propio botón dentro de la
  /// sección de cuentas.
  static const all = <FeatureModule>[
    dashboard,
    transactions,
    analytics,
    rates,
    accounts,
    loans,
    goals,
    services,
    settings,
  ];

  static const allIds = <String>[
    'dashboard',
    'transactions',
    'analytics',
    'rates',
    'accounts',
    'loans',
    'goals',
    'services',
    'settings',
  ];
}
