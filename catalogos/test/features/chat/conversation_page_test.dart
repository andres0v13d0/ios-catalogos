import 'package:catalogos/core/storage/storage.dart';
import 'package:catalogos/features/chat/chat_api.dart';
import 'package:catalogos/features/chat/conversation_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_cache.dart';

class _FakeChat extends ChatApi {
  _FakeChat(this.msgs) : super(Dio(), MemoryCache());

  List<ChatMessage> msgs;
  final List<String> sent = <String>[];

  @override
  Future<List<ChatMessage>> messages(String id, {int limit = 100}) async =>
      msgs;

  @override
  Future<void> send(String id, String text) async {
    sent.add(text);
    msgs = <ChatMessage>[
      ...msgs,
      ChatMessage(
        id: 'n${sent.length}',
        text: text,
        mine: true,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<void> markRead(String id) async {}
}

Future<_FakeChat> _pump(WidgetTester tester, List<ChatMessage> msgs) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final _FakeChat api = _FakeChat(msgs);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localCacheProvider.overrideWithValue(MemoryCache()),
        chatApiProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(
        home: ConversationPage(
          conversationId: 'c1',
          info: ConversationInfo(
            title: 'Distribuidora X',
            subtitle: 'Catálogo Y',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return api;
}

void main() {
  testWidgets('muestra cabecera, día y burbujas', (tester) async {
    await _pump(tester, <ChatMessage>[
      ChatMessage(
        id: '1',
        text: 'Hola, ¿en qué te ayudo?',
        mine: false,
        createdAt: DateTime.now(),
      ),
      ChatMessage(
        id: '2',
        text: 'Quiero 6 pares',
        mine: true,
        createdAt: DateTime.now(),
      ),
    ]);
    expect(find.text('Distribuidora X'), findsOneWidget);
    expect(find.text('Catálogo Y'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Hola, ¿en qué te ayudo?'), findsOneWidget);
    expect(find.text('Quiero 6 pares'), findsOneWidget);
    // Ya escribió: no se ofrecen respuestas rápidas.
    expect(find.text('¿Está disponible?'), findsNothing);
  });

  testWidgets('sin mensajes ofrece respuestas rápidas y envía', (tester) async {
    final _FakeChat api = await _pump(tester, <ChatMessage>[]);
    expect(find.text('¿Está disponible?'), findsOneWidget);

    await tester.tap(find.text('¿Está disponible?'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '¿Está disponible?'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Enviar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.sent, <String>['¿Está disponible?']);
  });

  testWidgets('muestra la tarjeta de producto y ofrece adjuntar', (
    tester,
  ) async {
    await _pump(tester, <ChatMessage>[
      ChatMessage(
        id: '1',
        text: 'Blusa',
        mine: true,
        type: 'PRODUCT',
        metadata: <String, dynamic>{
          'productId': 'p',
          'name': 'Blusa floral',
          'price': 25000,
        },
        createdAt: DateTime.now(),
      ),
    ]);
    expect(find.text('Blusa floral'), findsOneWidget);
    expect(find.text(r'$ 25.000'), findsOneWidget);
    expect(find.byTooltip('Adjuntar'), findsOneWidget);
  });
}
