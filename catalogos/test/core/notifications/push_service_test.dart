import 'package:catalogos/app/app.dart';
import 'package:catalogos/core/notifications/push_service.dart';
import 'package:catalogos/core/storage/storage.dart';
import 'package:catalogos/features/chat/conversation_page.dart';
import 'package:catalogos/features/visitor/visitor_buy_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_cache.dart';

void main() {
  test('chat abre la conversación', () {
    expect(
      routeFromPushData({'type': 'chat', 'conversationId': 'abc'}),
      '/chat/c/abc',
    );
  });
  test('productos nuevos abren el catálogo', () {
    expect(
      routeFromPushData({'type': 'new_products', 'shortUuid': 'ab12cd34'}),
      '/comprar/c/ab12cd34',
    );
  });
  test('datos incompletos o de otro tipo no navegan', () {
    expect(routeFromPushData({'type': 'chat'}), isNull);
    expect(routeFromPushData({'type': 'offer', 'shortUuid': 'x'}), isNull);
  });
  test('tema por catálogo igual al del backend', () {
    expect(topicFor('uuid-1'), 'catalogo_uuid-1_nuevos');
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final ProviderContainer c = ProviderContainer(
      overrides: [localCacheProvider.overrideWithValue(MemoryCache())],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const RevendedoresApp()),
    );
    await tester.pump();
    return c;
  }

  testWidgets('tocar un aviso de chat abre esa conversación', (tester) async {
    final ProviderContainer c = await pumpApp(tester);
    c.read(pushServiceProvider).open({'type': 'chat', 'conversationId': 'c1'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ConversationPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('tocar un aviso de productos nuevos abre el catálogo', (
    tester,
  ) async {
    final ProviderContainer c = await pumpApp(tester);
    c.read(pushServiceProvider).open({
      'type': 'new_products',
      'shortUuid': 'ab12cd34',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VisitorCatalogPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
