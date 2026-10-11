import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database/app_database.dart';

const _channelId = 'payment_reminders';
const _channelName = 'Recordatorios de pagos';
const _channelDescription = 'Avisos de servicios y préstamos por vencer';
const _reminderHour = 9;

/// Envuelve `flutter_local_notifications` para programar recordatorios de pagos.
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Sin zona local usamos UTC; el recordatorio sigue programándose.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    final settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      windows: const WindowsInitializationSettings(
        appName: 'Polaris Finance',
        appUserModelId: 'com.polarisfinance.polaris_finance',
        guid: 'b6f0e2c2-1d9a-4a3f-9c1e-2f7a5d3b8c10',
      ),
    );
    try {
      await _plugin.initialize(settings: settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
    } catch (_) {
      // Plataformas sin soporte de notificaciones programadas.
    }
    _initialized = true;
  }

  /// Pide permiso de notificaciones (Android 13+). Devuelve si quedó concedido.
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _cancelAllPending() async {
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (_) {
      try {
        await _plugin.cancelAll();
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // ignore
    }
  }
}

/// Recalcula y reprograma los recordatorios de servicios y préstamos.
Future<void> syncPaymentReminders({
  required List<RecurringService> services,
  required List<Loan> loans,
  required bool enabled,
}) async {
  final service = ReminderService.instance;
  await service._ensureInitialized();
  await service._cancelAllPending();
  if (!enabled) return;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (final s in services) {
    if (!s.isActive) continue;
    final due = nextServiceDue(s.dayOfMonth, today, s.lastPaidDate);
    await service._schedule(
      id: _stableId('service:${s.id}:${_dayKey(due)}'),
      when: due,
      title: 'Pago próximo: ${s.name}',
      body:
          'Vence el ${_formatDate(due)} · ${_formatAmount(s.amount)} ${s.currency}',
    );
  }

  for (final loan in loans) {
    final dueDate = loan.dueDate;
    if (!loan.isActive || dueDate == null) continue;
    final due = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      _reminderHour,
    );
    if (due.isBefore(today)) continue;
    if (due.difference(today).inDays > 180) continue;
    await service._schedule(
      id: _stableId('loan:${loan.id}:${_dayKey(due)}'),
      when: due,
      title: 'Préstamo por vencer: ${loan.name}',
      body: 'Vence el ${_formatDate(due)} · saldo pendiente',
    );
  }
}

/// Fecha (mismo mes o el siguiente) del día [day] de un mes, a las 9:00.
DateTime dateInMonth(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final safeDay = day > lastDay ? lastDay : day;
  return DateTime(year, month, safeDay, _reminderHour);
}

/// Próximo vencimiento de un servicio recurrente a partir de hoy.
DateTime nextServiceDue(int day, DateTime today, DateTime? lastPaid) {
  var due = dateInMonth(today.year, today.month, day);
  if (lastPaid != null) {
    final paid = DateTime(lastPaid.year, lastPaid.month, lastPaid.day);
    if (!due.isBefore(paid)) {
      due = dateInMonth(today.year, today.month + 1, day);
    }
  }
  if (due.isBefore(today)) {
    due = dateInMonth(today.year, today.month + 1, day);
  }
  return due;
}

String _dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime date) => DateFormat('d/M/yyyy').format(date);

String _formatAmount(double amount) =>
    NumberFormat('#,##0.00', 'es').format(amount);

int _stableId(String key) {
  var hash = 0x811c9dc5;
  for (final code in key.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
