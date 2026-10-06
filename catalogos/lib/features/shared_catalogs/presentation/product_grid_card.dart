import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/images/product_image_cache_manager.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_palette.dart';
import '../domain/catalog_detail.dart';
import 'catalog_products_icons.dart';
import 'catalog_products_palette.dart';
import 'home_palette.dart';
import 'product_thumbnail.dart';

/// Precarga la imagen de un producto (disco + memoria) sin montar ningún
/// widget — usado por [ProductGridCard]'s grid para adelantar la descarga de
/// las próximas tarjetas mientras el usuario hace scroll (ver
/// `catalog_detail_page.dart`, `_ProductsGrid`). Mismo [ProductImageCacheManager]
/// que la tarjeta, así que al llegar a pantalla ya está en disco.
Future<void> precacheProductImage(BuildContext context, String url) {
  return precacheImage(
    CachedNetworkImageProvider(url, cacheManager: ProductImageCacheManager.instance),
    context,
  );
}

/// Tarjeta de producto de la cuadrícula "Productos del catálogo" (diseño A,
/// ver `docs/design/productos-a.html`).
///
/// La etiqueta de ajuste, el precio del proveedor y el lápiz (etapa 2, ver
/// `catalog_products_flags.dart`) son opcionales: `null` = no se dibujan
/// (catálogo "sin precios", overlay aún no cargado, o producto sin regla
/// aplicable). La página decide cuándo pasarlos; esta tarjeta no conoce los
/// flags.
class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.product,
    required this.priceHidden,
    required this.onTap,
    required this.memCachePixels,
    this.markupBadgeLabel,
    this.providerPriceLowest,
    this.onEditPrice,
  });

  final Product product;

  /// `true` cuando el catálogo está en modo "sin precios"
  /// (`priceField == 'none'`): no se dibuja ninguna línea de precio.
  final bool priceHidden;

  final VoidCallback onTap;

  /// Ancho/alto (px físicos, ya `× devicePixelRatio`) al que se decodifica la
  /// imagen — el tamaño real en pantalla de la celda, calculado UNA VEZ por
  /// `_gridGeometry` (no en cada build, para no invalidar la caché de
  /// decodificación con un tamaño distinto cada vez). Ver
  /// `catalog_detail_page.dart`.
  final int memCachePixels;

  /// Etiqueta de la insignia verde (p. ej. "+30%" o "+\$5.000"). `null` = sin
  /// regla aplicable a este producto → no se dibuja.
  final String? markupBadgeLabel;

  /// Menor precio del PROVEEDOR (sin ajustar), para "Proveedor \$X". `null` =
  /// no se dibuja esa línea.
  final num? providerPriceLowest;

  /// `null` = no se dibuja el lápiz (p. ej. overlay aún no cargado).
  final VoidCallback? onEditPrice;

  @override
  Widget build(BuildContext context) {
    final num? lowest = product.lowestPrice;
    final bool showPrice = !priceHidden && lowest != null;
    final String semanticsLabel = showPrice
        ? '${product.nombre}, desde \$${formatCopPlain(lowest)}'
        : product.nombre;

    return Semantics(
      button: true,
      label: semanticsLabel,
      // Aísla el repintado de cada tarjeta: al hacer scroll o cuando una
      // imagen vecina termina de cargar, esto evita que Flutter repinte toda
      // la cuadrícula en vez de solo la celda que cambió.
      child: RepaintBoundary(
        child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: HomePalette.cardBorder),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: CatalogProductsPalette.cardShadow,
                  offset: Offset(0, 12),
                  blurRadius: 26,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: ProductThumbnail(
                          url: product.primaryThumbnail,
                          memCachePixels: memCachePixels,
                        ),
                      ),
                      if (markupBadgeLabel != null)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: _MarkupBadge(label: markupBadgeLabel!),
                        ),
                      if (onEditPrice != null)
                        Positioned(right: 6, top: 6, child: _EditPriceButton(onTap: onEditPrice!)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        product.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      if (showPrice)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text.rich(
                            TextSpan(
                              children: <InlineSpan>[
                                const TextSpan(
                                  text: 'Desde ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AuthPalette.textMuted,
                                  ),
                                ),
                                TextSpan(
                                  text: '\$${formatCopPlain(lowest)}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (providerPriceLowest != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Proveedor \$${formatCopPlain(providerPriceLowest!)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, height: 1.4, color: AuthPalette.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Insignia verde de ajuste (p. ej. "+30%"), esquina inferior izquierda de la
/// imagen (ver `docs/design/productos-a.html`).
class _MarkupBadge extends StatelessWidget {
  const _MarkupBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x5900FF94), offset: Offset(0, 6), blurRadius: 14),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
      ),
    );
  }
}

/// Botón lápiz "Ajustar el precio de este producto", esquina superior
/// derecha de la imagen (ver `docs/design/productos-a.html`).
class _EditPriceButton extends StatelessWidget {
  const _EditPriceButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ajustar el precio de este producto',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: Color(0x33001634), offset: Offset(0, 8), blurRadius: 18),
              ],
            ),
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(painter: PencilPainter(color: AppColors.primary)),
            ),
          ),
        ),
      ),
    );
  }
}
