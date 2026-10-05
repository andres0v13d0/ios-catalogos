
# Proyecto: app Flutter de revendedores (FlyStock)

## Qué es

App móvil Flutter para revendedores de la red de ventas. El revendedor ve los catálogos que los proveedores le comparten por número de celular, arma catálogos generales, gestiona pedidos y clientes propios (privados, el proveedor nunca los ve).

## Dónde está todo

- Flutter: /mnt/ssd_secundario/Repositorios/ios-catalogos/catalogos
- Spec: .kiro/specs/ (requirements.md, design.md, tasks.md) y docs/
- Backend NestJS: /mnt/ssd_secundario/Repositorios/surtte/main/backend (desplegado en api.minymol.com, es PRODUCCIÓN)
- Frontend web de catálogos: /mnt/ssd_secundario/Repositorios/flystock-catalogos (solo lectura)
- tasks.md es la fuente de verdad: marca [x] solo cuando la tarea esté verificada.

## Reglas estrictas

- NO hay entorno de pruebas: la app apunta al backend y a la base reales.
- NUNCA ejecutes migraciones ni escrituras en la base sin mostrarme antes el SQL y recibir mi aprobación explícita. Migraciones siempre aditivas e idempotentes.
- NUNCA envíes WhatsApp reales ni llames a producción desde tests; usa mocks.
- NO modifiques /notifications/verify* (flujo de recuperación de contraseña, tiene fallas de seguridad documentadas en docs/backlog-seguridad-verification-codes.md).
- No sé cómo se despliega el backend: avísame cuando un cambio requiera redespliegue y qué archivos.
- Cada tarea termina con flutter analyze limpio y flutter test en verde.
- Trabaja por fases; no avances a la siguiente sin mi visto bueno.

## Decisiones tomadas

- Revendedor = rol y tabla propia (resellers), uid Firebase estable: reseller:<E.164>.
- Login: teléfono + código por WhatsApp (plantilla verificacion_codigo) vía endpoints /auth/reseller/request-code, /verify-code, /resend-code; el backend emite Firebase custom token y la app usa signInWithCustomToken. Código hasheado con bcrypt, 5 min, 5 intentos, lockout 15 min.
- Los guards del backend validan idToken de Firebase. ResellerGuard resuelve por uid.
- Pedido multi-proveedor: un pedido por proveedor agrupados bajo un pedido padre.
- Estados del revendedor: pendiente, confirmado, entregado, anulado (desde anulado no se vuelve). Estado del proveedor, campo aparte: separado o entregado; el proveedor no cambia el estado del revendedor.
- Catálogo general: productos individuales, margen propio (porcentaje o precio fijo), checkout ON/OFF, portada. El cliente final nunca ve el precio del proveedor.
- Extender la tabla orders existente. Sin pago en línea en v1.
- Identidad visual FlyStock: Poppins; #001634, #004aad, #5de0e6, #00ff94. Español, COP.

## Entorno de desarrollo

- Android por USB, dispositivo Xiaomi M2004J19C, id abbbd06a0410. Flavor dev (applicationId com.flystock.revendedores.dev).
- Correr: flutter run -d abbbd06a0410 --flavor dev --dart-define-from-file=env/dev.json --dart-define=apiBaseUrl=https://api.minymol.com
- Firebase: proyecto surtte-4bf22. Android SDK en ~/Android/Sdk. iOS no se puede compilar aquí (Ubuntu).
- Hay logging [NET-ERR]/[PARSE-ERR] para fallos de red y parseo.

## Estado

- Fase 0 y Fase 1 funcionando en el celular contra el backend real: login por WhatsApp, lista de catálogos (tarjetas con banner, nombre público y proveedor) y detalle.
- Pendiente de Fase 1: probar sesión persistente, modo sin conexión, lockout; comprobar que notification_logs no guarde el código de WhatsApp; registrar token de debug de App Check; commit.
- Siguiente: Fase 2 (pedidos y estados).
