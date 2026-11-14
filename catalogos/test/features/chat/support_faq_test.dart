import 'package:catalogos/features/chat/chat_api.dart';
import 'package:catalogos/features/chat/support_faq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('horario: lunes a sábado 8-18 hora Colombia', () {
    // 13:00 UTC = 8:00 Colombia (lunes 2026-11-16).
    expect(supportIsOpen(DateTime.utc(2026, 11, 16, 13)), isTrue);
    expect(supportIsOpen(DateTime.utc(2026, 11, 16, 12)), isFalse);
    expect(supportIsOpen(DateTime.utc(2026, 11, 16, 23)), isFalse);
    expect(supportIsOpen(DateTime.utc(2026, 11, 15, 17)), isFalse); // domingo
  });

  test('la conversación de soporte se llama Soporte FLY+', () {
    final ChatConversation c = ChatConversation.fromJson(<String, dynamic>{
      'id': 'x',
      'providerName': 'Flystock',
      'isSupport': true,
    });
    expect(c.isSupport, isTrue);
    expect(c.title, kSupportTitle);
  });
}
