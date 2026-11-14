import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/brand_header.dart';
import '../domain/reseller_order.dart';
import '../../buy/cart_controller.dart';
import 'orders_controller.dart';
import 'purchases_controller.dart';

/// Pestaña "Pedidos": Recibidos (de mis clientes) y Mis compras (próximamente).
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  bool _purchases = false;
  OrderStatus? _filter; // null = todos

  @override
  Widget build(BuildContext context) {
    final List<ResellerOrder> orders =
        ref.watch(resellerOrdersControllerProvider).value ??
        const <ResellerOrder>[];
    int count(OrderStatus s) =>
        orders.where((ResellerOrder o) => o.status == s).length;
    return Scaffold(
      backgroundColor: kSheetTint,
      body: Column(
        children: <Widget>[
          BrandHeader(
            title: 'Pedidos',
            sheetColor: kSheetTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    BrandChip(
                      label: 'Recibidos',
                      on: !_purchases,
                      onTap: () => setState(() => _purchases = false),
                    ),
                    const SizedBox(width: 8),
                    BrandChip(
                      label: 'Mis compras',
                      on: _purchases,
                      onTap: () => setState(() => _purchases = true),
                    ),
                  ],
                ),
                if (!_purchases) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      BrandKpi(
                        '${count(OrderStatus.pending)}',
                        'Por confirmar',
                      ),
                      const SizedBox(width: 8),
                      BrandKpi(
                        '${count(OrderStatus.confirmed)}',
                        'Confirmados',
                      ),
                      const SizedBox(width: 8),
                      BrandKpi('${count(OrderStatus.delivered)}', 'Entregados'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _purchases
                ? const Center(child: Text('Próximamente'))
                : _ReceivedOrders(
                    filter: _filter,
                    onFilter: (OrderStatus? s) => setState(() => _filter = s),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReceivedOrders extends ConsumerWidget {
  const _ReceivedOrders({required this.filter, required this.onFilter});

  final OrderStatus? filter;
  final ValueChanged<OrderStatus?> onFilter;

  static bool _open(OrderStatus s) =>
      s == OrderStatus.pending ||
      s == OrderStatus.confirmed ||
      s == OrderStatus.preparing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ResellerOrder>> async = ref.watch(
      resellerOrdersControllerProvider,
    );
    return Column(
      children: <Widget>[
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: <Widget>[
              _chip('Todos', filter == null, () => onFilter(null)),
              for (final OrderStatus s in OrderStatus.values)
                _chip(s.label, filter == s, () => onFilter(s)),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, _) => Center(
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(resellerOrdersControllerProvider),
                child: const Text('No pudimos cargar los pedidos. Reintentar'),
              ),
            ),
            data: (List<ResellerOrder> all) {
              final List<ResellerOrder> orders = filter == null
                  ? all
                  : all.where((ResellerOrder o) => o.status == filter).toList();
              final List<Widget> rows = <Widget>[];
              void section(String title, List<ResellerOrder> l) {
                if (l.isEmpty) return;
                rows.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .5,
                        color: Color(0xFF5B6B84),
                      ),
                    ),
                  ),
                );
                rows.addAll(l.map((ResellerOrder o) => _OrderCard(order: o)));
              }

              if (filter == null) {
                section(
                  'EN CURSO',
                  orders.where((ResellerOrder o) => _open(o.status)).toList(),
                );
                section(
                  'CERRADOS',
                  orders.where((ResellerOrder o) => !_open(o.status)).toList(),
                );
              } else {
                rows.addAll(
                  orders.map((ResellerOrder o) => _OrderCard(order: o)),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref
                    .read(resellerOrdersControllerProvider.notifier)
                    .refresh(),
                child: orders.isEmpty
                    ? ListView(
                        children: const <Widget>[
                          SizedBox(height: 120),
                          Center(child: Text('No hay pedidos aquí')),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: rows,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: on ? AppColors.secondary : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: on ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final ResellerOrder order;

  static (Color, Color) _pill(OrderStatus s) => switch (s) {
    OrderStatus.pending => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
    OrderStatus.confirmed => (const Color(0xFFE3ECFB), AppColors.secondary),
    OrderStatus.preparing => (const Color(0xFFE0F6F8), const Color(0xFF0F6B73)),
    OrderStatus.delivered => (const Color(0xFFD7F7E8), const Color(0xFF0F6B41)),
    OrderStatus.canceled => (const Color(0xFFFDE4E4), const Color(0xFF8A1C1C)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (Color bg, Color fg) = _pill(order.status);
    final DateTime d = order.createdAt.toLocal();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: const Color(0x14001634),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _OrderSheet(orderId: order.id),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Pedido #${order.number}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        order.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.items.length} producto(s) · ${d.day}/${d.month}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5B6B84),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatCop(order.saleTotal),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderSheet extends ConsumerStatefulWidget {
  const _OrderSheet({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<_OrderSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _set(OrderStatus s) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? err = await ref
        .read(resellerOrdersControllerProvider.notifier)
        .setStatus(widget.orderId, s);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ResellerOrder? order = ref
        .watch(resellerOrdersControllerProvider)
        .value
        ?.where((ResellerOrder o) => o.id == widget.orderId)
        .firstOrNull;
    if (order == null) return const SizedBox.shrink();
    final bool canAct =
        order.status == OrderStatus.pending ||
        order.status == OrderStatus.confirmed;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Pedido #${order.number}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(order.status.label),
            const Divider(height: 24),
            for (final ResellerOrderItem it in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${it.quantity} × ${it.name}'
                  '${[it.color, it.size].whereType<String>().isEmpty ? '' : ' (${[it.color, it.size].whereType<String>().join(' · ')})'}'
                  ' — ${formatCop(it.saleUnitPrice * it.quantity)}',
                ),
              ),
            const Divider(height: 24),
            Text('Total cliente: ${formatCop(order.saleTotal)}'),
            Text('Costo proveedor: ${formatCop(order.costTotal)}'),
            Text(
              'Tu ganancia: ${formatCop(order.profit)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (canAct) ...<Widget>[
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  if (order.status == OrderStatus.pending)
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _set(OrderStatus.confirmed),
                        child: const Text('Confirmar pedido'),
                      ),
                    ),
                  if (order.status == OrderStatus.pending)
                    const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _set(OrderStatus.canceled),
                      child: const Text('Anular'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Mis compras": carrito pendiente de enviar + pedidos ya enviados a proveedores.
class _MyPurchases extends ConsumerStatefulWidget {
  const _MyPurchases();

  @override
  ConsumerState<_MyPurchases> createState() => _MyPurchasesState();
}

class _MyPurchasesState extends ConsumerState<_MyPurchases> {
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final String? err = await ref
        .read(purchasesControllerProvider.notifier)
        .submitCart();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<CartLine> cart = ref.watch(cartControllerProvider);
    final AsyncValue<List<ResellerOrder>> sent = ref.watch(
      purchasesControllerProvider,
    );
    final num estimate = cart.fold<num>(
      0,
      (num a, CartLine l) => a + (l.unitPrice ?? 0) * l.quantity,
    );
    return RefreshIndicator(
      onRefresh: () => ref.read(purchasesControllerProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          Text('Carrito', style: Theme.of(context).textTheme.titleMedium),
          if (cart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Vacío. Agrega productos desde la pestaña Comprar.'),
            )
          else
            Card(
              child: Column(
                children: <Widget>[
                  for (final CartLine l in cart)
                    ListTile(
                      title: Text('${l.quantity} × ${l.name}'),
                      subtitle: Text(
                        <String>[l.catalogName, ?l.color, ?l.size].join(' · '),
                      ),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.trash2),
                        onPressed: () => ref
                            .read(cartControllerProvider.notifier)
                            .remove(l.key),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Total estimado: ${formatCop(estimate)} (el servidor confirma el precio final)',
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _sending ? null : _send,
                            child: Text(
                              _sending ? 'Enviando…' : 'Enviar pedido',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text('Enviados', style: Theme.of(context).textTheme.titleMedium),
          sent.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, _) => TextButton(
              onPressed: () => ref.invalidate(purchasesControllerProvider),
              child: const Text('No pudimos cargar tus compras. Reintentar'),
            ),
            data: (List<ResellerOrder> orders) => orders.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aún no has enviado pedidos.'),
                  )
                : Column(
                    children: <Widget>[
                      for (final ResellerOrder o in orders)
                        Card(
                          child: ExpansionTile(
                            title: Text(
                              'Pedido #${o.number} · ${formatCop(o.costTotal)}',
                            ),
                            subtitle: Text(o.status.label),
                            children: <Widget>[
                              for (final ResellerOrderItem it in o.items)
                                ListTile(
                                  dense: true,
                                  title: Text('${it.quantity} × ${it.name}'),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
