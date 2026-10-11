import 'dart:math' as math;

/// Variación porcentual entre el primer y el último punto de la serie.
double? periodChangePercent(List<({DateTime date, double rate})> series) {
  if (series.length < 2) return null;
  final first = series.first.rate;
  final last = series.last.rate;
  if (first <= 0) return null;
  return (last - first) / first * 100;
}

/// Inflación mensual implícita (tasa efectiva) a partir de una serie de tasas
/// diarias. Se toma la variación total del periodo, se convierte a tasa diaria
/// compuesta y se eleva a [dayCount] días.
///
/// Se usa el tipo de cambio USD/VES como proxy de la inflación en bolívares:
/// cuando el bolívar se devalúa, la tasa sube y el poder de compra cae.
double? impliedMonthlyInflation(
  List<({DateTime date, double rate})> series, {
  int dayCount = 30,
}) {
  if (series.length < 2) return null;
  final first = series.first;
  final last = series.last;
  final days = last.date.difference(first.date).inDays;
  if (days < 1 || first.rate <= 0 || last.rate <= 0) return null;
  final dailyGrowth = last.rate / first.rate;
  final dailyRate = math.pow(dailyGrowth, 1 / days);
  final monthlyRate = math.pow(dailyRate, dayCount) - 1;
  return monthlyRate * 100;
}

/// Valor nominal necesario dentro de [months] meses para conservar el poder de
/// compra de [value] hoy, a una [monthlyRatePercent] constante.
double futureRequiredValue(
  double value,
  double monthlyRatePercent,
  double months,
) {
  final rate = monthlyRatePercent / 100;
  return value * math.pow(1 + rate, months);
}

/// Poder de compra actual (traído a hoy) de [nominal] dentro de [months] meses,
/// a una [monthlyRatePercent] constante.
double presentValue(
  double nominal,
  double monthlyRatePercent,
  double months,
) {
  final rate = monthlyRatePercent / 100;
  return nominal / math.pow(1 + rate, months);
}

class InflationSimulation {
  const InflationSimulation({
    required this.startValue,
    required this.monthlyRatePercent,
    required this.requiredNominal,
    required this.realValue,
  });

  final double startValue;
  final double monthlyRatePercent;

  /// Valor nominal necesario cada mes (índice 0..N) para igualar el poder de
  /// compra inicial.
  final List<double> requiredNominal;

  /// Poder de compra, en términos de hoy, de mantener [startValue] sin ajustar.
  final List<double> realValue;

  int get months => requiredNominal.length - 1;

  double get finalRequired => requiredNominal.last;
  double get finalReal => realValue.last;

  /// Poder de compra perdido en el horizonte, en porcentaje (0..100).
  double get purchasingPowerLossPercent {
    if (startValue <= 0) return 0;
    return (1 - finalReal / startValue) * 100;
  }
}

InflationSimulation simulateInflation({
  required double value,
  required double monthlyRatePercent,
  required int months,
}) {
  final rate = monthlyRatePercent / 100;
  final required = <double>[value];
  final real = <double>[value];
  var factor = 1.0;
  for (var month = 1; month <= months; month++) {
    factor *= (1 + rate);
    required.add(value * factor);
    real.add(value / factor);
  }
  return InflationSimulation(
    startValue: value,
    monthlyRatePercent: monthlyRatePercent,
    requiredNominal: required,
    realValue: real,
  );
}
