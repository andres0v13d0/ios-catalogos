import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catalogos/features/shared_catalogs/domain/reseller_banner.dart';
import 'package:catalogos/features/shared_catalogs/presentation/reseller_share_sheet.dart';

ResellerBannerState _state({bool withBanner = false, bool hasPriceRules = false}) => ResellerBannerState(
      catalogId: '7bbdc15f-d5dc-4277-a015-0358e6e3d2c7',
      shareLink: 'https://share.minymol.com/NYyndtvhMda0',
      publicName: 'Colección Primavera',
      hasPriceRules: hasPriceRules,
      ownBannerUrl: withBanner ? 'https://cdn.minymol.com/catalog-banners/og/mine.jpg' : null,
      providerImageUrl: 'https://cdn.minymol.com/banners/proveedor.jpg',
    );

void main() {
  setUp(() {
    // Captura las escrituras al portapapeles sin plugin real.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        return null; // Clipboard.setData / HapticFeedback => no-op.
      },
    );
  });

  Future<void> openSheet(
    WidgetTester tester, {
    required ResellerBannerState banner,
    List<Uri>? launched,
    List<String>? shared,
    bool launchSucceeds = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showResellerShareSheet(
                  context,
                  banner: banner,
                  onChangeBanner: () {},
                  launcher: (uri) async {
                    launched?.add(uri);
                    return launchSucceeds;
                  },
                  sharer: (text) async {
                    shared?.add(text);
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('subtítulo cambia según haya reglas de precio', (tester) async {
    await openSheet(tester, banner: _state(hasPriceRules: true));
    expect(find.text('Tus clientes verán tus precios ajustados.'), findsOneWidget);
  });

  testWidgets('sin reglas de precio: subtítulo del proveedor', (tester) async {
    await openSheet(tester, banner: _state(hasPriceRules: false));
    expect(find.text('Tus clientes verán el catálogo del proveedor.'), findsOneWidget);
  });

  testWidgets('Copiar -> "Copiado" + aviso "¡Enlace copiado!" que desaparece', (tester) async {
    await openSheet(tester, banner: _state());

    expect(find.text('Compartir catálogo'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);

    await tester.tap(find.text('Copiar'));
    await tester.pump();

    // El botón pasa a "Copiado" y aparece el aviso flotante.
    expect(find.text('Copiado'), findsOneWidget);
    expect(find.text('¡Enlace copiado!'), findsOneWidget);

    // Tras ~2s vuelve a "Copiar" y el aviso desaparece.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('¡Enlace copiado!'), findsNothing);
  });

  testWidgets('Enviar por WhatsApp usa wa.me con el texto y el enlace', (tester) async {
    final launched = <Uri>[];
    await openSheet(tester, banner: _state(), launched: launched);

    await tester.tap(find.text('Enviar por WhatsApp'));
    await tester.pump();

    expect(launched, hasLength(1));
    expect(launched.first.host, 'wa.me');
    final text = launched.first.queryParameters['text'] ?? '';
    expect(text, contains('Colección Primavera'));
    expect(text, contains('share.minymol.com/NYyndtvhMda0'));
  });

  testWidgets('si WhatsApp no abre, cae a la hoja nativa de compartir', (tester) async {
    final shared = <String>[];
    await openSheet(tester, banner: _state(), shared: shared, launchSucceeds: false);

    await tester.tap(find.text('Enviar por WhatsApp'));
    await tester.pump();

    expect(shared, hasLength(1));
    expect(shared.first, contains('share.minymol.com/NYyndtvhMda0'));
  });

  testWidgets('con banner propio, el enlace copiado incluye ?v= (rompe caché)', (tester) async {
    final banner = _state(withBanner: true);
    // El enlace completo que se comparte debe incluir el parámetro de versión.
    expect(banner.shareLinkWithCacheBust, contains('?v='));
    expect(banner.shareLinkWithCacheBust, startsWith('https://share.minymol.com/NYyndtvhMda0'));

    // Sin banner propio, no se añade ?v=.
    expect(_state().shareLinkWithCacheBust, isNot(contains('?v=')));
  });
}
