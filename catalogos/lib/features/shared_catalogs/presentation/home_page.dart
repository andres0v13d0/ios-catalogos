import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_gradient_button.dart';
import '../../auth/presentation/auth_palette.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import '../domain/catalog.dart';
import 'catalog_carousel.dart';
import 'home_hero.dart';
import 'home_palette.dart';
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

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => _LogoutDialog(
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authStateProvider.notifier).logout();
    }
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

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MediaQuery(
        // Limita el crecimiento del texto del sistema a 1.3x: a partir de
        // ahí la tarjeta deja de poder compactarse más sin desbordarse.
        data: mediaQuery.copyWith(
          textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.3),
        ),
        child: Scaffold(
          backgroundColor: HomePalette.screenBackground,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double t = ((constraints.maxHeight - 640) / (844 - 640))
                    .clamp(0.0, 1.0);
                final double heroHeight = 200 + (260 - 200) * t;
                final double overlap = 70 + (100 - 70) * t;
                // Pantallas cortas (≤640dp de alto): compacta cabecera y
                // tarjeta para que todo siga cabiendo sin desbordarse.
                final bool compact = constraints.maxHeight <= 640;

                // No se usa `AsyncValue.when` directamente: Riverpod 3.x
                // reintenta automáticamente un `build()` fallido manteniendo
                // `isLoading == true` (con el error ya adjunto) mientras lo
                // hace, así que `.when(loading:, error:, data:)` se quedaría
                // mostrando el esqueleto de carga en vez del error. El propio
                // controller solo deja un `hasError` real cuando NO hay caché
                // utilizable que mostrar (si la hay, cae a `AsyncData` con
                // `fromCache: true`), así que comprobar `hasError` primero es
                // seguro y muestra el error de inmediato en vez de esperar a
                // que se agoten los reintentos en silencio.
                if (asyncState.hasError) {
                  return _Scaffold(
                    heroHeight: heroHeight,
                    overlap: overlap,
                    subtitle: '',
                    dotsHeight: 0,
                    compact: compact,
                    intro: _introController,
                    onLogout: () => _confirmLogout(context, ref),
                    body: _ErrorBody(
                      onRetry: () => ref
                          .read(sharedCatalogsControllerProvider.notifier)
                          .refresh(),
                    ),
                    onRefresh: () => ref
                        .read(sharedCatalogsControllerProvider.notifier)
                        .refresh(),
                  );
                }

                final SharedCatalogsState? state = asyncState.value;
                if (asyncState.isLoading || state == null) {
                  return _Scaffold(
                    heroHeight: heroHeight,
                    overlap: overlap,
                    subtitle: '',
                    dotsHeight: 0,
                    compact: compact,
                    intro: _introController,
                    onLogout: () => _confirmLogout(context, ref),
                    body: const _SkeletonCard(),
                    onRefresh: null,
                  );
                }

                {
                  final int total = state.catalogs.length;
                  final String subtitle = total == 0
                      ? ''
                      : (total == 1
                            ? 'Toca para ver sus productos'
                            : 'Desliza para ver más');
                  final double dotsHeight = total > 1 ? 36 + (48 - 36) * t : 0;

                  return _Scaffold(
                    heroHeight: heroHeight,
                    overlap: overlap,
                    subtitle: subtitle,
                    dotsHeight: dotsHeight,
                    compact: compact,
                    intro: _introController,
                    onLogout: () => _confirmLogout(context, ref),
                    offlineNotice: state.fromCache,
                    body: total == 0
                        ? const _EmptyBody()
                        : CatalogCarousel(
                            catalogs: state.catalogs,
                            dotsHeight: dotsHeight,
                            compact: compact,
                            onOpenCatalog: _openCatalog,
                          ),
                    onRefresh: () => ref
                        .read(sharedCatalogsControllerProvider.notifier)
                        .refresh(),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Composición común a todos los estados: hero curvo + cuerpo (carrusel,
/// esqueleto, error o vacío) + aviso de "sin conexión" si aplica.
class _Scaffold extends StatelessWidget {
  const _Scaffold({
    required this.heroHeight,
    required this.overlap,
    required this.subtitle,
    required this.dotsHeight,
    required this.intro,
    required this.onLogout,
    required this.body,
    required this.onRefresh,
    this.compact = false,
    this.offlineNotice = false,
  });

  final double heroHeight;
  final double overlap;
  final String subtitle;
  final double dotsHeight;
  final Animation<double> intro;
  final VoidCallback onLogout;
  final Widget body;
  final bool compact;
  final bool offlineNotice;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    // Una sola medición del alto disponible (`constraints.maxHeight`, ya
    // dentro del `SafeArea` del padre): el `Stack` y el `SizedBox` del
    // scroll de abajo usan el mismo valor, para que nunca queden
    // desalineados y el contenido siempre llene exactamente la pantalla
    // (pull-to-refresh sin dejar scroll visible).
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double total = constraints.maxHeight;
        final Widget content = SizedBox(
          height: total,
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: heroHeight,
                child: AnimatedBuilder(
                  animation: intro,
                  builder: (BuildContext context, Widget? child) {
                    final double t = Curves.easeOut.transform(
                      intro.value.clamp(0.0, 1.0),
                    );
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * -16),
                        child: child,
                      ),
                    );
                  },
                  child: HomeHero(
                    height: heroHeight,
                    subtitle: subtitle,
                    onLogout: onLogout,
                    compact: compact,
                  ),
                ),
              ),
              Positioned(
                top: heroHeight - overlap,
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: intro,
                  builder: (BuildContext context, Widget? child) {
                    final double t = Curves.easeOut.transform(
                      ((intro.value - 0.15) / 0.85).clamp(0.0, 1.0),
                    );
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 24),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: <Widget>[
                      if (offlineNotice) const _OfflineBanner(),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        if (onRefresh == null) return content;

        return RefreshIndicator(
          onRefresh: onRefresh!,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(height: total, child: content),
          ),
        );
      },
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      namesRoute: true,
      label: 'Cerrar sesión, diálogo de confirmación',
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                '¿Cerrar sesión?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Vas a salir de tu cuenta de FLYmovil en este dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AuthPalette.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Cancelar',
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(
                            color: AuthPalette.fieldBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Salir',
                      child: FilledButton(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Salir'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
          Icon(Icons.cloud_off, size: 16, color: AuthPalette.textMuted),
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
            Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: AuthPalette.textMuted,
            ),
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
              Icons.error_outline,
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
