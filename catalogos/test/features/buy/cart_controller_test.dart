import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catalogos/features/buy/cart_controller.dart';

CartLine _line({
  int q = 1,
  String? color,
  String catalog = 'c1',
  Map<int, int> prices = const <int, int>{},
}) => CartLine(
  catalogId: catalog,
  catalogName: 'Cat',
  productId: 'p1',
  name: 'Zapato',
  quantity: q,
  color: color,
  priceMap: prices,
  unitPrice: prices.isEmpty ? null : prices[q],
);

void main() {
  test(
    'la misma variante reemplaza la cantidad y otra variante es otra línea',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(cartControllerProvider.notifier);
      n.add(_line(q: 2));
      n.add(_line(q: 3));
      n.add(_line(color: 'Rojo'));
      final cart = c.read(cartControllerProvider);
      expect(cart, hasLength(2));
      expect(cart.first.quantity, 3);
      n.remove(cart.first.key);
      expect(c.read(cartControllerProvider), hasLength(1));
    },
  );

  test(
    'cambiar la cantidad recalcula el precio por la escala del proveedor',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(cartControllerProvider.notifier);
      const prices = <int, int>{6: 48900, 12: 46500, 24: 44000};
      n.add(_line(q: 6, prices: prices));
      final key = c.read(cartControllerProvider).first.key;
      expect(c.read(cartControllerProvider).first.quantityOptions, [6, 12, 24]);
      n.setQuantity(key, 12);
      final l = c.read(cartControllerProvider).first;
      expect(l.quantity, 12);
      expect(l.unitPrice, 46500);
      expect(l.lineTotal, 46500 * 12);
    },
  );

  test(
    'removeCatalog quita solo ese pedido y el carrito se agrupa por catálogo',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(cartControllerProvider.notifier);
      n.add(_line());
      n.add(_line(catalog: 'c2'));
      n.removeCatalog('c1');
      final cart = c.read(cartControllerProvider);
      expect(cart, hasLength(1));
      expect(cart.single.catalogId, 'c2');
    },
  );
}
