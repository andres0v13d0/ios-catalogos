// Test del ErrorApp (endurecimiento del bootstrap de Firebase).
//
// Verifica que la pantalla de error renderiza el mensaje/detalle del error
// cuando la inicialización de Firebase falla en una plataforma soportada.

import 'package:catalogos/app/error_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ErrorApp muestra el mensaje de fallo de inicialización',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ErrorApp(error: 'FirebaseException: boom'),
    );
    await tester.pump();

    expect(find.text('No se pudo iniciar la aplicación'), findsOneWidget);
    expect(find.textContaining('FirebaseException: boom'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
