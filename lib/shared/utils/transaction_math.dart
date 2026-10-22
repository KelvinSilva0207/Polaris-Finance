import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import 'amount_format.dart';

double signedAmount(Transaction transaction) {
  final type = TransactionType.fromStorage(transaction.type);
  return switch (type) {
    TransactionType.income => transaction.amount,
    TransactionType.expense ||
    TransactionType.transfer ||
    TransactionType.pagoMovil => -(transaction.amount + transaction.feeAmount),
  };
}

Map<String, double> balancesOf(
  List<Transaction> transactions, {
  Iterable<Account> accounts = const [],
}) {
  final balances = <String, double>{
    for (final account in accounts) account.id: account.openingBalance,
  };
  final isOutflow = {
    TransactionType.expense,
    TransactionType.transfer,
    TransactionType.pagoMovil,
  };
  for (final transaction in transactions) {
    final type = TransactionType.fromStorage(transaction.type);
    final delta = switch (type) {
      TransactionType.income => transaction.amount,
      TransactionType.expense ||
      TransactionType.transfer ||
      TransactionType.pagoMovil =>
        -(transaction.amount + transaction.feeAmount),
    };
    balances.update(
      transaction.accountId,
      (current) => current + delta,
      ifAbsent: () => delta,
    );
    if (isOutflow.contains(type) && transaction.transferToId != null) {
      final credit = transaction.credAmount ?? transaction.amount;
      balances.update(
        transaction.transferToId!,
        (current) => current + credit,
        ifAbsent: () => credit,
      );
    }
  }
  return balances;
}

/// Factor para llevar un importe de [currency] a USD (USDT se trata como USD).
/// Devuelve null si faltan tasas o la moneda no está soportada.
double? usdFactor(String currency, {double? vesPerUsd, double? eurPerUsd}) {
  switch (currency) {
    case 'USD' || 'USDT':
      return 1;
    case 'VES':
      if (vesPerUsd == null || vesPerUsd <= 0) return null;
      return 1 / vesPerUsd;
    case 'EUR':
      if (eurPerUsd == null || eurPerUsd <= 0) return null;
      return 1 / eurPerUsd;
    default:
      return null;
  }
}

/// Convierte [value] de la moneda [from] a la moneda [to] usando USD como
/// moneda intermedia. Devuelve null si alguna de las dos no es convertible.
double? convertBetween(
  double value,
  String from,
  String to, {
  double? vesPerUsd,
  double? eurPerUsd,
}) {
  if (from == to) return value;
  final fromFactor = usdFactor(
    from,
    vesPerUsd: vesPerUsd,
    eurPerUsd: eurPerUsd,
  );
  final toFactor = usdFactor(to, vesPerUsd: vesPerUsd, eurPerUsd: eurPerUsd);
  if (fromFactor == null || toFactor == null) return null;
  return value * fromFactor / toFactor;
}

/// Equivalente de [amount] de [currency] en la otra moneda del par (VES -> USD
/// o USD/EUR -> VES).
double? convertedAmount(
  double amount,
  String currency,
  double? vesPerUsd, {
  double? eurPerUsd,
}) {
  final target = currency == 'VES' ? 'USD' : 'VES';
  return convertBetween(
    amount,
    currency,
    target,
    vesPerUsd: vesPerUsd,
    eurPerUsd: eurPerUsd,
  );
}

double? usdEquivalent(
  double balance,
  String currency,
  double vesPerUsd, {
  double? eurPerUsd,
}) {
  final factor = usdFactor(
    currency,
    vesPerUsd: vesPerUsd,
    eurPerUsd: eurPerUsd,
  );
  if (factor == null) return null;
  return balance * factor;
}

({double total, Set<String> currenciesExcluded})? totalUsdOf(
  Map<String, double> balances,
  Iterable<Account> accounts,
  double vesPerUsd, {
  double? eurPerUsd,
}) {
  var total = 0.0;
  final excluded = <String>{};
  var any = false;
  for (final account in accounts) {
    final usd = usdEquivalent(
      balances[account.id] ?? 0,
      account.currency,
      vesPerUsd,
      eurPerUsd: eurPerUsd,
    );
    if (usd == null) {
      excluded.add(account.currency);
    } else {
      total += usd;
      any = true;
    }
  }
  return any ? (total: total, currenciesExcluded: excluded) : null;
}

CurrencyRate? latestReferenceRate(
  List<CurrencyRate> rates,
  RateProvider provider,
) {
  for (final rate in rates) {
    if (rate.rateCode == 'USD/VES' && rate.provider == provider.name) {
      return rate;
    }
  }
  return null;
}

/// Bolívares por euro a partir de la tasa BCV (VES por USD) y la tasa de
/// referencia del euro (euros por USD).
double? vesPerEur(double? vesPerUsd, double? eurPerUsd) {
  if (vesPerUsd == null || eurPerUsd == null || eurPerUsd <= 0) return null;
  return vesPerUsd / eurPerUsd;
}

/// Última tasa guardada del euro en USD (par `USD/EUR`, proveedor `api`).
CurrencyRate? latestEurRate(List<CurrencyRate> rates) {
  for (final rate in rates) {
    if (rate.rateCode == 'USD/EUR') return rate;
  }
  return null;
}

/// Serie diaria (último valor de cada día) de una tasa, los últimos [days] días,
/// ordenada de más antigua a más reciente. Solo incluye días con datos.
List<({DateTime date, double rate})> dailyRateSeries(
  List<CurrencyRate> rates, {
  required RateProvider provider,
  String rateCode = 'USD/VES',
  int days = 30,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final start = DateTime(
    reference.year,
    reference.month,
    reference.day,
  ).subtract(Duration(days: days - 1));
  final byDay = <DateTime, CurrencyRate>{};
  for (final rate in rates) {
    if (rate.rateCode != rateCode || rate.provider != provider.name) continue;
    if (rate.date.isBefore(start)) continue;
    final day = DateTime(rate.date.year, rate.date.month, rate.date.day);
    final existing = byDay[day];
    if (existing == null || rate.date.isAfter(existing.date)) {
      byDay[day] = rate;
    }
  }
  final points = <({DateTime date, double rate})>[];
  for (var offset = 0; offset < days; offset++) {
    final day = start.add(Duration(days: offset));
    final entry = byDay[day];
    if (entry != null) points.add((date: day, rate: entry.rate));
  }
  return points;
}

/// Tipos de transacción a los que aplica una regla de comisión.
Set<TransactionType> feeRuleTypes(FeeRule rule) =>
    decodeFeeRuleTypes(rule.appliesTo);

/// Indica si la regla de comisión aplica al tipo de transacción dado.
bool feeRuleAppliesTo(FeeRule rule, TransactionType type) =>
    feeRuleTypes(rule).contains(type);

/// Resumen legible de una regla de comisión, para las listas y el formulario.
String feeRuleSummary(FeeRule rule) {
  final parts = <String>[];
  if (rule.feeType == FeeType.tiered.name && rule.tierThreshold != null) {
    final threshold = rule.tierThreshold!;
    parts.add(
      '${formatVeNumber(rule.tierFixedAmount ?? 0)} Bs hasta '
      '${formatVeNumber(threshold)}',
    );
    parts.add(
      '${formatVePercent(rule.tierPercent ?? 0)} desde '
      '${formatVeNumber(threshold)}',
    );
  } else {
    if (rule.fixedAmount > 0) {
      parts.add('${formatVeNumber(rule.fixedAmount)} Bs fijos');
    }
    if (rule.percent > 0) parts.add(formatVePercent(rule.percent));
  }
  if (rule.minAmount != null) {
    parts.add('mín ${formatVeNumber(rule.minAmount!)}');
  }
  if (rule.maxAmount != null) {
    parts.add('máx ${formatVeNumber(rule.maxAmount!)}');
  }
  return parts.join(' · ');
}

/// Calcula la comisión de una regla para un monto dado.
///
/// Las reglas *simples* cobran el monto fijo más el porcentaje sobre el
/// monto. Las reglas *por tramos* cobran un monto fijo por debajo del umbral
/// y el porcentaje a partir de él (como el pago móvil del Banco de
/// Venezuela: monto fijo hasta el límite y porcentaje a partir del límite).
double feeFor(
  FeeRule rule,
  double amount, {
  String? accountCurrency,
  double? vesPerUsd,
  double? eurPerUsd,
}) {
  double fee;
  final threshold = rule.tierThreshold;
  if (rule.feeType == FeeType.tiered.name && threshold != null) {
    fee = amount < threshold
        ? (rule.tierFixedAmount ?? 0)
        : amount * (rule.tierPercent ?? 0) / 100;
  } else {
    fee = rule.fixedAmount + amount * rule.percent / 100;
  }
  if (rule.minAmount != null && fee < rule.minAmount!) fee = rule.minAmount!;
  if (rule.maxAmount != null && fee > rule.maxAmount!) fee = rule.maxAmount!;
  if (fee <= 0) return 0;
  // El fijo, mínimo y máximo de la regla están en VES; se convierten a la
  // moneda de la cuenta cuando hace falta.
  final inUsd = accountCurrency == 'USD' || accountCurrency == 'USDT';
  final inEur = accountCurrency == 'EUR';
  if ((inUsd || inEur) && vesPerUsd != null && vesPerUsd > 0) {
    fee = fee / vesPerUsd;
    if (inEur && eurPerUsd != null && eurPerUsd > 0) fee = fee * eurPerUsd;
  }
  return double.parse(fee.toStringAsFixed(2));
}
