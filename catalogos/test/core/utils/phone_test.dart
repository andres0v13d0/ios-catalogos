// Tests de normalización de teléfonos a E.164 (tarea 0.6, CA; diseño Fase 1).

import 'package:catalogos/core/utils/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeToE164 — números nacionales CO (default +57)', () {
    test('número móvil local de 10 dígitos', () {
      expect(normalizeToE164('3001234567'), '+573001234567');
    });

    test('elimina espacios de formato', () {
      expect(normalizeToE164('300 123 4567'), '+573001234567');
    });

    test('elimina guiones y paréntesis', () {
      expect(normalizeToE164('(300) 123-4567'), '+573001234567');
      expect(normalizeToE164('300-123-4567'), '+573001234567');
    });

    test('descarta un 0 troncal inicial', () {
      expect(normalizeToE164('03001234567'), '+573001234567');
    });
  });

  group('normalizeToE164 — ya en formato internacional', () {
    test('deja intacto un E.164 válido', () {
      expect(normalizeToE164('+573001234567'), '+573001234567');
    });

    test('normaliza E.164 con espacios', () {
      expect(normalizeToE164('+57 300 123 4567'), '+573001234567');
    });

    test('acepta prefijo 00 como internacional', () {
      expect(normalizeToE164('0057 3001234567'), '+573001234567');
    });

    test('reconoce el código de país sin + cuando la longitud calza', () {
      expect(normalizeToE164('573001234567'), '+573001234567');
    });

    test('respeta otros países cuando llega con +', () {
      expect(normalizeToE164('+14155552671'), '+14155552671');
    });
  });

  group('normalizeToE164 — códigos de país alternativos', () {
    test('usa el countryCode indicado para números nacionales', () {
      expect(
        normalizeToE164('4155552671', countryCode: '1'),
        '+14155552671',
      );
    });
  });

  group('normalizeToE164 — entradas inválidas', () {
    test('null devuelve null', () {
      expect(normalizeToE164(null), isNull);
    });

    test('cadena vacía o solo espacios devuelve null', () {
      expect(normalizeToE164(''), isNull);
      expect(normalizeToE164('   '), isNull);
    });

    test('solo letras devuelve null', () {
      expect(normalizeToE164('abc'), isNull);
    });

    test('demasiado corto devuelve null', () {
      expect(normalizeToE164('123'), isNull);
    });

    test('demasiado largo devuelve null', () {
      expect(normalizeToE164('+1234567890123456'), isNull);
    });
  });

  group('isValidE164', () {
    test('acepta E.164 bien formado', () {
      expect(isValidE164('+573001234567'), isTrue);
      expect(isValidE164('+14155552671'), isTrue);
    });

    test('rechaza valores sin + o con formato inválido', () {
      expect(isValidE164('573001234567'), isFalse);
      expect(isValidE164('+0573001234567'), isFalse);
      expect(isValidE164('+57 300'), isFalse);
      expect(isValidE164(null), isFalse);
    });
  });
}
