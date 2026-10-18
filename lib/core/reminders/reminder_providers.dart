import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_providers.dart';
import '../../data/services/reminder_service.dart';
import '../settings/app_settings.dart';

/// Reprograma los recordatorios cada vez que cambian los ajustes, los servicios
/// o los préstamos. Mantenerlo observado (watch) mientras la app está abierta.
final reminderSyncProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(appSettingsProvider);
  final services = await ref.watch(servicesProvider.future);
  final loans = await ref.watch(loansProvider.future);
  await syncPaymentReminders(
    services: services,
    loans: loans,
    enabled: settings.remindersEnabled,
    daysBefore: settings.reminderDaysBefore,
    hour: settings.reminderHour,
    notifyServices: settings.notifyServices,
    notifyLoans: settings.notifyLoans,
  );
});
