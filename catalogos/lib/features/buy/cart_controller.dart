import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Línea del carrito de compra. El precio es solo un estimado para mostrar:
/// el total real lo calcula el servidor al enviar el pedido.
class CartLine {
  const CartLine({
    required this.catalogId,
    required this.catalogName,
    required this.productId,
    required this.name,
    required this.quantity,
    this.unitPrice,
    this.color,
    this.size,
  });

  final String catalogId;
  final String catalogName;
  final String productId;
  final String name;
  final int quantity;
  final num? unitPrice;
  final String? color;
  final String? size;

  String get key => '$catalogId|$productId|${color ?? ''}|${size ?? ''}';

  CartLine withQuantity(int q) => CartLine(
    catalogId: catalogId,
    catalogName: catalogName,
    productId: productId,
    name: name,
    quantity: q,
    unitPrice: unitPrice,
    color: color,
    size: size,
  );
}

/// Carrito en memoria.
/// shortcut: se pierde al cerrar la app; persistir en Hive si los revendedores lo piden.
class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const <CartLine>[];

  void add(CartLine line) {
    final int i = state.indexWhere((CartLine l) => l.key == line.key);
    if (i == -1) {
      state = <CartLine>[...state, line];
      return;
    }
    final List<CartLine> next = <CartLine>[...state];
    next[i] = state[i].withQuantity(state[i].quantity + line.quantity);
    state = next;
  }

  void remove(String key) =>
      state = state.where((CartLine l) => l.key != key).toList();

  void clear() => state = const <CartLine>[];
}

final NotifierProvider<CartController, List<CartLine>> cartControllerProvider =
    NotifierProvider<CartController, List<CartLine>>(CartController.new);
