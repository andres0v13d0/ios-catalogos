import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_gradient_button.dart';
import '../../auth/presentation/auth_palette.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import '../domain/catalog_detail.dart';
import 'catalog_detail_controller.dart';
import 'catalog_detail_filter.dart';
import 'catalog_products_header.dart';
import 'home_palette.dart';
import 'product_grid_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CatalogDetailState> asyncState = ref.watch(
      catalogDetailControllerProvider(widget.catalogId),
    );

    Future<void> onRefresh() => ref
        .read(catalogDetailControllerProvider(widget.catalogId).notifier)
        .refresh();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomePalette.screenBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double t = ((constraints.maxHeight - 640) / (844 - 640))
                  .clamp(0.0, 1.0);
              final double headerHeight = 176 + (200 - 176) * t;
              final String fallbackTitle = widget.title ?? 'Catálogo';

              // No se usa `AsyncValue.when` directamente: ver la misma nota
              // en `home_page.dart` (Riverpod 3.x reintenta un `build()`
              // fallido manteniendo `isLoading == true`; comprobar `hasError`
              // primero muestra el error de inmediato).
              if (asyncState.hasError) {
                return _Scaffold(
                  headerHeight: headerHeight,
                  title: fallbackTitle,
                  subtitle: '',
                  onBack: _goBack,
                  body: _ErrorBody(onRetry: onRefresh),
                  onRefresh: onRefresh,
                );
              }

              final CatalogDetailState? state = asyncState.value;
              if (asyncState.isLoading || state == null) {
                return _Scaffold(
                  headerHeight: headerHeight,
                  title: fallbackTitle,
                  subtitle: '',
                  onBack: _goBack,
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

              return _Scaffold(
                headerHeight: headerHeight,
                title: detail.displayName,
                subtitle: '$total producto${total == 1 ? '' : 's'}',
                onBack: _goBack,
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
                              onTap: _openProduct,
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
    required this.headerHeight,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.body,
    required this.onRefresh,
    this.offlineNotice = false,
    this.searchController,
    this.onSearchChanged,
  });

  final double headerHeight;
  final String title;
  final String subtitle;
  final VoidCallback onBack;

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
        SliverToBoxAdapter(
          child: CatalogProductsHeader(
            height: headerHeight,
            title: title,
            subtitle: subtitle,
            onBack: onBack,
          ),
        ),
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
          color: AuthPalette.countryFieldBackground,
          border: Border.all(color: HomePalette.cardBorder, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.search, size: 20, color: AuthPalette.textMuted),
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
                  hintStyle: TextStyle(color: AuthPalette.hint),
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
  final double priceBlockHeight = priceHidden ? 0.0 : (6.0 + 24.0 * textScale);
  final double textBlockHeight = 10 + nameBlockHeight + priceBlockHeight + 4;
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
    required this.onTap,
  });

  final List<Product> products;
  final bool priceHidden;
  final ValueChanged<Product> onTap;

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
            return ProductGridCard(
              key: ValueKey<String>(product.id),
              product: product,
              priceHidden: priceHidden,
              memCachePixels: geometry.memCachePixels,
              onTap: () => onTap(product),
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
        border: Border.all(color: HomePalette.cardBorder),
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
          Icon(Icons.cloud_off, size: 16, color: AuthPalette.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión: mostrando catálogo guardado.',
              style: TextStyle(fontSize: 12, color: AuthPalette.textMuted),
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
                color: AuthPalette.textMuted,
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
                color: AuthPalette.textMuted,
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
