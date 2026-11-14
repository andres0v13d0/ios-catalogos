import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../core/utils/money.dart';
import '../buy/cart_controller.dart';
import '../chat/chat_api.dart';
import '../../shared/widgets/brand_header.dart';
import '../shared_catalogs/domain/catalog.dart';
import '../shared_catalogs/presentation/catalog_carousel.dart';
import '../auth/presentation/auth_state_provider.dart';
import '../shared_catalogs/presentation/shared_catalogs_controller.dart';
import 'poster_catalog_card.dart';
import 'visitor_catalogs.dart';

Widget _img(String? url) => url == null || url.isEmpty
    ? const ColoredBox(color: Colors.black12)
    : CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
      );

/// Comprar para visitantes: catálogos guardados por enlace + novedades.
class VisitorBuyPage extends ConsumerWidget {
  const VisitorBuyPage({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final TextEditingController ctrl = TextEditingController();
    final String? raw = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Agregar catálogo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Pega el enlace del catálogo',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, ctrl.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty || !context.mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final VisitorCatalog? c = await ref
          .read(visitorCatalogApiProvider)
          .lookup(raw);
      if (c == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No encontramos ese catálogo.')),
        );
        return;
      }
      await ref.read(visitorCatalogsProvider.notifier).add(c);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos conectar. Intenta de nuevo.')),
      );
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    VisitorCatalog c,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: Text('¿Quitar ${c.name}?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(visitorCatalogsProvider.notifier).remove(c.shortUuid);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<VisitorCatalog> saved = ref.watch(visitorCatalogsProvider);
    final int cartCount = ref.watch(cartControllerProvider).length;
    // Con sesión, Comprar también muestra los catálogos que le asignaron al
    // revendedor (precios originales del proveedor, solo lectura).
    final List<Catalog> assigned = ref.watch(isSignedInProvider)
        ? (ref.watch(sharedCatalogsControllerProvider).value?.catalogs ??
              const <Catalog>[])
        : const <Catalog>[];
    final Set<String> assignedIds = <String>{
      for (final Catalog c in assigned) c.id,
    };
    final List<Catalog> catalogs = <Catalog>[
      ...assigned,
      for (final VisitorCatalog v in saved)
        if (!assignedIds.contains(v.catalogId)) v.toCatalog(),
    ];
    VisitorCatalog? savedOf(Catalog c) =>
        saved.where((VisitorCatalog v) => v.catalogId == c.id).firstOrNull;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          BrandHeader(
            title: 'Comprar',
            subtitle: catalogs.isEmpty
                ? 'Guarda el catálogo de tu proveedor'
                : (catalogs.length == 1
                      ? 'Toca para ver sus productos'
                      : 'Desliza para ver más'),
            actions: <Widget>[
              BrandHeaderButton(
                icon: LucideIcons.plus,
                label: 'Agregar catálogo',
                onTap: () => _add(context, ref),
              ),
              BrandHeaderButton(
                icon: LucideIcons.shoppingCart,
                label: 'Carrito',
                badge: cartCount,
                onTap: () => showCartSheet(context),
              ),
            ],
            child: const _Stories(),
          ),
          Expanded(
            child: catalogs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            LucideIcons.link,
                            size: 40,
                            color: Color(0xFF5B6B84),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aquí verás tus catálogos guardados. Pega el enlace que te compartió tu proveedor.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => _add(context, ref),
                            icon: const Icon(LucideIcons.plus),
                            label: const Text('Agregar catálogo'),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final bool compact = c.maxHeight < 520;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: CatalogCarousel(
                          catalogs: catalogs,
                          dotsHeight: catalogs.length > 1 ? 32 : 0,
                          compact: compact,
                          cardBuilder: (Catalog cat, int _, bool compact) =>
                              PosterCatalogCard(
                                key: Key('catalog_${cat.id}'),
                                catalog: cat,
                                compact: compact,
                                onTap: () => _open(
                                  context,
                                  cat,
                                  assignedIds,
                                  savedOf(cat),
                                ),
                              ),
                          onOpenCatalog: (Catalog cat) =>
                              _open(context, cat, assignedIds, savedOf(cat)),
                          onLongPressCatalog: (Catalog cat) {
                            final VisitorCatalog? v = savedOf(cat);
                            if (v != null && !assignedIds.contains(cat.id)) {
                              _remove(context, ref, v);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _open(
    BuildContext context,
    Catalog cat,
    Set<String> assignedIds,
    VisitorCatalog? saved,
  ) {
    if (assignedIds.contains(cat.id) || saved == null) {
      context.push(AppRoutes.buyCatalogPath(cat.id), extra: cat.displayName);
    } else {
      context.push(AppRoutes.visitorCatalogPath(saved.shortUuid));
    }
  }
}

typedef _Group = (VisitorCatalog, List<VisitorProduct>);

/// Fila tipo "estados": un círculo por catálogo con sus productos nuevos.
/// Los catálogos ya vistos pasan al final, no desaparecen.
class _Stories extends ConsumerWidget {
  const _Stories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<VisitorCatalog> saved = ref.watch(visitorCatalogsProvider);
    final Set<String> seen = ref.watch(visitorSeenProvider);
    // Sin catálogos guardados no hay nada que pedir al servidor.
    final AsyncValue<List<(VisitorCatalog, VisitorProduct)>>? feedAsync =
        saved.isEmpty ? null : ref.watch(visitorFeedProvider);
    final List<(VisitorCatalog, VisitorProduct)> feed =
        feedAsync?.value ?? const <(VisitorCatalog, VisitorProduct)>[];
    final List<_Group> groups = <_Group>[
      for (final VisitorCatalog c in saved)
        (
          c,
          <VisitorProduct>[
            for (final (VisitorCatalog fc, VisitorProduct p) in feed)
              if (fc.shortUuid == c.shortUuid) p,
          ],
        ),
    ];
    bool unread(_Group g) =>
        g.$2.any((VisitorProduct p) => !seen.contains(p.id));
    final List<_Group> withNew = groups
        .where((_Group g) => g.$2.isNotEmpty)
        .toList();
    // sort estable: no vistos primero, vistos después
    final List<_Group> ordered = <_Group>[
      ...withNew.where(unread),
      ...withNew.where((_Group g) => !unread(g)),
    ];
    final bool loading = (feedAsync?.isLoading ?? false) && feed.isEmpty;
    if (ordered.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Productos nuevos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          loading ? const _StorySkeleton() : const _StoryHint(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Productos nuevos',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ordered.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, int i) => _StoryCard(
              group: ordered[i],
              unread: unread(ordered[i]),
              onOpen: ordered[i].$2.isEmpty
                  ? () => context.push(
                      AppRoutes.visitorCatalogPath(ordered[i].$1.shortUuid),
                    )
                  : () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => _StoryViewer(
                          groups: ordered
                              .where((_Group g) => g.$2.isNotEmpty)
                              .toList(),
                          start: ordered[i].$1.shortUuid,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjetas "fantasma" mientras llegan los productos nuevos.
class _StorySkeleton extends StatelessWidget {
  const _StorySkeleton();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            Container(
              width: 100,
              decoration: BoxDecoration(
                color: const Color(0x24FFFFFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: Color(0x33FFFFFF),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    ),
  );
}

/// Aviso cuando todavía no hay productos nuevos (en vez de dejar el hueco).
class _StoryHint extends StatelessWidget {
  const _StoryHint();

  @override
  Widget build(BuildContext context) => Container(
    height: 84,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0x24FFFFFF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: const Row(
      children: <Widget>[
        Icon(LucideIcons.sparkles, color: Color(0xFF5DE0E6), size: 26),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            'Aquí verás los productos nuevos de tus catálogos apenas los suban.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFFE6EEFA),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StoryCard extends ConsumerWidget {
  const _StoryCard({
    required this.group,
    required this.unread,
    required this.onOpen,
  });

  final _Group group;
  final bool unread;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VisitorCatalog catalog = group.$1;
    final String? cover = group.$2.isEmpty ? null : group.$2.first.image;
    return GestureDetector(
      onTap: onOpen,
      onLongPress: () async {
        final bool? ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext d) => AlertDialog(
            title: Text('¿Quitar ${catalog.name}?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('Quitar'),
              ),
            ],
          ),
        );
        if (ok ?? false) {
          await ref
              .read(visitorCatalogsProvider.notifier)
              .remove(catalog.shortUuid);
        }
      },
      child: Opacity(
        opacity: unread || group.$2.isEmpty ? 1 : 0.7,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 100,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _img(cover ?? catalog.logoUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x33000000), Color(0xCC001634)],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: unread
                            ? const Color(0xFF00FF94)
                            : Colors.white54,
                        width: 2.5,
                      ),
                    ),
                    child: ClipOval(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: _img(catalog.logoUrl),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    catalog.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Visor a pantalla completa: toca derecha/izquierda para avanzar/retroceder,
/// avanza solo cada 5 s y marca cada producto como visto.
class _StoryViewer extends ConsumerStatefulWidget {
  const _StoryViewer({required this.groups, required this.start});

  final List<_Group> groups;
  final String start;

  @override
  ConsumerState<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<_StoryViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..addStatusListener((AnimationStatus s) {
          if (s == AnimationStatus.completed) _next();
        });
  late int _g;
  int _i = 0;

  _Group get _group => widget.groups[_g];
  VisitorProduct get _product => _group.$2[_i];

  @override
  void initState() {
    super.initState();
    _g = widget.groups.indexWhere((_Group g) => g.$1.shortUuid == widget.start);
    if (_g < 0) _g = 0;
    final Set<String> seen = ref.read(visitorSeenProvider);
    final int first = _group.$2.indexWhere(
      (VisitorProduct p) => !seen.contains(p.id),
    );
    _i = first < 0 ? 0 : first;
    _play();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _play() {
    final String id = _product.id;
    Future<void>.microtask(
      () => ref.read(visitorSeenProvider.notifier).mark(id),
    );
    _c.forward(from: 0);
    setState(() {});
  }

  void _next() {
    if (_i < _group.$2.length - 1) {
      _i++;
    } else if (_g < widget.groups.length - 1) {
      _g++;
      _i = 0;
    } else {
      Navigator.of(context).pop();
      return;
    }
    _play();
  }

  void _prev() {
    if (_i > 0) {
      _i--;
    } else if (_g > 0) {
      _g--;
      _i = 0;
    }
    _play();
  }

  Future<void> _openSheet() async {
    _c.stop();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSheet(catalog: _group.$1, product: _product),
    );
    if (mounted) _c.forward();
  }

  @override
  Widget build(BuildContext context) {
    final VisitorProduct p = _product;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (TapUpDetails d) =>
            d.globalPosition.dx < MediaQuery.sizeOf(context).width / 3
            ? _prev()
            : _next(),
        onLongPressStart: (_) => _c.stop(),
        onLongPressEnd: (_) => _c.forward(),
        onVerticalDragEnd: (DragEndDetails d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: p.image ?? '',
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: <Widget>[
                        for (int k = 0; k < _group.$2.length; k++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: AnimatedBuilder(
                                animation: _c,
                                builder: (_, _) => LinearProgressIndicator(
                                  value: k < _i
                                      ? 1
                                      : k == _i
                                      ? _c.value
                                      : 0,
                                  minHeight: 3,
                                  backgroundColor: Colors.white24,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: ClipOval(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: _img(_group.$1.logoUrl),
                      ),
                    ),
                    title: Text(
                      _group.$1.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Colors.transparent, Colors.black87],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          p.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (p.priceFrom > 0)
                          Text(
                            'Desde ${formatCop(p.priceFrom)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _openSheet,
                          child: const Text('Ver y agregar al carrito'),
                        ),
                      ],
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

class _Grid extends StatelessWidget {
  const _Grid({required this.items});

  final List<(VisitorCatalog, VisitorProduct)> items;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.72,
    ),
    itemCount: items.length,
    itemBuilder: (_, int i) =>
        _ProductCard(catalog: items[i].$1, product: items[i].$2),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.catalog, required this.product});

  final VisitorCatalog catalog;
  final VisitorProduct product;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _AddSheet(catalog: catalog, product: product),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _img(product.image)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.priceFrom > 0)
                  Text(
                    'Desde ${formatCop(product.priceFrom)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Abre el chat del catálogo. La primera vez ofrece (sin obligar) decir el nombre.
Future<void> _openChat(
  BuildContext context,
  WidgetRef ref,
  VisitorCatalog c,
) async {
  final ChatApi api = ref.read(chatApiProvider);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final GoRouter router = GoRouter.of(context);
  try {
    final String id = await api.start(c.catalogId);
    if (!api.nameAsked && context.mounted) {
      final TextEditingController ctrl = TextEditingController();
      final String? name = await showDialog<String>(
        context: context,
        builder: (BuildContext d) => AlertDialog(
          title: const Text('¿Cómo te llamas?'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Así te verá el proveedor (opcional)',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Omitir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, ctrl.text),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      await api.markNameAsked();
      if (name != null && name.trim().isNotEmpty) {
        await api.setName(name.trim()).catchError((Object _) {});
      }
    }
    unawaited(router.push(AppRoutes.conversationPath(id), extra: c.name));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir el chat. Intenta de nuevo.'),
      ),
    );
  }
}

/// Detalle de un catálogo guardado.
class VisitorCatalogPage extends ConsumerWidget {
  const VisitorCatalogPage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<(VisitorCatalog, List<VisitorProduct>)> async = ref.watch(
      visitorCatalogProductsProvider(code),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(async.value?.$1.name ?? 'Catálogo'),
        actions: <Widget>[
          if (async.value != null)
            IconButton(
              tooltip: 'Chatear con el proveedor',
              onPressed: () => _openChat(context, ref, async.value!.$1),
              icon: const Icon(LucideIcons.messageCircle),
            ),
          IconButton(
            onPressed: () => showCartSheet(context),
            icon: const Icon(LucideIcons.shoppingCart),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(visitorCatalogProductsProvider(code)),
            child: const Text('No pudimos cargar el catálogo. Reintentar'),
          ),
        ),
        data: ((VisitorCatalog, List<VisitorProduct>) d) => d.$2.isEmpty
            ? const Center(child: Text('Este catálogo aún no tiene productos.'))
            : Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: _Grid(
                    items: <(VisitorCatalog, VisitorProduct)>[
                      for (final VisitorProduct p in d.$2) (d.$1, p),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet({required this.catalog, required this.product});

  final VisitorCatalog catalog;
  final VisitorProduct product;

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  late int _qty = widget.product.minTotal;
  String? _color;
  String? _size;

  @override
  Widget build(BuildContext context) {
    final VisitorProduct p = widget.product;
    final bool needsChoice =
        (p.colors.isNotEmpty && _color == null) ||
        (p.sizes.isNotEmpty && _size == null);
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
            Text(p.name, style: Theme.of(context).textTheme.titleMedium),
            if (p.priceFor(_qty) > 0)
              Text('${formatCop(p.priceFor(_qty))} c/u'),
            if (p.colors.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _color,
                decoration: const InputDecoration(labelText: 'Color'),
                items: <DropdownMenuItem<String>>[
                  for (final String c in p.colors)
                    DropdownMenuItem<String>(value: c, child: Text(c)),
                ],
                onChanged: (String? v) => setState(() => _color = v),
              ),
            if (p.sizes.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _size,
                decoration: const InputDecoration(labelText: 'Talla'),
                items: <DropdownMenuItem<String>>[
                  for (final String s in p.sizes)
                    DropdownMenuItem<String>(value: s, child: Text(s)),
                ],
                onChanged: (String? v) => setState(() => _size = v),
              ),
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: _qty > p.minTotal
                      ? () => setState(() => _qty--)
                      : null,
                  icon: const Icon(LucideIcons.circleMinus),
                ),
                Text('$_qty'),
                IconButton(
                  onPressed: () => setState(() => _qty++),
                  icon: const Icon(LucideIcons.circlePlus),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: needsChoice
                      ? null
                      : () {
                          ref
                              .read(cartControllerProvider.notifier)
                              .add(
                                CartLine(
                                  catalogId: widget.catalog.catalogId,
                                  catalogName: widget.catalog.name,
                                  productId: p.id,
                                  name: p.name,
                                  quantity: _qty,
                                  unitPrice: p.priceFor(_qty),
                                  color: _color,
                                  size: _size,
                                ),
                              );
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Agregado al carrito'),
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

/// Carrito del visitante: datos de contacto y envío (un pedido por catálogo).
void showCartSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _CartSheet(),
);

class _CartSheet extends ConsumerStatefulWidget {
  const _CartSheet();

  @override
  ConsumerState<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<_CartSheet> {
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _celular = TextEditingController();
  final TextEditingController _ciudad = TextEditingController();
  final TextEditingController _direccion = TextEditingController();
  // Un id por catálogo, estable entre reintentos: el servidor no duplica el pedido.
  final Map<String, String> _orderIds = <String, String>{};
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _celular.dispose();
    _ciudad.dispose();
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu nombre.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final VisitorCatalogApi api = ref.read(visitorCatalogApiProvider);
    final CartController cart = ref.read(cartControllerProvider.notifier);
    final List<VisitorCatalog> saved = ref.read(visitorCatalogsProvider);
    final Map<String, List<CartLine>> byCatalog = <String, List<CartLine>>{};
    for (final CartLine l in ref.read(cartControllerProvider)) {
      byCatalog.putIfAbsent(l.catalogId, () => <CartLine>[]).add(l);
    }
    final BuyerInfo buyer = BuyerInfo(
      nombre: _nombre.text,
      celular: _celular.text,
      ciudad: _ciudad.text,
      direccion: _direccion.text,
    );
    final List<String> done = <String>[];
    String? failure;
    for (final MapEntry<String, List<CartLine>> e in byCatalog.entries) {
      final VisitorCatalog? c = saved
          .where((VisitorCatalog x) => x.catalogId == e.key)
          .firstOrNull;
      if (c == null) {
        failure = 'Un catálogo del carrito ya no está guardado.';
        continue;
      }
      try {
        final SubmittedOrder o = await api.submitOrder(
          clientOrderId: _orderIds.putIfAbsent(e.key, newUuid),
          shortUuid: c.shortUuid,
          lines: e.value,
          buyer: buyer,
        );
        done.add('${c.name} #${o.number} (${formatCop(o.total)})');
        for (final CartLine l in e.value) {
          cart.remove(l.key);
        }
      } on DioException catch (err) {
        final dynamic body = err.response?.data;
        final dynamic msg = body is Map ? body['message'] : null;
        failure = msg is String
            ? msg
            : msg is List
            ? msg.join(', ')
            : 'No pudimos enviar el pedido de ${c.name}. Intenta de nuevo.';
      }
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = failure;
    });
    if (done.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pedido enviado: ${done.join(', ')}')),
      );
    }
    if (failure == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final List<CartLine> lines = ref.watch(cartControllerProvider);
    final num total = lines.fold<num>(
      0,
      (num s, CartLine l) => s + (l.unitPrice ?? 0) * l.quantity,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: lines.isEmpty
            ? const SizedBox(
                height: 120,
                child: Center(child: Text('Tu carrito está vacío')),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Carrito',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final CartLine l in lines)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${l.quantity} × ${l.name}'),
                            subtitle: Text(
                              <String>[
                                l.catalogName,
                                ?l.color,
                                ?l.size,
                              ].join(' · '),
                            ),
                            trailing: IconButton(
                              icon: const Icon(LucideIcons.trash2),
                              onPressed: () => ref
                                  .read(cartControllerProvider.notifier)
                                  .remove(l.key),
                            ),
                          ),
                        const Divider(),
                        TextField(
                          controller: _nombre,
                          decoration: const InputDecoration(
                            labelText: 'Tu nombre *',
                          ),
                        ),
                        TextField(
                          controller: _celular,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Celular',
                          ),
                        ),
                        TextField(
                          controller: _ciudad,
                          decoration: const InputDecoration(
                            labelText: 'Ciudad',
                          ),
                        ),
                        TextField(
                          controller: _direccion,
                          decoration: const InputDecoration(
                            labelText: 'Dirección',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Total estimado: ${formatCop(total)} (el servidor confirma el precio final)',
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: Text(_sending ? 'Enviando…' : 'Enviar pedido'),
                  ),
                ],
              ),
      ),
    );
  }
}
