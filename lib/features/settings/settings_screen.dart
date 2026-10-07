import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feature_module.dart';
import '../../core/settings/app_settings.dart';
import '../../data/models/enums.dart';

const _accentOptions = <Color>[
  Color(0xFF9C6BFF),
  Color(0xFF00BCD4),
  Color(0xFF26A69A),
  Color(0xFFFFB300),
  Color(0xFFFF7043),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFEC407A),
];

IconData _providerIcon(RateProvider provider) {
  return switch (provider) {
    RateProvider.bcv => Icons.account_balance_outlined,
    RateProvider.binance => Icons.currency_exchange,
    RateProvider.manual => Icons.edit_outlined,
  };
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader('Aspecto'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in _accentOptions)
                    _ColorDot(
                      color: color,
                      selected: settings.accentColorValue == color.toARGB32(),
                      onTap: () => controller.setAccentColor(color),
                    ),
                ],
              ),
            ),
          ),
          const Divider(),
          const _SectionHeader('Moneda de referencia'),
          Card(
            child: Column(
              children: [
                for (final provider in RateProvider.values)
                  ListTile(
                    leading: Icon(_providerIcon(provider)),
                    title: Text(provider.label),
                    subtitle: Text(provider.description),
                    trailing: settings.referenceProvider == provider
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => controller.setReferenceProvider(provider),
                  ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Privacidad'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.visibility_off_outlined),
              title: const Text('Ocultar montos'),
              subtitle: const Text('Difumina los saldos dentro de la app'),
              value: settings.hideBalances,
              onChanged: controller.setHideBalances,
            ),
          ),
          const Divider(),
          const _SectionHeader('Módulos activos'),
          Card(
            child: Column(
              children: [
                for (final module in FeatureModule.all)
                  module.core
                      ? ListTile(
                          leading: Icon(module.icon),
                          title: Text(module.label),
                          subtitle: const Text('Siempre activo'),
                          trailing: const Icon(Icons.lock_outline, size: 18),
                        )
                      : SwitchListTile(
                          secondary: Icon(module.icon),
                          title: Text(module.label),
                          value: settings.isEnabled(module.id),
                          onChanged: (_) => controller.toggleModule(module.id),
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            width: selected ? 3 : 1,
            color: selected ? Colors.white : Colors.white24,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}