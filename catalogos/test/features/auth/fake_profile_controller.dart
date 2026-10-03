// Fake de [ProfileController] para los tests de autenticación (tareas 1.9/1.10).
//
// Los tests de OTP solo validan el flujo de auth. Tras un login exitoso,
// `AuthController._promoteSession` dispara `profileController.loadProfile()`
// (GET /reseller/me) en segundo plano. Ese provider real cuelga de
// `resellerRepository` → `dioProvider` (Dio/Firebase reales), que NO están
// disponibles en estos tests.
//
// Este fake sustituye a `profileControllerProvider` con un `loadProfile()`
// no-op, de modo que el test de OTP quede aislado de la capa de datos y de la
// red/Firebase, sin tocar el comportamiento de producción.

import 'package:catalogos/features/profile/presentation/profile_controller.dart';

class FakeProfileController extends ProfileController {
  /// Número de veces que se invocó [loadProfile] (para aserciones opcionales).
  int loadProfileCalls = 0;

  @override
  ProfileState build() => const ProfileState();

  @override
  Future<void> loadProfile() async {
    loadProfileCalls += 1;
  }
}
