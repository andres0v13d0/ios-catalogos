// Puerto Dart de `price-rule-calculator.ts` (backend) — mismos vectores de
// prueba obligatorios, usados aquí para la vista previa en vivo del editor
// "Ajustar precios". El backend es la fuente de verdad al guardar.

import 'package:catalogos/features/shared_catalogs/domain/price_rule_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyPriceRule — vectores de prueba obligatorios', () {
    final vectors = <({num price, PriceRule rule, num expected})>[
      (
        price: 20000,
        rule: const PriceRule(mode: PriceRuleMode.percent, value: 30),
        expected: 26000,
      ),
      (
        price: 12999,
        rule: const PriceRule(mode: PriceRuleMode.percent, value: 30),
        expected: 16900,
      ),
      (
        price: 4449,
        rule: const PriceRule(mode: PriceRuleMode.percent, value: 30),
        expected: 5800,
      ),
      (
        price: 12999,
        rule: const PriceRule(mode: PriceRuleMode.fixed, value: 5000),
        expected: 18000,
      ),
      (
        price: 5000,
        rule: const PriceRule(mode: PriceRuleMode.fixed, value: 450),
        expected: 5500,
      ),
      (
        price: 5000,
        rule: const PriceRule(mode: PriceRuleMode.fixed, value: 449),
        expected: 5400,
      ),
      (
        price: 1000,
        rule: const PriceRule(mode: PriceRuleMode.percent, value: 5),
        expected: 1100,
      ),
      (
        price: 3500,
        rule: const PriceRule(mode: PriceRuleMode.percent, value: 1),
        expected: 3500,
      ),
      (
        // Naive da 1400, bajo el proveedor (1440) → protección de piso → 1500.
        price: 1440,
        rule: const PriceRule(mode: PriceRuleMode.fixed, value: 9),
        expected: 1500,
      ),
    ];

    for (final v in vectors) {
      test('(${v.price}, ${v.rule.mode.api} ${v.rule.value}) → ${v.expected}', () {
        expect(applyPriceRule(v.price, v.rule), v.expected);
      });
    }
  });

  group('applyPriceRule — casos extra', () {
    test('sin regla retorna el precio del proveedor tal cual', () {
      expect(applyPriceRule(20000, null), 20000);
      expect(applyPriceRule(4449.0, null), 4449);
    });

    test('decimal con centavos reales (12999.50) se calcula exacto', () {
      expect(
        applyPriceRule(
          12999.50,
          const PriceRule(mode: PriceRuleMode.percent, value: 30),
        ),
        16900,
      );
    });

    test('precio 0: el markup no genera un precio negativo ni inválido', () {
      expect(
        applyPriceRule(0, const PriceRule(mode: PriceRuleMode.percent, value: 30)),
        0,
      );
      expect(
        applyPriceRule(0, const PriceRule(mode: PriceRuleMode.fixed, value: 100)),
        100,
      );
    });

    test('porcentaje máximo permitido (300%) calcula correcto', () {
      expect(
        applyPriceRule(5000, const PriceRule(mode: PriceRuleMode.percent, value: 300)),
        20000,
      );
    });

    test('valor fijo máximo permitido (+10.000.000) calcula correcto', () {
      expect(
        applyPriceRule(
          1000,
          const PriceRule(mode: PriceRuleMode.fixed, value: 10000000),
        ),
        10001000,
      );
    });

    test(
      'el resultado nunca tiene centavos y nunca es menor que el precio del proveedor',
      () {
        const prices = <num>[100, 999.99, 1440, 4449, 5000.01, 12999.50, 999999.99];
        const rules = <PriceRule>[
          PriceRule(mode: PriceRuleMode.percent, value: 1),
          PriceRule(mode: PriceRuleMode.percent, value: 30),
          PriceRule(mode: PriceRuleMode.percent, value: 300),
          PriceRule(mode: PriceRuleMode.fixed, value: 1),
          PriceRule(mode: PriceRuleMode.fixed, value: 449),
          PriceRule(mode: PriceRuleMode.fixed, value: 10000000),
        ];

        for (final price in prices) {
          for (final rule in rules) {
            final result = applyPriceRule(price, rule);
            expect(result % 100, 0);
            expect(result, greaterThanOrEqualTo(price.truncate()));
          }
        }
      },
    );
  });

  group('validatePriceRule — validación controlada', () {
    test('rechaza porcentaje fuera de rango (0 y 301)', () {
      expect(
        () => validatePriceRule(PriceRuleMode.percent, 0),
        throwsA(isA<InvalidPriceRuleException>()),
      );
      expect(
        () => validatePriceRule(PriceRuleMode.percent, 301),
        throwsA(isA<InvalidPriceRuleException>()),
      );
    });

    test('rechaza valor fijo fuera de rango (0 y 10.000.001)', () {
      expect(
        () => validatePriceRule(PriceRuleMode.fixed, 0),
        throwsA(isA<InvalidPriceRuleException>()),
      );
      expect(
        () => validatePriceRule(PriceRuleMode.fixed, 10000001),
        throwsA(isA<InvalidPriceRuleException>()),
      );
    });

    test('acepta los límites inclusive (1, 300, 1, 10.000.000)', () {
      expect(() => validatePriceRule(PriceRuleMode.percent, 1), returnsNormally);
      expect(() => validatePriceRule(PriceRuleMode.percent, 300), returnsNormally);
      expect(() => validatePriceRule(PriceRuleMode.fixed, 1), returnsNormally);
      expect(
        () => validatePriceRule(PriceRuleMode.fixed, 10000000),
        returnsNormally,
      );
    });
  });
}
