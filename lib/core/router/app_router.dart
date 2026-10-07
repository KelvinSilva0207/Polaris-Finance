import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/accounts_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/loans/loans_screen.dart';
import '../../features/rates/rates_screen.dart';
import '../../features/services/services_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../feature_module.dart';
import '../settings/app_settings.dart';
import 'home_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final modules = ref.watch(appSettingsProvider).activeModules;

  Widget screenFor(FeatureModule module) {
    return switch (module.id) {
      'transactions' => const TransactionsScreen(),
      'accounts' => const AccountsScreen(),
      'rates' => const RatesScreen(),
      'loans' => const LoansScreen(),
      'goals' => const GoalsScreen(),
      'services' => const ServicesScreen(),
      'analytics' => const AnalyticsScreen(),
      'settings' => const SettingsScreen(),
      _ => const DashboardScreen(),
    };
  }

  return GoRouter(
    initialLocation: '/dashboard',
    errorBuilder: (context, state) => const DashboardScreen(),
    routes: [
      ShellRoute(
        builder: (context, state, child) => HomeShell(
          modules: modules,
          currentPath: state.uri.path,
          child: child,
        ),
        routes: [
          for (final module in modules)
            GoRoute(
              path: module.route,
              builder: (context, state) => screenFor(module),
            ),
        ],
      ),
      GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
    ],
  );
});