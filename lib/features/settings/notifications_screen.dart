import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../data/services/reminder_service.dart';

const _leadOptions = <(int, String)>[
  (0, 'El mismo día'),
  (1, '1 día antes'),
  (2, '2 días antes'),
  (3, '3 días antes'),
  (5, '5 días antes'),
  (7, '1 semana antes'),
];

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _setEnabled(
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

  Future<void> _pickTime(
    BuildContext context,
    AppSettingsController controller,
    int hour,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: 0),
      helpText: 'Hora del recordatorio',
    );
    if (picked != null) await controller.setReminderHour(picked.hour);
  }

  String _timeLabel(int hour) {
    final period = hour < 12 ? 'a. m.' : 'p. m.';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:00 $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);
    final leadLabel = _leadOptions
        .firstWhere(
          (option) => option.$1 == settings.reminderDaysBefore,
          orElse: () => (
            settings.reminderDaysBefore,
            '${settings.reminderDaysBefore} días antes',
          ),
        )
        .$2;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Recordatorios de pagos'),
              subtitle: const Text(
                'Avisa cuando vence un servicio o una deuda',
              ),
              value: settings.remindersEnabled,
              onChanged: (value) => _setEnabled(context, controller, value),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.system_update_outlined),
              title: const Text('Novedades de la app'),
              subtitle: const Text(
                'Avisa cuando hay una nueva versión disponible',
              ),
              value: settings.notifyUpdates,
              onChanged: controller.setNotifyUpdates,
            ),
          ),
          const SizedBox(height: 8),
          if (!settings.remindersEnabled)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Activa los recordatorios para personalizar cuándo y sobre '
                  'qué quieres que te avisemos.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (settings.remindersEnabled) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: _SectionLabel('Frecuencia y horario'),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_repeat_outlined, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Avisar con anticipación',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(leadLabel, style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in const [0, 1, 2, 3, 5, 7])
                          ChoiceChip(
                            label: Text(
                              option == 0
                                  ? 'Mismo día'
                                  : '$option día${option == 1 ? '' : 's'}',
                            ),
                            selected: settings.reminderDaysBefore == option,
                            onSelected: (_) =>
                                controller.setReminderDaysBefore(option),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Días antes del vencimiento',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Divider(height: 28),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Hora del recordatorio'),
                      trailing: Text(
                        _timeLabel(settings.reminderHour),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onTap: () =>
                          _pickTime(context, controller, settings.reminderHour),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: _SectionLabel('Qué quieres recordar'),
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Servicios y suscripciones'),
                    subtitle: const Text(
                      'Internet, telefonía, streaming, etc.',
                    ),
                    value: settings.notifyServices,
                    onChanged: controller.setNotifyServices,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.account_balance_outlined),
                    title: const Text('Préstamos y deudas'),
                    subtitle: const Text('Pagos y vencimientos pendientes'),
                    value: settings.notifyLoans,
                    onChanged: controller.setNotifyLoans,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await ReminderService.instance.requestPermission();
                await ReminderService.instance.showTestNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notificación de prueba enviada'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.notifications_none),
              label: const Text('Enviar notificación de prueba'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    );
  }
}
