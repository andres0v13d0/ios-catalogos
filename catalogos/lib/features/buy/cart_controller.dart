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
    this.imageUrl,
    this.priceMap = const <int, int>{},
    this.minTotal = 1,
  });

  final String catalogId;
  final String catalogName;
  final String productId;
  final String name;
  final int quantity;
  final num? unitPrice;
  final String? color;
  final String? size;
  final String? imageUrl;

  /// Cantidad → precio unitario del producto (lo que configura el proveedor).
  final Map<int, int> priceMap;
  final int minTotal;

  String get key => '$catalogId|$productId|${color ?? ''}|${size ?? ''}';

  /// Cantidades que ofrece el proveedor para este producto.
  List<int> get quantityOptions {
    final List<int> o = priceMap.keys.where((int q) => q >= minTotal).toList()
      ..sort();
    return o.isEmpty ? <int>[quantity] : o;
  }

  /// Precio unitario para [q]: el del mayor umbral que no la supere.
  num? priceFor(int q) {
    if (priceMap.isEmpty) return unitPrice;
    final List<MapEntry<int, int>> e = priceMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    int chosen = e.first.value;
    for (final MapEntry<int, int> x in e) {
      if (q >= x.key) chosen = x.value;
    }
    return chosen;
  }

  num get lineTotal => (unitPrice ?? 0) * quantity;

  String? get variantLabel {
    final List<String> parts = <String>[
      if (color != null && color!.isNotEmpty) color!,
      if (size != null && size!.isNotEmpty) 'Talla $size',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  CartLine withQuantity(int q) => CartLine(
    catalogId: catalogId,
    catalogName: catalogName,
    productId: productId,
    name: name,
    quantity: q,
    unitPrice: priceFor(q),
    color: color,
    size: size,
    imageUrl: imageUrl,
    priceMap: priceMap,
    minTotal: minTotal,
  );
}

/// Carrito en memoria.
/// shortcut: se pierde al cerrar la app; persistir en Hive si los revendedores lo piden.
class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const <CartLine>[];

  /// Agrega la línea; si ya existe el mismo producto/variante, reemplaza su
  /// cantidad (las cantidades son las que ofrece el proveedor, no se suman).
  void add(CartLine line) {
    final int i = state.indexWhere((CartLine l) => l.key == line.key);
    if (i == -1) {
      state = <CartLine>[...state, line];
      return;
    }
    final List<CartLine> next = <CartLine>[...state];
    next[i] = line;
    state = next;
  }

  void setQuantity(String key, int q) => state = <CartLine>[
    for (final CartLine l in state) l.key == key ? l.withQuantity(q) : l,
  ];

  void remove(String key) =>
      state = state.where((CartLine l) => l.key != key).toList();

  void removeCatalog(String catalogId) =>
      state = state.where((CartLine l) => l.catalogId != catalogId).toList();

  void clear() => state = const <CartLine>[];
}

final NotifierProvider<CartController, List<CartLine>> cartControllerProvider =
    NotifierProvider<CartController, List<CartLine>>(CartController.new);
