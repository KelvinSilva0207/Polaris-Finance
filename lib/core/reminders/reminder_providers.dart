import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_providers.dart';
import '../../data/services/reminder_service.dart';
import '../settings/app_settings.dart';

/// Reprograma los recordatorios cada vez que cambian los ajustes, los servicios
/// o los préstamos. Mantenerlo observado (watch) mientras la app está abierta.
final reminderSyncProvider = FutureProvider<void>((ref) async {
  final enabled = ref.watch(
    appSettingsProvider.select((s) => s.remindersEnabled),
  );
  final services = await ref.watch(servicesProvider.future);
  final loans = await ref.watch(loansProvider.future);
  await syncPaymentReminders(services: services, loans: loans, enabled: enabled);
});
