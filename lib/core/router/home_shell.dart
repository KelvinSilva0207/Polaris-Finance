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
          icon: Icon(module.icon, size: 28),
          label: Text(module.label),
        ),
    ];

    const maxBarItems = 4;
    final primaryModules = modules.take(maxBarItems).toList();
    final overflowModules = modules.skip(maxBarItems).toList();

    final barDestinations = [
      for (final module in primaryModules)
        NavigationDestination(
          icon: Icon(module.icon, size: 26),
          label: module.label,
          tooltip: module.label,
        ),
      if (overflowModules.isNotEmpty)
        const NavigationDestination(
          icon: Icon(Icons.more_horiz, size: 26),
          label: 'Más',
          tooltip: 'Más secciones',
        ),
    ];

    final primaryIndex = primaryModules.indexWhere(
      (m) => m.route == currentPath,
    );
    final barIndex = primaryIndex >= 0
        ? primaryIndex
        : (overflowModules.isEmpty ? index : primaryModules.length);

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
            selectedIndex: barIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: (i) {
              if (i < primaryModules.length) {
                context.go(primaryModules[i].route);
              } else {
                _openMore(context, overflowModules);
              }
            },
            destinations: barDestinations,
          );
        },
      ),
    );
  }

  Future<void> _openMore(
    BuildContext context,
    List<FeatureModule> overflowModules,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final module in overflowModules)
              ListTile(
                leading: Icon(module.icon, size: 26),
                title: Text(module.label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(module.route);
                },
              ),
          ],
        ),
      ),
    );
  }
}
