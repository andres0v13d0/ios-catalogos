import 'package:catalogos/features/buy/cart_controller.dart';
import 'package:catalogos/features/visitor/visitor_catalogs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  test('newUuid tiene formato v4', () {
    expect(
      newUuid(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test(
    'submitOrder manda el cuerpo esperado y lee el total del servidor',
    () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final DioAdapter adapter = DioAdapter(dio: dio);
      const String id = '11111111-1111-4111-8111-111111111111';
      adapter.onPost(
        '/catalog-orders',
        (server) => server.reply(200, <String, dynamic>{
          'orderId': 'o1',
          'providerOrderNumber': 7,
          'total': 66000,
          'status': 'pendiente',
        }),
        data: <String, dynamic>{
          'clientOrderId': id,
          'shortUuid': 'abcd1234',
          'buyer': <String, dynamic>{'nombre': 'Ana'},
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'productId': 'p1',
              'quantity': 2,
              'color': 'Rojo',
            },
          ],
        },
      );
      final SubmittedOrder o = await VisitorCatalogApi(dio).submitOrder(
        clientOrderId: id,
        shortUuid: 'abcd1234',
        lines: const <CartLine>[
          CartLine(
            catalogId: 'c1',
            catalogName: 'X',
            productId: 'p1',
            name: 'P',
            quantity: 2,
            color: 'Rojo',
          ),
        ],
        buyer: const BuyerInfo(nombre: ' Ana ', celular: ' '),
      );
      expect(o.number, 7);
      expect(o.total, 66000);
    },
  );
}
