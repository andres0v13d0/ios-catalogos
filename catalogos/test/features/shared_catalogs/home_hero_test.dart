// Los botones del hero ("Tus catálogos") deben invocar su callback propio:
// ajustes de cuenta y play del video de ayuda son botones distintos, uno al
// lado del otro (ver home_page_test.dart para el flujo de ajustes integrado
// con el router; aquí solo se verifica el cableado del widget).

import 'package:catalogos/features/shared_catalogs/presentation/home_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHero(
    WidgetTester tester, {
    required VoidCallback onOpenSettings,
    required VoidCallback onPlayVideo,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeHero(
            height: 200,
            subtitle: '',
            onOpenSettings: onOpenSettings,
            onPlayVideo: onPlayVideo,
          ),
        ),
      ),
    );
  }

  testWidgets('el botón de ajustes invoca onOpenSettings', (
    WidgetTester tester,
  ) async {
    int openSettingsCount = 0;
    await pumpHero(
      tester,
      onOpenSettings: () => openSettingsCount++,
      onPlayVideo: () => fail('no debía llamarse'),
    );

    await tester.tap(find.bySemanticsLabel('Ajustes de cuenta'));

    expect(openSettingsCount, 1);
  });

  testWidgets('el botón de play invoca onPlayVideo', (
    WidgetTester tester,
  ) async {
    int playVideoCount = 0;
    await pumpHero(
      tester,
      onOpenSettings: () => fail('no debía llamarse'),
      onPlayVideo: () => playVideoCount++,
    );

    await tester.tap(find.bySemanticsLabel('Ver video de ayuda'));

    expect(playVideoCount, 1);
  });
}
