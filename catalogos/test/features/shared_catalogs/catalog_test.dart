// Tests del modelo Catalog (tarea 1.14) con la FORMA REAL anidada del backend.
//
// Verifica los dos bugs corregidos:
//  - PROBLEMA 1: id debe ser el UUID del catálogo (catalogId / catalog.id),
//    NUNCA el id numérico del vínculo (reseller_shared_catalogs.id).
//  - PROBLEMA 2: providerName/logo se leen de provider.nombreEmpresa /
//    provider.logoOptimizedUrl; providerLabel nunca devuelve "Proveedor <id>".

import 'package:catalogos/features/shared_catalogs/domain/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixture con la forma EXACTA que devuelve serializeSharedCatalog.
Map<String, dynamic> realNestedFixture() => <String, dynamic>{
  'id': 3, // id del vínculo (INT) — NO es el id del catálogo
  'catalogId': '11111111-2222-3333-4444-555555555555',
  'providerId': 5,
  'linkedAt': '2025-01-01T00:00:00.000Z',
  'catalog': <String, dynamic>{
    'id': '11111111-2222-3333-4444-555555555555',
    'publicName': 'Catálogo Público',
    'description': 'desc',
    'bannerUrl': 'https://cdn/catalog-banner.jpg',
    'ogImageUrl': 'https://cdn/catalog-og.jpg',
    'enlace': 'mi-enlace',
    'priceField': 'none',
  },
  'provider': <String, dynamic>{
    'id': 5,
    'nombreEmpresa': 'Mi Empresa',
    'logoUrl': 'https://cdn/logo.png',
    'logoOptimizedUrl': 'https://cdn/logo.webp',
    'bannerUrl': 'https://cdn/provider-banner.jpg',
    'bannerDesktopUrl': null,
    'bannerMobileUrl': null,
  },
};

void main() {
  group('Catalog.fromJson (forma anidada real)', () {
    test('id = UUID del catálogo (NO el id numérico del vínculo)', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.id, '11111111-2222-3333-4444-555555555555');
      expect(c.linkId, 3);
      // Nunca el id del vínculo.
      expect(c.id, isNot('3'));
    });

    test('displayName = catalog.publicName', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.displayName, 'Catálogo Público');
    });

    test('providerName = provider.nombreEmpresa', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.providerName, 'Mi Empresa');
      expect(c.providerId, 5);
    });

    test('providerLogoUrl prefiere el logo optimizado', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.providerLogoUrl, 'https://cdn/logo.webp');
    });

    test('providerBannerUrl y bannerUrl mapeados', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.providerBannerUrl, 'https://cdn/provider-banner.jpg');
      expect(c.bannerUrl, 'https://cdn/catalog-banner.jpg');
    });

    test('priceField mapeado (modo sin precios)', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.priceField, 'none');
    });

    test('ogImageUrl mapeado (catalog.ogImageUrl / og_image_url)', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.ogImageUrl, 'https://cdn/catalog-og.jpg');

      final json = realNestedFixture();
      final cat = json['catalog'] as Map<String, dynamic>;
      cat.remove('ogImageUrl');
      cat['og_image_url'] = 'https://cdn/snake-og.jpg';
      expect(Catalog.fromJson(json).ogImageUrl, 'https://cdn/snake-og.jpg');
    });
  });

  group('PRIVACIDAD: internalName NUNCA se usa como displayName', () {
    test('ignora internalName aunque falte publicName', () {
      final json = realNestedFixture();
      final cat = json['catalog'] as Map<String, dynamic>;
      cat.remove('publicName');
      cat['internalName'] = 'NOMBRE INTERNO SECRETO';
      // También a nivel plano, por si el payload legado lo trae arriba.
      json['internalName'] = 'NOMBRE INTERNO SECRETO';

      final c = Catalog.fromJson(json);
      // Sin publicName, displayName queda vacío; nunca el nombre interno.
      expect(c.displayName, isNot('NOMBRE INTERNO SECRETO'));
      expect(c.displayName, '');
    });
  });

  group('coverImageUrl (portada de la tarjeta)', () {
    test('prefiere el banner del catálogo', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.coverImageUrl, 'https://cdn/catalog-banner.jpg');
    });

    test('cae a ogImageUrl cuando no hay banner del catálogo', () {
      final json = realNestedFixture();
      (json['catalog'] as Map<String, dynamic>).remove('bannerUrl');
      final c = Catalog.fromJson(json);
      expect(c.coverImageUrl, 'https://cdn/catalog-og.jpg');
    });

    test('cae al banner del proveedor cuando no hay banner ni ogImage', () {
      final json = realNestedFixture();
      final cat = json['catalog'] as Map<String, dynamic>;
      cat.remove('bannerUrl');
      cat.remove('ogImageUrl');
      final c = Catalog.fromJson(json);
      expect(c.coverImageUrl, 'https://cdn/provider-banner.jpg');
    });

    test('es null cuando no hay ninguna imagen (la UI usa gradiente)', () {
      final json = realNestedFixture();
      final cat = json['catalog'] as Map<String, dynamic>;
      cat.remove('bannerUrl');
      cat.remove('ogImageUrl');
      (json['provider'] as Map<String, dynamic>).remove('bannerUrl');
      final c = Catalog.fromJson(json);
      expect(c.coverImageUrl, isNull);
    });
  });

  group('isPriceHidden', () {
    test('true cuando priceField == none', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.isPriceHidden, isTrue);
    });

    test('false cuando priceField es otro valor', () {
      final json = realNestedFixture();
      (json['catalog'] as Map<String, dynamic>)['priceField'] = 'mayorista';
      expect(Catalog.fromJson(json).isPriceHidden, isFalse);
    });
  });

  group('providerLabel / providerInitials', () {
    test('providerLabel usa el nombre cuando existe', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.providerLabel, 'Mi Empresa');
    });

    test('providerLabel NUNCA es "Proveedor <id>" cuando falta el nombre', () {
      final json = realNestedFixture();
      (json['provider'] as Map<String, dynamic>).remove('nombreEmpresa');
      final c = Catalog.fromJson(json);
      expect(c.providerName, isNull);
      expect(c.providerLabel, 'Proveedor');
      expect(c.providerLabel, isNot(contains('5')));
    });

    test('providerInitials: 2 iniciales del nombre', () {
      final c = Catalog.fromJson(realNestedFixture());
      expect(c.providerInitials, 'ME'); // Mi Empresa
    });

    test('providerInitials: marcador neutro sin nombre', () {
      final json = realNestedFixture();
      (json['provider'] as Map<String, dynamic>).remove('nombreEmpresa');
      final c = Catalog.fromJson(json);
      expect(c.providerInitials, 'PR');
    });

    test('providerInitials: una sola palabra toma 2 letras', () {
      final json = realNestedFixture();
      (json['provider'] as Map<String, dynamic>)['nombreEmpresa'] = 'Acme';
      final c = Catalog.fromJson(json);
      expect(c.providerInitials, 'AC');
    });
  });

  group('toJson round-trip (caché Hive)', () {
    test('fromJson(toJson(x)) == x', () {
      final original = Catalog.fromJson(realNestedFixture());
      final roundTripped = Catalog.fromJson(original.toJson());
      expect(roundTripped, original);
    });

    test('el round-trip preserva id (UUID) y no lo cambia al link id', () {
      final original = Catalog.fromJson(realNestedFixture());
      final roundTripped = Catalog.fromJson(original.toJson());
      expect(roundTripped.id, '11111111-2222-3333-4444-555555555555');
      expect(roundTripped.linkId, 3);
    });
  });

  group('tolerancia legacy', () {
    test('nunca usa un id numérico plano como id de catálogo', () {
      // Payload legado solo con id numérico plano: no hay UUID disponible.
      final c = Catalog.fromJson(<String, dynamic>{
        'id': 42,
        'publicName': 'Legacy',
        'providerId': 7,
      });
      // id no puede ser "42"; queda vacío por falta de UUID.
      expect(c.id, '');
      expect(c.linkId, 42);
      expect(c.displayName, 'Legacy');
    });

    test('acepta un id plano SOLO si parece UUID', () {
      const uuid = 'abcabcab-1234-1234-1234-abcabcabcabc';
      final c = Catalog.fromJson(<String, dynamic>{
        'id': uuid,
        'publicName': 'Legacy UUID',
        'providerId': 7,
      });
      expect(c.id, uuid);
      expect(c.linkId, isNull);
    });
  });
}
