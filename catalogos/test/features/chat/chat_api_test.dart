import 'package:catalogos/features/chat/chat_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../helpers/memory_cache.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late MemoryCache cache;
  late ChatApi api;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    adapter = DioAdapter(dio: dio);
    cache = MemoryCache();
    api = ChatApi(dio, cache);
  });

  test('lista conversaciones y resume fotos y productos', () async {
    adapter.onGet(
      '/conversations',
      (s) => s.reply(200, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'c1',
          'providerName': 'Mayorista X',
          'catalogName': 'Detal',
          'lastMessage': 'foto.jpg',
          'lastMessageType': 'IMAGE',
          'lastMessageAt': '2026-11-12T10:00:00.000Z',
          'unreadCount': 2,
        },
      ]),
    );
    final List<ChatConversation> l = await api.conversations();
    expect(l.single.title, 'Mayorista X');
    expect(l.single.lastMessage, '📷 Foto');
    expect(l.single.unread, 2);
  });

  test('start devuelve el id y messages marca los propios', () async {
    adapter
      ..onPost(
        '/conversations/start',
        (s) => s.reply(200, <String, dynamic>{'id': 'c9'}),
        data: <String, dynamic>{'catalogId': 'cat1'},
      )
      ..onGet(
        '/conversations/c9/messages',
        (s) => s.reply(200, <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'm1',
            'message': 'Hola',
            'messageType': 'TEXT',
            'isMine': true,
            'createdAt': '2026-11-12T10:00:00.000Z',
          },
          <String, dynamic>{
            'id': 'm2',
            'message': 'Buenas',
            'messageType': 'TEXT',
            'isMine': false,
            'createdAt': '2026-11-12T10:01:00.000Z',
          },
        ]),
        queryParameters: <String, dynamic>{'limit': 100},
      );
    expect(await api.start('cat1'), 'c9');
    final List<ChatMessage> m = await api.messages('c9');
    expect(m.map((ChatMessage x) => x.mine), <bool>[true, false]);
  });

  test('el nombre solo se pregunta una vez', () async {
    expect(api.nameAsked, isFalse);
    await api.markNameAsked();
    expect(api.nameAsked, isTrue);
  });
}
