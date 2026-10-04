import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../domain/catalog_detail.dart';
import 'catalog_detail_controller.dart';
import 'catalog_detail_filter.dart';

/// Pantalla de detalle de catálogo (tareas 1.16/1.17/1.18).
///
/// Muestra el banner, la búsqueda por nombre y facetas de variante (1.17), y la
/// lista de productos con imagen(es), nombre, variantes (colores/tallas) y
/// precios por cantidad (1.16). En el modo "sin precios" muestra las cantidades
/// sin importes reales ("Precio a convenir"). Si la vista proviene de la caché
/// (red caída) muestra un indicador sutil de "sin conexión" (1.18).
class CatalogDetailPage extends ConsumerWidget {
  const CatalogDetailPage({
    super.key,
    required this.catalogId,
    this.title,
  });

  /// Id del catálogo a mostrar (viene de la navegación desde el home).
  final String catalogId;

  /// Título opcional conocido de antemano (p. ej. el nombre que mostraba la
  /// lista), usado en el AppBar mientras carga.
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CatalogDetailState> asyncState =
        ref.watch(catalogDetailControllerProvider(catalogId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          asyncState.value?.detail.displayName ?? (title ?? 'Catálogo'),
        ),
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, _) => _DetailError(
            onRetry: () => ref
                .read(catalogDetailControllerProvider(catalogId).notifier)
                .refresh(),
          ),
          data: (CatalogDetailState state) =>
              _DetailBody(catalogId: catalogId, state: state),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.catalogId, required this.state});

  final String catalogId;
  final CatalogDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CatalogDetail detail = state.detail;
    final DetailFilter filter = ref.watch(detailFilterProvider);
    final DetailFilterController filterCtrl =
        ref.read(detailFilterProvider.notifier);

    final List<String> colors = distinctColors(detail.products);
    final List<String> sizes = distinctSizes(detail.products);
    final List<Product> filtered = filterProducts(
      detail.products,
      search: filter.search,
      color: filter.color,
      size: filter.size,
    );

    Future<void> onRefresh() => ref
        .read(catalogDetailControllerProvider(catalogId).notifier)
        .refresh();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const Key('catalog_detail_scroll'),
        slivers: <Widget>[
          if (state.fromCache)
            const SliverToBoxAdapter(child: _OfflineBanner()),
          // Banner del detalle: usa la MISMA portada pública que la tarjeta de
          // la lista. Si no hay bannerUrl del catálogo, cae al logo del
          // proveedor y, en último término, a un gradiente de marca. Nunca el
          // nombre interno (el título ya usa displayName = publicName).
          SliverToBoxAdapter(
            child: _Banner(
              url: detail.bannerUrl ?? detail.logoUrl,
            ),
          ),
          if ((detail.nombreEmpresa ?? '').trim().isNotEmpty)
            SliverToBoxAdapter(child: _ProviderHeader(detail: detail)),
          if (detail.priceHidden)
            const SliverToBoxAdapter(child: _PriceHiddenNotice()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                key: const Key('catalog_detail_search_field'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar producto por nombre',
                  isDense: true,
                ),
                onChanged: filterCtrl.setSearch,
              ),
            ),
          ),
          if (colors.isNotEmpty)
            SliverToBoxAdapter(
              child: _FacetBar(
                keyPrefix: 'color',
                label: 'Color',
                options: colors,
                selected: filter.color,
                onSelected: filterCtrl.selectColor,
              ),
            ),
          if (sizes.isNotEmpty)
            SliverToBoxAdapter(
              child: _FacetBar(
                keyPrefix: 'size',
                label: 'Talla',
                options: sizes,
                selected: filter.size,
                onSelected: filterCtrl.selectSize,
              ),
            ),
          if (filtered.isEmpty)
            const SliverToBoxAdapter(child: _EmptyProducts())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) =>
                    _ProductCard(
                  product: filtered[index],
                  priceHidden: detail.priceHidden,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Banner superior del catálogo. Si [url] es nulo o la imagen falla, muestra el
/// gradiente de marca FlyStock (`#004AAD → #5DE0E6 → #00FF94`), igual que la
/// portada de respaldo de la tarjeta en la lista.
class _Banner extends StatelessWidget {
  const _Banner({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final String? src = (url ?? '').trim().isEmpty ? null : url;
    return AspectRatio(
      key: const Key('catalog_detail_banner'),
      aspectRatio: 16 / 6,
      child: src == null
          ? const _GradientBanner()
          : Image.network(
              src,
              fit: BoxFit.cover,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stack,
              ) =>
                  const _GradientBanner(),
            ),
    );
  }
}

/// Fondo con el gradiente de marca para el banner del detalle sin imagen.
class _GradientBanner extends StatelessWidget {
  const _GradientBanner();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.collections_bookmark_outlined,
          color: AppColors.onDark,
          size: 40,
        ),
      ),
    );
  }
}

/// Fila con el proveedor (logo + nombre) bajo el banner del detalle. Reutiliza
/// un avatar circular con iniciales de respaldo.
class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader({required this.detail});

  final CatalogDetail detail;

  String get _initials {
    final name = (detail.nombreEmpresa ?? '').trim();
    if (name.isEmpty) return 'PR';
    final words =
        name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'PR';
    if (words.length == 1) {
      final w = words.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String? logo = detail.logoUrl;
    final Widget initials = Text(
      _initials,
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: colors.onSecondaryContainer),
    );

    return Padding(
      key: const Key('catalog_detail_provider'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.secondaryContainer,
            child: (logo == null || logo.trim().isEmpty)
                ? initials
                : ClipOval(
                    child: Image.network(
                      logo,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stack,
                      ) =>
                          initials,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail.nombreEmpresa!.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de producto: imagen, nombre, descripción, variantes y precios.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.priceHidden});

  final Product product;
  final bool priceHidden;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Card(
      key: Key('product_${product.id}'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ProductImage(url: product.primaryImage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.nombre,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if ((product.descripcion ?? '').trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      product.descripcion!.trim(),
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (product.colores.isNotEmpty)
                    _VariantLine(
                      label: 'Colores',
                      values:
                          product.colores.map((v) => v.name).toList(),
                    ),
                  if (product.tallas.isNotEmpty)
                    _VariantLine(
                      label: 'Tallas',
                      values: product.tallas.map((v) => v.name).toList(),
                    ),
                  const SizedBox(height: 8),
                  _PriceByQuantity(
                    product: product,
                    priceHidden: priceHidden,
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 84,
        height: 84,
        child: url == null
            ? Container(
                color: colors.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.inventory_2_outlined),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) =>
                        Container(
                  color: colors.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(Icons.inventory_2_outlined),
                ),
              ),
      ),
    );
  }
}

/// Línea de variantes (colores o tallas) como texto compacto.
class _VariantLine extends StatelessWidget {
  const _VariantLine({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: ${values.join(', ')}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// Precios por cantidad. En modo "sin precios" muestra solo las cantidades con
/// un marcador "a convenir" (CA de 1.16).
class _PriceByQuantity extends StatelessWidget {
  const _PriceByQuantity({required this.product, required this.priceHidden});

  final Product product;
  final bool priceHidden;

  @override
  Widget build(BuildContext context) {
    final List<String> cantidades = product.cantidades;
    if (cantidades.isEmpty) {
      return priceHidden
          ? const Text('Precio a convenir')
          : const SizedBox.shrink();
    }

    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String qty in cantidades)
          Padding(
            key: Key('price_${product.id}_$qty'),
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('x$qty  ', style: textTheme.bodySmall),
                if (priceHidden)
                  Text(
                    'Precio a convenir',
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    formatCop(product.precios[qty] ?? 0),
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Barra horizontal de chips para una faceta (color o talla).
class _FacetBar extends StatelessWidget {
  const _FacetBar({
    required this.keyPrefix,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String keyPrefix;
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text('$label:')),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: Key('${keyPrefix}_todos'),
              label: const Text('Todos'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final String option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('${keyPrefix}_$option'),
                label: Text(option),
                selected: selected == option,
                onSelected: (_) => onSelected(option),
              ),
            ),
        ],
      ),
    );
  }
}

/// Aviso de modo "sin precios" en el encabezado del detalle.
class _PriceHiddenNotice extends StatelessWidget {
  const _PriceHiddenNotice();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('catalog_detail_price_hidden'),
      width: double.infinity,
      color: colors.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 16, color: colors.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Este catálogo no muestra precios. Consúltalos con el proveedor.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('catalog_detail_offline_banner'),
      width: double.infinity,
      color: colors.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión: mostrando datos guardados.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío (sin productos tras aplicar el filtro).
class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'No hay productos para mostrar.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Estado de error con reintento.
class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              'No pudimos cargar el catálogo.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onRetry(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
