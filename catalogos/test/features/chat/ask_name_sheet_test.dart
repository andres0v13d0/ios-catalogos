import 'package:catalogos/features/chat/ask_name_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String?> _open(WidgetTester tester) async {
  String? result = 'sin-respuesta';
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext c) => TextButton(
          onPressed: () async =>
              result = await showAskNameSheet(c, providerName: 'Ulala'),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  expect(find.text('¿Cómo te llamas?'), findsOneWidget);
  expect(find.textContaining('Así te verá Ulala'), findsOneWidget);
  return Future<String?>.value(result);
}

void main() {
  testWidgets('Continuar devuelve el nombre escrito (sin espacios sobrantes)', (
    tester,
  ) async {
    String? out = 'x';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext c) => TextButton(
            onPressed: () async => out = await showAskNameSheet(c),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Ana ');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(out, 'Ana');
  });

  testWidgets('Omitir devuelve null', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo te llamas?'), findsNothing);
  });
}
