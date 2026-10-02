/// Barrel de la capa de red (diseño §2.4).
///
/// Reexporta la fábrica del cliente Dio, los interceptores y la abstracción de
/// token para que las capas superiores importen un único archivo.
library;

export 'app_check_interceptor.dart';
export 'auth_interceptor.dart';
export 'dio_client.dart';
export 'error_interceptor.dart';
export 'token_provider.dart';
