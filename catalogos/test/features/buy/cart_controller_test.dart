import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catalogos/features/buy/cart_controller.dart';

CartLine _line({int q = 1, String? color}) => CartLine(
  catalogId: 'c1',
  catalogName: 'Cat',
  productId: 'p1',
  name: 'Zapato',
  quantity: q,
  color: color,
);

void main() {
  test('la misma variante suma cantidades y otra variante es otra línea', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(cartControllerProvider.notifier);
    n.add(_line(q: 2));
    n.add(_line(q: 3));
    n.add(_line(color: 'Rojo'));
    final cart = c.read(cartControllerProvider);
    expect(cart, hasLength(2));
    expect(cart.first.quantity, 5);
    n.remove(cart.first.key);
    expect(c.read(cartControllerProvider), hasLength(1));
  });
}
