import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/images/product_image_cache_manager.dart';
import '../../core/utils/money.dart';
import '../visitor/visitor_buy_page.dart';
import 'cart_controller.dart';
import '../shared_catalogs/domain/catalog_detail.dart';
import '../shared_catalogs/presentation/catalog_detail_controller.dart';
import '../shared_catalogs/presentation/catalog_price_overlay_controller.dart';

/// Pestaña "Comprar": igual para todos (visitante o revendedor): los
/// catálogos que guardó por enlace y sus productos nuevos. Los catálogos que
/// le asignaron sus proveedores al revendedor viven en "Vender".
class BuyPage extends StatelessWidget {
  const BuyPage({super.key});

  @override
  Widget build(BuildContext context) => const VisitorBuyPage();
}

/// Productos de un catálogo con el precio original del proveedor.
class BuyCatalogPage extends ConsumerWidget {
  const BuyCatalogPage({super.key, required this.catalogId, this.title});

  final String catalogId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CatalogDetailState> async = ref.watch(
      catalogDetailControllerProvider(catalogId),
    );
    // El precio del proveedor solo lo da el overlay del revendedor; si falla,
    // queda vacío y la pantalla sigue funcionando sin precio.
    final CatalogPriceOverlayState overlay =
        ref.watch(catalogPriceOverlayControllerProvider(catalogId)).value ??
        CatalogPriceOverlayState.empty;
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Catálogo')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(catalogDetailControllerProvider(catalogId)),
            child: const Text('No pudimos cargar el catálogo. Reintentar'),
          ),
        ),
        data: (CatalogDetailState s) {
          final CatalogDetail d = s.detail;
          if (d.products.isEmpty) {
            return const Center(
              child: Text('Este catálogo aún no tiene productos.'),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: d.products.length,
            itemBuilder: (_, int i) {
              final Product p = d.products[i];
              final num? price = d.priceHidden
                  ? null
                  : (overlay.byProductId[p.id]?.lowestProviderPrice ??
                        p.lowestPrice);
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _AddToCartSheet(
                      catalogId: catalogId,
                      catalogName: title ?? 'Catálogo',
                      product: p,
                      unitPrice: price,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: _Thumb(url: p.primaryThumbnail)),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              p.nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (price != null && price > 0)
                              Text(
                                'Desde ${formatCop(price)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Elige cantidad/color/talla y agrega al carrito. El mínimo por producto lo
/// valida el servidor al enviar el pedido.
class _AddToCartSheet extends ConsumerStatefulWidget {
  const _AddToCartSheet({
    required this.catalogId,
    required this.catalogName,
    required this.product,
    required this.unitPrice,
  });

  final String catalogId;
  final String catalogName;
  final Product product;
  final num? unitPrice;

  @override
  ConsumerState<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends ConsumerState<_AddToCartSheet> {
  int _qty = 1;
  String? _color;
  String? _size;

  @override
  Widget build(BuildContext context) {
    final Product p = widget.product;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(p.nombre, style: Theme.of(context).textTheme.titleMedium),
            if (widget.unitPrice != null && widget.unitPrice! > 0)
              Text('Desde ${formatCop(widget.unitPrice!)}'),
            if (p.colores.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _color,
                decoration: const InputDecoration(labelText: 'Color'),
                items: <DropdownMenuItem<String>>[
                  for (final Variant v in p.colores)
                    DropdownMenuItem<String>(
                      value: v.name,
                      child: Text(v.name),
                    ),
                ],
                onChanged: (String? v) => setState(() => _color = v),
              ),
            if (p.tallas.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _size,
                decoration: const InputDecoration(labelText: 'Talla'),
                items: <DropdownMenuItem<String>>[
                  for (final Variant v in p.tallas)
                    DropdownMenuItem<String>(
                      value: v.name,
                      child: Text(v.name),
                    ),
                ],
                onChanged: (String? v) => setState(() => _size = v),
              ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(LucideIcons.circleMinus),
                ),
                Text('$_qty', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  onPressed: () => setState(() => _qty++),
                  icon: const Icon(LucideIcons.circlePlus),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(cartControllerProvider.notifier)
                        .add(
                          CartLine(
                            catalogId: widget.catalogId,
                            catalogName: widget.catalogName,
                            productId: p.id,
                            name: p.nombre,
                            quantity: _qty,
                            unitPrice: widget.unitPrice,
                            color: _color,
                            size: _size,
                          ),
                        );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Agregado al carrito (Pedidos → Mis compras)',
                        ),
                      ),
                    );
                  },
                  child: const Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = ColoredBox(
      color: Colors.black12,
      child: Center(
        child: Icon(LucideIcons.image, size: 32),
      ),
    );
    final Widget child = url == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url!,
            cacheManager: ProductImageCacheManager.instance,
            fit: BoxFit.cover,
            width: double.infinity,
            errorWidget: (_, _, _) => placeholder,
          );
    return child;
  }
}
