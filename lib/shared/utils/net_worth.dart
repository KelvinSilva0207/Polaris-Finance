import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import 'transaction_math.dart';

class NetWorthPoint {
  const NetWorthPoint({
    required this.date,
    required this.assetsUsd,
    required this.liabilitiesUsd,
    required this.skippedCurrencies,
  });

  final DateTime date;

  /// Total de cuentas (más lo que te deben) en USD.
  final double assetsUsd;

  /// Total de deudas propias en USD.
  final double liabilitiesUsd;

  /// Monedas sin tasa que quedaron fuera del cálculo en este punto.
  final Set<String> skippedCurrencies;

  double get netUsd => assetsUsd - liabilitiesUsd;
}

class NetWorthSeries {
  const NetWorthSeries(this.points);

  final List<NetWorthPoint> points;

  bool get isEmpty => points.isEmpty;

  NetWorthPoint? get latest => points.isEmpty ? null : points.last;
  NetWorthPoint? get first => points.isEmpty ? null : points.first;

  /// Cambio absoluto en USD entre el primer y el último punto.
  double get changeUsd => (latest?.netUsd ?? 0) - (first?.netUsd ?? 0);

  /// Cambio porcentual respecto al primer punto (null si no se puede calcular).
  double? get changePercent {
    final start = first?.netUsd ?? 0;
    if (start == 0) return null;
    return changeUsd / start.abs() * 100;
  }
}

/// Tasa USD/VES vigente en [date]: la más reciente con fecha <= [date].
double? rateOnOrBefore(
  List<CurrencyRate> rates,
  DateTime date, {
  required RateProvider provider,
  String rateCode = 'USD/VES',
}) {
  CurrencyRate? best;
  for (final rate in rates) {
    if (rate.rateCode != rateCode || rate.provider != provider.name) continue;
    if (rate.date.isAfter(date)) continue;
    if (best == null || rate.date.isAfter(best.date)) best = rate;
  }
  return best?.rate;
}

/// Construye la serie de patrimonio neto al cierre de cada uno de los últimos
/// [months] meses (más el punto actual). Los activos son los saldos de las
/// cuentas y lo que te deben (préstamos tipo `lend`); los pasivos, lo que debes
/// (préstamos tipo `debt`).
///
/// [vesPerUsdAt] entrega la tasa USD/VES vigente en una fecha (o null si no hay).
/// El avance de un préstamo es aproximado: se usa su saldo pendiente actual.
NetWorthSeries buildNetWorthSeries({
  required List<Transaction> transactions,
  required List<Account> accounts,
  required List<Loan> loans,
  required double? Function(DateTime date) vesPerUsdAt,
  double? eurPerUsd,
  int months = 12,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final points = <NetWorthPoint>[];

  for (var offset = months; offset >= 0; offset--) {
    final monthStart = DateTime(reference.year, reference.month - offset, 1);
    final DateTime pointDate;
    if (offset == 0) {
      pointDate = reference;
    } else {
      pointDate = DateTime(
        monthStart.year,
        monthStart.month + 1,
        1,
      ).subtract(const Duration(days: 1));
    }

    final pastTx = transactions
        .where((transaction) => !transaction.date.isAfter(pointDate))
        .toList();
    final balances = balancesOf(pastTx, accounts: accounts);
    final rate = vesPerUsdAt(pointDate);

    final skipped = <String>{};
    var assets = 0.0;

    for (final account in accounts) {
      final balance = balances[account.id] ?? account.openingBalance;
      if (balance == 0) continue;
      final usd = _toUsd(balance, account.currency, rate, eurPerUsd);
      if (usd == null) {
        skipped.add(account.currency);
      } else {
        assets += usd;
      }
    }

    var liabilities = 0.0;
    for (final loan in loans) {
      if (loan.startDate.isAfter(pointDate)) continue;
      final outstanding = loan.principal - loan.paidAmount;
      if (outstanding <= 0) continue;
      final usd = _toUsd(outstanding, loan.currency, rate, eurPerUsd);
      if (usd == null) {
        skipped.add(loan.currency);
        continue;
      }
      final type = LoanType.fromStorage(loan.type);
      if (type == LoanType.lend) {
        assets += usd;
      } else {
        liabilities += usd;
      }
    }

    points.add(
      NetWorthPoint(
        date: pointDate,
        assetsUsd: assets,
        liabilitiesUsd: liabilities,
        skippedCurrencies: skipped,
      ),
    );
  }

  return NetWorthSeries(points);
}

double? _toUsd(
  double amount,
  String currency,
  double? vesPerUsd,
  double? eurPerUsd,
) {
  if (currency == 'USD' || currency == 'USDT') return amount;
  if (currency == 'VES') {
    if (vesPerUsd == null || vesPerUsd <= 0) return null;
    return amount / vesPerUsd;
  }
  if (currency == 'EUR') {
    if (eurPerUsd == null || eurPerUsd <= 0) return null;
    return amount / eurPerUsd;
  }
  return null;
}
