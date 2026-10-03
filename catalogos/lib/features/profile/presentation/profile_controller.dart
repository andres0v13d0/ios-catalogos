import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../shared/models/reseller.dart';
import '../../auth/data/session_store.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../data/reseller_repository.dart';

/// Estado del guard de "perfil incompleto" (tarea 1.13).
///
/// - [unknown]: aún no se consultó `/reseller/me` (no se fuerza redirección).
/// - [incomplete]: el reseller no tiene `nombre` → el router redirige a la
///   ruta de completar perfil.
/// - [complete]: el reseller ya tiene `nombre` → el guard deja de redirigir.
enum ProfileStatus { unknown, incomplete, complete }

/// Estado del controlador de perfil.
class ProfileState {
  const ProfileState({
    this.status = ProfileStatus.unknown,
    this.reseller,
    this.isLoading = false,
    this.errorMessage,
  });

  final ProfileStatus status;
  final Reseller? reseller;
  final bool isLoading;
  final String? errorMessage;

  ProfileState copyWith({
    ProfileStatus? status,
    Reseller? reseller,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      reseller: reseller ?? this.reseller,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controlador del perfil del revendedor (tarea 1.13).
///
/// Carga el perfil (`GET /reseller/me`), expone si el perfil está incompleto
/// (para el guard de navegación) y permite completar el nombre
/// (`PATCH /reseller/me`). Mantiene en caché local segura los metadatos del
/// perfil vía el `SessionStore` para que el guard tenga un valor inmediato en
/// arranques posteriores.
class ProfileController extends Notifier<ProfileState> {
  ResellerRepository get _repo => ref.read(resellerRepositoryProvider);

  @override
  ProfileState build() {
    // Al cerrar sesión (logout o política de 401), reinicia el estado del
    // perfil para que el guard no siga redirigiendo a completar perfil.
    ref.listen<AuthStatus>(authStateProvider, (AuthStatus? prev, AuthStatus next) {
      if (next == AuthStatus.signedOut) {
        state = const ProfileState();
      }
    });
    return const ProfileState();
  }

  /// Determina el estado del perfil a partir de un [Reseller].
  ProfileStatus _statusFor(Reseller reseller) =>
      reseller.isProfileComplete
          ? ProfileStatus.complete
          : ProfileStatus.incomplete;

  /// Carga el perfil desde el backend y actualiza el estado + los metadatos
  /// persistidos. Se invoca tras el login y, opcionalmente, al entrar a la
  /// pantalla de completar perfil.
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final Result<Reseller> result = await _repo.getMe();
    switch (result) {
      case Ok<Reseller>(:final value):
        await _persist(value);
        state = ProfileState(
          status: _statusFor(value),
          reseller: value,
        );
      case Err<Reseller>(:final failure):
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
    }
  }

  /// Completa/actualiza el nombre del perfil (`PATCH /reseller/me`).
  ///
  /// Devuelve `true` si se guardó con éxito (y el estado pasa a `complete`,
  /// deteniendo la redirección del guard).
  Future<bool> saveName(String nombre) async {
    final trimmed = nombre.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(errorMessage: 'Ingresa tu nombre.');
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final Result<Reseller> result = await _repo.updateMe(nombre: trimmed);
    switch (result) {
      case Ok<Reseller>(:final value):
        await _persist(value);
        state = ProfileState(
          status: _statusFor(value),
          reseller: value,
        );
        return value.isProfileComplete;
      case Err<Reseller>(:final failure):
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
    }
  }

  /// Reinicia el estado (p. ej. tras un logout).
  void reset() => state = const ProfileState();

  Future<void> _persist(Reseller reseller) async {
    await ref.read(sessionStoreProvider).save(
          SessionMetadata(resellerId: reseller.id, nombre: reseller.nombre),
        );
  }
}

/// Provider del controlador de perfil.
final NotifierProvider<ProfileController, ProfileState>
    profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);
