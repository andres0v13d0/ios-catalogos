// Tests de formateo de precios en COP (tarea 0.6, CA; diseño §5).

import 'package:catalogos/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCop', () {
    test('formatea cero', () {
      expect(formatCop(0), r'$ 0');
    });

    test('formatea valores de menos de mil sin separador', () {
      expect(formatCop(5), r'$ 5');
      expect(formatCop(999), r'$ 999');
    });

    test('agrupa miles con punto', () {
      expect(formatCop(1000), r'$ 1.000');
      expect(formatCop(12500), r'$ 12.500');
      expect(formatCop(999999), r'$ 999.999');
    });

    test('formatea millones (valor grande)', () {
      expect(formatCop(1500000), r'$ 1.500.000');
      expect(formatCop(1000000000), r'$ 1.000.000.000');
    });

    test('redondea decimales al entero más cercano (sin decimales, UX-2)', () {
      expect(formatCop(1500.4), r'$ 1.500');
      expect(formatCop(1500.5), r'$ 1.501');
      expect(formatCop(2999.99), r'$ 3.000');
    });

    test('conserva el signo en valores negativos', () {
      expect(formatCop(-2500), r'-$ 2.500');
      expect(formatCop(-1000000), r'-$ 1.000.000');
    });
  });

  group('formatCopPlain', () {
    test('formatea sin símbolo de moneda', () {
      expect(formatCopPlain(0), '0');
      expect(formatCopPlain(1500000), '1.500.000');
    });

    test('usa el valor absoluto', () {
      expect(formatCopPlain(-1500000), '1.500.000');
    });
  });
}
