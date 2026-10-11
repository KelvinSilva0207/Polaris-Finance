import '../database/app_database.dart';

/// Sin soporte de notificaciones programadas en esta plataforma (web).
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  Future<bool> requestPermission() async => false;
}

Future<void> syncPaymentReminders({
  required List<RecurringService> services,
  required List<Loan> loans,
  required bool enabled,
}) async {}
