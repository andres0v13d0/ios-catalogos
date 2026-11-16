import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/brand_header.dart';
import '../buy/cart_controller.dart';
import 'cart_flow.dart';
import 'catalog_access.dart';
import 'visitor_buy_page.dart' show openVisitorChat;
import 'visitor_catalogs.dart';
import 'visitor_product_page.dart';

/// Detalle de un catálogo guardado: logo del proveedor, mosaico de productos
/// con su portada a su alto real y botón explícito de añadir al carrito.
class VisitorCatalogPage extends ConsumerStatefulWidget {
  const VisitorCatalogPage({super.key, required this.code});

  final String code;

  @override
  ConsumerState<VisitorCatalogPage> createState() => _VisitorCatalogPageState();
}

class _VisitorCatalogPageState extends ConsumerState<VisitorCatalogPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String? _catId;
  String? _subId;
  // Filtros de la primera respuesta sin filtro: al filtrar el backend puede
  // devolverlos recortados y la fila no debe desaparecer.
  List<CatalogCategory> _categories = const <CatalogCategory>[];
  List<CatalogChip> _subcategories = const <CatalogChip>[];

  String get code => widget.code;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _search = v.trim());
    });
  }

  /// Igual que la web: elegir una categoría o "Todos" limpia la búsqueda.
  void _select(String? id, {bool category = false}) {
    _searchCtrl.clear();
    setState(() {
      _search = '';
      if (id == null) {
        _catId = null;
        _subId = null;
      } else if (category) {
        _catId = id;
        _subId = null;
      } else {
        _subId = id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool searchable = !ref.watch(sharedCatalogIdsProvider).contains(code);
    final VisitorCatalogQuery query = (
      code: code,
      search: searchable ? _search : '',
      byCategory: _subId == null && _catId != null,
      chipId: searchable ? (_subId ?? _catId) : null,
    );
    final AsyncValue<VisitorCatalogResult> async = ref.watch(
      visitorCatalogQueryProvider(query),
    );
    final VisitorCatalogResult? res = async.value;
    if (res != null &&
        _catId == null &&
        _subId == null &&
        _search.isEmpty &&
        (res.categories.isNotEmpty || res.subcategories.isNotEmpty)) {
      _categories = res.categories;
      _subcategories = res.subcategories;
    }
    final VisitorCatalog? saved = ref
        .watch(visitorCatalogsProvider)
        .where((VisitorCatalog c) => c.shortUuid == code)
        .firstOrNull;
    final VisitorCatalog? catalog = res?.catalog ?? saved;
    final List<VisitorProduct> products =
        res?.products ?? const <VisitorProduct>[];
    final String provider =
        catalog?.providerName ?? catalog?.name ?? 'Catálogo';
    final bool noPrices = (catalog?.priceField ?? '').toLowerCase() == 'none';
    final String? accessMessage = catalog == null
        ? null
        : ref.watch(catalogAccessProvider(catalog.catalogId)).value?.message;
    return Scaffold(
      backgroundColor: kSheetTint,
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              BrandHeader(
                title: provider,
                subtitle: catalog == null || catalog.name == provider
                    ? null
                    : catalog.name,
                titleSize: 18,
                sheetColor: kSheetTint,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    BrandHeaderButton(
                      icon: LucideIcons.chevronLeft,
                      label: 'Volver',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 10),
                    _Logo(url: catalog?.logoUrl, name: provider),
                  ],
                ),
                actions: <Widget>[
                  if (catalog != null)
                    BrandHeaderButton(
                      icon: LucideIcons.messageCircle,
                      label: 'Chatear con el proveedor',
                      onTap: () => openVisitorChat(context, ref, catalog),
                    ),
                ],
                child: Row(
                  children: <Widget>[
                    if (products.isNotEmpty)
                      _Chip(
                        '${products.length} ${products.length == 1 ? 'producto' : 'productos'}',
                      ),
                    if (products.isNotEmpty) const SizedBox(width: 6),
                    if (catalog != null)
                      _Chip(
                        noPrices || accessMessage != null
                            ? 'Sin precios'
                            : 'Con precios',
                      ),
                  ],
                ),
              ),
              if (accessMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(LucideIcons.lock, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          accessMessage,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (searchable)
                _FilterBar(
                  controller: _searchCtrl,
                  onSearch: _onSearch,
                  categories: _categories,
                  subcategories: _subcategories,
                  catId: _catId,
                  subId: _subId,
                  onSelect: _select,
                ),
              Expanded(
                child: async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () =>
                          ref.invalidate(visitorCatalogQueryProvider(query)),
                      child: const Text(
                        'No pudimos cargar el catálogo. Reintentar',
                      ),
                    ),
                  ),
                  data: (VisitorCatalogResult d) => d.products.isEmpty
                      ? Center(
                          child: Text(
                            _search.isNotEmpty || _catId != null
                                ? 'No encontramos productos con ese filtro.'
                                : 'Este catálogo aún no tiene productos.',
                          ),
                        )
                      : _Masonry(catalog: d.catalog, products: d.products),
                ),
              ),
            ],
          ),
          const Positioned(right: 18, bottom: 28, child: FloatingCartButton()),
        ],
      ),
    );
  }
}

/// Buscador + categorías como en la web: una fila de categorías y, si la elegida
/// tiene subcategorías, otra debajo con solo las suyas. Sin categorías, una
/// fila plana de subcategorías.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.onSearch,
    required this.categories,
    required this.subcategories,
    required this.catId,
    required this.subId,
    required this.onSelect,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final List<CatalogCategory> categories;
  final List<CatalogChip> subcategories;
  final String? catId;
  final String? subId;
  final void Function(String? id, {bool category}) onSelect;

  Widget _row(
    List<CatalogChip> items,
    String? active,
    void Function(String? id) pick, {
    bool allActive = false,
  }) => SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: <Widget>[
        _Tab('Todos', allActive, () => pick(null)),
        for (final CatalogChip c in items)
          _Tab(c.name, active == c.id, () => pick(c.id)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bool hierarchical = categories.isNotEmpty;
    final CatalogCategory? cat = categories
        .where((CatalogCategory c) => c.id == catId)
        .firstOrNull;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar productos…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (hierarchical) ...<Widget>[
          _row(
            categories,
            catId,
            (String? id) => onSelect(id, category: true),
            allActive: catId == null,
          ),
          if (cat != null && cat.subs.isNotEmpty)
            _row(
              cat.subs,
              subId,
              (String? id) =>
                  id == null ? onSelect(cat.id, category: true) : onSelect(id),
              allActive: subId == null,
            ),
        ] else if (subcategories.isNotEmpty)
          _row(
            subcategories,
            subId,
            (String? id) => onSelect(id),
            allActive: subId == null,
          ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.text, this.active, this.onTap);

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? AppColors.secondary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.secondary : const Color(0xFF5B6B84),
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0x2EFFFFFF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: AppColors.accent, width: 2.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: url == null || url!.isEmpty
        ? Center(
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          )
        : CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
  );
}

/// Mosaico de dos columnas: cada foto conserva su alto (no se recorta).
class _Masonry extends ConsumerWidget {
  const _Masonry({required this.catalog, required this.products});

  final VisitorCatalog catalog;
  final List<VisitorProduct> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> left = <Widget>[];
    final List<Widget> right = <Widget>[];
    for (int i = 0; i < products.length; i++) {
      (i.isEven ? left : right).add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ProductCard(catalog: catalog, product: products[i]),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Column(children: left)),
          const SizedBox(width: 10),
          Expanded(child: Column(children: right)),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.catalog, required this.product});

  final VisitorCatalog catalog;
  final VisitorProduct product;

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VisitorProductPage(catalog: catalog, product: product),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VisitorProduct p = product;
    final int from = p.priceFrom;
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: const Color(0x14001634),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                if (p.image == null)
                  const AspectRatio(
                    aspectRatio: 1,
                    child: ColoredBox(color: Color(0xFFE3ECFB)),
                  )
                else
                  CachedNetworkImage(
                    imageUrl: p.image!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    placeholder: (_, _) => const AspectRatio(
                      aspectRatio: 1,
                      child: ColoredBox(color: Color(0xFFE3ECFB)),
                    ),
                    errorWidget: (_, _, _) => const AspectRatio(
                      aspectRatio: 1,
                      child: ColoredBox(color: Color(0xFFE3ECFB)),
                    ),
                  ),
                if (p.isNew)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C27A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Nuevo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (from > 0)
                          Text(
                            formatCop(from),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Añadir ${p.name} al carrito',
                    child: Material(
                      color: AppColors.secondary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          // Sin color ni talla que elegir: se agrega directo con
                          // la primera cantidad del proveedor. Si no, al detalle.
                          if (p.colors.isEmpty && p.sizes.isEmpty) {
                            final int q = p.quantityOptions.first;
                            ref
                                .read(cartControllerProvider.notifier)
                                .add(cartLineFor(catalog, p, q));
                          } else {
                            _open(context);
                          }
                        },
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            LucideIcons.shoppingCart,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
