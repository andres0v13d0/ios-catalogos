import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/auth_state_provider.dart';
import 'visitor_catalogs.dart';

/// Acceso de la cuenta a un catálogo (lo decide el proveedor). Solo aplica a la
/// app: la web de catálogos no lo consulta.
enum CatalogAccess {
  approved,
  pending,
  blocked,

  /// Sin sesión en una compilación que exige cuenta para ver precios.
  loginRequired;

  bool get canSeePrices => this == approved;

  /// Mensaje para quien no puede ver precios ni pedir; `null` si tiene acceso.
  String? get message => switch (this) {
    approved => null,
    pending => 'El proveedor aún no ha aceptado tu solicitud.',
    blocked => 'No tienes acceso a este catálogo.',
    loginRequired =>
      'Inicia sesión en la pestaña Cuenta para ver los precios y hacer pedidos.',
  };

  static CatalogAccess parse(Object? v) => switch (v) {
    'pending' => pending,
    'blocked' => blocked,
    _ => approved,
  };
}

/// Estado de acceso del catálogo [catalogId]. Sin sesión en un catálogo no público exige iniciar sesión; en un catálogo
/// compartido por el proveedor, o si falla la consulta, no se restringe (la
/// restricción es una regla de producto, no de seguridad: la web sigue igual).
final catalogAccessProvider = FutureProvider.autoDispose
    .family<CatalogAccess, String>((Ref ref, String catalogId) async {
      if (!ref.watch(isSignedInProvider)) {
        // Sin sesión solo ve precios un catálogo que el proveedor marcó público.
        try {
          return await ref
                  .watch(visitorCatalogApiProvider)
                  .isPublicCatalog(catalogId)
              ? CatalogAccess.approved
              : CatalogAccess.loginRequired;
        } catch (_) {
          return CatalogAccess.approved;
        }
      }
      if (ref.watch(sharedCatalogIdsProvider).contains(catalogId)) {
        return CatalogAccess.approved;
      }
      try {
        return await ref.watch(visitorCatalogApiProvider).accessFor(catalogId);
      } catch (_) {
        return CatalogAccess.approved;
      }
    });
