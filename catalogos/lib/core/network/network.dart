/// Barrel de la capa de red (diseño §2.4).
///
/// Reexporta la fábrica del cliente Dio, los interceptores y la abstracción de
/// token para que las capas superiores importen un único archivo.
library;

export 'app_check_interceptor.dart';
export 'app_check_token_source.dart';
export 'auth_interceptor.dart';
export 'dio_client.dart';
export 'dio_provider.dart';
export 'error_interceptor.dart';
export 'token_provider.dart';
export 'unauthorized_interceptor.dart';
