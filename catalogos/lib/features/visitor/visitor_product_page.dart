import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../buy/cart_controller.dart';
import 'cart_flow.dart';

import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../auth/presentation/auth_state_provider.dart';
import '../shared_catalogs/presentation/catalog_price_overlay_controller.dart';
import '../shared_catalogs/domain/price_rules_contract.dart';
import 'catalog_access.dart';
import 'image_gallery.dart';
import 'visitor_buy_page.dart' show openVisitorChat;
import 'visitor_catalogs.dart';

/// Línea de carrito para [p] con la cantidad [qty] y la variante elegida.
CartLine cartLineFor(
  VisitorCatalog catalog,
  VisitorProduct p,
  int qty, {
  String? color,
  String? size,
}) => CartLine(
  catalogId: catalog.catalogId,
  catalogName: catalog.name,
  productId: p.id,
  name: p.name,
  quantity: qty,
  unitPrice: p.priceFor(qty),
  color: color,
  size: size,
  imageUrl: p.image,
  priceMap: p.prices,
  minTotal: p.minTotal,
);

/// Detalle de un producto: todas sus fotos (la portada primero), color, talla
/// y la cantidad que configura el proveedor.
class VisitorProductPage extends ConsumerStatefulWidget {
  const VisitorProductPage({
    super.key,
    required this.catalog,
    required this.product,
  });

  final VisitorCatalog catalog;
  final VisitorProduct product;

  @override
  ConsumerState<VisitorProductPage> createState() => _VisitorProductPageState();
}

class _VisitorProductPageState extends ConsumerState<VisitorProductPage> {
  final PageController _pages = PageController();
  int _page = 0;
  late int _qty = widget.product.quantityOptions.first;
  String? _color;
  String? _size;

  /// Fotos ampliadas; al cerrar, el carrusel queda en la que se estaba viendo.
  Future<void> _openGallery(List<String> imgs, int i) async {
    final int? last = await showImageGallery(context, imgs, initial: i);
    if (last != null && last != _page && _pages.hasClients) {
      _pages.jumpToPage(last);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VisitorProduct p = widget.product;
    final List<String> imgs = p.images.isNotEmpty
        ? p.images
        : <String>[?p.image];
    final bool needsChoice =
        (p.colors.isNotEmpty && _color == null) ||
        (p.sizes.isNotEmpty && _size == null);
    final int unit = p.priceFor(_qty);
    final String? accessMessage = ref
        .watch(catalogAccessProvider(widget.catalog.catalogId))
        .value
        ?.message;
    final bool mine = ref
        .watch(sharedCatalogIdsProvider)
        .contains(widget.catalog.shortUuid);
    final CatalogPriceRuleProduct? ov = mine
        ? ref
              .watch(
                catalogPriceOverlayControllerProvider(widget.catalog.catalogId),
              )
              .value
              ?.byProductId[p.id]
        : null;
    // Fondo claro: iconos de la barra de estado oscuros (si no, se pierden).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: const FloatingCartButton(),
        body: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            SizedBox(
              height: 340 + MediaQuery.paddingOf(context).top,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (imgs.isEmpty)
                    const ColoredBox(color: Color(0xFFE3ECFB))
                  else
                    PageView.builder(
                      controller: _pages,
                      itemCount: imgs.length,
                      onPageChanged: (int i) => setState(() => _page = i),
                      itemBuilder: (_, int i) => GestureDetector(
                        onTap: () => _openGallery(imgs, i),
                        child: ColoredBox(
                          color: const Color(0xFFF1F5FB),
                          // Debajo de la barra de estado, no tapada por ella.
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: MediaQuery.paddingOf(context).top,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: imgs[i],
                              fit: BoxFit.contain,
                              errorWidget: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 14,
                    top: MediaQuery.paddingOf(context).top + 8,
                    child: Material(
                      color: const Color(0xD9FFFFFF),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Volver',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          LucideIcons.chevronLeft,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  if (imgs.length > 1)
                    Positioned(
                      right: 14,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99001634),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_page + 1} / ${imgs.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (imgs.length > 1)
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  itemCount: imgs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, int i) => GestureDetector(
                    onTap: () => _pages.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                    child: Container(
                      width: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: i == _page
                              ? AppColors.secondary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: imgs[i],
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            const ColoredBox(color: Color(0xFFE3ECFB)),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.catalog.isReseller
                              ? widget.catalog.name
                              : (widget.catalog.providerName ??
                                    widget.catalog.name),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5B6B84),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Preguntar por este producto',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        iconSize: 28,
                        color: AppColors.secondary,
                        onPressed: () => openVisitorChat(
                          context,
                          ref,
                          widget.catalog,
                          product: p,
                        ),
                        icon: const Icon(LucideIcons.messageCircle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (unit > 0)
                    Text(
                      '${formatCop(unit)} por unidad',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  if (p.colors.isNotEmpty) ...<Widget>[
                    const _Label('COLOR'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String c in p.colors)
                          _Pill(
                            label: c,
                            on: _color == c,
                            onTap: () {
                              setState(() => _color = c);
                              // Si el proveedor asoció una foto a este color, mostrarla.
                              final int? photo = p.colorPhoto[c];
                              if (photo != null && _pages.hasClients) {
                                _pages.animateToPage(
                                  photo,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                  if (p.sizes.isNotEmpty) ...<Widget>[
                    const _Label('TALLA'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String s in p.sizes)
                          _Pill(
                            label: s,
                            on: _size == s,
                            onTap: () => setState(() => _size = s),
                          ),
                      ],
                    ),
                  ],
                  const _Label('CANTIDAD'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final int q in p.quantityOptions)
                        _Pill(
                          label: '$q',
                          on: q == _qty,
                          onTap: () => setState(() => _qty = q),
                        ),
                    ],
                  ),
                  if ((p.description ?? '').isNotEmpty) ...<Widget>[
                    const _Label('DESCRIPCIÓN'),
                    Text(
                      p.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF3A4A66),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x14001634),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: mine
                  ? Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (ov?.lowestAdjustedPrice != null)
                                Text(
                                  'Tu precio ${formatCop(ov!.lowestAdjustedPrice!)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              Text(
                                'Proveedor ${formatCop(p.priceFrom)} · Para pedir, usa Personalizar y comparte tu catálogo.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF5B6B84),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : accessMessage != null
                  ? Row(
                      children: <Widget>[
                        const Icon(LucideIcons.lock, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(accessMessage)),
                        const SizedBox(width: 8),
                        if (!ref.watch(isSignedInProvider))
                          FilledButton(
                            onPressed: () => context.go(AppRoutes.login),
                            child: const Text('Iniciar sesión'),
                          ),
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Subtotal',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5B6B84),
                              ),
                            ),
                            Text(
                              formatCop(unit * _qty),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: Builder(
                              builder: (BuildContext btnCtx) => FilledButton(
                                onPressed: needsChoice
                                    ? null
                                    : () {
                                        ref
                                            .read(
                                              cartControllerProvider.notifier,
                                            )
                                            .add(
                                              cartLineFor(
                                                widget.catalog,
                                                p,
                                                _qty,
                                                color: _color,
                                                size: _size,
                                              ),
                                            );
                                        flyToCart(btnCtx);
                                      },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Text(
                                  needsChoice
                                      ? 'Elige color y talla'
                                      : 'Añadir al carrito',
                                ),
                              ),
                            ),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: .4,
        color: Color(0xFF5B6B84),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: on ? AppColors.secondary : Colors.white,
    shape: StadiumBorder(
      side: BorderSide(
        color: on ? AppColors.secondary : const Color(0xFFCFE0F7),
        width: 1.5,
      ),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: on ? Colors.white : AppColors.secondary,
          ),
        ),
      ),
    ),
  );
}
