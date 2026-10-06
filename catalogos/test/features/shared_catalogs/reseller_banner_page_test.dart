import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/shared_catalogs/data/reseller_banner_repository.dart';
import 'package:catalogos/features/shared_catalogs/domain/reseller_banner.dart';
import 'package:catalogos/features/shared_catalogs/presentation/reseller_banner_page.dart';

/// Repositorio falso: cuenta las llamadas y devuelve resultados controlados.
class _FakeBannerRepo implements ResellerBannerRepository {
  int uploadCalls = 0;
  int deleteCalls = 0;

  @override
  Future<Result<ResellerBannerResult>> uploadBanner(String catalogId, String filePath) async {
    uploadCalls++;
    return const Ok<ResellerBannerResult>(
      ResellerBannerResult(ogImageUrl: 'https://cdn.minymol.com/catalog-banners/og/new.jpg', enlace: 'https://share.minymol.com/abc'),
    );
  }

  @override
  Future<Result<ResellerBannerResult>> deleteBanner(String catalogId) async {
    deleteCalls++;
    return const Ok<ResellerBannerResult>(ResellerBannerResult(ogImageUrl: null, enlace: 'https://share.minymol.com/abc'));
  }
}

/// Plataforma de image_picker falsa: devuelve [result] (o null = cancelado).
class _FakePickerPlatform extends ImagePickerPlatform {
  _FakePickerPlatform({this.result});

  XFile? result;
  int pickCalls = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    pickCalls++;
    return result;
  }
}

ResellerBannerState _state({String? ownBanner}) => ResellerBannerState(
      catalogId: '7bbdc15f-d5dc-4277-a015-0358e6e3d2c7',
      shareLink: 'https://share.minymol.com/NYyndtvhMda0',
      publicName: 'Colección Primavera',
      hasPriceRules: false,
      ownBannerUrl: ownBanner,
      providerImageUrl: 'https://cdn.minymol.com/banners/proveedor.jpg',
    );

void main() {
  Widget wrap(ResellerBannerState s, {_FakeBannerRepo? repo}) {
    return ProviderScope(
      overrides: [
        resellerBannerRepositoryProvider.overrideWithValue(repo ?? _FakeBannerRepo()),
      ],
      child: MaterialApp(home: ResellerBannerPage(args: s)),
    );
  }

  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pump();
  }

  testWidgets('Banner-1 (sin banner): muestra "Sube tu banner", nota y "Elegir imagen"', (tester) async {
    await pump(tester, wrap(_state()));

    expect(find.text('Banner del catálogo'), findsOneWidget);
    expect(find.text('Sube tu banner'), findsOneWidget);
    expect(find.textContaining('Solo se usa como vista previa'), findsOneWidget);
    expect(find.text('Elegir imagen'), findsOneWidget);
    // Sin banner propio: no hay "Quitar" ni "Banner guardado".
    expect(find.text('Quitar'), findsNothing);
    expect(find.text('Banner guardado'), findsNothing);
    // La vista previa usa el nombre REAL del catálogo (no fijo).
    expect(find.text('Colección Primavera'), findsOneWidget);
  });

  testWidgets('Banner-2 (con banner): muestra "Banner guardado", "Cambiar banner", "Listo" y "Quitar"', (tester) async {
    await pump(tester, wrap(_state(ownBanner: 'https://cdn.minymol.com/catalog-banners/og/mine.jpg')));

    expect(find.text('Banner guardado'), findsOneWidget);
    expect(find.text('Cambiar banner'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
    expect(find.text('Quitar'), findsOneWidget);
    expect(find.text('Sube tu banner'), findsNothing);
    expect(find.text('Elegir imagen'), findsNothing);
  });

  testWidgets('Cancelar el selector: sin error, estado sigue en reposo (sin banner)', (tester) async {
    final picker = _FakePickerPlatform(result: null); // null = cancelado
    ImagePickerPlatform.instance = picker;
    final repo = _FakeBannerRepo();

    await pump(tester, wrap(_state(), repo: repo));

    await tester.tap(find.text('Elegir imagen'));
    await tester.pump();
    await tester.pump();

    // No se subió nada, no hay mensaje de error, sigue el estado inicial.
    expect(picker.pickCalls, 1);
    expect(repo.uploadCalls, 0);
    expect(find.text('Sube tu banner'), findsOneWidget);
    expect(find.textContaining('No pudimos abrir'), findsNothing);
  });
}
