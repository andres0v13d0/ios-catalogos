import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_routes.dart';
import '../../features/chat/chat_api.dart';
import '../../features/visitor/visitor_catalogs.dart';
import '../storage/storage.dart';

/// Canal y sonido: CONTRATO con el backend (mismos que usa Flymovil).
/// Android no deja cambiar el sonido de un canal ya creado: para otro sonido
/// hay que crear un canal con otro id.
const String kPushChannelId = 'catalogos_v2';
const String _channelName = 'Novedades de tus catálogos';

/// Chat: canal propio con su sonido (contrato con el backend: GUEST_CHAT_PUSH).
const String kChatChannelId = 'chat_v1';
const String _chatChannelName = 'Mensajes de chat';
const _chatSound = RawResourceAndroidNotificationSound('chat_message');
const _sound = RawResourceAndroidNotificationSound('flymovil_notif');
const String _topicsKey = 'push_topics';

/// Conversación abierta y visible: no se muestra aviso de ella en primer plano.
String? activeChatId;

/// Ruta a abrir según el data del aviso (contrato del backend):
/// `{type:'chat', conversationId}` o `{type:'new_products', shortUuid}`.
String? routeFromPushData(Map<String, dynamic> d) {
  final Object? id = d['conversationId'];
  if (d['type'] == 'chat' && id is String && id.isNotEmpty) {
    return AppRoutes.conversationPath(id);
  }
  final Object? code = d['shortUuid'];
  if (d['type'] == 'new_products' && code is String && code.isNotEmpty) {
    return AppRoutes.visitorCatalogPath(code);
  }
  return null;
}

String topicFor(String catalogId) => 'catalogo_${catalogId}_nuevos';

/// FCM + avisos locales. Todo es "mejor esfuerzo": sin Firebase (tests,
/// escritorio) no hace nada.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  void Function(String route)? _navigate;
  bool _started = false;

  bool get _available => Firebase.apps.isNotEmpty;

  /// Conecta el router: toda ruta de aviso (toque) pasa por aquí.
  void bindNavigator(void Function(String route) navigate) =>
      _navigate = navigate;

  Future<void> start() async {
    if (_started || !_available) return;
    _started = true;
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse r) {
          final String? p = r.payload;
          if (p == null || p.isEmpty) return;
          _open((jsonDecode(p) as Map).cast<String, dynamic>());
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              kPushChannelId,
              _channelName,
              importance: Importance.high,
              sound: _sound,
            ),
          );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              kChatChannelId,
              _chatChannelName,
              importance: Importance.high,
              sound: _chatSound,
            ),
          );
      final FirebaseMessaging fcm = FirebaseMessaging.instance;
      await fcm.requestPermission();
      FirebaseMessaging.onMessage.listen(_foreground);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage m) => _open(m.data),
      );
      final RemoteMessage? initial = await fcm.getInitialMessage();
      if (initial != null) _open(initial.data);
      fcm.onTokenRefresh.listen((_) => registerGuestToken());
      await syncTopics(_ref.read(visitorCatalogsProvider));
      await registerGuestToken();
    } catch (e) {
      debugPrint('[push] start falló: $e');
    }
  }

  /// Toque de un aviso: navega a su pantalla (chat o catálogo).
  @visibleForTesting
  void open(Map<String, dynamic> data) => _open(data);

  void _open(Map<String, dynamic> data) {
    final String? route = routeFromPushData(data);
    if (route != null) _navigate?.call(route);
  }

  Future<void> _foreground(RemoteMessage m) async {
    final RemoteNotification? n = m.notification;
    if (n == null) return;
    if (m.data['type'] == 'chat' && m.data['conversationId'] == activeChatId) {
      return;
    }
    final bool chat = m.data['type'] == 'chat';
    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          chat ? kChatChannelId : kPushChannelId,
          chat ? _chatChannelName : _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
          sound: chat ? _chatSound : _sound,
        ),
        iOS: DarwinNotificationDetails(
          sound: chat ? 'chat_message.wav' : 'flymovil_notif.wav',
        ),
      ),
      payload: jsonEncode(m.data),
    );
  }

  /// Suscribe a los temas de los catálogos guardados y baja los quitados.
  Future<void> syncTopics(List<VisitorCatalog> saved) async {
    if (!_available || !_started) return;
    try {
      final LocalCache cache = _ref.read(localCacheProvider);
      final Set<String> old = <String>{
        ...(jsonDecode(cache.get(_topicsKey) ?? '[]') as List<dynamic>)
            .cast<String>(),
      };
      final Set<String> want = saved
          .map((VisitorCatalog c) => topicFor(c.catalogId))
          .toSet();
      final FirebaseMessaging fcm = FirebaseMessaging.instance;
      for (final String t in want.difference(old)) {
        await fcm.subscribeToTopic(t);
      }
      for (final String t in old.difference(want)) {
        await fcm.unsubscribeFromTopic(t);
      }
      await cache.put(_topicsKey, jsonEncode(want.toList()));
    } catch (e) {
      debugPrint('[push] topics falló: $e');
    }
  }

  /// Registra el token FCM para avisos de chat. Solo si ya existe sesión de
  /// visitante (se llama también justo al crearla).
  Future<void> registerGuestToken() async {
    if (!_available) return;
    try {
      if (_ref.read(localCacheProvider).get('guest_chat_session') == null) {
        return;
      }
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _ref
          .read(chatDioProvider)
          .post<void>(
            '/guest-chat/push-token',
            data: <String, String>{
              'fcmToken': token,
              'platform': defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'android',
            },
          );
    } catch (e) {
      debugPrint('[push] token falló: $e');
    }
  }
}

final Provider<PushService> pushServiceProvider = Provider<PushService>(
  PushService.new,
);
