// El botón de play del hero ("Tus catálogos") invoca su callback. El engranaje
// de ajustes y la marca FLY+ ya no están: Cuenta es una pestaña propia.

import 'package:catalogos/features/shared_catalogs/presentation/home_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el botón de play invoca onPlayVideo y no hay engranaje', (
    WidgetTester tester,
  ) async {
    int playVideoCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeHero(
            height: 200,
            subtitle: '',
            onPlayVideo: () => playVideoCount++,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Ver video de ayuda'));

    expect(playVideoCount, 1);
    expect(find.bySemanticsLabel('Ajustes de cuenta'), findsNothing);
    expect(find.text('FLY'), findsNothing);
  });
}
