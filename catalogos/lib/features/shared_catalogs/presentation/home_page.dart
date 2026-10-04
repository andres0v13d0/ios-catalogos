import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../domain/catalog.dart';
import '../domain/catalog_grouping.dart';
import 'shared_catalogs_controller.dart';
import 'shared_catalogs_filter.dart';

/// Pantalla principal / autenticada (tareas 1.14 y 1.15, rediseño UX).
///
/// Al montarse, observa [sharedCatalogsControllerProvider], cuyo `build`
/// dispara el `POST /reseller/sync-shared-catalogs` (idempotente) seguido del
/// `GET /reseller/me/shared-catalogs` y aplica la caché offline
/// *stale-while-revalidate*.
///
/// === REDISEÑO: el CATÁLOGO es el protagonista ===
/// En vez de agrupar por proveedor, se muestra una **lista plana de tarjetas de
/// catálogo** ([_CatalogCard]). Cada tarjeta destaca la imagen de portada del
/// catálogo (banner → ogImage → banner del proveedor → gradiente de marca) y su
/// nombre público; el proveedor aparece en una fila secundaria (logo + nombre).
/// Para revendedores con muchos proveedores se conservan el **buscador por
/// nombre** y el **filtro por proveedor** (chips). Pull-to-refresh e indicador
/// de "sin conexión" se mantienen.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SharedCatalogsState> asyncState =
        ref.watch(sharedCatalogsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogos compartidos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, _) => _ErrorBody(
            onRetry: () =>
                ref.read(sharedCatalogsControllerProvider.notifier).refresh(),
          ),
          data: (SharedCatalogsState state) => _CatalogsBody(state: state),
        ),
      ),
    );
  }
}

/// Cuerpo con la lista plana de tarjetas, el filtro de proveedor, la búsqueda,
/// el indicador offline y el pull-to-refresh.
class _CatalogsBody extends ConsumerWidget {
  const _CatalogsBody({required this.state});

  final SharedCatalogsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SharedCatalogsFilter filter =
        ref.watch(sharedCatalogsFilterProvider);
    final List<ProviderOption> providers = distinctProviders(state.catalogs);
    final List<Catalog> filtered = filterCatalogs(
      state.catalogs,
      providerId: filter.providerId,
      search: filter.search,
    )
      // Orden estable por nombre de catálogo (A→Z) para una lista plana.
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    Future<void> onRefresh() =>
        ref.read(sharedCatalogsControllerProvider.notifier).refresh();

    return Column(
      children: <Widget>[
        if (state.fromCache) const _OfflineBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            key: const Key('shared_catalogs_search_field'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar catálogo por nombre',
              isDense: true,
            ),
            onChanged: (String value) => ref
                .read(sharedCatalogsFilterProvider.notifier)
                .setSearch(value),
          ),
        ),
        if (providers.length > 1)
          _ProviderFilterBar(providers: providers, selected: filter.providerId),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: filtered.isEmpty
                ? const _EmptyBody()
                : ListView.separated(
                    key: const Key('shared_catalogs_list'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) =>
                        _CatalogCard(catalog: filtered[index]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Barra de chips para filtrar por proveedor (se mantiene en el rediseño).
class _ProviderFilterBar extends ConsumerWidget {
  const _ProviderFilterBar({required this.providers, required this.selected});

  final List<ProviderOption> providers;
  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(sharedCatalogsFilterProvider.notifier);
    return SizedBox(
      height: 48,
      child: ListView(
        key: const Key('shared_catalogs_provider_filter'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: selected == null,
              onSelected: (_) => controller.selectProvider(null),
            ),
          ),
          for (final ProviderOption option in providers)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('provider_chip_${option.id}'),
                label: Text(option.label),
                selected: selected == option.id,
                onSelected: (_) => controller.selectProvider(option.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de un catálogo (el protagonista del rediseño).
///
/// - Imagen principal = [Catalog.coverImageUrl] (banner del catálogo → portada
///   ogImage → banner del proveedor). Si no hay ninguna, un gradiente de marca
///   FlyStock ([AppColors.primaryGradient]).
/// - Título = nombre público del catálogo ([Catalog.displayName]).
/// - Fila secundaria = avatar + nombre del proveedor.
/// - Insignia "Sin precios" cuando [Catalog.isPriceHidden].
/// - Al tocar navega al detalle con el UUID del catálogo y pasa el nombre
///   público como título.
class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Card(
      key: Key('catalog_${catalog.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          // catalog.id es el UUID del catálogo (no el id del vínculo), por lo
          // que el detalle llama a /catalog/by-catalog/<uuid>/products.
          AppRoutes.catalogDetailPath(catalog.id),
          extra: catalog.displayName,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CatalogCover(catalog: catalog),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    catalog.displayName,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      _ProviderAvatar(catalog: catalog),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          catalog.providerLabel,
                          style: textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (catalog.isPriceHidden) const _NoPriceBadge(),
                    ],
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

/// Portada de la tarjeta: imagen de red (si hay) o gradiente de marca.
class _CatalogCover extends StatelessWidget {
  const _CatalogCover({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final String? url = catalog.coverImageUrl;
    return AspectRatio(
      key: Key('catalog_cover_${catalog.id}'),
      aspectRatio: 16 / 9,
      child: url == null
          ? const _GradientCover()
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stack,
              ) =>
                  const _GradientCover(),
            ),
    );
  }
}

/// Fondo con el gradiente de marca FlyStock (`#004AAD → #5DE0E6 → #00FF94`),
/// usado cuando el catálogo no tiene ninguna imagen de portada.
class _GradientCover extends StatelessWidget {
  const _GradientCover();

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
          size: 36,
        ),
      ),
    );
  }
}

/// Insignia discreta de "Sin precios".
class _NoPriceBadge extends StatelessWidget {
  const _NoPriceBadge();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('catalog_no_price_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Sin precios',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSecondaryContainer,
            ),
      ),
    );
  }
}

/// Avatar circular del proveedor: logo (si hay) con fallback a iniciales.
class _ProviderAvatar extends StatelessWidget {
  const _ProviderAvatar({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String? logo = catalog.providerLogoUrl;
    final Widget initials = Text(
      catalog.providerInitials,
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: colors.onSecondaryContainer),
    );

    if (logo == null || logo.trim().isEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: colors.secondaryContainer,
        child: initials,
      );
    }

    return CircleAvatar(
      radius: 12,
      backgroundColor: colors.secondaryContainer,
      child: ClipOval(
        child: Image.network(
          logo,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) =>
                  initials,
        ),
      ),
    );
  }
}

/// Indicador sutil de que la lista proviene de la caché (sin conexión).
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
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

/// Estado vacío (sin catálogos tras aplicar el filtro).
class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    // ListView para que el RefreshIndicator siga funcionando aun vacío.
    return ListView(
      children: <Widget>[
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No hay catálogos compartidos todavía.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// Estado de error con acción de reintento.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

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
              'No pudimos cargar tus catálogos.',
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
