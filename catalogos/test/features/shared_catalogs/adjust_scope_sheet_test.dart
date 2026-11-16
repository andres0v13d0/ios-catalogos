import 'package:catalogos/features/shared_catalogs/domain/price_rule_calculator.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rules_contract.dart';
import 'package:catalogos/features/shared_catalogs/presentation/adjust_scope_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const List<CatalogSubcategory> _subs = <CatalogSubcategory>[
  CatalogSubcategory(id: 's1', name: 'Camisetas', productCount: 3, rule: null),
  CatalogSubcategory(
    id: 's2',
    name: 'Blusas',
    productCount: 9,
    rule: PriceRule(mode: PriceRuleMode.percent, value: 15),
  ),
];

Future<Future<AdjustScope?> Function()> _open(WidgetTester tester) async {
  AdjustScope? out;
  bool done = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext c) => TextButton(
          onPressed: () async {
            out = await showAdjustScopeSheet(
              c,
              subcategories: _subs,
              catalogRule: null,
            );
            done = true;
          },
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  return () async {
    expect(done, isTrue);
    return out;
  };
}

void main() {
  testWidgets('"Todo el catálogo" termina de una vez', (tester) async {
    final result = await _open(tester);
    await tester.pump();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Por subcategoría'), findsOneWidget);
    expect(
      find.text('Camisetas'),
      findsNothing,
    ); // aún no se ven las subcategorías
    await tester.tap(find.text('Todo el catálogo'));
    await tester.pumpAndSettle();
    expect((await result())!.subcategories, isEmpty);
  });

  testWidgets(
    '"Por subcategoría" abre un segundo paso con botones multi-selección',
    (tester) async {
      final result = await _open(tester);
      await tester.pump();
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por subcategoría'));
      await tester.pumpAndSettle();
      expect(find.text('Elige las subcategorías'), findsOneWidget);
      expect(find.text('Elige al menos una'), findsOneWidget);
      await tester.tap(find.text('Camisetas'));
      await tester.tap(find.text('Blusas'));
      await tester.pump();
      expect(find.text('Continuar (2)'), findsOneWidget);
      await tester.tap(find.text('Camisetas')); // desmarca
      await tester.pump();
      expect(find.text('Continuar (1)'), findsOneWidget);
      await tester.tap(find.text('Continuar (1)'));
      await tester.pumpAndSettle();
      expect((await result())!.subcategories.map((s) => s.id), <String>['s2']);
    },
  );
}
