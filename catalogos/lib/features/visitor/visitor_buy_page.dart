import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../core/utils/money.dart';
import '../buy/cart_controller.dart';
import '../chat/chat_api.dart';
import '../chat/conversation_page.dart';
import '../../shared/widgets/brand_header.dart';
import '../shared_catalogs/domain/catalog.dart';
import '../shared_catalogs/presentation/catalog_carousel.dart';
import 'add_catalog_sheet.dart';
import 'cart_flow.dart';
import 'visitor_product_page.dart';
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
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? saved = await showAddCatalogSheet(context);
    if (saved ?? false) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Catálogo agregado a Comprar.')),
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
    // Los que le comparten sus proveedores (revendedor) y los que agregó con un enlace.
    final List<VisitorCatalog> saved = ref.watch(buyCatalogsProvider);
    final Set<String> sharedIds = ref.watch(sharedCatalogIdsProvider);
    final int cartCount = ref.watch(cartControllerProvider).length;
    final List<Catalog> catalogs = <Catalog>[
      for (final VisitorCatalog v in saved) v.toCatalog(),
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
                onTap: () => openCart(context, ref),
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
                          cardBuilder: (Catalog cat, int _, bool compact) {
                            final Widget card = PosterCatalogCard(
                              key: Key('catalog_${cat.id}'),
                              catalog: cat,
                              compact: compact,
                              onTap: () => _open(context, savedOf(cat)),
                            );
                            if (!sharedIds.contains(cat.id)) return card;
                            // Compartido por un proveedor: se puede personalizar
                            // (precios de venta, banner, compartir).
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Flexible(child: card),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => context.push(
                                      AppRoutes.catalogDetailPath(cat.id),
                                      extra: cat.displayName,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.slidersHorizontal,
                                      size: 18,
                                    ),
                                    label: const Text('Personalizar'),
                                  ),
                                ),
                              ],
                            );
                          },
                          onOpenCatalog: (Catalog cat) =>
                              _open(context, savedOf(cat)),
                          onLongPressCatalog: (Catalog cat) {
                            final VisitorCatalog? v = savedOf(cat);
                            if (v != null && !sharedIds.contains(cat.id)) {
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

  void _open(BuildContext context, VisitorCatalog? saved) {
    if (saved != null) {
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
    final List<VisitorCatalog> saved = ref.watch(buyCatalogsProvider);
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
        // Los que te compartió un proveedor no se quitan desde aquí.
        if (ref.read(sharedCatalogIdsProvider).contains(catalog.catalogId)) {
          return;
        }
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            VisitorProductPage(catalog: _group.$1, product: _product),
      ),
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

/// Abre el chat del catálogo. La primera vez ofrece (sin obligar) decir el nombre.
Future<void> openVisitorChat(
  BuildContext context,
  WidgetRef ref,
  VisitorCatalog c, {
  VisitorProduct? product,
}) async {
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
    // Pregunta por un producto: la tarjeta queda como primer mensaje.
    if (product != null) {
      await api.sendProduct(id, productChatPayload(c, product));
    }
    unawaited(
      router.push(
        AppRoutes.conversationPath(id),
        extra: ConversationInfo(
          title: c.name,
          subtitle: c.providerName,
          logoUrl: c.logoUrl,
          catalogId: c.catalogId,
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir el chat. Intenta de nuevo.'),
      ),
    );
  }
}
