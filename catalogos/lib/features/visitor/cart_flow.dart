import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/brand_header.dart';
import '../../core/result/result.dart';
import '../auth/presentation/auth_state_provider.dart';
import '../buy/cart_controller.dart';
import '../orders/data/purchases_repository.dart';
import '../orders/presentation/purchases_controller.dart';
import 'catalog_access.dart';
import 'order_message.dart';
import 'visitor_orders.dart';
import 'visitor_catalogs.dart';

/// Un pedido por catálogo: el carrito se agrupa y cada grupo se completa aparte.
Map<String, List<CartLine>> cartByCatalog(List<CartLine> lines) {
  final Map<String, List<CartLine>> m = <String, List<CartLine>>{};
  for (final CartLine l in lines) {
    m.putIfAbsent(l.catalogId, () => <CartLine>[]).add(l);
  }
  return m;
}

/// Punto de entrada del carrito (botón flotante o ícono de la cabecera):
/// con un solo catálogo va directo a su pedido; con varios, muestra la lista.
Future<void> openCart(BuildContext context, WidgetRef ref) async {
  final Map<String, List<CartLine>> groups = cartByCatalog(
    ref.read(cartControllerProvider),
  );
  if (groups.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Tu carrito está vacío.')));
    return;
  }
  if (groups.length == 1) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderSummaryPage(catalogId: groups.keys.first),
      ),
    );
    return;
  }
  final String? chosen = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: const Color(0x8015171C),
    builder: (_) => const _CartListSheet(),
  );
  if (chosen != null && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderSummaryPage(catalogId: chosen),
      ),
    );
  }
}

String _initials(String s) {
  final List<String> w = s
      .trim()
      .split(RegExp(r'\s+'))
      .where((String x) => x.isNotEmpty)
      .toList();
  if (w.isEmpty) return '?';
  if (w.length == 1) {
    return w.first.substring(0, w.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (w[0][0] + w[1][0]).toUpperCase();
}

/// Botón flotante del carrito con la cantidad de referencias; se oculta vacío.
/// Al agregar algo, "salta" y el contador se ilumina (en vez de un aviso aparte).
// Botones de carrito vivos (catálogo y producto pueden coexistir): el último es el visible.
final List<GlobalKey> _fabs = <GlobalKey>[];

/// Estrella fugaz desde [from] hasta el botón del carrito. Llamar después de
/// agregar: espera un frame porque el botón aparece con el primer producto.
void flyToCart(BuildContext from) {
  final RenderBox? src = from.findRenderObject() as RenderBox?;
  if (src == null || !src.attached) return;
  final Offset start = src.localToGlobal(src.size.center(Offset.zero));
  final OverlayState overlay = Overlay.of(from);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final RenderBox? dst = _fabs.isEmpty
        ? null
        : _fabs.last.currentContext?.findRenderObject() as RenderBox?;
    if (dst == null || !dst.attached || !overlay.mounted) return;
    final Offset end = dst.localToGlobal(dst.size.center(Offset.zero));
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) =>
          _ShootingStar(start: start, end: end, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  });
}

class _ShootingStar extends StatefulWidget {
  const _ShootingStar({
    required this.start,
    required this.end,
    required this.onDone,
  });

  final Offset start;
  final Offset end;
  final VoidCallback onDone;

  @override
  State<_ShootingStar> createState() => _ShootingStarState();
}

class _ShootingStarState extends State<_ShootingStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Trayectoria curva: control a mitad de camino y más arriba.
  Offset _at(double t) {
    final Offset c = Offset(
      (widget.start.dx + widget.end.dx) / 2,
      math.min(widget.start.dy, widget.end.dy) - 120,
    );
    final double u = 1 - t;
    return widget.start * (u * u) + c * (2 * u * t) + widget.end * (t * t);
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        final double t = Curves.easeIn.transform(_c.value);
        return Stack(
          children: <Widget>[
            // Estela: puntos que se encogen y se desvanecen detrás de la estrella.
            for (int i = 6; i >= 1; i--)
              if (t - i * 0.03 >= 0)
                _dot(_at(t - i * 0.03), 14.0 - i * 1.8, 0.5 - i * 0.07),
            _dot(_at(t), 18, 1, star: true),
          ],
        );
      },
    ),
  );

  Widget _dot(Offset o, double size, double opacity, {bool star = false}) =>
      Positioned(
        left: o.dx - size,
        top: o.dy - size,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Icon(
            star ? Icons.star_rounded : Icons.circle,
            size: size * 2,
            color: star ? AppColors.accent : AppColors.brand,
          ),
        ),
      );
}

class FloatingCartButton extends ConsumerStatefulWidget {
  const FloatingCartButton({super.key});

  @override
  ConsumerState<FloatingCartButton> createState() => _FloatingCartButtonState();
}

class _FloatingCartButtonState extends ConsumerState<FloatingCartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fabs.add(_fabKey);
  }

  @override
  void dispose() {
    _fabs.remove(_fabKey);
    _bump.dispose();
    super.dispose();
  }

  static int _units(List<CartLine> l) =>
      l.fold(0, (int a, CartLine x) => a + x.quantity);

  @override
  Widget build(BuildContext context) {
    ref.listen<List<CartLine>>(cartControllerProvider, (
      List<CartLine>? prev,
      List<CartLine> next,
    ) {
      if (_units(next) > _units(prev ?? const <CartLine>[])) {
        _bump.forward(from: 0);
      }
    });
    final int n = ref.watch(cartControllerProvider).length;
    if (n == 0) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: 'Carrito, $n productos',
      child: AnimatedBuilder(
        animation: _bump,
        builder: (BuildContext context, Widget? child) {
          // 0→1: sube a 1.25 y vuelve; el contador pasa de verde a su color.
          final double t = _bump.value;
          final double scale = 1 + 0.25 * math.sin(t * math.pi);
          return Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                child!,
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        AppColors.brand,
                        AppColors.accent,
                        math.sin(t * math.pi),
                      ),
                      shape: n > 9 ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: n > 9 ? BorderRadius.circular(11) : null,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '$n',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Material(
          key: _fabKey,
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => openCart(context, ref),
            child: const SizedBox(
              width: 60,
              height: 60,
              child: Center(
                child: Icon(
                  LucideIcons.shoppingCart,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista "Tus pedidos pendientes" (varios catálogos en el carrito).
class _CartListSheet extends ConsumerWidget {
  const _CartListSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, List<CartLine>> groups = cartByCatalog(
      ref.watch(cartControllerProvider),
    );
    final List<VisitorCatalog> saved = ref.watch(visitorCatalogsProvider);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5DCE8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 2),
                    child: Text(
                      'Tus pedidos pendientes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Text(
                      'Completa un pedido por catálogo',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5B6B84)),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final MapEntry<String, List<CartLine>> e
                            in groups.entries)
                          _CartRow(
                            lines: e.value,
                            catalog: saved
                                .where(
                                  (VisitorCatalog c) => c.catalogId == e.key,
                                )
                                .firstOrNull,
                            onTap: () => Navigator.of(context).pop(e.key),
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

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.lines,
    required this.catalog,
    required this.onTap,
  });

  final List<CartLine> lines;
  final VisitorCatalog? catalog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = catalog?.providerName ?? lines.first.catalogName;
    final num total = lines.fold<num>(
      0,
      (num s, CartLine l) => s + l.lineTotal,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: <Widget>[
            _LogoCircle(
              url: catalog?.logoUrl,
              label: _initials(name),
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '${lines.first.catalogName} · ${lines.length} ${lines.length == 1 ? 'producto' : 'productos'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B6B84),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatCop(total),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: Color(0xFF9AA8BF),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoCircle extends StatelessWidget {
  const _LogoCircle({this.url, required this.label, required this.size});

  final String? url;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.secondary,
    ),
    clipBehavior: Clip.antiAlias,
    alignment: Alignment.center,
    child: url == null || url!.isEmpty
        ? Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          )
        : CachedNetworkImage(
            imageUrl: url!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) =>
                Text(label, style: const TextStyle(color: Colors.white)),
          ),
  );
}

/// Resumen de UN pedido (un catálogo): cantidades, nombre y nota opcionales.
class OrderSummaryPage extends ConsumerStatefulWidget {
  const OrderSummaryPage({super.key, required this.catalogId});

  final String catalogId;

  @override
  ConsumerState<OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends ConsumerState<OrderSummaryPage> {
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _nota = TextEditingController();
  // Estable entre reintentos: el servidor no duplica el pedido.
  final String _orderId = newUuid();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _pickQuantity(CartLine l) async {
    final int? q = await showModalBottomSheet<int>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Cantidad',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            for (final int o in l.quantityOptions)
              ListTile(
                title: Text('$o und'),
                trailing: Text(
                  l.priceMap.isEmpty
                      ? ''
                      : '${formatCop(l.priceFor(o) ?? 0)} c/u',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: o == l.quantity,
                onTap: () => Navigator.of(c).pop(o),
              ),
          ],
        ),
      ),
    );
    if (q != null) {
      ref.read(cartControllerProvider.notifier).setQuantity(l.key, q);
    }
  }

  Future<void> _send(VisitorCatalog? catalog, List<CartLine> lines) async {
    final String? denied = (await ref.read(
      catalogAccessProvider(widget.catalogId).future,
    )).message;
    if (!mounted) return;
    if (denied != null) {
      setState(() => _error = denied);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState nav = Navigator.of(context);
    // El catálogo se identifica por los 8 primeros caracteres de su id (igual que
    // la web): el pedido sale aunque el catálogo ya no esté en la lista guardada.
    final String shortUuid =
        catalog?.shortUuid ?? widget.catalogId.substring(0, 8);
    final String catalogName = catalog?.name ?? lines.first.catalogName;
    final String? providerName = catalog?.providerName;
    try {
      final SubmittedOrder o;
      if (ref.read(isSignedInProvider)) {
        // Revendedor con sesión: el pedido queda en su cuenta ("Mis compras").
        final Result<SubmittedOrder> res = await ref
            .read(purchasesRepositoryProvider)
            .submitOne(_orderId, lines, notes: _nota.text);
        switch (res) {
          case Ok<SubmittedOrder>(:final value):
            o = value;
            ref.invalidate(purchasesControllerProvider);
          case Err<SubmittedOrder>(:final failure):
            if (!mounted) return;
            setState(() {
              _sending = false;
              _error = failure.message;
            });
            return;
        }
      } else {
        o = await ref
            .read(visitorCatalogApiProvider)
            .submitOrder(
              clientOrderId: _orderId,
              shortUuid: shortUuid,
              lines: lines,
              buyer: BuyerInfo(nombre: _nombre.text),
              notes: _nota.text,
            );
        // Sin cuenta: se guarda en el celular para verlo en la pestaña Pedidos.
        if (o.orderId != null) {
          await ref
              .read(visitorOrdersProvider.notifier)
              .add(
                SavedOrder(
                  id: o.orderId!,
                  number: o.number,
                  total: o.total,
                  catalogName: catalogName,
                  providerName: providerName,
                  createdAt: DateTime.now(),
                ),
              );
        }
      }
      ref.read(cartControllerProvider.notifier).removeCatalog(widget.catalogId);
      // En la app no hay bloqueo de ventanas: tras guardar el pedido se crea su
      // enlace y se abre WhatsApp con el mensaje listo (si el catálogo tiene número).
      final String? phone = catalog?.phone;
      bool whatsappFailed = false;
      if (phone != null && phone.isNotEmpty) {
        final String link = o.orderId == null
            ? ''
            : await ref
                  .read(visitorCatalogApiProvider)
                  .createOrderShare(
                    title: 'Pedido #${o.number}',
                    description: buildOrderSummary(lines),
                    redirectUrl:
                        'https://catalogos.flystock.com.co/pedido/${o.orderId}',
                  );
        final String message = buildOrderMessage(
          lines,
          link,
          total: o.total,
          hidePrices: (catalog?.priceField ?? '').toLowerCase() == 'none',
        );
        try {
          whatsappFailed = !await ref.read(whatsappLauncherProvider)(
            whatsappUri(phone, message, android: Platform.isAndroid),
          );
        } catch (_) {
          whatsappFailed = true;
        }
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Pedido #${o.number} enviado a ${providerName ?? catalogName} (${formatCop(o.total)})'
            '${whatsappFailed ? '. No pudimos abrir WhatsApp.' : ''}',
          ),
        ),
      );
      nav.pop();
    } on DioException catch (err) {
      final dynamic body = err.response?.data;
      final dynamic msg = body is Map ? body['message'] : null;
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = msg is String
            ? msg
            : msg is List
            ? msg.join(', ')
            : 'No pudimos enviar el pedido. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<CartLine> lines = ref
        .watch(cartControllerProvider)
        .where((CartLine l) => l.catalogId == widget.catalogId)
        .toList();
    final VisitorCatalog? catalog = ref
        .watch(visitorCatalogsProvider)
        .where((VisitorCatalog c) => c.catalogId == widget.catalogId)
        .firstOrNull;
    final num total = lines.fold<num>(
      0,
      (num s, CartLine l) => s + l.lineTotal,
    );
    final String provider =
        catalog?.providerName ?? (lines.isEmpty ? '' : lines.first.catalogName);
    final ({int? units, int? amount})? rules = ref
        .watch(
          visitorOrderRulesProvider(catalog?.shortUuid ?? widget.catalogId),
        )
        .value;
    final int units = lines.fold<int>(0, (int s, CartLine l) => s + l.quantity);
    final String? ruleMsg = rules == null
        ? null
        : (rules.units != null && units < rules.units!)
        ? 'Este proveedor pide mínimo ${rules.units} unidades por pedido. Llevas $units.'
        : (rules.amount != null && total < rules.amount!)
        ? 'El pedido debe ser de mínimo ${formatCop(rules.amount!)}. Llevas ${formatCop(total)}.'
        : null;
    return Scaffold(
      backgroundColor: kSheetTint,
      body: Column(
        children: <Widget>[
          BrandHeader(
            title: 'Tu pedido',
            subtitle: catalog == null
                ? provider
                : '${catalog.name}${catalog.providerName == null ? '' : ' · ${catalog.providerName}'}',
            titleSize: 18,
            sheetColor: kSheetTint,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BrandHeaderButton(
                  icon: LucideIcons.chevronLeft,
                  label: 'Volver',
                  onTap: () => context.canPop()
                      ? context.pop()
                      : Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
                _LogoCircle(
                  url: catalog?.logoUrl,
                  label: _initials(provider),
                  size: 44,
                ),
              ],
            ),
          ),
          Expanded(
            child: lines.isEmpty
                ? const Center(
                    child: Text('Este pedido ya no tiene productos.'),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: <Widget>[
                      Material(
                        color: Colors.white,
                        elevation: 1.5,
                        shadowColor: const Color(0x14001634),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            children: <Widget>[
                              for (
                                int i = 0;
                                i < lines.length;
                                i++
                              ) ...<Widget>[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFEEF3FB),
                                  ),
                                _LineTile(
                                  line: lines[i],
                                  onQuantity: () => _pickQuantity(lines[i]),
                                  onRemove: () => ref
                                      .read(cartControllerProvider.notifier)
                                      .remove(lines[i].key),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          'TU NOMBRE (OPCIONAL)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5B6B84),
                          ),
                        ),
                      ),
                      _Field(controller: _nombre, hint: 'Cómo te llamas'),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, top: 14, bottom: 6),
                        child: Text(
                          'NOTA (OPCIONAL)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5B6B84),
                          ),
                        ),
                      ),
                      _Field(
                        controller: _nota,
                        hint: 'Ej.: entregar a Laura',
                        lines: 3,
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFD12B2B)),
                          ),
                        ),
                    ],
                  ),
          ),
          Container(
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Total estimado',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5B6B84),
                            ),
                          ),
                        ),
                        Text(
                          formatCop(total),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'El proveedor confirma el precio final.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A97AB),
                        ),
                      ),
                    ),
                    if (ruleMsg != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              LucideIcons.info,
                              size: 16,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ruleMsg,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8A4B08),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: lines.isEmpty || _sending || ruleMsg != null
                            ? null
                            : () => _send(catalog, lines),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.accent.withValues(
                            alpha: 0.4,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _sending
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Enviando…'),
                                ],
                              )
                            : const Text('Enviar pedido'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, this.lines = 1});

  final TextEditingController controller;
  final String hint;
  final int lines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    minLines: lines,
    maxLines: lines == 1 ? 1 : 4,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCFE0F7), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCFE0F7), width: 1.5),
      ),
    ),
  );
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.onQuantity,
    required this.onRemove,
  });

  final CartLine line;
  final VoidCallback onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 60,
            height: 60,
            child: line.imageUrl == null
                ? const ColoredBox(color: Color(0xFFE3ECFB))
                : CachedNetworkImage(
                    imageUrl: line.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: Color(0xFFE3ECFB)),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                line.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                <String>[
                  ?line.variantLabel,
                  if (line.unitPrice != null)
                    '${formatCop(line.unitPrice!)} c/u',
                ].join(' · '),
                style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B84)),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: onQuantity,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3ECFB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${line.quantity} und',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.chevronDown,
                        size: 14,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            IconButton(
              tooltip: 'Quitar',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(
                LucideIcons.trash2,
                size: 18,
                color: Color(0xFF9AA8BF),
              ),
            ),
            Text(
              formatCop(line.lineTotal),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    ),
  );
}
