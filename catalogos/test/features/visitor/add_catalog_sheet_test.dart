import 'package:catalogos/core/storage/storage.dart';
import 'package:catalogos/features/visitor/add_catalog_sheet.dart';
import 'package:catalogos/features/visitor/visitor_catalogs.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_cache.dart';

class _FakeApi extends VisitorCatalogApi {
  _FakeApi(this.result, {this.fail = false}) : super(Dio());

  final CatalogPage? result;
  final bool fail;

  @override
  Future<CatalogPage?> lookupPage(String raw) async {
    if (fail) {
      throw DioException(requestOptions: RequestOptions(path: '/x'));
    }
    return result;
  }
}

const CatalogPage _page = CatalogPage(
  catalog: VisitorCatalog(
    shortUuid: 'ab12cd34',
    catalogId: 'ab12cd34-0000-0000-0000-000000000000',
    name: 'Catálogo Prueba',
  ),
  newIds: <String>[],
  ids: <String>['a', 'b', 'c'],
);

Future<void> _open(WidgetTester tester, _FakeApi api, MemoryCache cache) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localCacheProvider.overrideWithValue(cache),
        visitorCatalogApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAddCatalogSheet(c),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra vista previa y recién ahí permite agregar', (
    tester,
  ) async {
    final MemoryCache cache = MemoryCache();
    await _open(tester, _FakeApi(_page), cache);

    // Sin enlace, el botón está apagado.
    FilledButton btn() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn().onPressed, isNull);

    await tester.enterText(
      find.byType(TextField),
      'https://share.minymol.com/ab12cd34',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('Catálogo Prueba'), findsOneWidget);
    expect(find.textContaining('3 productos'), findsOneWidget);
    expect(btn().onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(cache.get('visitor_catalogs'), contains('Catálogo Prueba'));
  });

  testWidgets('enlace que no existe muestra el error', (tester) async {
    await _open(tester, _FakeApi(null), MemoryCache());
    await tester.enterText(
      find.byType(TextField),
      'https://share.minymol.com/zzzzzzzz',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.textContaining('No encontramos ese catálogo'), findsOneWidget);
  });

  testWidgets('sin internet ofrece reintentar', (tester) async {
    await _open(tester, _FakeApi(null, fail: true), MemoryCache());
    await tester.enterText(
      find.byType(TextField),
      'https://share.minymol.com/ab12cd34',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.textContaining('No pudimos conectar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
