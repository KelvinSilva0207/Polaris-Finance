import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/shared/utils/inflation.dart';

void main() {
  test('periodChangePercent calcula la variacion total', () {
    final series = [
      (date: DateTime(2026, 1, 1), rate: 100.0),
      (date: DateTime(2026, 1, 31), rate: 150.0),
    ];
    expect(periodChangePercent(series), 50);
  });

  test('periodChangePercent devuelve null con menos de dos puntos', () {
    expect(periodChangePercent(const []), isNull);
    expect(
      periodChangePercent([(date: DateTime(2026, 1, 1), rate: 100.0)]),
      isNull,
    );
  });

  test('impliedMonthlyInflation anualiza la variacion diaria (30 dias)', () {
    final series = [
      (date: DateTime(2026, 1, 1), rate: 100.0),
      (date: DateTime(2026, 1, 31), rate: 150.0),
    ];
    final monthly = impliedMonthlyInflation(series)!;
    // Una subida del 50% en 30 dias equivale a ~50% mensual.
    expect(monthly, closeTo(50, 0.01));
  });

  test('impliedMonthlyInflation normaliza a un mes de 30 dias', () {
    final series = [
      (date: DateTime(2026, 1, 1), rate: 100.0),
      (date: DateTime(2026, 1, 16), rate: 121.0),
    ];
    // +21% en 15 dias => (1.21^(1/15))^30 - 1 = 46.41% mensual.
    final monthly = impliedMonthlyInflation(series)!;
    expect(monthly, closeTo(46.41, 0.05));
  });

  test('futureRequiredValue y presentValue son inversos', () {
    final future = futureRequiredValue(1000, 10, 6);
    expect(future, closeTo(1771.56, 0.01));
    expect(presentValue(future, 10, 6), closeTo(1000, 0.01));
  });

  test('simulateInflation genera series de N+1 puntos', () {
    final sim = simulateInflation(
      value: 1000,
      monthlyRatePercent: 10,
      months: 12,
    );
    expect(sim.requiredNominal.length, 13);
    expect(sim.realValue.length, 13);
    expect(sim.requiredNominal.first, 1000);
    expect(sim.realValue.first, 1000);
    expect(sim.finalRequired, greaterThan(1000));
    expect(sim.finalReal, lessThan(1000));
    expect(sim.purchasingPowerLossPercent, greaterThan(0));
  });

  test('tasa cero mantiene el poder de compra', () {
    final sim = simulateInflation(value: 500, monthlyRatePercent: 0, months: 6);
    expect(sim.finalRequired, 500);
    expect(sim.finalReal, 500);
    expect(sim.purchasingPowerLossPercent, 0);
  });
}
