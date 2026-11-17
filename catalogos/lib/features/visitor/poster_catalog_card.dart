import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../auth/presentation/auth_gradient_button.dart';
import '../auth/presentation/auth_vector_icons.dart';
import '../shared_catalogs/domain/catalog.dart';
import 'visitor_catalogs.dart';

/// Tarjeta tipo póster del carrusel de Comprar: la foto del catálogo ocupa
/// toda la tarjeta y el logo, nombre, proveedor y botón van encima, sobre un
/// degradado oscuro.
/// Cantidad de productos y de productos nuevos de un catálogo (endpoint
/// público `/catalog/short/<8 primeros del id>`). `null` si no se pudo leer:
/// la tarjeta simplemente no muestra cifras.
final catalogStatsProvider = FutureProvider.autoDispose
    .family<({int products, int fresh})?, String>((
      Ref ref,
      String catalogId,
    ) async {
      try {
        final CatalogPage p = await ref
            .watch(visitorCatalogApiProvider)
            .fetchPage(catalogId.substring(0, 8));
        return (products: p.ids.length, fresh: p.newIds.length);
      } catch (_) {
        return null;
      }
    });

class PosterCatalogCard extends ConsumerWidget {
  const PosterCatalogCard({
    super.key,
    required this.catalog,
    required this.onTap,
    this.compact = false,
    this.hideProvider = false,
  });

  /// Catálogo de revendedor: sin logo ni nombre del proveedor.
  final bool hideProvider;

  final Catalog catalog;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({int products, int fresh})? stats = ref
        .watch(catalogStatsProvider(catalog.id))
        .value;
    final String? cover = catalog.coverImageUrl;
    final String? logo = catalog.providerLogoUrl;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double h = c.maxHeight.isFinite
            ? c.maxHeight.clamp(0.0, c.maxWidth * 1.45)
            : c.maxWidth * 1.3;
        return Semantics(
          button: true,
          label: 'Catálogo ${catalog.displayName}, de ${catalog.providerLabel}',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color.fromRGBO(0, 22, 52, 0.22),
                    offset: Offset(0, 14),
                    blurRadius: 34,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            AppColors.secondary,
                            AppColors.primary,
                          ],
                        ),
                      ),
                    ),
                    if (cover != null)
                      CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Color(0xF0001634),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (!hideProvider)
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: logo == null
                                    ? Center(
                                        child: Text(
                                          catalog.providerInitials,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: logo,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      ),
                              ),
                            ),
                          if (!hideProvider) const SizedBox(height: 10),
                          Text(
                            catalog.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (!hideProvider)
                            Text(
                              catalog.providerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFCFE0F7),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              _Pill(
                                icon: LucideIcons.tag,
                                label: catalog.isPriceHidden
                                    ? 'Sin precios'
                                    : 'Con precios',
                                tint: catalog.isPriceHidden
                                    ? const Color(0x33FFFFFF)
                                    : const Color(0x3300FF94),
                              ),
                              if (stats != null && stats.products > 0)
                                _Pill(
                                  icon: LucideIcons.package,
                                  label: '${stats.products} productos',
                                ),
                              if (stats != null && stats.fresh > 0)
                                _Pill(
                                  icon: LucideIcons.sparkles,
                                  label: '${stats.fresh} nuevos',
                                  tint: const Color(0x555DE0E6),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AuthGradientButton(
                            label: 'Ver catálogo',
                            height: compact ? 46 : 50,
                            iconPainter: const ArrowForwardPainter(
                              color: AppColors.primary,
                              strokeWidth: 2.4,
                            ),
                            enabled: true,
                            loading: false,
                            onPressed: onTap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    this.tint = const Color(0x33FFFFFF),
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}
