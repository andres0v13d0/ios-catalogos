import 'package:catalogos/features/visitor/visitor_catalogs.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _img(String u) => <String, dynamic>{
  'imageUrl': u,
  'fullUrl': '$u?full',
};

void main() {
  test('coloresImagenes se traduce a la posición de la foto en la galería', () {
    final VisitorProduct p = VisitorProduct.fromJson(<String, dynamic>{
      'id': 'p1',
      'nombre': 'Gorra',
      'imagenes': <Object>[_img('a'), _img('b'), _img('c')],
      'colores': <String>['Azul', 'Blanco', 'Rojo'],
      'coloresImagenes': <String, String>{
        'Blanco': 'c',
        'Rojo': 'borrada', // foto que ya no existe: se ignora
      },
    });
    expect(p.colorPhoto, <String, int>{'Blanco': 2});
    expect(p.asNew().colorPhoto, p.colorPhoto);
    expect(p.withoutPrices().colorPhoto, p.colorPhoto);
  });

  test('sin coloresImagenes el producto se comporta como antes', () {
    final VisitorProduct p = VisitorProduct.fromJson(<String, dynamic>{
      'id': 'p1',
      'nombre': 'Gorra',
      'imagenes': <Object>[_img('a')],
    });
    expect(p.colorPhoto, isEmpty);
  });
}
