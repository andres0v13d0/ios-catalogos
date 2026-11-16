import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../../core/storage/storage.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/brand_header.dart';
import 'visitor_catalogs.dart';

/// Pedido enviado desde este celular (sin cuenta). El estado se consulta al servidor.
class SavedOrder {
  const SavedOrder({
    required this.id,
    required this.number,
    required this.total,
    required this.catalogName,
    required this.createdAt,
    this.providerName,
  });

  final String id;
  final int number;
  final num total;
  final String catalogName;
  final String? providerName;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'number': number,
    'total': total,
    'catalogName': catalogName,
    'providerName': providerName,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedOrder.fromJson(Map<String, dynamic> j) => SavedOrder(
    id: j['id'] as String,
    number: (j['number'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?) ?? 0,
    catalogName: j['catalogName'] as String? ?? 'Catálogo',
    providerName: j['providerName'] as String?,
    createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
  );
}

const String _ordersKey = 'visitor_orders';

/// Historial local de pedidos del visitante (el más reciente primero).
/// shortcut: se guardan los últimos 50; no se sincroniza entre dispositivos.
class VisitorOrdersController extends Notifier<List<SavedOrder>> {
  @override
  List<SavedOrder> build() {
    final String? raw = ref.read(localCacheProvider).get(_ordersKey);
    if (raw == null) return const <SavedOrder>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (dynamic e) =>
                SavedOrder.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return const <SavedOrder>[];
    }
  }

  Future<void> add(SavedOrder o) async {
    final List<SavedOrder> next = <SavedOrder>[
      o,
      ...state.where((SavedOrder x) => x.id != o.id),
    ].take(50).toList();
    state = next;
    await ref
        .read(localCacheProvider)
        .put(
          _ordersKey,
          jsonEncode(next.map((SavedOrder x) => x.toJson()).toList()),
        );
  }
}

final NotifierProvider<VisitorOrdersController, List<SavedOrder>>
visitorOrdersProvider =
    NotifierProvider<VisitorOrdersController, List<SavedOrder>>(
      VisitorOrdersController.new,
    );

final visitorOrderProvider = FutureProvider.autoDispose
    .family<PublicOrderView, String>(
      (Ref ref, String id) =>
          ref.watch(visitorCatalogApiProvider).publicOrder(id),
    );

String _date(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Pestaña "Pedidos" del visitante: solo los pedidos hechos en este celular.
class VisitorOrdersPage extends ConsumerWidget {
  const VisitorOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SavedOrder> orders = ref.watch(visitorOrdersProvider);
    return Scaffold(
      backgroundColor: kSheetTint,
      body: Column(
        children: <Widget>[
          const BrandHeader(
            title: 'Pedidos',
            subtitle: 'Tus pedidos en este celular',
            sheetColor: kSheetTint,
          ),
          Expanded(
            child: orders.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            LucideIcons.receiptText,
                            size: 40,
                            color: Color(0xFF5B6B84),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Aún no has hecho pedidos. Cuando envíes uno desde un catálogo, lo verás aquí con su estado.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      for (final SavedOrder o in orders) {
                        ref.invalidate(visitorOrderProvider(o.id));
                      }
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, int i) => _OrderCard(order: orders[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final SavedOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PublicOrderView> async = ref.watch(
      visitorOrderProvider(order.id),
    );
    final String label = async.value?.statusLabel ?? 'Enviado';
    final bool done = async.value?.status == 'delivered';
    final bool canceled = async.value?.status == 'canceled';
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: const Color(0x14001634),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _OrderDetail(order: order),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Pedido #${order.number}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      <String>{
                        ?order.providerName,
                        order.catalogName,
                      }.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5B6B84),
                      ),
                    ),
                    Text(
                      _date(order.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A97AB),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: canceled
                          ? const Color(0xFFFDE4E4)
                          : done
                          ? const Color(0xFFD7F7E8)
                          : const Color(0xFFE3ECFB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: canceled
                            ? const Color(0xFF8A1C1C)
                            : done
                            ? const Color(0xFF0F6B41)
                            : AppColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatCop(order.total),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetail extends ConsumerWidget {
  const _OrderDetail({required this.order});

  final SavedOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PublicOrderView> async = ref.watch(
      visitorOrderProvider(order.id),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: async.when(
          loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => SizedBox(
            height: 140,
            child: Center(
              child: TextButton(
                onPressed: () => ref.invalidate(visitorOrderProvider(order.id)),
                child: const Text('No pudimos cargar el pedido. Reintentar'),
              ),
            ),
          ),
          data: (PublicOrderView v) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Pedido #${v.number}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF001634),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3ECFB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        v.statusLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[?v.providerName, ?v.catalogName].join(' · '),
                  style: const TextStyle(color: Color(0xFF5B6B84)),
                ),
                Text(
                  _date(v.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8795AB),
                  ),
                ),
                const SizedBox(height: 14),
                for (final PublicOrderItem it in v.items) _ItemTile(item: it),
                if (v.total != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '${v.items.fold<int>(0, (int a, PublicOrderItem i) => a + i.quantity)} unidades',
                          style: const TextStyle(color: Color(0xFF5B6B84)),
                        ),
                        const Spacer(),
                        Text(
                          'Total  ${formatCop(v.total!)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if ((v.notes ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        LucideIcons.stickyNote,
                        size: 16,
                        color: Color(0xFF5B6B84),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          v.notes!,
                          style: const TextStyle(color: Color(0xFF5B6B84)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de un producto del pedido: foto, nombre, variantes y precios.
class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final PublicOrderItem item;

  @override
  Widget build(BuildContext context) {
    final PublicOrderItem it = item;
    final List<String> tags = <String>[
      ?it.color,
      if (it.size != null) 'Talla ${it.size}',
    ];
    const Widget ph = ColoredBox(
      color: Color(0xFFE3ECFB),
      child: Icon(LucideIcons.image, color: Color(0xFF8795AB)),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3ECFB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: it.imageUrl == null
                  ? ph
                  : CachedNetworkImage(
                      imageUrl: it.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ph,
                      errorWidget: (_, _, _) => ph,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  it.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final String t in tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5FC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(t, style: const TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(
                      it.unitPrice == null
                          ? '${it.quantity} uds'
                          : '${it.quantity} × ${formatCop(it.unitPrice!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5B6B84),
                      ),
                    ),
                    const Spacer(),
                    if (it.totalPrice != null)
                      Text(
                        formatCop(it.totalPrice!),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
