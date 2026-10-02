# Tasks — App móvil de Revendedores (Flutter)

> Acompaña a `requirements.md` y `design.md`. Cada tarea es pequeña, verificable y tiene criterio de aceptación (CA).
> Convención: `[BE]` cambio de backend, `[FL]` tarea Flutter, `[M]` paso manual del usuario (ver también §"Pasos manuales").
> NO se modifica backend ni frontend web hasta aprobación del spec. Las tareas `[BE]` quedan especificadas para ejecutarse tras aprobación.

---

## Fase 0 — Fundaciones (habilita todas las fases)

- [x] 0.1 `[FL]` Reemplazar template y crear estructura feature-first en `catalogos/lib` (`app/`, `core/`, `features/`, `shared/`).
  - CA: compila `flutter analyze` sin errores; `main.dart` arranca una pantalla placeholder.
- [x] 0.2 `[FL]` Configurar flavors dev/staging/prod (Android product flavors, iOS schemes/xcconfig) + `env/*.json` con `apiBaseUrl`.
  - CA: `flutter run --flavor dev` y `--flavor prod` arrancan con distinta base URL visible en logs.
- [x] 0.3 `[FL]` Theme FlyStock: `ThemeData` Poppins + `ColorScheme` (`#001634/#004aad/#5de0e6/#00ff94`), botón gradiente primario.
  - CA: pantalla de muestra renderiza tipografía y colores correctos.
- [x] 0.4 `[FL]` Capa de red: Dio + `AuthInterceptor` (idToken) + `ErrorInterceptor` (mapeo a `Failure`) + `AppCheckInterceptor` (stub hasta 1.x).
  - CA: test unitario que verifica header `Authorization` y mapeo de 401/429.
- [x] 0.5 `[FL]` Riverpod + go_router con guard de auth (placeholder) y rutas base.
  - CA: navegación entre 2 rutas; guard redirige a login si no hay sesión.
- [x] 0.6 `[FL]` Caché local (drift o hive) inicializada + utils `money` (COP) y `phone` (E.164).
  - CA: tests unitarios de formateo de precio COP y normalización de teléfono.
- [x] 0.7 `[M]` Registrar apps Android/iOS en Firebase `surtte-4bf22`, descargar `google-services.json` / `GoogleService-Info.plist`, correr FlutterFire. (ver §Pasos manuales)
  - CA: `firebase_core` inicializa sin error en ambos targets.

---

## Fase 1 — Autenticación (OTP) + catálogos compartidos

### Backend
- [ ] 1.1 `[BE]` Migración: añadir valor `revendedor` a enum `usuarios.rol`.
  - CA: migración sube/baja sin romper; valor disponible.
- [ ] 1.2 `[BE]` Migración + entidad `resellers` (`firebase_uid` unique, `telefono_e164` unique, `nombre`, `country_code`).
  - CA: tabla creada; constraints verificados.
- [ ] 1.3 `[BE]` Migración + entidad `reseller_shared_catalogs` con `unique(reseller_id, catalog_id)`.
  - CA: inserción duplicada rechazada por constraint.
- [ ] 1.4 `[BE]` Extender `AuthService.login` para detectar/crear `reseller` por `firebase_uid` + teléfono del token; respuesta `tipo:'REVENDEDOR'`.
  - CA: test: login con teléfono nuevo crea reseller; login repetido no duplica.
- [ ] 1.5 `[BE]` `ResellerGuard` (resuelve reseller por `firebase_uid`) + endpoints `GET /reseller/me`, `PATCH /reseller/me`.
  - CA: sin token → 401; con token de proveedor → 403; con reseller → 200.
- [ ] 1.6 `[BE]` `POST /reseller/sync-shared-catalogs`: vincula `private_catalogs` por `telefono` E.164 (idempotente).
  - CA: test: catálogos con teléfono coincidente se vinculan; segunda llamada no duplica.
- [ ] 1.7 `[BE]` `GET /reseller/me/shared-catalogs` con filtros `providerId`, `search`.
  - CA: devuelve solo catálogos del reseller autenticado.
- [ ] 1.8 `[BE]` App Check: validar en endpoints públicos de red de ventas (reemplazo de reCAPTCHA).
  - CA: request sin App Check válido es rechazado en entorno configurado.

### Flutter
- [ ] 1.9 `[FL]` Firebase Phone Auth: pantalla de ingreso de teléfono (selector país, default +57) + envío OTP.
  - CA: envía OTP a número de prueba; muestra errores de formato.
- [ ] 1.10 `[FL]` Pantalla de verificación OTP (reenvío con cooldown) + obtención de `idToken`.
  - CA: OTP correcto autentica; incorrecto muestra error; reenvío respeta cooldown.
- [ ] 1.11 `[FL]` Integrar App Check (Play Integrity / DeviceCheck/App Attest).
  - CA: requests incluyen token App Check en header.
- [ ] 1.12 `[FL]` Sesión: persistir login (secure storage), `AuthInterceptor` real, logout.
  - CA: reinicio de app mantiene sesión; 401 persistente cierra sesión.
- [ ] 1.13 `[FL]` Perfil reseller: completar nombre tras primer login (`GET/PATCH /reseller/me`).
  - CA: guarda nombre; guard de "perfil incompleto" deja de redirigir.
- [ ] 1.14 `[FL]` Al iniciar sesión, llamar `POST /reseller/sync-shared-catalogs` y listar catálogos.
  - CA: tras login, aparecen los catálogos compartidos del número.
- [ ] 1.15 `[FL]` Lista de catálogos compartidos (agrupar/filtrar por proveedor) + pull-to-refresh.
  - CA: muestra catálogos de múltiples proveedores; refresca.
- [ ] 1.16 `[FL]` Detalle de catálogo: productos (imágenes, variantes, precios por cantidad, banner) reutilizando `GET /catalog/by-catalog/:id/products` y `POST /catalog/products/previews`.
  - CA: renderiza productos; respeta modo "sin precios".
- [ ] 1.17 `[FL]` Búsqueda y filtro por categoría/subcategoría en el detalle.
  - CA: filtra resultados correctamente.
- [ ] 1.18 `[FL]` Caché offline de catálogos consultados (stale-while-revalidate).
  - CA: con red apagada tras una consulta previa, el catálogo se muestra desde caché.

---

## Fase 2 — Pedidos y estados

### Backend
- [ ] 2.1 `[BE]` Migración: extender `orders` con `reseller_id`, `reseller_order_status`, `provider_fulfillment_status`, `reseller_customer_id` (null), `checkout_group_id` (null), `price_source`.
  - CA: columnas añadidas, nullables, sin romper pedidos existentes.
- [ ] 2.2 `[BE]` `POST /reseller/orders` (un proveedor): crea `order` con `reseller_id`, estado `pendiente`, items con precio del proveedor.
  - CA: test: pedido creado y asociado al reseller y proveedor correctos.
- [ ] 2.3 `[BE]` `GET /reseller/me/orders` con filtros (status, providerId) y paginación.
  - CA: devuelve solo pedidos del reseller; paginación correcta.
- [ ] 2.4 `[BE]` `GET /reseller/orders/:id` (solo dueño) con proveedor y ambos estados.
  - CA: otro reseller → 403.
- [ ] 2.5 `[BE]` `PATCH /reseller/orders/:id/status`: valida transición; `anulado` es terminal.
  - CA: test: transición válida ok; desde `anulado` → 400/409.
- [ ] 2.6 `[BE]` Guard: el proveedor no puede escribir `reseller_order_status`.
  - CA: test negativo: proveedor intentando cambiar estado del revendedor → 403.

### Flutter
- [ ] 2.7 `[FL]` Carrito por proveedor (desde detalle de catálogo compartido).
  - CA: agrega/edita cantidades y variantes; total calculado.
- [ ] 2.8 `[FL]` Crear pedido (requiere conexión) vía `POST /reseller/orders`.
  - CA: sin red, acción deshabilitada con aviso; con red, crea pedido.
- [ ] 2.9 `[FL]` Lista "Mis pedidos" con proveedor, total, estado revendedor y despacho proveedor (solo lectura).
  - CA: muestra ambos estados; filtra por estado y proveedor.
- [ ] 2.10 `[FL]` Detalle de pedido + cambio de estado del revendedor (bloquea tras `anulado`).
  - CA: cambia estado; `anulado` deshabilita el resto.

---

## Fase 3 — Clientes privados

### Backend
- [ ] 3.1 `[BE]` Migración + entidad `reseller_customers` (dueño `reseller_id`, borrado lógico `is_deleted`).
  - CA: tabla creada; índice por `reseller_id`.
- [ ] 3.2 `[BE]` CRUD `GET/POST/PATCH/DELETE /reseller/customers` (filtra por reseller del token; búsqueda por nombre/celular).
  - CA: un reseller solo ve/edita sus clientes.
- [ ] 3.3 `[BE]` Vincular `reseller_customer_id` al crear pedido (`POST /reseller/orders` y checkout).
  - CA: pedido guarda el cliente privado como referencia del reseller.
- [ ] 3.4 `[BE]` **Aislamiento**: asegurar que ningún endpoint `/provider/*` ni serializer de pedido del proveedor exponga `reseller_customers`/`reseller_customer_id`.
  - CA: test negativo de contrato: proveedor no obtiene datos del cliente privado (campo ausente).

### Flutter
- [ ] 3.5 `[FL]` Pantalla de clientes privados: listar, buscar, crear, editar, eliminar (lógico).
  - CA: CRUD funcional contra API.
- [ ] 3.6 `[FL]` Selector de cliente en el flujo de pedido (elegir existente o crear nuevo inline).
  - CA: el pedido queda asociado al cliente elegido/creado.

---

## Fase 4 — Catálogo general (checkout on/off, portada, margen)

### Backend
- [ ] 4.1 `[BE]` Migración + entidades `reseller_general_catalogs` y `reseller_general_catalog_items` (margen por defecto y override, `order_index`, `checkout_enabled`, `cover_url`).
  - CA: tablas creadas; `unique(general_catalog_id, product_id)`.
- [ ] 4.2 `[BE]` CRUD de catálogos generales (`GET/POST/PATCH/DELETE /reseller/general-catalogs[/:id]`).
  - CA: un reseller gestiona varios catálogos; rename/eliminar ok.
- [ ] 4.3 `[BE]` Items: agregar individual, `bulk` ("todo el catálogo de un proveedor"), editar margen/orden, eliminar.
  - CA: bulk inserta todos los productos del catálogo origen; reordenar persiste `order_index`.
- [ ] 4.4 `[BE]` Cálculo de precio cliente por regla de margen (percent/fixed/inherit/none); exponer solo precio cliente al cliente final.
  - CA: test: precio cliente correcto por cada regla; nunca se expone costo del proveedor.
- [ ] 4.5 `[BE]` Portada: `POST .../cover/signed-url` (S3 presign) + `confirm` (reutiliza patrón banner).
  - CA: sube imagen y persiste `cover_url`.
- [ ] 4.6 `[BE]` Migración + entidad `checkout_groups`.
  - CA: tabla creada con FKs.
- [ ] 4.7 `[BE]` `POST /reseller/general-catalogs/:id/checkout`:
  - ON → crea `checkout_group` + N `orders` (split por `provider_id`), items a precio del proveedor; total cliente a nivel grupo.
  - OFF → devuelve payload WhatsApp (precios con margen); no crea orders.
  - CA: test: 3 proveedores → 3 orders bajo 1 grupo; OFF no crea orders.
- [ ] 4.8 `[BE]` `GET /reseller/checkout-groups/:id` (grupo + subpedidos, solo dueño).
  - CA: devuelve subpedidos; otro reseller → 403.

### Flutter
- [ ] 4.9 `[FL]` Lista y CRUD de catálogos generales (crear, renombrar, eliminar).
  - CA: múltiples catálogos; cambios persistidos.
- [ ] 4.10 `[FL]` Agregar productos: desde catálogos compartidos (individual) + atajo "agregar todo el catálogo".
  - CA: productos añadidos; bulk funcional.
- [ ] 4.11 `[FL]` Reordenar productos (drag & drop) y configurar margen por defecto y por producto.
  - CA: orden y márgenes persisten; precio cliente se actualiza en UI.
- [ ] 4.12 `[FL]` Portada: elegir/recortar imagen y subir (image_picker + image_cropper + presign).
  - CA: portada visible en el catálogo general.
- [ ] 4.13 `[FL]` Toggle checkout ON/OFF por catálogo.
  - CA: estado persiste y condiciona el flujo de compra.
- [ ] 4.14 `[FL]` Flujo de checkout: ON → crear grupo + subpedidos (muestra agrupación); OFF → abrir WhatsApp con precios de revendedor.
  - CA: ON crea grupo y aparece en "Mis pedidos" agrupado; OFF abre WhatsApp con mensaje correcto.
- [ ] 4.15 `[FL]` Vista de "compra agrupada" (grupo + subpedidos por proveedor).
  - CA: muestra el grupo y cada subpedido con su proveedor.

---

## Fase 5 — Vista y acciones del proveedor (separado/entregado)

### Backend
- [ ] 5.1 `[BE]` `GET /provider/reseller-orders` (pedidos de revendedores del proveedor; estado del revendedor en solo lectura; **sin** cliente privado).
  - CA: test: respuesta no contiene datos de `reseller_customers`.
- [ ] 5.2 `[BE]` `PATCH /orders/:id/provider-fulfillment` (`separado`|`entregado`); guard proveedor dueño; no toca `reseller_order_status`.
  - CA: test: proveedor marca despacho; intento de cambiar estado del revendedor → 403.
- [ ] 5.3 `[BE]` Documentar/validar independencia de estados en servicio (tests de ambos lados).
  - CA: suite verde para separación de estados.

### Flutter (opcional móvil para proveedor)
- [ ] 5.4 `[FL]` (Si aplica) Pantalla proveedor: lista de pedidos de revendedor + acción separado/entregado.
  - CA: proveedor cambia su estado de despacho; no ve cliente privado ni cambia estado del revendedor.

> Si la UI del proveedor se queda en el frontend web existente, 5.4 se omite y solo se entregan los `[BE]`.

---

## Fase 6 — Notificaciones push, pulido y publicación

### Backend
- [ ] 6.1 `[BE]` Migración + entidad `device_tokens` + endpoints `POST /reseller/devices`, `POST /provider/devices`.
  - CA: registra/actualiza token (unique por `fcm_token`).
- [ ] 6.2 `[BE]` Emitir FCM: pedido nuevo → proveedor; cambio `provider_fulfillment_status` → revendedor.
  - CA: test: evento dispara envío (mock de FCM) con payload/deeplink correcto.

### Flutter
- [ ] 6.3 `[FL]` `firebase_messaging`: permisos, registro de token tras login, manejo foreground/background/terminated + deep link a pedido.
  - CA: recibe push de prueba y navega al detalle.
- [ ] 6.4 `[FL]` Pulido: estados carga/vacío/error consistentes; revisión de identidad FlyStock; textos en español/COP.
  - CA: revisión visual aprobada; sin strings hardcodeados fuera de i18n básico.
- [ ] 6.5 `[FL]` Iconos, splash, nombre de app, bundle id/package name definitivos por flavor.
  - CA: build release Android e iOS con branding correcto.
- [ ] 6.6 `[FL]` Build release firmado Android (Play) e iOS (App Store).
  - CA: `.aab` y archive iOS generados; checklist de tienda cumplido.
- [ ] 6.7 `[M]` Publicación en tiendas + política de privacidad (ver §Pasos manuales).
  - CA: apps en revisión/aprobadas; política enlazada en la ficha.

---

## Pasos manuales (los realiza el usuario) `[M]`

### Firebase (proyecto `surtte-4bf22`)
1. Crear app Android (package name definitivo, p. ej. `com.flystock.revendedores`) y descargar `google-services.json`.
2. Crear app iOS (bundle id, p. ej. `com.flystock.revendedores`) y descargar `GoogleService-Info.plist`.
3. Habilitar **Phone Authentication** (y números de prueba para QA).
4. Habilitar **App Check**: Play Integrity (Android) y DeviceCheck/App Attest (iOS); registrar apps y claves.
5. Habilitar **Cloud Messaging (FCM)**; en iOS subir **APNs Auth Key** (.p8) y configurar capacidades Push.
6. Confirmar correo/propietario para que el backend (firebase-admin) acepte los `idToken` de estas apps (mismo proyecto).

### Backend / entornos
7. Confirmar si existe **staging** (RE-2). Proveer `apiBaseUrl` de dev/staging y, si aplica, credenciales no productivas.
8. Autorizar la ejecución de las migraciones `[BE]` por fase (tras aprobación del spec).

### Tiendas
9. Cuenta **Google Play Console** y **Apple Developer** activas.
10. Definir nombre público de la app, descripción, capturas, íconos.
11. **Política de privacidad** publicada (debe cubrir: datos de clientes privados del revendedor, teléfono/OTP, push). Enlace para fichas de tienda y data safety / privacy nutrition labels.
12. Certificados/perfiles iOS (distribución) y keystore Android (firma de release).

### Decisiones pendientes de confirmar
13. Bundle id/package name definitivos.
14. ¿La UI del proveedor (separado/entregado) va en la app Flutter o se queda en el frontend web? (afecta tarea 5.4).

---

## Orden de ejecución sugerido

Fase 0 → Fase 1 → Fase 2 → Fase 3 → Fase 4 → Fase 5 → Fase 6.
Cada fase es entregable de forma independiente. Las tareas `[BE]` de una fase deben desplegarse antes de las `[FL]` dependientes de esa misma fase.
