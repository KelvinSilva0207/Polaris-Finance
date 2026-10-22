import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/accounts_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/loans/loans_screen.dart';
import '../../features/rates/rates_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/services/services_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../feature_module.dart';
import 'home_shell.dart';

/// Transición de página propia: fundido + deslizamiento corto.
Page<T> _fadeSlidePage<T>({
  required GoRouterState state,
  required Widget child,
  Offset beginOffset = const Offset(0.04, 0),
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// El router es estable: registra todas las rutas y nunca se recrea por un
/// cambio de ajustes (módulos, tema, tipografía...). [HomeShell] decide qué
/// destinos mostrar y redirige al inicio si el módulo actual se desactiva.
final appRouterProvider = Provider<GoRouter>((ref) {
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
        builder: (context, state, child) =>
            HomeShell(currentPath: state.uri.path, child: child),
        routes: [
          for (final module in FeatureModule.all)
            GoRoute(
              path: module.route,
              pageBuilder: (context, state) =>
                  _fadeSlidePage(state: state, child: screenFor(module)),
            ),
        ],
      ),
      GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
    ],
  );
});
