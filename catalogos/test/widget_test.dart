// Smoke test de la app de Revendedores (Fase 0).
//
// Tras la tarea 0.5 la app usa go_router con un guard de auth placeholder.
// Sin sesión la app arranca en Comprar (pública).

import 'package:catalogos/app/app.dart';
import 'package:catalogos/core/storage/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_cache.dart';

void main() {
  testWidgets('La app arranca y, sin sesión, muestra Comprar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localCacheProvider.overrideWithValue(MemoryCache())],
        child: const RevendedoresApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Aquí verás tus catálogos guardados'),
      findsOneWidget,
    );
  });
}
