import 'package:catalogos/features/buy/cart_controller.dart';
import 'package:catalogos/features/visitor/order_message.dart';
import 'package:flutter_test/flutter_test.dart';

CartLine _l(String name, int q, {num? price, String? color, String? size}) =>
    CartLine(
      catalogId: 'c',
      catalogName: 'Cat',
      productId: name,
      name: name,
      quantity: q,
      unitPrice: price,
      color: color,
      size: size,
    );

void main() {
  group('formatWhatsAppNumber', () {
    test('respeta el indicativo y agrega el 57 a un celular colombiano', () {
      expect(formatWhatsAppNumber('+57 301 664 3479'), '573016643479');
      expect(formatWhatsAppNumber('573016643479'), '573016643479');
      expect(formatWhatsAppNumber('3016643479'), '573016643479');
      expect(formatWhatsAppNumber('(301) 664-3479'), '573016643479');
    });
  });

  group('whatsappUri', () {
    test(
      'Android usa api.whatsapp.com y el resto wa.me, con el texto codificado',
      () {
        final Uri a = whatsappUri('3016643479', 'hola ñ', android: true);
        expect(a.host, 'api.whatsapp.com');
        expect(a.queryParameters, {'phone': '573016643479', 'text': 'hola ñ'});
        final Uri i = whatsappUri('3016643479', 'hola ñ', android: false);
        expect(i.host, 'wa.me');
        expect(i.path, '/573016643479');
        expect(i.queryParameters['text'], 'hola ñ');
      },
    );
  });

  group('buildOrderMessage', () {
    test('lista productos, total y el enlace', () {
      final String m = buildOrderMessage(
        <CartLine>[
          _l('Tenis', 6, price: 48900, color: 'Negro', size: '32'),
          _l('Sandalia', 12),
        ],
        'https://share.minymol.com/x',
        total: 400000,
      );
      expect(m, startsWith('¡Hola!'));
      expect(m, contains('pedido de 2 productos'));
      expect(
        m,
        contains(
          'Tenis\n  • Color: Negro, Talla: 32, Cantidad: 6\n\$ 48.900 c/u',
        ),
      );
      expect(m, contains('Sandalia\n  • Cantidad: 12'));
      expect(m, contains('Total estimado: \$ 400.000'));
      expect(m, contains('aquí: https://share.minymol.com/x'));
    });

    test('con precios ocultos no aparece ningún monto', () {
      final String m = buildOrderMessage(
        <CartLine>[_l('Tenis', 6, price: 48900)],
        'https://x',
        total: 293400,
        hidePrices: true,
      );
      expect(m, isNot(contains('48.900')));
      expect(m, isNot(contains('293.400')));
      expect(m, contains('Precios por confirmar con el proveedor'));
    });

    test('un solo producto va en singular', () {
      expect(
        buildOrderMessage(<CartLine>[_l('A', 1)], 'u', total: 0),
        contains('pedido de 1 producto:'),
      );
    });
  });

  group('buildOrderSummary', () {
    test('muestra tres productos y cuenta el resto', () {
      expect(
        buildOrderSummary(<CartLine>[
          _l('A', 1),
          _l('B', 2),
          _l('C', 3),
          _l('D', 4),
          _l('E', 5),
        ]),
        '1 A, 2 B, 3 C y 2 más',
      );
      expect(buildOrderSummary(<CartLine>[_l('A', 6)]), '6 A');
    });
  });
}
