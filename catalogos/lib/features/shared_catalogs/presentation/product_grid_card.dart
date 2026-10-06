import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/images/product_image_cache_manager.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_palette.dart';
import '../domain/catalog_detail.dart';
import 'catalog_products_palette.dart';
import 'home_palette.dart';

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
/// Etapa 1 (ver `catalog_products_flags.dart`): solo imagen + nombre +
/// "Desde $X". El lápiz de ajuste, la etiqueta "+30%" y "Proveedor $X" quedan
/// detrás de sus flags — sin UI propia todavía, así que no se dibuja nada en
/// su lugar (ver comentarios en el punto de uso).
class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.product,
    required this.priceHidden,
    required this.onTap,
    required this.memCachePixels,
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _ProductThumbnail(
                            url: product.primaryThumbnail,
                            memCachePixels: memCachePixels,
                          ),
                        ),
                      ),
                      // Etapa 2: etiqueta "+30%" (bottom-left) y botón lápiz
                      // "Ajustar el precio de este producto" (top-right) van
                      // aquí, sobre la imagen, detrás de
                      // CatalogProductsFlags.showMarkupBadge /
                      // .showPerProductEdit.
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
                      // Etapa 2: "Proveedor $X" va aquí, detrás de
                      // CatalogProductsFlags.showProviderPrice.
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

/// Imagen principal del producto (cover, sin deformarse). Si no hay imagen o
/// falla la carga, cae a un cuadro con ícono — nunca al gradiente de marca
/// (ese es solo el respaldo de banners, no de fotos de producto).
class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.url, required this.memCachePixels});

  final String? url;
  final int memCachePixels;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return const _ProductImageFallback();
    }
    return CachedNetworkImage(
      imageUrl: url!,
      cacheManager: ProductImageCacheManager.instance,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // Decodifica al tamaño real de la celda (no al tamaño original de la
      // imagen, que puede llegar a 2000px) — calculado una sola vez por
      // `_gridGeometry`, nunca recalculado por build para no invalidar la
      // caché de decodificación.
      memCacheWidth: memCachePixels,
      memCacheHeight: memCachePixels,
      fadeInDuration: const Duration(milliseconds: 150),
      // Al reciclar la tarjeta (p. ej. tras filtrar la búsqueda) sigue
      // mostrando la imagen anterior mientras llega la nueva, en vez de un
      // parpadeo al marcador.
      useOldImageOnUrlChange: true,
      placeholder: (BuildContext context, String url) =>
          const _ProductImagePlaceholder(),
      errorWidget:
          (BuildContext context, String url, Object error) =>
              const _ProductImageFallback(),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFF4F8FC)),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFF4F8FC)),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: AuthPalette.textMuted,
          size: 36,
        ),
      ),
    );
  }
}
