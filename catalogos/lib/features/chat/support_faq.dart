/// Preguntas y respuestas rápidas del chat "Soporte FLY+" (se responden en la
/// app, sin pasar por el equipo). Textos de Hernan; los de [corchetes] están
/// adaptados a los nombres reales de la app y los debe confirmar el equipo.
class SupportFaq {
  const SupportFaq(this.question, this.answer);

  final String question;
  final String answer;
}

const String kSupportTitle = 'Soporte FLY+';

const List<SupportFaq> kSupportFaqs = <SupportFaq>[
  SupportFaq(
    '¿Cómo agrego a mi proveedor?',
    'Pídele a tu proveedor el enlace de su catálogo en FLY+. Cuando te lo mande por WhatsApp, ábrelo con la app instalada y queda agregado. Desde ahí ves sus novedades.',
  ),
  SupportFaq(
    '¿Cómo hago un pedido?',
    'Entra al catálogo de tu proveedor, agrega los productos al carrito y toca Enviar pedido. El pedido le llega directo a tu proveedor y él te confirma.',
  ),
  SupportFaq(
    '¿Cómo le escribo a mi proveedor?',
    'Abre el catálogo de tu proveedor y toca el ícono de chat. Ahí le puedes preguntar por precios, colores o tu pedido.',
  ),
  SupportFaq(
    'No me llegan las notificaciones',
    'Revisa que FLY+ tenga las notificaciones activadas: en tu celular ve a Ajustes › Aplicaciones › FLY+ › Notificaciones y actívalas. Si sigue igual, toca “Hablar con soporte”.',
  ),
  SupportFaq(
    '¿La app tiene algún costo?',
    'No. FLY+ es gratis para ti. Descárgala, agrega a tus proveedores y úsala sin pagar nada.',
  ),
  SupportFaq(
    '¿Quién ve mis datos?',
    'Solo los proveedores que tú agregaste. En FLY+ no te mostramos otros proveedores ni compartimos tus datos con nadie más.',
  ),
];

const String kTalkToSupport = 'Hablar con soporte';
const String kSupportAsk = '¿Te sirvió?';
const String kSupportYes = 'Sí';
const String kSupportThanks =
    '¡Qué bueno! Si necesitas algo más, aquí estamos.';

const String kSupportOpen =
    'Listo, cuéntanos qué pasó y te respondemos lo antes posible. Nuestro horario es de lunes a sábado, de 8 a.m. a 6 p.m.';
const String kSupportClosed =
    'Recibimos tu mensaje 🙌 Ahora estamos fuera de horario, pero te respondemos apenas abramos, mañana desde las 8 a.m.';

/// Mensaje que le llega al equipo cuando alguien pide hablar con soporte.
const String kSupportRequestMessage = 'Hola, necesito hablar con soporte.';

/// Horario: lunes a sábado, 8:00–18:00, hora de Colombia (UTC-5).
bool supportIsOpen([DateTime? now]) {
  final DateTime co = (now ?? DateTime.now()).toUtc().subtract(
    const Duration(hours: 5),
  );
  return co.weekday != DateTime.sunday && co.hour >= 8 && co.hour < 18;
}
