/// Hora del día en que se programan los recordatorios de pago.
const reminderHour = 9;

/// Fecha del día [day] de un mes (ajustando al último día si no existe) a la
/// hora de recordatorios.
DateTime dateInMonth(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final safeDay = day > lastDay ? lastDay : day;
  return DateTime(year, month, safeDay, reminderHour);
}

/// Próximo vencimiento de un servicio recurrente a partir de [today].
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
