import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_gradient_button.dart';
import '../../auth/presentation/auth_palette.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import '../domain/catalog_detail.dart';
import '../domain/price_rules_contract.dart';
import 'catalog_detail_controller.dart';
import 'catalog_detail_page.dart' show overlayBadgeLabel, hasVisibleMarkup;
import 'catalog_design_tokens.dart';
import 'catalog_price_overlay_controller.dart';
import 'price_adjustment_controller.dart';
import 'product_thumbnail.dart';

/// Argumentos de navegación de [ProductDetailPage]. El [product] ya viene
/// completo desde la cuadrícula (mismo objeto que carga `CatalogDetailPage`;
/// no se vuelve a pedir nada a la red para abrir este detalle).
class ProductDetailArgs {
  const ProductDetailArgs({
    required this.catalogId,
    required this.product,
    required this.priceHidden,
    required this.totalProducts,
  });

  final String catalogId;
  final Product product;

  /// `true` si el catálogo está en modo "sin precios" (`priceField == 'none'`).
  final bool priceHidden;

  /// Total de productos del catálogo, igual que en `PriceAdjustmentArgs`
  /// (hint para la pantalla de "Ajustar precios").
  final int totalProducts;
}

/// Detalle de producto: fotos, colores, tallas y precios — todo de SOLO
/// LECTURA salvo el precio de venta, que se edita reabriendo la MISMA
/// pantalla de "Ajustar precios" que ya usa el lápiz de la cuadrícula (fuente
/// única de esa lógica; aquí no se reimplementa).
class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.args});

  final ProductDetailArgs args;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  final PageController _imageController = PageController();
  int _imageIndex = 0;

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// Igual que `CatalogDetailPage._afterPriceRuleChange`: invalida la caché
  /// Hive y los controladores para que la cuadrícula y este detalle reflejen
  /// el precio nuevo al volver de "Ajustar precios".
  Future<void> _afterPriceRuleChange() async {
    final String catalogId = widget.args.catalogId;
    await ref.read(localCacheProvider).delete(catalogDetailCacheKey(catalogId));
    ref.invalidate(catalogDetailControllerProvider(catalogId));
    ref.invalidate(catalogPriceOverlayControllerProvider(catalogId));
  }

  Future<void> _openEditPrice(CatalogPriceRuleProduct overlayProduct) async {
    final bool? changed = await context.push<bool>(
      AppRoutes.adjustPricesPath(widget.args.catalogId),
      extra: PriceAdjustmentArgs(
        catalogId: widget.args.catalogId,
        totalProductsHint: widget.args.totalProducts,
        singleProduct: overlayProduct,
      ),
    );
    if (changed ?? false) {
      await _afterPriceRuleChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Product product = widget.args.product;
    final bool priceHidden = widget.args.priceHidden;

    // Mismo overlay (precio del proveedor + origen de regla) que la
    // cuadrícula, para que la insignia/el botón de editar sean consistentes
    // con lo que el revendedor ya vio ahí.
    final CatalogPriceOverlayState overlay = priceHidden
        ? CatalogPriceOverlayState.empty
        : ref.watch(catalogPriceOverlayControllerProvider(widget.args.catalogId)).value ??
              CatalogPriceOverlayState.empty;
    final CatalogPriceRuleProduct? overlayProduct = overlay.byProductId[product.id];
    final bool showMarkup = hasVisibleMarkup(overlayProduct);

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final int memCachePixels = (screenWidth * MediaQuery.devicePixelRatioOf(context)).round();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(title: product.nombre, onBack: _goBack),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ImageGallery(
                      images: product.imagenes,
                      controller: _imageController,
                      memCachePixels: memCachePixels,
                      currentIndex: _imageIndex,
                      onPageChanged: (int i) => setState(() => _imageIndex = i),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            product.nombre,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          if (!priceHidden) ...<Widget>[
                            const SizedBox(height: 14),
                            _PriceSection(
                              product: product,
                              overlayProduct: showMarkup ? overlayProduct : null,
                              badgeLabel: showMarkup ? overlayBadgeLabel(overlayProduct!) : null,
                            ),
                          ],
                          if (product.colores.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 20),
                            _VariantSection(title: 'Color', variants: product.colores),
                          ],
                          if (product.tallas.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 20),
                            _VariantSection(title: 'Talla', variants: product.tallas),
                          ],
                          if ((product.descripcion ?? '').trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 20),
                            const Text(
                              'Descripción',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              product.descripcion!.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AuthPalette.textMuted,
                              ),
                            ),
                          ],
                          if (!priceHidden && overlayProduct != null) ...<Widget>[
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: AuthGradientButton(
                                label: 'Editar precio',
                                iconPainter: const ArrowForwardPainter(color: AppColors.primary),
                                enabled: true,
                                loading: false,
                                onPressed: () => _openEditPrice(overlayProduct),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabecera simple: botón "Volver" + nombre del producto (1 línea).
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: <Widget>[
          Semantics(
            button: true,
            label: 'Volver',
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carrusel de fotos del producto (1:1, igual criterio de recorte que la
/// cuadrícula — ver [ProductThumbnail]) con puntos indicadores.
class _ImageGallery extends StatelessWidget {
  const _ImageGallery({
    required this.images,
    required this.controller,
    required this.memCachePixels,
    required this.currentIndex,
    required this.onPageChanged,
  });

  final List<ProductImage> images;
  final PageController controller;
  final int memCachePixels;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final int count = images.isEmpty ? 1 : images.length;
    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: count,
            itemBuilder: (BuildContext context, int index) {
              final String? url = images.isEmpty ? null : images[index].detailUrl;
              return ProductThumbnail(
                url: url,
                memCachePixels: memCachePixels,
                borderRadius: 0,
                fallbackIconSize: 64,
              );
            },
          ),
        ),
        if (count > 1) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(count, (int i) {
              final bool active = i == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.secondary : CatalogTokens.cardBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Precio de venta (solo lectura aquí) por cantidad disponible, más el precio
/// del proveedor y la insignia de ajuste cuando aplica — mismos datos que la
/// cuadrícula, sin duplicar su cálculo (ver `overlayBadgeLabel`/`hasVisibleMarkup`
/// en `catalog_detail_page.dart`).
class _PriceSection extends StatelessWidget {
  const _PriceSection({
    required this.product,
    required this.overlayProduct,
    required this.badgeLabel,
  });

  final Product product;
  final CatalogPriceRuleProduct? overlayProduct;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final List<String> cantidades = product.cantidades;
    if (cantidades.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: <Widget>[
            Text(
              '\$${formatCopPlain(product.lowestPrice ?? 0)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            if (badgeLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
          ],
        ),
        if (overlayProduct?.lowestProviderPrice != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            'Proveedor \$${formatCopPlain(overlayProduct!.lowestProviderPrice!)}',
            style: const TextStyle(fontSize: 12, color: AuthPalette.textMuted),
          ),
        ],
        if (cantidades.length > 1 && product.hasRealPrices) ...<Widget>[
          const SizedBox(height: 10),
          ...cantidades.map((String cantidad) {
            final num precio = product.precios[cantidad] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Desde $cantidad unidad${cantidad == '1' ? '' : 'es'}: \$${formatCopPlain(precio)}',
                style: const TextStyle(fontSize: 12, color: AuthPalette.textMuted),
              ),
            );
          }),
        ],
      ],
    );
  }
}

/// Fila de opciones de solo lectura (colores o tallas): "Color" / "Talla" +
/// pastillas con cada nombre. Sin selección: el revendedor no compra ni
/// reserva inventario desde aquí.
class _VariantSection extends StatelessWidget {
  const _VariantSection({required this.title, required this.variants});

  final String title;
  final List<Variant> variants;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: variants
              .map(
                (Variant v) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: CatalogTokens.searchBackground,
                    border: Border.all(color: CatalogTokens.cardBorder),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    v.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
