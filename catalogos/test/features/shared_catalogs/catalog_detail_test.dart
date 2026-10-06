// Tests del modelo CatalogDetail — foco en la CORRECCIÓN DE PRIVACIDAD.
//
// El endpoint legado GET /catalog/by-catalog/:id/products puede devolver, bajo
// `catalog`, tanto `internalName` (nombre interno) como `publicName`/`name`.
// El nombre interno JAMÁS debe mostrarse: si `publicName` falta, displayName
// debe caer al nombre del proveedor (nombre_empresa) o al genérico 'Catálogo',
// NUNCA a `internalName`.

import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogDetail.fromJson — displayName / privacidad', () {
    test('usa publicName cuando está presente', () {
      final detail = CatalogDetail.fromJson(<String, dynamic>{
        'catalog': <String, dynamic>{
          'id': 'cat-1',
          'internalName': 'NOMBRE INTERNO SECRETO',
          'publicName': 'Catálogo Público',
          'priceField': 'mayorista',
        },
        'products': <dynamic>[],
      });

      expect(detail.publicName, 'Catálogo Público');
      expect(detail.displayName, 'Catálogo Público');
    });

    test('NUNCA cae a internalName: usa el nombre del proveedor cuando falta '
        'publicName', () {
      final detail = CatalogDetail.fromJson(<String, dynamic>{
        'nombre_empresa': 'Mi Empresa',
        'catalog': <String, dynamic>{
          'id': 'cat-1',
          // Sin publicName ni name; solo internalName (que debe ignorarse).
          'internalName': 'NOMBRE INTERNO SECRETO',
          'priceField': 'none',
        },
        'products': <dynamic>[],
      });

      // publicName no se puebla con el nombre interno.
      expect(detail.publicName, isNull);
      // displayName cae al nombre del proveedor, nunca al interno.
      expect(detail.displayName, 'Mi Empresa');
      expect(detail.displayName, isNot('NOMBRE INTERNO SECRETO'));
    });

    test(
      'sin publicName ni proveedor, displayName es "Catálogo" (no el interno)',
      () {
        final detail = CatalogDetail.fromJson(<String, dynamic>{
          'catalog': <String, dynamic>{
            'id': 'cat-1',
            'internalName': 'NOMBRE INTERNO SECRETO',
          },
          'products': <dynamic>[],
        });

        expect(detail.displayName, 'Catálogo');
        expect(detail.displayName, isNot('NOMBRE INTERNO SECRETO'));
      },
    );

    test("'name' SÍ es un fallback aceptable (= publicName en el legado)", () {
      final detail = CatalogDetail.fromJson(<String, dynamic>{
        'catalog': <String, dynamic>{
          'id': 'cat-1',
          'internalName': 'NOMBRE INTERNO SECRETO',
          'name': 'Nombre Compat',
        },
        'products': <dynamic>[],
      });

      expect(detail.publicName, 'Nombre Compat');
      expect(detail.displayName, 'Nombre Compat');
    });
  });
}
