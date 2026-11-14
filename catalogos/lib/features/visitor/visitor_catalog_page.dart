import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/brand_header.dart';
import '../buy/cart_controller.dart';
import 'cart_flow.dart';
import 'visitor_buy_page.dart' show openVisitorChat;
import 'visitor_catalogs.dart';
import 'visitor_product_page.dart';

/// Detalle de un catálogo guardado: logo del proveedor, mosaico de productos
/// con su portada a su alto real y botón explícito de añadir al carrito.
class VisitorCatalogPage extends ConsumerWidget {
  const VisitorCatalogPage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<(VisitorCatalog, List<VisitorProduct>)> async = ref.watch(
      visitorCatalogProductsProvider(code),
    );
    final VisitorCatalog? saved = ref
        .watch(visitorCatalogsProvider)
        .where((VisitorCatalog c) => c.shortUuid == code)
        .firstOrNull;
    final VisitorCatalog? catalog = async.value?.$1 ?? saved;
    final List<VisitorProduct> products =
        async.value?.$2 ?? const <VisitorProduct>[];
    final String provider =
        catalog?.providerName ?? catalog?.name ?? 'Catálogo';
    final bool noPrices = (catalog?.priceField ?? '').toLowerCase() == 'none';
    return Scaffold(
      backgroundColor: kSheetTint,
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              BrandHeader(
                title: provider,
                subtitle: catalog == null || catalog.name == provider
                    ? null
                    : catalog.name,
                titleSize: 18,
                sheetColor: kSheetTint,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    BrandHeaderButton(
                      icon: LucideIcons.chevronLeft,
                      label: 'Volver',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 10),
                    _Logo(url: catalog?.logoUrl, name: provider),
                  ],
                ),
                actions: <Widget>[
                  if (catalog != null)
                    BrandHeaderButton(
                      icon: LucideIcons.messageCircle,
                      label: 'Chatear con el proveedor',
                      onTap: () => openVisitorChat(context, ref, catalog),
                    ),
                ],
                child: Row(
                  children: <Widget>[
                    if (products.isNotEmpty)
                      _Chip(
                        '${products.length} ${products.length == 1 ? 'producto' : 'productos'}',
                      ),
                    if (products.isNotEmpty) const SizedBox(width: 6),
                    if (catalog != null)
                      _Chip(noPrices ? 'Sin precios' : 'Con precios'),
                  ],
                ),
              ),
              Expanded(
                child: async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () =>
                          ref.invalidate(visitorCatalogProductsProvider(code)),
                      child: const Text(
                        'No pudimos cargar el catálogo. Reintentar',
                      ),
                    ),
                  ),
                  data: ((VisitorCatalog, List<VisitorProduct>) d) =>
                      d.$2.isEmpty
                      ? const Center(
                          child: Text('Este catálogo aún no tiene productos.'),
                        )
                      : _Masonry(catalog: d.$1, products: d.$2),
                ),
              ),
            ],
          ),
          const Positioned(right: 18, bottom: 28, child: FloatingCartButton()),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0x2EFFFFFF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: AppColors.accent, width: 2.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: url == null || url!.isEmpty
        ? Center(
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          )
        : CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
  );
}

/// Mosaico de dos columnas: cada foto conserva su alto (no se recorta).
class _Masonry extends ConsumerWidget {
  const _Masonry({required this.catalog, required this.products});

  final VisitorCatalog catalog;
  final List<VisitorProduct> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> left = <Widget>[];
    final List<Widget> right = <Widget>[];
    for (int i = 0; i < products.length; i++) {
      (i.isEven ? left : right).add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ProductCard(catalog: catalog, product: products[i]),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Column(children: left)),
          const SizedBox(width: 10),
          Expanded(child: Column(children: right)),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.catalog, required this.product});

  final VisitorCatalog catalog;
  final VisitorProduct product;

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VisitorProductPage(catalog: catalog, product: product),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VisitorProduct p = product;
    final int from = p.priceFrom;
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: const Color(0x14001634),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (p.image == null)
              const AspectRatio(
                aspectRatio: 1,
                child: ColoredBox(color: Color(0xFFE3ECFB)),
              )
            else
              CachedNetworkImage(
                imageUrl: p.image!,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                placeholder: (_, _) => const AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(color: Color(0xFFE3ECFB)),
                ),
                errorWidget: (_, _, _) => const AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(color: Color(0xFFE3ECFB)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (from > 0)
                          Text(
                            formatCop(from),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Añadir ${p.name} al carrito',
                    child: Material(
                      color: AppColors.secondary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          // Sin color ni talla que elegir: se agrega directo con
                          // la primera cantidad del proveedor. Si no, al detalle.
                          if (p.colors.isEmpty && p.sizes.isEmpty) {
                            final int q = p.quantityOptions.first;
                            ref
                                .read(cartControllerProvider.notifier)
                                .add(cartLineFor(catalog, p, q));
                          } else {
                            _open(context);
                          }
                        },
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            LucideIcons.shoppingCart,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
