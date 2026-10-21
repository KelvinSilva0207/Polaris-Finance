import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/database/seeds.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/shared/utils/transaction_math.dart';

FeeRule _rule({
  String id = 'r',
  String name = 'Comisión',
  double fixedAmount = 0,
  double percent = 0,
  String feeType = 'simple',
  String appliesTo = 'expense,pagoMovil,transfer',
  double? tierThreshold,
  double? tierFixedAmount,
  double? tierPercent,
  double? minAmount,
  double? maxAmount,
}) {
  return FeeRule(
    id: id,
    name: name,
    fixedAmount: fixedAmount,
    percent: percent,
    isActive: true,
    feeType: feeType,
    appliesTo: appliesTo,
    tierThreshold: tierThreshold,
    tierFixedAmount: tierFixedAmount,
    tierPercent: tierPercent,
    minAmount: minAmount,
    maxAmount: maxAmount,
  );
}

/// Regla por defecto del pago móvil del Banco de Venezuela.
FeeRule _bdvRule() => _rule(
  id: 'bdv',
  name: 'Pago móvil (BDV)',
  feeType: 'tiered',
  appliesTo: 'pagoMovil',
  tierThreshold: 5000,
  tierFixedAmount: 14,
  tierPercent: 0.3,
);

void main() {
  group('feeFor por tramos (pago móvil del BDV)', () {
    test('cobra el monto fijo por debajo de 5.000 Bs', () {
      final rule = _bdvRule();
      expect(feeFor(rule, 500), 14);
      expect(feeFor(rule, 1000), 14);
      expect(feeFor(rule, 4999.99), 14);
    });

    test('cobra el porcentaje a partir de 5.000 Bs', () {
      final rule = _bdvRule();
      expect(feeFor(rule, 5000), 15);
      expect(feeFor(rule, 10000), 30);
      expect(feeFor(rule, 20000), 60);
    });

    test('respeta el mínimo y el máximo de la comisión', () {
      final rule = _rule(
        feeType: 'tiered',
        tierThreshold: 5000,
        tierFixedAmount: 14,
        tierPercent: 0.3,
        minAmount: 20,
      );
      expect(feeFor(rule, 1000), 20);
    });
  });

  group('feeFor simple', () {
    test('suma el monto fijo y el porcentaje', () {
      final rule = _rule(fixedAmount: 10, percent: 0.3);
      expect(feeFor(rule, 10000), 40);
    });

    test('ignora los tramos si el tipo es simple', () {
      final rule = _rule(
        fixedAmount: 0,
        percent: 0.3,
        tierThreshold: 5000,
        tierFixedAmount: 14,
        tierPercent: 0.3,
      );
      expect(feeFor(rule, 1000), 3);
    });
  });

  group('alcance por tipo de transacción', () {
    test('decodifica los tipos guardados', () {
      expect(decodeFeeRuleTypes('pagoMovil'), {TransactionType.pagoMovil});
      expect(decodeFeeRuleTypes('expense,transfer'), {
        TransactionType.expense,
        TransactionType.transfer,
      });
    });

    test('sin valor aplica a los tipos de salida de dinero', () {
      expect(decodeFeeRuleTypes(null), {
        TransactionType.expense,
        TransactionType.pagoMovil,
        TransactionType.transfer,
      });
      expect(decodeFeeRuleTypes(''), {
        TransactionType.expense,
        TransactionType.pagoMovil,
        TransactionType.transfer,
      });
    });

    test('codifica y decodifica sin perder información', () {
      final types = {TransactionType.expense, TransactionType.pagoMovil};
      expect(decodeFeeRuleTypes(encodeFeeRuleTypes(types)), types);
    });

    test('indica si la regla aplica a un tipo', () {
      final rule = _bdvRule();
      expect(feeRuleAppliesTo(rule, TransactionType.pagoMovil), isTrue);
      expect(feeRuleAppliesTo(rule, TransactionType.transfer), isFalse);
      expect(feeRuleAppliesTo(rule, TransactionType.expense), isFalse);
      expect(feeRuleAppliesTo(rule, TransactionType.income), isFalse);
    });
  });

  group('feeRuleSummary', () {
    test('describe los tramos del pago móvil', () {
      expect(
        feeRuleSummary(_bdvRule()),
        '14,00 Bs hasta 5.000,00 · 0,30 % desde 5.000,00',
      );
    });

    test('describe una regla simple', () {
      expect(
        feeRuleSummary(_rule(fixedAmount: 10, percent: 0.3)),
        '10,00 Bs fijos · 0,30 %',
      );
    });
  });

  group('base de datos', () {
    test('guarda el alcance por tipo de transacción', () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);

      final rule = await database.addFeeRule(
        name: 'Pago móvil',
        fixedAmount: 14,
        appliesTo: const [TransactionType.pagoMovil],
      );

      final stored = await database.select(database.feeRules).get();
      expect(stored, hasLength(1));
      expect(stored.first.id, rule.id);
      expect(stored.first.appliesTo, 'pagoMovil');
      expect(feeRuleAppliesTo(stored.first, TransactionType.pagoMovil), isTrue);
      expect(feeRuleAppliesTo(stored.first, TransactionType.expense), isFalse);
    });

    test('guarda los tramos', () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);

      await database.addFeeRule(
        name: 'Pago móvil (BDV)',
        feeType: FeeType.tiered,
        appliesTo: const [TransactionType.pagoMovil],
        tierThreshold: 5000,
        tierFixedAmount: 14,
        tierPercent: 0.3,
      );

      final stored = (await database.select(database.feeRules).get()).first;
      expect(stored.feeType, 'tiered');
      expect(stored.tierThreshold, 5000);
      expect(stored.tierFixedAmount, 14);
      expect(stored.tierPercent, 0.3);
      expect(feeFor(stored, 1000), 14);
      expect(feeFor(stored, 10000), 30);
    });
  });

  group('perfil por defecto', () {
    test('se crea en la primera ejecución con el cobro del BDV', () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);

      await seedDatabase(database);

      final rules = await database.select(database.feeRules).get();
      expect(rules, hasLength(1));
      final rule = rules.first;
      expect(rule.id, defaultFeeRuleId);
      expect(rule.name, 'Pago móvil (BDV)');
      expect(rule.feeType, 'tiered');
      expect(rule.appliesTo, 'pagoMovil');
      expect(rule.tierThreshold, 5000);
      expect(rule.tierFixedAmount, 14);
      expect(rule.tierPercent, 0.3);
      expect(feeFor(rule, 1000), 14);
      expect(feeFor(rule, 10000), 30);
    });

    test('si el usuario lo elimina no vuelve a aparecer', () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);

      await seedDatabase(database);
      await database.deleteFeeRule(defaultFeeRuleId);
      await seedDatabase(database);

      final rules = await database.select(database.feeRules).get();
      expect(rules, isEmpty);
    });
  });
}
