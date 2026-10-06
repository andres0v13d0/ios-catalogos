import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_gradient_button.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import '../domain/catalog.dart';
import '../domain/catalog_detail.dart';
import '../domain/price_rule_calculator.dart';
import '../domain/price_rules_contract.dart';
import '../domain/reseller_banner.dart';
import 'catalog_design_tokens.dart';
import 'catalog_detail_controller.dart';
import 'catalog_detail_filter.dart';
import 'catalog_price_overlay_controller.dart';
import 'catalog_products_header.dart';
import 'price_adjustment_controller.dart';
import 'product_grid_card.dart';
import 'reseller_share_sheet.dart';
import 'shared_catalogs_controller.dart';

/// Pantalla "Productos del catálogo" (diseño A, ver
/// `docs/design/productos-a.html`) — reemplaza el detalle de catálogo
/// anterior. Etapa 1 (ver `catalog_products_flags.dart`): solo ver
/// productos con lo que el backend ya entrega vía
/// `GET /catalog/by-catalog/:id/products` (mismo endpoint/caché/offline que
/// ya usaba el detalle anterior, sin cambios de red ni caché).
class CatalogDetailPage extends ConsumerStatefulWidget {
  const CatalogDetailPage({super.key, required this.catalogId, this.title});

  /// Id del catálogo a mostrar (viene de la navegación desde el home).
  final String catalogId;

  /// Título opcional conocido de antemano (p. ej. el nombre que mostraba la
  /// lista), usado en la cabecera mientras carga.
  final String? title;

  @override
  ConsumerState<CatalogDetailPage> createState() => _CatalogDetailPageState();
}

class _CatalogDetailPageState extends ConsumerState<CatalogDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounce de ~250ms: filtra sobre lo ya cargado, sin pedir nada a la red.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _search = value);
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// El detalle de producto se diseña en otra etapa; de momento no hace nada.
  void _openProduct(Product product) {}

  /// Tras guardar/quitar una regla (vuelve `true` de "Ajustar precios"):
  /// invalida la caché Hive de este catálogo y recarga productos + overlay,
  /// para que la cuadrícula muestre los precios nuevos.
  Future<void> _afterPriceRuleChange() async {
    await ref.read(localCacheProvider).delete(catalogDetailCacheKey(widget.catalogId));
    ref.invalidate(catalogDetailControllerProvider(widget.catalogId));
    ref.invalidate(catalogPriceOverlayControllerProvider(widget.catalogId));
  }

  Future<void> _openCatalogWideAdjust(int totalProducts) async {
    final bool? changed = await context.push<bool>(
      AppRoutes.adjustPricesPath(widget.catalogId),
      extra: PriceAdjustmentArgs(catalogId: widget.catalogId, totalProductsHint: totalProducts),
    );
    if (changed ?? false) {
      await _afterPriceRuleChange();
    }
  }

  Future<void> _openProductAdjust(
    Product product,
    int totalProducts,
    CatalogPriceRuleProduct? overlayProduct,
  ) async {
    if (overlayProduct == null) return; // overlay aún no cargado: el lápiz no se dibuja en ese caso
    final bool? changed = await context.push<bool>(
      AppRoutes.adjustPricesPath(widget.catalogId),
      extra: PriceAdjustmentArgs(
        catalogId: widget.catalogId,
        totalProductsHint: totalProducts,
        singleProduct: overlayProduct,
      ),
    );
    if (changed ?? false) {
      await _afterPriceRuleChange();
    }
  }

  /// Busca el [Catalog] de este detalle en la lista de catálogos compartidos
  /// (fuente del `enlace`, `ogImageUrl` propio y la imagen del proveedor).
  /// Devuelve `null` si aún no está en la lista (p. ej. apertura por deep link
  /// antes de cargar el home).
  Catalog? _catalogFromList() {
    final listState = ref.read(sharedCatalogsControllerProvider).value;
    final catalogs = listState?.catalogs ?? const <Catalog>[];
    for (final c in catalogs) {
      if (c.id == widget.catalogId) return c;
    }
    return null;
  }

  /// Arma el estado para las pantallas de banner/compartir a partir del detalle
  /// cargado, el [Catalog] de la lista y el overlay de reglas de precio.
  ResellerBannerState _bannerStateFor(CatalogDetail detail, CatalogPriceOverlayState overlay) {
    final Catalog? c = _catalogFromList();
    // Banner PROPIO del revendedor = ogImageUrl de su fila hija (null si no subió).
    final String? ownBanner = c?.ogImageUrl;
    // Imagen del proveedor para la vista previa cuando no hay banner propio.
    final String? providerImage = c?.bannerUrl ?? c?.providerBannerUrl ?? detail.bannerUrl ?? c?.providerLogoUrl;
    // Hay reglas de precio si el overlay trae regla de catálogo o de producto.
    final bool hasRules = overlay.catalogRule != null || overlay.byProductId.isNotEmpty;

    return ResellerBannerState(
      catalogId: widget.catalogId,
      shareLink: (c?.enlace ?? '').trim(),
      publicName: detail.displayName,
      hasPriceRules: hasRules,
      ownBannerUrl: (ownBanner ?? '').trim().isEmpty ? null : ownBanner,
      providerImageUrl: (providerImage ?? '').trim().isEmpty ? null : providerImage,
    );
  }

  Future<void> _openBanner(CatalogDetail detail, CatalogPriceOverlayState overlay) async {
    await context.push<void>(
      AppRoutes.bannerPath(widget.catalogId),
      extra: _bannerStateFor(detail, overlay),
    );
    // Al volver, refrescar la lista para reflejar el banner nuevo/quitado.
    ref.invalidate(sharedCatalogsControllerProvider);
  }

  void _openShareSheet(CatalogDetail detail, CatalogPriceOverlayState overlay) {
    showResellerShareSheet(
      context,
      banner: _bannerStateFor(detail, overlay),
      onChangeBanner: () => _openBanner(detail, overlay),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CatalogDetailState> asyncState = ref.watch(
      catalogDetailControllerProvider(widget.catalogId),
    );

    Future<void> onRefresh() => ref
        .read(catalogDetailControllerProvider(widget.catalogId).notifier)
        .refresh();

    final String fallbackTitle = widget.title ?? 'Catálogo';

    // No se usa `AsyncValue.when` directamente: ver la misma nota en
    // `home_page.dart` (Riverpod 3.x reintenta un `build()` fallido
    // manteniendo `isLoading == true`; comprobar `hasError` primero muestra
    // el error de inmediato).
    // Cabecera para los estados de carga/error: aún no hay detalle ni overlay,
    // así que las acciones de banner/compartir no hacen nada todavía (los
    // accesos apenas se ven en esos estados). Se activan con el detalle cargado.
    Widget hero({required String title, required String subtitle}) => CatalogProductsHero(
      title: title,
      subtitle: subtitle,
      onBack: _goBack,
      onShare: () {},
      showAdjustPrices: false,
      adjustPricesBadge: null,
      onAdjustPrices: () {},
      onImageLink: () {},
      onShareLink: () {},
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Builder(
            builder: (BuildContext context) {
              if (asyncState.hasError) {
                return _Scaffold(
                  hero: hero(title: fallbackTitle, subtitle: ''),
                  body: _ErrorBody(onRetry: onRefresh),
                  onRefresh: onRefresh,
                );
              }

              final CatalogDetailState? state = asyncState.value;
              if (asyncState.isLoading || state == null) {
                return _Scaffold(
                  hero: hero(title: fallbackTitle, subtitle: ''),
                  body: const _SkeletonGrid(),
                  onRefresh: null,
                );
              }

              final CatalogDetail detail = state.detail;
              final int total = detail.products.length;
              final List<Product> filtered = filterProducts(
                detail.products,
                search: _search,
              );

              // El overlay (precio del proveedor + origen de regla) solo
              // tiene sentido si el catálogo SÍ muestra precios: en modo "sin
              // precios" ni se pide (evitaría un 409) ni se dibuja nada.
              final CatalogPriceOverlayState overlay = detail.priceHidden
                  ? CatalogPriceOverlayState.empty
                  : ref.watch(catalogPriceOverlayControllerProvider(widget.catalogId)).value ??
                        CatalogPriceOverlayState.empty;

              return _Scaffold(
                hero: CatalogProductsHero(
                  title: detail.displayName,
                  subtitle: '$total producto${total == 1 ? '' : 's'}',
                  onBack: _goBack,
                  onShare: () => _openShareSheet(detail, overlay),
                  showAdjustPrices: !detail.priceHidden,
                  adjustPricesBadge: overlay.catalogRule == null ? null : _ruleBadgeLabel(overlay.catalogRule!),
                  onAdjustPrices: () => _openCatalogWideAdjust(total),
                  onImageLink: () => _openBanner(detail, overlay),
                  onShareLink: () => _openShareSheet(detail, overlay),
                ),
                offlineNotice: state.fromCache,
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                body: total == 0
                    ? const _EmptyBody(
                        message: 'Este catálogo aún no tiene productos.',
                      )
                    : (filtered.isEmpty
                          ? const _EmptyBody(
                              message: 'Sin resultados para tu búsqueda.',
                            )
                          : _ProductsGrid(
                              products: filtered,
                              priceHidden: detail.priceHidden,
                              overlay: overlay,
                              onTap: _openProduct,
                              onEditPrice: (Product p) =>
                                  _openProductAdjust(p, total, overlay.byProductId[p.id]),
                            )),
                onRefresh: onRefresh,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Composición común a todos los estados: cabecera curva + aviso offline
/// (opcional) + buscador (opcional, oculto en carga/error) + cuerpo (sliver).
/// Un único `CustomScrollView` para toda la pantalla (sin scroll anidado).
class _Scaffold extends StatelessWidget {
  const _Scaffold({
    required this.hero,
    required this.body,
    required this.onRefresh,
    this.offlineNotice = false,
    this.searchController,
    this.onSearchChanged,
  });

  /// Cabecera + fila de accesos rápidos (ver [CatalogProductsHero]).
  final Widget hero;

  /// Sliver de contenido (grilla, esqueleto, error o vacío).
  final Widget body;

  final Future<void> Function()? onRefresh;
  final bool offlineNotice;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final Widget scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Colchón moderado para que la cuadrícula construya (y por tanto
      // empiece a descargar) unas pocas filas más allá de lo visible, sin
      // llegar a inflar de golpe media pantalla extra de imágenes.
      //
      // `cacheExtent` está deprecado a favor de `scrollCacheExtent`, pero
      // `ScrollCacheExtent` (rendering/viewport.dart) todavía no se reexporta
      // desde ningún barrel público (`material.dart`/`widgets.dart`/
      // `rendering.dart`) en este SDK — es inalcanzable sin un import
      // `src/` interno, así que se mantiene `cacheExtent` hasta que el SDK
      // exponga el reemplazo.
      // ignore: deprecated_member_use
      cacheExtent: 400,
      slivers: <Widget>[
        SliverToBoxAdapter(child: hero),
        if (offlineNotice) const SliverToBoxAdapter(child: _OfflineBanner()),
        if (searchController != null && onSearchChanged != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: _SearchField(
                controller: searchController!,
                onChanged: onSearchChanged!,
              ),
            ),
          ),
        body,
      ],
    );

    if (onRefresh == null) return scrollView;
    return RefreshIndicator(onRefresh: onRefresh!, child: scrollView);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Buscar producto',
      child: Container(
        key: const Key('catalog_products_search_field'),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: CatalogTokens.searchBackground,
          border: Border.all(color: CatalogTokens.cardBorder, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.search, size: 20, color: CatalogTokens.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Buscar producto',
                  hintStyle: TextStyle(color: CatalogTokens.searchHint),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Geometría de la cuadrícula: columnas (2 en móvil, más en pantallas
/// anchas), proporción de la tarjeta (imagen 1:1 + bloque de texto a su alto
/// natural, calculado — no fijo, ver cabecera del archivo), el relleno
/// horizontal que centra el contenido con un ancho máximo razonable en
/// tablet/horizontal, y el tamaño (px físicos) al que decodificar la imagen
/// de cada tarjeta — el de la celda real, no el original de la imagen
/// (tarea de rendimiento: evita decodificar a 2000px algo que se pinta en
/// ~150px). Se calcula UNA sola vez aquí, nunca por tarjeta, para que todas
/// pidan el mismo tamaño y compartan la misma entrada de caché decodificada.
({
  int columns,
  double aspectRatio,
  double horizontalPadding,
  int memCachePixels,
})
_gridGeometry(BuildContext context, {required bool priceHidden}) {
  const double basePadding = 20;
  const double gridGap = 14;
  const double maxContentWidth = 900;
  const double cardPadding = 8;
  const double imageAspect = 1; // 1:1, ver docs/design/productos-a.html

  final double screenWidth = MediaQuery.sizeOf(context).width;
  final int columns = screenWidth >= 900 ? 4 : (screenWidth >= 600 ? 3 : 2);
  final double contentWidth = screenWidth < maxContentWidth
      ? screenWidth
      : maxContentWidth;
  final double horizontalPadding =
      basePadding + (screenWidth - contentWidth) / 2;
  final double gridAreaWidth = contentWidth - basePadding * 2;
  final double columnWidth =
      (gridAreaWidth - gridGap * (columns - 1)) / columns;

  // Alto del bloque de texto a partir del propio contenido (nombre de hasta
  // 2 líneas + "Desde $X"), con el mismo tope de textScaler (1.3x) que el
  // resto de la app — nunca una altura de tarjeta fija.
  final double textScale = MediaQuery.textScalerOf(context)
      .scale(1.0)
      .clamp(1.0, 1.3);
  final double innerWidth = columnWidth - cardPadding * 2;
  final double imageHeight = innerWidth * imageAspect;
  final double nameBlockHeight = 34.0 * textScale;
  // "Desde $X" (margen 6 + ~24) y, SIEMPRE que el catálogo muestre precios,
  // se reserva además la línea "Proveedor $X" (margen 2 + 11×1.4). Se reserva
  // aunque un producto concreto no tenga ajuste visible: todas las tarjetas de
  // una fila deben tener la MISMA altura, y reservar de más nunca desborda.
  final double priceBlockHeight = priceHidden ? 0.0 : (6.0 + 24.0 * textScale);
  final double providerLineHeight = priceHidden ? 0.0 : (2.0 + 11.0 * 1.4 * textScale);
  final double textBlockHeight = 10 + nameBlockHeight + priceBlockHeight + providerLineHeight + 4;
  // +10: margen de seguridad (métricas reales de fuente/plataforma varían
  // un poco respecto a esta estimación; mejor un pelín de aire de más que
  // arriesgar un overflow de 1-2px).
  final double cardHeight =
      cardPadding * 2 + imageHeight + textBlockHeight + 10;

  // Tamaño físico de decodificación: el ancho de la imagen (cuadrada, 1:1)
  // en dp × devicePixelRatio, redondeado. Así una imagen de 2000px se
  // decodifica a, p. ej., ~340px físicos en vez de su tamaño completo.
  final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  final int memCachePixels = (innerWidth * devicePixelRatio).round();

  return (
    columns: columns,
    aspectRatio: columnWidth / cardHeight,
    horizontalPadding: horizontalPadding,
    memCachePixels: memCachePixels,
  );
}

class _ProductsGrid extends StatelessWidget {
  const _ProductsGrid({
    required this.products,
    required this.priceHidden,
    required this.overlay,
    required this.onTap,
    required this.onEditPrice,
  });

  final List<Product> products;
  final bool priceHidden;

  /// Precio del proveedor + origen de regla por producto (ver
  /// `CatalogProductsFlags.showMarkupBadge`/`.showProviderPrice`/
  /// `.showPerProductEdit`); vacío = esos elementos no se dibujan.
  final CatalogPriceOverlayState overlay;

  final ValueChanged<Product> onTap;
  final ValueChanged<Product> onEditPrice;

  /// Cuántas imágenes más allá de la que se está construyendo se precargan
  /// (disco + memoria) mientras el usuario hace scroll.
  static const int _precacheLookahead = 6;

  @override
  Widget build(BuildContext context) {
    final geometry = _gridGeometry(context, priceHidden: priceHidden);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        geometry.horizontalPadding,
        8,
        geometry.horizontalPadding,
        24,
      ),
      sliver: SliverGrid(
        key: const Key('catalog_products_grid'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: geometry.columns,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: geometry.aspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final Product product = products[index];
            _precacheUpcoming(context, index);
            final CatalogPriceRuleProduct? overlayProduct = overlay.byProductId[product.id];
            // Solo hay "ajuste" visible cuando el precio ajustado DIFIERE del
            // del proveedor (hay regla efectiva con efecto real). Sin esa
            // diferencia no se dibujan ni la etiqueta verde ni la línea
            // "Proveedor $X": la tarjeta muestra únicamente "Desde $X" (ver
            // productos-a.html / regla del prompt).
            final bool hasVisibleMarkup = _hasVisibleMarkup(overlayProduct);
            return ProductGridCard(
              key: ValueKey<String>(product.id),
              product: product,
              priceHidden: priceHidden,
              memCachePixels: geometry.memCachePixels,
              onTap: () => onTap(product),
              markupBadgeLabel: hasVisibleMarkup ? _overlayBadgeLabel(overlayProduct!) : null,
              providerPriceLowest: hasVisibleMarkup ? overlayProduct!.lowestProviderPrice : null,
              onEditPrice: overlayProduct != null ? () => onEditPrice(product) : null,
            );
          },
          childCount: products.length,
          // Permite a Flutter reubicar una tarjeta por su `Key` cuando su
          // índice cambia (p. ej. al filtrar por búsqueda) en vez de
          // destruirla y reconstruirla: el debounce de búsqueda reordena
          // las tarjetas que siguen visibles en vez de recargar su imagen.
          findChildIndexCallback: (Key key) {
            final String id = (key as ValueKey<String>).value;
            final int index = products.indexWhere((Product p) => p.id == id);
            return index == -1 ? null : index;
          },
        ),
      ),
    );
  }

  /// Precarga (disco + memoria) las próximas [_precacheLookahead] imágenes a
  /// partir de [index], mientras esa tarjeta entra en construcción (scroll
  /// hacia abajo): para cuando el usuario llegue a verlas, ya están listas.
  /// `precacheImage` resuelve al instante si la URL ya está cacheada, así
  /// que repetir la llamada en cada build no tiene costo real.
  void _precacheUpcoming(BuildContext context, int index) {
    final int end = (index + _precacheLookahead + 1).clamp(0, products.length);
    for (int i = index + 1; i < end; i++) {
      final String? url = products[i].primaryThumbnail;
      if (url != null && url.trim().isNotEmpty) {
        unawaited(precacheProductImage(context, url));
      }
    }
  }
}

/// Esqueleto con la forma de la cuadrícula mientras carga.
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final geometry = _gridGeometry(context, priceHidden: false);
    return SliverPadding(
      key: const Key('catalog_products_skeleton'),
      padding: EdgeInsets.fromLTRB(
        geometry.horizontalPadding,
        8,
        geometry.horizontalPadding,
        24,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: geometry.columns,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: geometry.aspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) => const _SkeletonCard(),
          childCount: geometry.columns * 3,
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CatalogTokens.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FC),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  height: 13,
                  width: double.infinity,
                  color: const Color(0xFFF4F8FC),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 13,
                  width: 80,
                  color: const Color(0xFFF4F8FC),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 17,
                  width: 70,
                  color: const Color(0xFFF4F8FC),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador sutil de que la vista proviene de la caché (sin conexión).
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('catalog_products_offline_banner'),
      width: double.infinity,
      color: const Color(0xFFF4F8FC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: <Widget>[
          Icon(Icons.cloud_off, size: 16, color: CatalogTokens.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión: mostrando catálogo guardado.',
              style: TextStyle(fontSize: 12, color: CatalogTokens.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío: catálogo sin productos, o sin resultados de búsqueda.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      key: const Key('catalog_products_empty'),
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: CatalogTokens.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de error con reintento.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      key: const Key('catalog_products_error'),
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: 40,
                color: CatalogTokens.textMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                'No pudimos cargar los productos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: AuthGradientButton(
                  label: 'Reintentar',
                  iconPainter: const ArrowForwardPainter(
                    color: AppColors.primary,
                  ),
                  enabled: true,
                  loading: false,
                  onPressed: () => onRetry(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta "+30%"/"+\$5.000" de una regla exacta (usada en el acceso rápido,
/// donde sí se conoce la regla de catálogo completa).
String _ruleBadgeLabel(PriceRule rule) =>
    rule.mode == PriceRuleMode.percent ? '+${rule.value}%' : '+\$${formatCopPlain(rule.value)}';

/// Etiqueta de la insignia por producto de la cuadrícula: el listado
/// paginado del backend (`GET /reseller/app/catalogs/:id/products`) solo
/// entrega `reglaOrigen` (quién manda), no el modo/valor exacto de esa
/// regla — se deriva el porcentaje real a partir de precioProveedor vs.
/// precioAjustado (válido sea la regla de catálogo o de producto, y sea
/// porcentaje o valor fijo).
String? _overlayBadgeLabel(CatalogPriceRuleProduct product) {
  final num? provider = product.lowestProviderPrice;
  final num? adjusted = product.lowestAdjustedPrice;
  if (provider == null || adjusted == null || provider <= 0) return null;
  final int pct = (((adjusted - provider) / provider) * 100).round();
  if (pct <= 0) return null;
  return '+$pct%';
}

/// `true` solo si el producto tiene un ajuste con efecto REAL: hay regla
/// efectiva (`reglaOrigen != null`) y el precio ajustado es ESTRICTAMENTE
/// mayor que el del proveedor. Sin diferencia (mismo precio, o sin regla) no
/// se dibujan ni la etiqueta "+X%" ni la línea "Proveedor $X".
bool _hasVisibleMarkup(CatalogPriceRuleProduct? product) {
  if (product == null || product.reglaOrigen == null) return false;
  final num? provider = product.lowestProviderPrice;
  final num? adjusted = product.lowestAdjustedPrice;
  if (provider == null || adjusted == null) return false;
  return adjusted > provider;
}
