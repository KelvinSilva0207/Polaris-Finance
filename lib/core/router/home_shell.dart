import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/database_providers.dart';
import '../feature_module.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({
    super.key,
    required this.modules,
    required this.currentPath,
    required this.child,
  });

  final List<FeatureModule> modules;
  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(seedProvider);

    final selectedIndex = modules.indexWhere((m) => m.route == currentPath);
    final index = selectedIndex < 0 ? 0 : selectedIndex;

    final railDestinations = [
      for (final module in modules)
        NavigationRailDestination(
          icon: Icon(module.icon),
          label: Text(module.label),
        ),
    ];

    final barDestinations = [
      for (final module in modules)
        NavigationDestination(
          icon: Icon(module.icon),
          label: module.label,
          tooltip: module.label,
        ),
    ];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Row(
            children: [
              if (wide) ...[
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => context.go(modules[i].route),
                  labelType: NavigationRailLabelType.all,
                  destinations: railDestinations,
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(child: child),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) return const SizedBox.shrink();
          return NavigationBar(
            selectedIndex: index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: (i) => context.go(modules[i].route),
            destinations: barDestinations,
          );
        },
      ),
    );
  }
}