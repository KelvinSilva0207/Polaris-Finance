import '../../data/database/app_database.dart';
import 'schedule.dart';

enum CommitmentKind { service, loan }

class Commitment {
  const Commitment({
    required this.label,
    required this.amountUsd,
    required this.date,
    required this.kind,
  });

  final String label;

  /// Importe comprometido convertido a USD (moneda de referencia).
  final double amountUsd;
  final DateTime date;
  final CommitmentKind kind;
}

class ForecastResult {
  const ForecastResult({
    required this.currentUsd,
    required this.commitments,
    required this.skippedCurrencies,
  });

  /// Saldo total actual de las cuentas en USD.
  final double currentUsd;

  /// Compromisos (servicios y préstamos) dentro del horizonte, ordenados.
  final List<Commitment> commitments;

  /// Monedas para las que no hubo tasa y quedaron fuera del cálculo.
  final Set<String> skippedCurrencies;

  double get committedUsd =>
      commitments.fold(0.0, (sum, item) => sum + item.amountUsd);

  double get projectedUsd => currentUsd - committedUsd;
}

/// Proyecta el saldo a [withinDays] días vista: resta al saldo actual los
/// servicios recurrentes y préstamos con vencimiento dentro del horizonte.
///
/// [toUsd] convierte un importe de su moneda a USD (o null si no hay tasa).
ForecastResult buildForecast({
  required double currentUsd,
  required List<RecurringService> services,
  required List<Loan> loans,
  required DateTime from,
  required double? Function(double amount, String currency) toUsd,
  int withinDays = 30,
}) {
  final horizon = from.add(Duration(days: withinDays));
  final commitments = <Commitment>[];
  final skipped = <String>{};

  for (final service in services) {
    if (!service.isActive) continue;
    final due = nextServiceDue(service.dayOfMonth, from, service.lastPaidDate);
    if (due.isAfter(horizon)) continue;
    final usd = toUsd(service.amount, service.currency);
    if (usd == null) {
      skipped.add(service.currency);
      continue;
    }
    commitments.add(
      Commitment(
        label: service.name,
        amountUsd: usd,
        date: due,
        kind: CommitmentKind.service,
      ),
    );
  }

  for (final loan in loans) {
    if (!loan.isActive || loan.dueDate == null) continue;
    final due = loan.dueDate!;
    if (due.isBefore(from) || due.isAfter(horizon)) continue;
    final outstanding = loan.principal - loan.paidAmount;
    if (outstanding <= 0) continue;
    final usd = toUsd(outstanding, loan.currency);
    if (usd == null) {
      skipped.add(loan.currency);
      continue;
    }
    commitments.add(
      Commitment(
        label: loan.name,
        amountUsd: usd,
        date: due,
        kind: CommitmentKind.loan,
      ),
    );
  }

  commitments.sort((a, b) => a.date.compareTo(b.date));
  return ForecastResult(
    currentUsd: currentUsd,
    commitments: commitments,
    skippedCurrencies: skipped,
  );
}
