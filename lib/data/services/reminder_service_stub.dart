import '../database/app_database.dart';

/// Sin soporte de notificaciones programadas en esta plataforma (web).
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  Future<bool> requestPermission() async => false;

  Future<void> showTestNotification() async {}
}

Future<void> syncPaymentReminders({
  required List<RecurringService> services,
  required List<Loan> loans,
  required bool enabled,
  int daysBefore = 1,
  int hour = 9,
  bool notifyServices = true,
  bool notifyLoans = true,
}) async {}
