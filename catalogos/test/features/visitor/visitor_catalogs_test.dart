import 'package:catalogos/features/visitor/visitor_catalogs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCatalogCode', () {
    test(
      'código suelto',
      () => expect(parseCatalogCode('aB3dE5fG7hJk'), 'aB3dE5fG7hJk'),
    );
    test('enlace flystock', () {
      expect(
        parseCatalogCode('https://acme.flystock.com.co/aB3dE5fG/'),
        'aB3dE5fG',
      );
    });
    test('enlace api', () {
      expect(
        parseCatalogCode('https://api.minymol.com/catalog/short/57e0dffb'),
        '57e0dffb',
      );
    });
    test('inválidos', () {
      expect(parseCatalogCode(''), isNull);
      expect(parseCatalogCode('corto'), isNull);
    });
  });

  test('VisitorProduct: precio por umbral y desde', () {
    final VisitorProduct p = VisitorProduct.fromJson(<String, dynamic>{
      'id': 'p1',
      'nombre': ' Camisa ',
      'precios': <String, dynamic>{'6': 33000, '12': 30000, '3': 0},
      'colores': <String>['Rojo', ' ', 'Rojo'],
    });
    expect(p.name, 'Camisa');
    expect(p.priceFrom, 30000);
    expect(p.priceFor(6), 33000);
    expect(p.priceFor(20), 30000);
    expect(p.colors, <String>['Rojo']);
  });
}
