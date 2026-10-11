import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feature_module.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/biometric_service.dart';
import '../../core/settings/app_settings.dart';
import '../../data/models/enums.dart';
import '../../data/services/reminder_service.dart';
import '../../shared/widgets/brand_logo.dart';
import '../categories/categories_screen.dart';
import '../fees/fee_rules_screen.dart';
import '../lock/pin_setup_screen.dart';
import 'backup_screen.dart';

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

const _themeLabels = <ThemeMode, String>{
  ThemeMode.system: 'Sistema',
  ThemeMode.light: 'Claro',
  ThemeMode.dark: 'Oscuro',
};

const _themeIcons = <ThemeMode, IconData>{
  ThemeMode.system: Icons.brightness_auto_outlined,
  ThemeMode.light: Icons.light_mode_outlined,
  ThemeMode.dark: Icons.dark_mode_outlined,
};

IconData _providerIcon(RateProvider provider) {
  return switch (provider) {
    RateProvider.bcv => Icons.account_balance_outlined,
    RateProvider.binance => Icons.currency_exchange,
    RateProvider.manual => Icons.edit_outlined,
  };
}

Future<void> _toggleReminders(
  BuildContext context,
  AppSettingsController controller,
  bool value,
) async {
  if (value) {
    final granted = await ReminderService.instance.requestPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Activa las notificaciones en los ajustes del sistema',
            ),
          ),
        );
      }
      return;
    }
  }
  await controller.setRemindersEnabled(value);
}

Future<void> _toggleLock(
  BuildContext context,
  AppLockController controller,
  bool value,
) async {
  if (value) {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const PinSetupScreen()),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Desactivar bloqueo'),
      content: const Text('¿Quitar el PIN de Polaris Finance?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Desactivar'),
        ),
      ],
    ),
  );
  if (confirmed == true) await controller.disable();
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final lock = ref.watch(appLockProvider);
    final lockController = ref.read(appLockProvider.notifier);
    final biometricAvailable =
        ref.watch(biometricAvailableProvider).asData?.value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: BrandLogo(height: 64)),
          const SizedBox(height: 8),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tema', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      for (final mode in ThemeMode.values)
                        ButtonSegment<ThemeMode>(
                          value: mode,
                          label: Text(_themeLabels[mode]!),
                          icon: Icon(_themeIcons[mode], size: 18),
                        ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) =>
                        controller.setThemeMode(selection.first),
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
          const _SectionHeader('Seguridad'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.pin_outlined),
                  title: const Text('Bloqueo con PIN'),
                  subtitle: const Text('Pide un PIN al abrir la app'),
                  value: lock.enabled,
                  onChanged: (value) => _toggleLock(context, lockController, value),
                ),
                if (lock.enabled) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Desbloqueo biométrico'),
                    subtitle: Text(
                      biometricAvailable
                          ? 'Usa tu huella o rostro'
                          : 'No disponible en este dispositivo',
                    ),
                    value: lock.biometricEnabled,
                    onChanged: biometricAvailable
                        ? lockController.setBiometricEnabled
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Notificaciones'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Recordatorios de pagos'),
              subtitle: const Text(
                'Avisa cuando vence un servicio o préstamo',
              ),
              value: settings.remindersEnabled,
              onChanged: (value) =>
                  _toggleReminders(context, controller, value),
            ),
          ),
          const Divider(),
          const _SectionHeader('Datos'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Categorías'),
                  subtitle: const Text('Gestiona ingresos y egresos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const CategoriesScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: const Text('Comisiones'),
                  subtitle: const Text(
                    'Reglas de comisión aplicables a movimientos',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const FeeRulesScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Copia de seguridad'),
                  subtitle: const Text('Respalda y restaura tus datos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const BackupScreen(),
                    ),
                  ),
                ),
              ],
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
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

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
