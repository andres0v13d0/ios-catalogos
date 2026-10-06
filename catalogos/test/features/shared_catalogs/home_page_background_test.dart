// Prueba del fondo de "Tus catálogos" (carrusel), ver
// docs/design/inicio-a-carrusel.html.
//
// El diseño tiene un único fondo blanco (#FFFFFF) bajo la cabecera: sin
// franja distinta detrás de los puntos del carrusel. Esta prueba renderiza
// la pantalla a una imagen y compara, por color de píxel real (no solo
// estructura de widgets), el fondo a la altura de las tarjetas contra el
// fondo a la altura de los puntos.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:catalogos/features/auth/data/session_store.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_carousel.dart';
import 'package:catalogos/features/shared_catalogs/presentation/home_page.dart';
import 'package:catalogos/features/shared_catalogs/presentation/home_palette.dart';
import 'package:catalogos/features/shared_catalogs/presentation/shared_catalogs_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/fake_auth_dependencies.dart';

class _FakeSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<SessionMetadata> read() async => const SessionMetadata();

  @override
  Future<void> save(SessionMetadata metadata) async {}
}

class _FakeController extends SharedCatalogsController {
  _FakeController(this.catalogs);

  final List<Catalog> catalogs;

  @override
  Future<SharedCatalogsState> build() async =>
      SharedCatalogsState(catalogs: catalogs);

  @override
  Future<void> refresh() async {}
}

final List<Catalog> _fiveCatalogs = List<Catalog>.generate(
  5,
  (int i) => Catalog(
    id: 'eeeeeeee-eeee-eeee-eeee-00000000000$i',
    displayName: 'Cat ${i + 1}',
    providerId: 50 + i,
    providerName: 'Prov ${i + 1}',
    priceField: i.isEven ? 'none' : 'mayorista',
  ),
);

/// Color de un píxel de la [image] en coordenadas lógicas (`dp`), asumiendo
/// `pixelRatio: 1.0` al capturarla.
Color _pixelAt(ByteData rgba, int width, int x, int y) {
  final int offset = (y * width + x) * 4;
  final int r = rgba.getUint8(offset);
  final int g = rgba.getUint8(offset + 1);
  final int b = rgba.getUint8(offset + 2);
  final int a = rgba.getUint8(offset + 3);
  return Color.fromARGB(a, r, g, b);
}

/// 390x844 (sobra espacio de sobra, la tarjeta no llega a llenar su slot) y
/// 360x640 (pantalla "compacta": la tarjeta llena TODO el alto disponible,
/// sin aire propio debajo — el caso donde se detectó la franja gris de la
/// sombra pegada a los puntos).
const List<Size> _sizes = <Size>[Size(390, 844), Size(360, 640)];

void main() {
  for (final Size size in _sizes) {
    testWidgets(
      '${size.width.toInt()}x${size.height.toInt()}: el fondo detrás de los '
      'puntos es idéntico (#FFFFFF) al de detrás de las tarjetas, sin franja '
      'de sombra pegada a ellos',
      (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final GlobalKey boundaryKey = GlobalKey();
        final GoRouter router = GoRouter(
          initialLocation: '/home',
          routes: <RouteBase>[
            GoRoute(path: '/home', builder: (context, _) => const HomePage()),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedCatalogsControllerProvider.overrideWith(
                () => _FakeController(_fiveCatalogs),
              ),
              authUserServiceProvider.overrideWithValue(FakeAuthUserService()),
              sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
            ],
            child: RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // La columna del Scaffold (fondo nominal) debe ser la constante
        // única de esta pantalla.
        final Scaffold scaffold = tester.widget(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, HomePalette.screenBackground);
        expect(HomePalette.screenBackground, const Color(0xFFFFFFFF));

        final Rect card = tester.getRect(
          find.byKey(Key('catalog_${_fiveCatalogs.first.id}')),
        );
        final Rect dotsRow = tester.getRect(
          find.descendant(
            of: find.byType(CatalogCarousel),
            matching: find.byType(SizedBox).last,
          ),
        );

        await tester.runAsync(() async {
          final RenderRepaintBoundary boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
          final ByteData rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;

          // x=5: cerca del borde izquierdo, fuera de la tarjeta y del grupo
          // de puntos (centrado) — solo debe verse el fondo liso.
          const int x = 5;
          final Color behindCards = _pixelAt(
            rgba,
            image.width,
            x,
            card.center.dy.round(),
          );
          final Color behindDots = _pixelAt(
            rgba,
            image.width,
            x,
            dotsRow.center.dy.round(),
          );

          expect(
            behindCards,
            const Color(0xFFFFFFFF),
            reason: 'Fondo detrás de las tarjetas debe ser blanco puro.',
          );
          expect(
            behindDots,
            const Color(0xFFFFFFFF),
            reason: 'Fondo detrás de los puntos debe ser blanco puro.',
          );
          expect(
            behindDots,
            behindCards,
            reason: 'No debe notarse ninguna franja distinta tras los puntos.',
          );

          // El punto crítico: justo ENCIMA de los puntos (donde se veía la
          // franja gris de la sombra de la tarjeta) también debe ser blanco
          // puro, en el mismo eje x que la tarjeta (ahí es donde cae la
          // sombra, no a los costados).
          final Color justAboveDots = _pixelAt(
            rgba,
            image.width,
            card.center.dx.round(),
            (dotsRow.top - 2).round(),
          );
          expect(
            justAboveDots,
            const Color(0xFFFFFFFF),
            reason:
                'Justo encima de los puntos (bajo el centro de la tarjeta) '
                'no debe quedar un resto visible de la sombra.',
          );
        });
      },
    );
  }
}
