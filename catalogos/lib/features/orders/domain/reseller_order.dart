/// Estados de un pedido (mismos valores que `catalog_orders.status`).
enum OrderStatus {
  pending('pending', 'Por confirmar'),
  confirmed('confirmed', 'Confirmado'),
  preparing('preparing', 'En preparación'),
  delivered('delivered', 'Entregado'),
  canceled('canceled', 'Anulado');

  const OrderStatus(this.wire, this.label);
  final String wire;
  final String label;

  static OrderStatus parse(Object? raw) => OrderStatus.values.firstWhere(
    (OrderStatus s) => s.wire == raw,
    orElse: () => OrderStatus.pending,
  );
}

class ResellerOrderItem {
  const ResellerOrderItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.saleUnitPrice,
    this.color,
    this.size,
  });

  final String name;
  final int quantity;
  final num unitPrice; // costo del proveedor
  final num saleUnitPrice; // lo que paga el cliente
  final String? color;
  final String? size;

  factory ResellerOrderItem.fromJson(Map<String, dynamic> j) {
    final num cost = num.tryParse('${j['unitPrice']}') ?? 0;
    return ResellerOrderItem(
      name: '${j['productName'] ?? ''}',
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: cost,
      saleUnitPrice: num.tryParse('${j['saleUnitPrice']}') ?? cost,
      color: j['color'] as String?,
      size: j['size'] as String?,
    );
  }
}

class ResellerOrder {
  const ResellerOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.costTotal,
    required this.saleTotal,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final int number;
  final OrderStatus status;
  final num costTotal;
  final num saleTotal;
  final DateTime createdAt;
  final List<ResellerOrderItem> items;

  /// Ganancia del revendedor (precio al cliente menos costo del proveedor).
  num get profit => saleTotal - costTotal;

  factory ResellerOrder.fromJson(Map<String, dynamic> j) {
    final num cost = num.tryParse('${j['totalAmount']}') ?? 0;
    return ResellerOrder(
      id: '${j['id']}',
      number: (j['providerOrderNumber'] as num?)?.toInt() ?? 0,
      status: OrderStatus.parse(j['status']),
      costTotal: cost,
      saleTotal: num.tryParse('${j['saleTotalAmount']}') ?? cost,
      createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      items: ((j['items'] as List?) ?? const <dynamic>[])
          .map(
            (e) =>
                ResellerOrderItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}
