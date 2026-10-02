// Test de la identidad visual FlyStock (tarea 0.3).
//
// Verifica el criterio de aceptación: "pantalla de muestra renderiza
// tipografía y colores correctos". Al no haber Android SDK en el entorno
// (sin `flutter run` on-device), esta prueba de widget cubre el CA:
//   - El tema expone Poppins y el ColorScheme de marca.
//   - La pantalla de muestra renderiza y usa la tipografía Poppins.
//   - El botón primario pinta el gradiente #004AAD → #5DE0E6 → #00FF94.

import 'package:catalogos/app/theme/app_colors.dart';
import 'package:catalogos/app/theme/app_theme.dart';
import 'package:catalogos/shared/widgets/fly_primary_button.dart';
import 'package:catalogos/shared/widgets/theme_showcase_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Nota: en el entorno de test no hay red, por lo que `google_fonts` no puede
  // descargar el .ttf de Poppins y recurre a su fuente de respaldo. Eso es
  // esperado y no afecta a las aserciones: la familia tipográfica declarada en
  // el estilo sigue siendo "Poppins", que es lo que verifican los tests.
  group('AppTheme (identidad FlyStock)', () {
    test('ColorScheme usa la paleta de marca', () {
      const ColorScheme scheme = AppTheme.colorScheme;

      expect(scheme.primary, AppColors.primary); // #001634
      expect(scheme.secondary, AppColors.secondary); // #004AAD
      expect(scheme.tertiary, AppColors.accent); // #5DE0E6
      expect(scheme.brightness, Brightness.light);
    });

    test('ThemeData aplica fontFamily Poppins y fondo de marca', () {
      final ThemeData theme = AppTheme.themeData;

      expect(theme.textTheme.bodyMedium!.fontFamily, contains('Poppins'));
      expect(theme.scaffoldBackgroundColor, AppColors.background); // #F8F9FA
      expect(theme.colorScheme.primary, AppColors.primary);
    });

    test('El gradiente del botón primario es #004AAD → #5DE0E6 → #00FF94', () {
      expect(AppColors.primaryGradient, <Color>[
        AppColors.secondary,
        AppColors.accent,
        AppColors.brand,
      ]);
    });
  });

  group('ThemeShowcasePage (pantalla de muestra)', () {
    testWidgets('renderiza tipografía Poppins y la paleta de color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData,
          home: const ThemeShowcasePage(),
        ),
      );

      // Tipografía: el texto de encabezado se renderiza con Poppins.
      expect(find.text('Tipografía Poppins'), findsOneWidget);
      final Text heading = tester.widget<Text>(find.text('Tipografía Poppins'));
      final TextStyle effective = heading.style ??
          DefaultTextStyle.of(
            tester.element(find.text('Tipografía Poppins')),
          ).style;
      expect(effective.fontFamily, contains('Poppins'));

      // Colores: hay muestras de cada color de marca.
      expect(find.text('Primario'), findsOneWidget);
      expect(find.text('Secundario'), findsOneWidget);
      expect(find.text('Acento'), findsOneWidget);
      expect(find.text('Brand'), findsOneWidget);
    });

    testWidgets('el botón primario pinta el gradiente de marca',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData,
          home: const ThemeShowcasePage(),
        ),
      );

      expect(find.byType(FlyPrimaryButton), findsNWidgets(2));

      // El contenedor decorado del botón habilitado usa el gradiente de marca.
      final Finder gradientBox = find
          .descendant(
            of: find.widgetWithText(FlyPrimaryButton, 'Continuar'),
            matching: find.byType(DecoratedBox),
          )
          .first;

      final DecoratedBox decorated = tester.widget<DecoratedBox>(gradientBox);
      final BoxDecoration decoration =
          decorated.decoration as BoxDecoration;
      final LinearGradient gradient = decoration.gradient! as LinearGradient;

      expect(gradient.colors, <Color>[
        AppColors.secondary,
        AppColors.accent,
        AppColors.brand,
      ]);
    });
  });
}
