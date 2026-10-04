# Requirements — App móvil de Revendedores (Flutter)

> Base: `docs/00-analisis-contexto.md` + decisiones de negocio aprobadas (N-1..N-3, A-1..A-3, P-1..P-4, CG-1..CG-3, Pg-1, Nt-1, UX-1..UX-3, St-1, RE-1, RE-2).
> El proyecto Flutter vive en `/mnt/ssd_secundario/Repositorios/ios-catalogos/catalogos`.
> Backend objetivo: NestJS + TypeORM + PostgreSQL (`api.minymol.com`), Firebase project `surtte-4bf22`.

## Glosario

- **Revendedor (reseller):** cuenta/rol nuevo. Vendedor de la red que recibe catálogos de proveedores y revende a sus propios clientes.
- **Proveedor (provider):** entidad existente que crea productos y catálogos.
- **Código WhatsApp (login code):** código numérico de 6 dígitos enviado por WhatsApp (Meta Cloud API, plantilla `verificacion_codigo` reutilizada tal cual) que el revendedor usa para iniciar sesión. Es un flujo NUEVO y HARDENED, independiente del sistema de recuperación de contraseña existente.
- **Firebase custom token:** token acuñado por el backend con `admin.auth().createCustomToken(uid)`. La app lo canjea con `signInWithCustomToken` para obtener una sesión Firebase normal (y su `idToken`).
- **uid estable del revendedor:** identificador Firebase determinístico derivado del teléfono E.164 (`reseller:<E.164>`), de modo que el mismo teléfono siempre produce el mismo `firebase_uid`.
- **App Check:** atestación de integridad de app de Firebase (Play Integrity / DeviceCheck/App Attest) que protege endpoints públicos.
- **Catálogo compartido:** `private_catalog` de un proveedor cuyo WhatsApp coincide con el teléfono del revendedor; aparece automáticamente en su cuenta.
- **Catálogo general:** catálogo propio del revendedor que combina productos de varios proveedores, con margen y portada propios.
- **Checkout group:** pedido "padre" que agrupa los pedidos reales (uno por proveedor) generados en un checkout del catálogo general.
- **Cliente privado:** cliente del revendedor; el proveedor nunca lo ve (ni por API ni por UI).
- **Estado del revendedor:** `pendiente | confirmado | entregado | anulado`.
- **Estado de despacho del proveedor:** `separado | entregado` (independiente del estado del revendedor).

## Convenciones

- Formato EARS para criterios de aceptación.
- Prioridad: `P0` (MVP de la fase), `P1` (deseable), `P2` (posterior).
- Cada requisito indica la fase (1–6) a la que pertenece.

---

## Fase 1 — Autenticación (código WhatsApp + custom token) + catálogos compartidos

> **DECISIÓN APROBADA (autoritativa):** el login del revendedor usa un **código de verificación por WhatsApp** emitido por el backend (Meta Cloud API + plantilla existente `verificacion_codigo`, reutilizada TAL CUAL, sin cambios en Meta), pero **HARDENED**. Validado el código, el backend acuña un **Firebase custom token** (`admin.auth().createCustomToken`) que la app canjea con `signInWithCustomToken`. **Firebase Phone Auth queda REEMPLAZADO** en la app (no es híbrido). **App Check se mantiene.** Los guards del backend siguen validando el `idToken` de Firebase (el canje del custom token produce un `idToken` normal).
>
> **AISLAMIENTO DEL FLUJO LEGADO:** este login usa endpoints NUEVOS y dedicados (`/auth/reseller/*`) y NO reutiliza ni altera `POST /notifications/verify*` ni `PATCH /users/recover-password`. El `POST /auth/login` existente y sus ramas (PROVEEDOR/comerciante/EMPLEADO) permanecen idénticos.

### R1.1 Login con teléfono + código WhatsApp (P0, Fase 1)
**Historia:** Como revendedor, quiero iniciar sesión con mi número de celular y un código recibido por WhatsApp, para acceder a mi cuenta sin contraseña.

**Criterios (EARS):**
1. CUANDO el revendedor ingresa un número (default Colombia +57, cambiable) y solicita el código, EL Reseller_Auth_Service DEBE normalizar el número a E.164 y enviar un código de 6 dígitos por WhatsApp usando la plantilla `verificacion_codigo`.
2. CUANDO el Reseller_Auth_Service responde a una solicitud de código, EL Reseller_Auth_Service DEBE devolver `{ ok, expiresInSeconds, resendAvailableInSeconds }` y NUNCA el código.
3. CUANDO el revendedor ingresa el código correcto dentro de la ventana de validez, EL Reseller_Auth_Service DEBE acuñar un Firebase custom token con `uid` estable derivado del teléfono E.164 y devolverlo junto con el perfil del revendedor.
4. CUANDO la app recibe el custom token, EL App_Cliente DEBE canjearlo con `signInWithCustomToken` para obtener una sesión Firebase y su `idToken`.
5. EL Reseller_Auth_Service DEBE almacenar el código de login HASHEADO (no en claro), generado con un RNG criptográficamente seguro.
6. EL Reseller_Auth_Service DEBE forzar expiración corta del código de login de 300 segundos (5 minutos).
7. EL Reseller_Auth_Service DEBE forzar uso único del código: una vez validado con éxito, el código DEBE quedar consumido.
8. EL App_Cliente DEBE adjuntar el token de App Check en las solicitudes a los endpoints públicos de login.
9. MIENTRAS la sesión esté activa, EL App_Cliente DEBE renovar el `idToken` automáticamente y adjuntarlo como `Authorization: Bearer <idToken>` en cada request autenticado.

### R1.2 Alta/registro de cuenta de revendedor (P0, Fase 1)
**Historia:** Como revendedor nuevo, quiero que mi cuenta se cree automáticamente al validar el código WhatsApp, para empezar a usar la app.

**Criterios:**
1. CUANDO un código de login se valida con éxito y no existe cuenta de revendedor para ese `uid` estable, EL Reseller_Auth_Service DEBE crear un registro `reseller` ligado al `firebase_uid` (= `uid` estable) y al teléfono en formato E.164.
2. SI ya existe una cuenta `reseller` para ese `firebase_uid`, EL Reseller_Auth_Service DEBE resolver la cuenta existente sin duplicar (resolve-or-create idempotente).
3. CUANDO el Reseller_Auth_Service responde a una validación exitosa, EL Reseller_Auth_Service DEBE indicar `isNewProfile` para que la app sepa si debe pedir completar el perfil.
4. EL App_Cliente DEBE permitir completar nombre y datos básicos del revendedor tras el primer login (perfil).
5. EL Sistema DEBE mantener separado el rol `reseller` del rol `comerciante` existente.

### R1.3 Vinculación automática de catálogos compartidos (P0, Fase 1)
**Historia:** Como revendedor, quiero ver automáticamente todos los catálogos que proveedores me compartieron a mi número, para no tener que reclamarlos uno por uno.

**Criterios:**
1. CUANDO el teléfono del revendedor se valida por código WhatsApp, EL SISTEMA DEBE vincular todos los `private_catalogs` cuyo `telefono` (normalizado E.164) coincida con ese número.
2. EL SISTEMA DEBE acumular catálogos de múltiples proveedores en la misma cuenta.
3. CUANDO un proveedor comparte un nuevo catálogo al mismo número después del alta, EL SISTEMA DEBE reflejarlo en la cuenta (al refrescar o vía re-sincronización).
4. EL SISTEMA DEBE conservar el funcionamiento del enlace público actual (`/red-de-ventas/:token/*`) sin romperlo.
5. SI un catálogo compartido fue configurado "sin precios" por el proveedor, EL SISTEMA DEBE respetar esa configuración.

### R1.4 Listado y vista de catálogos compartidos (P0, Fase 1)
**Historia:** Como revendedor, quiero navegar mis catálogos compartidos con sus productos, precios y banners, para conocer qué puedo vender.

**Criterios:**
1. EL SISTEMA DEBE listar los catálogos compartidos agrupados o filtrables por proveedor.
2. CUANDO el revendedor abre un catálogo, EL SISTEMA DEBE mostrar productos con imágenes, variantes (color/talla), precios por cantidad y banner/portada.
3. EL SISTEMA DEBE permitir búsqueda y filtro por categoría/subcategoría dentro del catálogo.
4. EL SISTEMA DEBE cachear el catálogo consultado para lectura offline básica (UX-3).

### R1.5 Robustez y seguridad del login por código WhatsApp (P0, Fase 1)
**Historia:** Como operador de la plataforma, quiero que el envío y la validación del código WhatsApp sean resistentes a abuso y fuerza bruta, para proteger a los usuarios y controlar costos de mensajería.

**Criterios (EARS):**
1. SI un teléfono excede el máximo de envíos permitidos por hora, ENTONCES EL Reseller_Auth_Service DEBE rechazar la solicitud con 429 e informar el tiempo de espera.
2. SI una nueva solicitud de código llega antes de cumplir el cooldown de 60 segundos entre envíos, ENTONCES EL Reseller_Auth_Service DEBE rechazar la solicitud con 429 e informar `resendAvailableInSeconds`.
3. SI una dirección IP excede el máximo de solicitudes de código permitidas por hora, ENTONCES EL Reseller_Auth_Service DEBE rechazar la solicitud con 429.
4. SI el revendedor ingresa un código incorrecto, ENTONCES EL Reseller_Auth_Service DEBE incrementar el contador de intentos del teléfono y responder 400 sin revelar si el número existe.
5. SI el teléfono alcanza 5 intentos fallidos, ENTONCES EL Reseller_Auth_Service DEBE bloquear la validación de ese teléfono durante 15 minutos y responder 429.
6. SI el código está expirado, ENTONCES EL Reseller_Auth_Service DEBE responder 400 indicando que el código expiró y ofrecer reenvío.
7. SI el envío por WhatsApp falla en Meta Cloud API, ENTONCES EL Reseller_Auth_Service DEBE responder 502/503 e indicar al App_Cliente que reintente más tarde.
8. CUANDO el App_Cliente recibe 429 o un bloqueo, EL App_Cliente DEBE mostrar un mensaje en español claro y deshabilitar el reenvío hasta que termine el cooldown.

---

## Fase 2 — Pedidos y estados

### R2.1 Crear pedido desde un catálogo (P0, Fase 2)
**Historia:** Como revendedor, quiero crear un pedido a un proveedor desde su catálogo, para gestionar mis ventas.

**Criterios:**
1. CUANDO el revendedor arma un carrito de un solo proveedor y confirma, EL SISTEMA DEBE crear un `order` real asociado a ese `provider` y al `reseller`.
2. EL SISTEMA DEBE requerir conexión para crear el pedido (UX-3).
3. CADA pedido DEBE mostrar claramente de qué proveedor es (P4).
4. EL SISTEMA DEBE registrar el pedido con estado inicial del revendedor = `pendiente`.

### R2.2 Estado del revendedor (P0, Fase 2)
**Historia:** Como revendedor, quiero cambiar el estado de mis pedidos, para llevar el control de mi operación.

**Criterios:**
1. EL SISTEMA DEBE permitir estados: `pendiente, confirmado, entregado, anulado`.
2. EL SISTEMA DEBE permitir transiciones flexibles entre estados no terminales.
3. CUANDO un pedido está en `anulado`, EL SISTEMA NO DEBE permitir cambiarlo a otro estado.
4. EL estado del revendedor DEBE ser un campo independiente del estado de despacho del proveedor (P3).
5. SOLO el revendedor dueño del pedido DEBE poder cambiar su estado.

### R2.3 Listado de pedidos del revendedor (P0, Fase 2)
**Historia:** Como revendedor, quiero ver todos mis pedidos con su proveedor y estado, para dar seguimiento.

**Criterios:**
1. EL SISTEMA DEBE listar los pedidos del revendedor con proveedor, total, estado del revendedor y estado de despacho del proveedor (solo lectura).
2. EL SISTEMA DEBE permitir filtrar por estado y por proveedor.
3. EL SISTEMA DEBE paginar el listado.
4. CUANDO el pedido pertenece a un checkout group, EL SISTEMA DEBE poder mostrar su agrupación (Fase 4).

---

## Fase 3 — Clientes privados

### R3.1 Gestión de clientes privados (P0, Fase 3)
**Historia:** Como revendedor, quiero administrar mis propios clientes, para asignarlos a mis pedidos.

**Criterios:**
1. EL SISTEMA DEBE permitir crear, listar, editar y eliminar (lógico) clientes del revendedor.
2. LOS clientes del revendedor DEBEN almacenarse separados de la tabla `customers` del proveedor.
3. EL SISTEMA DEBE permitir buscar clientes por nombre o celular.

### R3.2 Privacidad de clientes (P0, Fase 3)
**Historia:** Como revendedor, quiero que mis clientes sean privados, para que el proveedor nunca los vea.

**Criterios:**
1. EL SISTEMA (API) NO DEBE exponer clientes del revendedor en ningún endpoint accesible por el proveedor.
2. CUANDO un pedido llega al proveedor, EL SISTEMA NO DEBE incluir datos del cliente privado del revendedor.
3. EL aislamiento DEBE aplicarse a nivel de consulta/datos, no solo de UI.
4. SOLO el revendedor dueño DEBE poder leer/escribir sus clientes.

### R3.3 Cliente en el pedido (P0, Fase 3)
**Historia:** Como revendedor, quiero asociar un cliente a cada pedido (existente o nuevo), para registrar a quién le vendo.

**Criterios:**
1. CUANDO el revendedor crea un pedido, EL SISTEMA DEBE permitir elegir un cliente existente o crear uno nuevo en el flujo.
2. EL cliente asociado DEBE guardarse como referencia privada del revendedor en el pedido.
3. EL SISTEMA NO DEBE propagar esa referencia al proveedor.

---

## Fase 4 — Catálogo general (checkout on/off, portada, margen)

### R4.1 Crear y administrar catálogos generales (P0, Fase 4)
**Historia:** Como revendedor, quiero armar catálogos generales combinando productos de varios proveedores, para vender un surtido propio.

**Criterios:**
1. EL SISTEMA DEBE permitir crear varios catálogos generales por revendedor, renombrarlos y eliminarlos.
2. EL SISTEMA DEBE permitir agregar productos individuales desde cualquier catálogo compartido.
3. EL SISTEMA DEBE ofrecer un atajo "agregar todo el catálogo de este proveedor" (CG-1).
4. EL SISTEMA DEBE permitir reordenar productos (CG-2).
5. EL SISTEMA DEBE permitir configurar una portada (imagen) por catálogo general.

### R4.2 Margen propio del revendedor (P0, Fase 4)
**Historia:** Como revendedor, quiero definir mi precio de venta, para ganar margen sin exponer el costo del proveedor.

**Criterios:**
1. EL SISTEMA DEBE permitir definir margen por producto como porcentaje o precio fijo (CG-3).
2. EL cliente final DEBE ver solo el precio del revendedor, NUNCA el del proveedor.
3. EL SISTEMA DEBE permitir un margen por defecto a nivel de catálogo general, sobreescribible por producto.
4. CUANDO el proveedor cambia su precio base, EL SISTEMA DEBE recalcular el precio mostrado según la regla de margen vigente (porcentaje) o conservar el fijo.

### R4.3 Checkout ON/OFF por catálogo general (P0, Fase 4)
**Historia:** Como revendedor, quiero activar o desactivar el checkout por catálogo, para elegir entre venta transaccional o por WhatsApp.

**Criterios:**
1. EL SISTEMA DEBE permitir activar/desactivar checkout por cada catálogo general.
2. CUANDO checkout está OFF, EL SISTEMA DEBE usar el flujo de WhatsApp hacia el cliente final.
3. CUANDO checkout está ON, EL SISTEMA DEBE generar pedidos reales.
4. EL diseño DEBE quedar preparado para pago en línea futuro sin re-arquitectura (Pg-1).

### R4.4 Checkout multi-proveedor dividido (P0, Fase 4)
**Historia:** Como revendedor, quiero que un pedido con productos de varios proveedores se divida por proveedor, para que cada uno reciba solo su parte.

**Criterios:**
1. CUANDO un checkout del catálogo general contiene productos de N proveedores, EL SISTEMA DEBE crear N pedidos reales (uno por proveedor) agrupados bajo un checkout group (P1).
2. CADA proveedor DEBE ver solo su pedido, nunca los items de otros proveedores.
3. EL revendedor DEBE poder ver el grupo como una sola compra y también cada subpedido.
4. EL precio enviado/registrado hacia el proveedor DEBE ser el del proveedor; el precio del cliente DEBE reflejar el margen del revendedor.

---

## Fase 5 — Vista y acciones del proveedor (separado/entregado)

### R5.1 Visibilidad del proveedor sobre pedidos del revendedor (P0, Fase 5)
**Historia:** Como proveedor, quiero ver los pedidos que me generan los revendedores y su estado, para prepararlos.

**Criterios:**
1. EL SISTEMA DEBE permitir al proveedor ver los pedidos de revendedores dirigidos a él, con el estado del revendedor en modo solo lectura.
2. EL SISTEMA NO DEBE mostrar al proveedor los clientes privados del revendedor.

### R5.2 Estado de despacho del proveedor (P0, Fase 5)
**Historia:** Como proveedor, quiero marcar mi propio estado de despacho, sin alterar el estado del revendedor.

**Criterios:**
1. EL SISTEMA DEBE permitir al proveedor marcar `separado` o `entregado` en su campo propio.
2. EL SISTEMA NO DEBE permitir al proveedor cambiar el estado del revendedor.
3. LOS dos estados DEBEN persistirse en campos independientes (P3).
4. SOLO el proveedor dueño del pedido DEBE poder cambiar su estado de despacho.

> Nota: la UI del proveedor puede implementarse en el frontend web existente; esta fase define los cambios de backend y, si se decide, pantallas móviles. La app Flutter de esta spec es primariamente para el revendedor.

---

## Fase 6 — Notificaciones push, pulido y publicación

### R6.1 Notificaciones push (P0, Fase 6)
**Historia:** Como usuario, quiero recibir notificaciones de pedidos nuevos y cambios de estado, para enterarme a tiempo.

**Criterios:**
1. EL SISTEMA DEBE enviar push (FCM) al revendedor ante cambios de estado de despacho del proveedor.
2. EL SISTEMA DEBE enviar push al proveedor ante un pedido nuevo de revendedor.
3. EL SISTEMA DEBE registrar y actualizar el token FCM del dispositivo por cuenta.
4. WhatsApp DEBE seguir siendo el canal hacia el cliente final (Nt-1).

### R6.2 Pulido, rendimiento y accesibilidad (P1, Fase 6)
**Criterios:**
1. EL SISTEMA DEBE mantener la identidad FlyStock (Poppins; `#001634`, `#004aad`, `#5de0e6`, `#00ff94`).
2. EL SISTEMA DEBE funcionar en español y moneda COP (UX-2).
3. EL SISTEMA DEBE ofrecer estados de carga, vacío y error consistentes.

### R6.3 Publicación en tiendas (P0, Fase 6)
**Criterios:**
1. EL SISTEMA DEBE compilar y firmar para Android (Play) e iOS (App Store) desde el inicio (St-1).
2. EL SISTEMA DEBE tener bundle id/package name definitivos, iconos y splash.
3. EL SISTEMA DEBE incluir política de privacidad acorde al manejo de clientes privados.

---

## Requisitos transversales

### RT.1 Seguridad y privacidad (P0, todas las fases)
1. EL backend DEBE validar el `idToken` de Firebase en cada endpoint autenticado.
2. EL backend DEBE autorizar por rol (`reseller` vs `provider`) y por propiedad del recurso.
3. EL aislamiento de clientes privados DEBE ser verificable con pruebas de API (un proveedor no puede leerlos).
4. App Check DEBE proteger endpoints sensibles/públicos (A-3).

### RT.2 Configuración por entorno (P0, Fase 1)
1. EL SISTEMA DEBE soportar los flavors de build `dev`, `staging` y `prod` con base URL y claves por flavor.
2. EL SISTEMA DEBE permitir fijar la base URL para pruebas manuales/locales vía `--dart-define apiBaseUrl=...` apuntando al backend local del usuario (p. ej. `http://<PC_LAN_IP>:3000` en dispositivo físico o `http://10.0.2.2:3000` en emulador Android).
3. EL SISTEMA DEBE usar `https://api.minymol.com` como base URL de producción.
4. NO existe un entorno de prueba desplegado (no hay `dev-api`/`staging-api`); EL SISTEMA NO DEBE referenciar hosts de staging/dev inexistentes.
5. EL SISTEMA NO DEBE ejecutar pruebas destructivas contra producción (RE-2).

### RT.3 Extensibilidad (P1)
1. EL diseño DEBE permitir añadir límites/planes (N-3) y pago en línea (Pg-1) sin re-arquitectura.
