import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_gradient_button.dart';
import '../../auth/presentation/auth_palette.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import '../domain/catalog.dart';
import 'catalog_carousel.dart';
import '../../../shared/widgets/brand_header.dart';
import '../../visitor/poster_catalog_card.dart';
import 'home_palette.dart';
import 'onboarding_video.dart';
import 'shared_catalogs_controller.dart';

/// Pantalla "Tus catálogos" (carrusel) — pantalla principal tras iniciar
/// sesión (rediseño, ver `docs/design/inicio-a-carrusel.html`).
///
/// Reemplaza la lista plana/agrupada anterior. Observa
/// [sharedCatalogsControllerProvider] igual que antes (mismo
/// sync+GET+caché *stale-while-revalidate*; sin cambios de datos/red, solo
/// de presentación).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;

  // Evita el parpadeo de "sin conexión" en cada entrada a la pantalla: la
  // caché se muestra de inmediato (stale-while-revalidate) y casi siempre se
  // revalida en pocos cientos de ms; solo se avisa si sigue en caché pasado
  // este margen (offline real o red lenta).
  // shortcut: umbral fijo de 600ms sin medir latencia real de red; subir si
  // hay quejas de falsos "sin conexión" en redes lentas.
  bool _showOfflineBanner = false;
  Timer? _offlineDebounce;

  /// Actualiza el debounce del aviso offline a partir del `fromCache` más
  /// reciente. Se llama en cada `build()` (no vía `ref.listen`: esta versión
  /// de Riverpod no admite `fireImmediately` en `WidgetRef.listen`, y
  /// `ref.watch` ya reconstruye en cada cambio del provider). Mutar el campo
  /// directamente es seguro aquí porque se lee en el mismo `build()`; el
  /// `setState` solo ocurre de forma diferida, desde el callback del Timer.
  void _syncOfflineBanner(bool fromCache) {
    if (fromCache) {
      _offlineDebounce ??= Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _showOfflineBanner = true);
      });
    } else {
      _offlineDebounce?.cancel();
      _offlineDebounce = null;
      _showOfflineBanner = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _maybeShowOnboardingVideo();
  }

  /// Primera apertura de la app: muestra el modal del video una sola vez.
  Future<void> _maybeShowOnboardingVideo() async {
    final OnboardingVideoSeenStore store = ref.read(
      onboardingVideoSeenStoreProvider,
    );
    if (await store.hasSeen()) return;
    await store.markSeen();
    if (mounted) showOnboardingVideoModal(context);
  }

  @override
  void dispose() {
    _introController.dispose();
    _offlineDebounce?.cancel();
    super.dispose();
  }

  void _openCatalog(Catalog catalog) {
    context.push(
      AppRoutes.catalogDetailPath(catalog.id),
      extra: catalog.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SharedCatalogsState> asyncState = ref.watch(
      sharedCatalogsControllerProvider,
    );
    _syncOfflineBanner(asyncState.value?.fromCache ?? false);
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final SharedCatalogsState? state = asyncState.value;
    final int total = state?.catalogs.length ?? 0;
    // Cifras de la cabecera: productos y productos nuevos de todos los
    // catálogos (cada uno se lee aparte; "…" mientras llegan).
    int products = 0;
    int fresh = 0;
    bool pending = false;
    for (final Catalog c in state?.catalogs ?? const <Catalog>[]) {
      final AsyncValue<({int products, int fresh})?> st = ref.watch(
        catalogStatsProvider(c.id),
      );
      if (st.isLoading) {
        pending = true;
      } else {
        products += st.value?.products ?? 0;
        fresh += st.value?.fresh ?? 0;
      }
    }
    Future<void> refresh() =>
        ref.read(sharedCatalogsControllerProvider.notifier).refresh();

    // No se usa `AsyncValue.when`: Riverpod 3.x reintenta un `build()` fallido
    // manteniendo `isLoading == true` con el error adjunto; `hasError` primero
    // muestra el error de inmediato (el controller solo deja un error real
    // cuando no hay caché que mostrar).
    final bool failed = asyncState.hasError;
    final bool loading = !failed && (asyncState.isLoading || state == null);

    return MediaQuery(
      // Limita el texto del sistema a 1.3x: más allá la tarjeta no cabe.
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.3),
      ),
      child: Scaffold(
        backgroundColor: HomePalette.screenBackground,
        body: Column(
          children: <Widget>[
            BrandHeader(
              title: 'Vender',
              subtitle: total == 0
                  ? 'Tus catálogos para compartir'
                  : (total == 1
                        ? 'Toca para ver sus productos'
                        : 'Desliza para ver más'),
              actions: <Widget>[
                BrandHeaderButton(
                  icon: LucideIcons.play,
                  label: 'Ver video de ayuda',
                  onTap: () => showOnboardingVideoModal(context),
                ),
              ],
              child: total == 0
                  ? null
                  : Row(
                      children: <Widget>[
                        BrandKpi(
                          '$total',
                          total == 1 ? 'Catálogo' : 'Catálogos',
                        ),
                        const SizedBox(width: 8),
                        BrandKpi(pending ? '…' : '$products', 'Productos'),
                        const SizedBox(width: 8),
                        BrandKpi(pending ? '…' : '$fresh', 'Nuevos'),
                      ],
                    ),
            ),
            if (_showOfflineBanner) const _OfflineBanner(),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final bool compact = c.maxHeight < 520;
                  final Widget body = failed
                      ? _ErrorBody(onRetry: refresh)
                      : loading
                      ? const _SkeletonCard()
                      : total == 0
                      ? const _EmptyBody()
                      : Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: CatalogCarousel(
                            catalogs: state!.catalogs,
                            dotsHeight: total > 1 ? 32 : 0,
                            compact: compact,
                            cardBuilder: (Catalog cat, int _, bool compact) =>
                                PosterCatalogCard(
                                  key: Key('catalog_${cat.id}'),
                                  catalog: cat,
                                  compact: compact,
                                  onTap: () => _openCatalog(cat),
                                ),
                            onOpenCatalog: _openCatalog,
                          ),
                        );
                  if (failed || loading) return body;
                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(height: c.maxHeight, child: body),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF4F8FC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: <Widget>[
          Icon(LucideIcons.cloudOff, size: 16, color: AuthPalette.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión: mostrando catálogos guardados.',
              style: TextStyle(fontSize: 12, color: AuthPalette.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(LucideIcons.package, size: 40, color: AuthPalette.textMuted),
            SizedBox(height: 16),
            Text(
              'Aún no tienes catálogos compartidos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              LucideIcons.circleAlert,
              size: 40,
              color: AuthPalette.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'No pudimos cargar tus catálogos.',
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
    );
  }
}

/// Esqueleto con la forma de la tarjeta mientras carga.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FC),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE3ECF7)),
        ),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}
