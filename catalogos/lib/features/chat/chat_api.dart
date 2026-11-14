import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/notifications/push_service.dart';
import '../../core/network/dio_provider.dart';
import '../../core/network/token_provider.dart';
import '../../core/storage/storage.dart';

const String _sessionKey = 'guest_chat_session';
const String _nameAskedKey = 'guest_chat_name_asked';

String? _readToken(LocalCache cache) {
  final String? raw = cache.get(_sessionKey);
  if (raw == null) return null;
  try {
    return (jsonDecode(raw) as Map<String, dynamic>)['token'] as String?;
  } catch (_) {
    return null;
  }
}

/// Identidad de chat de ESTE dispositivo (visitante), también para revendedores:
/// el chat no depende de la sesión de revendedor.
/// shortcut: el JWT vive en la caché local (Hive) sin cifrar; moverlo a
/// almacenamiento seguro si el chat pasa a manejar datos sensibles.
final Provider<TokenProvider> guestTokenProvider = Provider<TokenProvider>((
  Ref ref,
) {
  final LocalCache cache = ref.read(localCacheProvider);
  final Dio base = ref.read(dioProvider);
  Future<String?>? pending;
  Future<String?> create() async {
    final Response<Map<String, dynamic>> r = await base
        .post<Map<String, dynamic>>('/guest-chat/session');
    final String? token = r.data?['token'] as String?;
    if (token != null) {
      await cache.put(_sessionKey, jsonEncode(r.data));
      // Ya hay sesión: registra el token FCM para recibir respuestas.
      unawaited(ref.read(pushServiceProvider).registerGuestToken());
    }
    return token;
  }

  return StaticTokenProvider(
    resolver: () async =>
        _readToken(cache) ??
        await (pending ??= create().whenComplete(() => pending = null)),
  );
});

/// Dio que firma con el token de visitante (no con el de Firebase).
final Provider<Dio> chatDioProvider = Provider<Dio>((Ref ref) {
  final LocalCache cache = ref.read(localCacheProvider);
  return DioClient.create(
    tokenProvider: ref.watch(guestTokenProvider),
    appCheckTokenSource: ref.watch(appCheckTokenSourceProvider),
    // Token vencido/inválido: se descarta y el próximo envío crea otro.
    onUnauthorized: () => cache.delete(_sessionKey),
  );
});

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    this.subtitle,
    this.logoUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unread = 0,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? logoUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unread;

  factory ChatConversation.fromJson(Map<String, dynamic> j) => ChatConversation(
    id: j['id'] as String,
    title: (j['providerName'] as String?) ?? 'Mayorista',
    subtitle: j['catalogName'] as String?,
    logoUrl: j['logoUrl'] as String?,
    lastMessage: _preview(
      j['lastMessage'] as String?,
      j['lastMessageType'] as String?,
    ),
    lastMessageAt: DateTime.tryParse('${j['lastMessageAt']}')?.toLocal(),
    unread: (j['unreadCount'] as num?)?.toInt() ?? 0,
  );
}

String? _preview(String? text, String? type) => switch (type) {
  'IMAGE' => '📷 Foto',
  'PRODUCT' => '🛍️ Producto',
  _ => text,
};

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.mine,
    required this.createdAt,
  });

  final String id;
  final String text;
  final bool mine;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    text: _preview(j['message'] as String?, j['messageType'] as String?) ?? '',
    mine: j['isMine'] as bool? ?? false,
    createdAt:
        DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
  );
}

class ChatApi {
  ChatApi(this._dio, this._cache);

  final Dio _dio;
  final LocalCache _cache;

  Future<List<ChatConversation>> conversations() async {
    final Response<List<dynamic>> r = await _dio.get<List<dynamic>>(
      '/conversations',
    );
    return (r.data ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> e) =>
              ChatConversation.fromJson(e.cast<String, dynamic>()),
        )
        .toList();
  }

  /// Abre (o retoma) el chat de un catálogo; devuelve el id de la conversación.
  Future<String> start(String catalogId, {String? message}) async {
    final Response<Map<String, dynamic>> r = await _dio
        .post<Map<String, dynamic>>(
          '/conversations/start',
          data: <String, dynamic>{'catalogId': catalogId, 'message': ?message},
        );
    return r.data!['id'] as String;
  }

  Future<List<ChatMessage>> messages(String id) async {
    final Response<List<dynamic>> r = await _dio.get<List<dynamic>>(
      '/conversations/$id/messages',
      queryParameters: <String, dynamic>{'limit': 100},
    );
    return (r.data ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> e) =>
              ChatMessage.fromJson(e.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<void> send(String id, String text) => _dio.post<dynamic>(
    '/conversations/$id/messages',
    data: <String, dynamic>{'message': text, 'messageType': 'TEXT'},
  );

  Future<void> markRead(String id) =>
      _dio.post<dynamic>('/conversations/$id/read');

  Future<void> setName(String nombre) => _dio.patch<dynamic>(
    '/guest-chat/me',
    data: <String, dynamic>{'nombre': nombre},
  );

  /// Solo se pregunta el nombre una vez (también si el usuario lo omite).
  bool get nameAsked => _cache.contains(_nameAskedKey);

  Future<void> markNameAsked() => _cache.put(_nameAskedKey, '1');
}

final Provider<ChatApi> chatApiProvider = Provider<ChatApi>(
  (Ref ref) =>
      ChatApi(ref.watch(chatDioProvider), ref.read(localCacheProvider)),
);

final conversationsProvider =
    FutureProvider.autoDispose<List<ChatConversation>>(
      (Ref ref) => ref.watch(chatApiProvider).conversations(),
    );
