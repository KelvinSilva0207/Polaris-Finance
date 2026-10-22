import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database/app_database.dart';
import '../../shared/utils/schedule.dart';

const _channelId = 'payment_reminders';
const _channelName = 'Recordatorios de pagos';
const _channelDescription = 'Avisos de servicios y préstamos por vencer';

const _updateChannelId = 'app_updates';
const _updateChannelName = 'Actualizaciones';
const _updateChannelDescription = 'Avisos de nuevas versiones de Polaris';

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
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _updateChannelId,
              _updateChannelName,
              description: _updateChannelDescription,
              importance: Importance.defaultImportance,
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

  /// Avisa una sola vez (lo controla quien llama) de que hay una versión nueva.
  Future<void> showUpdateNotification({required String version}) async {
    await _ensureInitialized();
    try {
      await _plugin.show(
        id: 2,
        title: 'Nueva versión disponible',
        body:
            'Polaris Finance $version ya está publicada. Abre Ajustes para '
            'descargarla.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _updateChannelId,
            _updateChannelName,
            channelDescription: _updateChannelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // ignore
    }
  }

  /// Muestra una notificación inmediata de prueba.
  Future<void> showTestNotification() async {
    await _ensureInitialized();
    try {
      await _plugin.show(
        id: 1,
        title: 'Así se verán tus recordatorios',
        body: 'Te avisaremos cuando un servicio o una deuda estén por vencer.',
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
  int daysBefore = 1,
  int hour = reminderHour,
  bool notifyServices = true,
  bool notifyLoans = true,
}) async {
  final service = ReminderService.instance;
  await service._ensureInitialized();
  await service._cancelAllPending();
  if (!enabled) return;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final lead = Duration(days: daysBefore);

  DateTime remindAt(DateTime due) {
    final when = due.subtract(lead);
    return when.isBefore(now) ? now.add(const Duration(minutes: 1)) : when;
  }

  if (notifyServices) {
    for (final s in services) {
      if (!s.isActive) continue;
      final due = nextServiceDue(
        s.dayOfMonth,
        today,
        s.lastPaidDate,
        hour: hour,
      );
      await service._schedule(
        id: _stableId('service:${s.id}:${_dayKey(due)}'),
        when: remindAt(due),
        title: 'Pago próximo: ${s.name}',
        body:
            'Vence el ${_formatDate(due)} · ${_formatAmount(s.amount)} ${s.currency}',
      );
    }
  }

  if (notifyLoans) {
    for (final loan in loans) {
      final dueDate = loan.dueDate;
      if (!loan.isActive || dueDate == null) continue;
      final due = DateTime(dueDate.year, dueDate.month, dueDate.day, hour);
      if (due.isBefore(today)) continue;
      if (due.difference(today).inDays > 180) continue;
      await service._schedule(
        id: _stableId('loan:${loan.id}:${_dayKey(due)}'),
        when: remindAt(due),
        title: 'Préstamo por vencer: ${loan.name}',
        body: 'Vence el ${_formatDate(due)} · saldo pendiente',
      );
    }
  }
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
