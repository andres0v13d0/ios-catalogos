import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Metadatos de sesión del lado de la app persistidos de forma segura
/// (tarea 1.12).
///
/// Guarda SOLO datos no sensibles de perfil/onboarding del revendedor:
/// el `id` y el `nombre` del reseller (para pintar la UI al instante y evaluar
/// el guard de "perfil incompleto" sin esperar a la red).
///
/// DECISIÓN DE DISEÑO (importante): aquí NO se guarda el `idToken` de Firebase.
/// El token es efímero (expira en ~1h) y `firebase_auth` ya persiste su propio
/// usuario entre reinicios; el token se deriva on-demand con
/// `currentUser.getIdToken()` (ver `FirebaseTokenProvider`). Persistir el token
/// aquí sería redundante e inseguro (quedaría obsoleto). Por eso este store se
/// limita a metadatos del perfil.
class SessionMetadata {
  const SessionMetadata({this.resellerId, this.nombre});

  /// Id del reseller (del backend), si se conoce.
  final int? resellerId;

  /// Nombre del reseller; si está vacío/null, el perfil se considera
  /// incompleto y el guard redirige a completar perfil (tarea 1.13).
  final String? nombre;

  /// `true` si el perfil tiene un nombre no vacío.
  bool get isProfileComplete => (nombre ?? '').trim().isNotEmpty;
}

/// Abstracción del almacenamiento de metadatos de sesión, para poder
/// inyectar un fake en tests sin tocar el almacenamiento seguro del SO.
abstract interface class SessionStore {
  Future<SessionMetadata> read();
  Future<void> save(SessionMetadata metadata);
  Future<void> clear();
}

/// Implementación de [SessionStore] respaldada por `flutter_secure_storage`.
class SecureSessionStore implements SessionStore {
  // En flutter_secure_storage 11.x el constructor por defecto ya usa cifrado
  // fuerte (AES-GCM con envoltura de clave RSA) en Android y Keychain en iOS,
  // por lo que no hace falta configurar `encryptedSharedPreferences`.
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _kResellerId = 'session.reseller_id';
  static const String _kNombre = 'session.reseller_nombre';

  @override
  Future<SessionMetadata> read() async {
    final idRaw = await _storage.read(key: _kResellerId);
    final nombre = await _storage.read(key: _kNombre);
    return SessionMetadata(
      resellerId: idRaw == null ? null : int.tryParse(idRaw),
      nombre: nombre,
    );
  }

  @override
  Future<void> save(SessionMetadata metadata) async {
    if (metadata.resellerId != null) {
      await _storage.write(
        key: _kResellerId,
        value: metadata.resellerId.toString(),
      );
    }
    if (metadata.nombre != null) {
      await _storage.write(key: _kNombre, value: metadata.nombre);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kResellerId);
    await _storage.delete(key: _kNombre);
  }
}
