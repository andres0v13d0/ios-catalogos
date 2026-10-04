import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../domain/catalog.dart';
import '../domain/catalog_grouping.dart';
import 'shared_catalogs_controller.dart';
import 'shared_catalogs_filter.dart';

/// Pantalla principal / autenticada (tareas 1.14 y 1.15).
///
/// Al montarse, observa [sharedCatalogsControllerProvider], cuyo `build`
/// dispara el `POST /reseller/sync-shared-catalogs` (idempotente) seguido del
/// `GET /reseller/me/shared-catalogs` y aplica la caché offline
/// *stale-while-revalidate*. Muestra los catálogos **agrupados por proveedor**,
/// con filtro por proveedor (chips) y búsqueda por nombre, además de
/// pull-to-refresh. Si la lista proviene de la caché (red caída) muestra un
/// indicador sutil de "sin conexión".
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

/// Cuerpo con la lista agrupada, el filtro de proveedor, la búsqueda, el
/// indicador offline y el pull-to-refresh.
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
    );
    final List<CatalogGroup> groups = groupByProvider(filtered);

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
            child: groups.isEmpty
                ? const _EmptyBody()
                : ListView(
                    key: const Key('shared_catalogs_list'),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: <Widget>[
                      for (final CatalogGroup group in groups)
                        _ProviderSection(group: group),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Barra de chips para filtrar por proveedor (tarea 1.15).
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

/// Sección de un proveedor: encabezado (logo + nombre) + sus catálogos.
class _ProviderSection extends StatelessWidget {
  const _ProviderSection({required this.group});

  final CatalogGroup group;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    // El logo/nombre vienen en cada Catalog; dentro del grupo todos comparten
    // proveedor, así que tomamos el primero como representante.
    final Catalog representative = group.catalogs.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: <Widget>[
              _ProviderAvatar(catalog: representative),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.providerLabel,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        for (final Catalog catalog in group.catalogs)
          ListTile(
            key: Key('catalog_${catalog.id}'),
            leading: const Icon(Icons.collections_bookmark_outlined),
            title: Text(catalog.displayName),
            // La descripción del propio catálogo es más útil que repetir el
            // nombre del proveedor (ya está en el encabezado). Si no hay
            // descripción, no mostramos subtítulo.
            subtitle: (catalog.priceField == 'none')
                ? const Text('Sin precios')
                : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              // catalog.id ahora es el UUID del catálogo (no el id del vínculo),
              // por lo que el detalle llama /catalog/by-catalog/<uuid>/products.
              AppRoutes.catalogDetailPath(catalog.id),
              extra: catalog.displayName,
            ),
          ),
      ],
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
          .labelMedium
          ?.copyWith(color: colors.onSecondaryContainer),
    );

    if (logo == null || logo.trim().isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: colors.secondaryContainer,
        child: initials,
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: colors.secondaryContainer,
      child: ClipOval(
        child: Image.network(
          logo,
          width: 32,
          height: 32,
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
