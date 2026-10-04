# Design — App móvil de Revendedores (Flutter)

> Acompaña a `requirements.md`. Define arquitectura Flutter, cambios de backend, modelo de datos, seguridad/privacidad y contratos de API por fase.
> Proyecto Flutter: `/mnt/ssd_secundario/Repositorios/ios-catalogos/catalogos`. Backend: NestJS + TypeORM + PostgreSQL. Firebase: `surtte-4bf22`.

## 1. Visión general

La app es **primariamente para el revendedor**. El backend se **extiende** (no se reemplaza) para soportar: cuenta/rol `reseller`, vinculación de catálogos compartidos por teléfono, catálogos generales con margen, clientes privados, pedidos con doble estado (revendedor/proveedor) y checkout group multi-proveedor.

Principios:
- Reutilizar lo existente (`orders`, `private_catalogs`, vistas públicas de catálogo, auth Firebase).
- Aislamiento estricto de datos del revendedor frente al proveedor.
- Backend como fuente de verdad de precios del proveedor; el margen del revendedor se calcula y se persiste a nivel de catálogo general.
- Diseño por flavors de build (dev/staging/prod); para pruebas se usa el backend local (no hay host de staging desplegado); nunca pruebas destructivas en prod.

---

## 2. Arquitectura Flutter

### 2.1 Capas (feature-first + Clean-lite)
```
catalogos/lib/
  main.dart                      # bootstrap: Firebase, App Check, env, runApp
  app/
    app.dart                     # MaterialApp.router
    theme/                       # ThemeData FlyStock (Poppins + paleta)
    router/                      # go_router + guards de auth/rol
    env/                         # Environment (dev/staging/prod) + flavors
  core/
    network/                     # Dio + AuthInterceptor (idToken) + AppCheckInterceptor + error mapping
    storage/                     # secure storage (sesión) + cache (hive/drift) para offline
    result/                      # Result<T>/Either, Failure types
    utils/                       # money (COP), phone (E.164), whatsapp link
  features/
    auth/                        # login por código WhatsApp + signInWithCustomToken, perfil reseller
    shared_catalogs/             # catálogos recibidos (lista, detalle, cache)
    orders/                      # crear pedido, listado, estados del revendedor
    customers/                   # clientes privados (CRUD, selección en pedido)
    general_catalog/             # catálogos generales, margen, portada, checkout on/off
    provider_view/               # (opcional móvil) vista proveedor: separado/entregado
    notifications/               # FCM token, handlers
    profile/
  shared/
    widgets/                     # botones FlyStock, estados vacío/carga/error
    models/                      # modelos compartidos
```

Cada feature: `data/` (datasources, DTOs, repos impl) · `domain/` (entities, repo interfaces, usecases ligeros) · `presentation/` (pages, widgets, controllers/providers).

### 2.2 Gestión de estado
- **Riverpod** (riverpod + flutter_riverpod) con `AsyncNotifier`/`Notifier`.
- Rationale: inyección de dependencias simple, testeable, buen manejo de estados async (loading/data/error) alineado con UX-3.

### 2.3 Navegación
- **go_router** con rutas tipadas y **redirect guards**: no autenticado → login; autenticado sin perfil → completar perfil; rutas de proveedor protegidas por rol.

### 2.4 Capa de datos y red
- **Dio** con interceptores:
  - `AuthInterceptor`: adjunta `Authorization: Bearer <firebaseIdToken>` (refresco automático; reintento único ante 401, equivalente a `secureFetch.ts`).
  - `AppCheckInterceptor`: adjunta token de App Check en endpoints protegidos.
  - `ErrorInterceptor`: mapea HTTP → `Failure` (network, auth, validation, server, rateLimited 429).
- Base URL por entorno (`Environment.apiBaseUrl`).
- **Serialización:** `freezed` + `json_serializable`.

### 2.5 Caché / offline (UX-3)
- **drift** (SQLite) o **hive** para cachear catálogos compartidos y productos consultados (lectura offline).
- Estrategia **stale-while-revalidate**: muestra caché y refresca en background.
- La **creación de pedidos requiere conexión**; si no hay red, se bloquea con mensaje (sin cola offline en v1).

### 2.6 Manejo de errores
- `Result<T>` en repos; UI consume `AsyncValue`.
- Widgets consistentes de error/empty/loading en `shared/widgets`.
- 429 (rate limit) → backoff y mensaje; 401 persistente → cerrar sesión.

### 2.7 Configuración por entornos
- **Flavors** Flutter: `dev`, `staging`, `prod` (Android product flavors + iOS schemes/xcconfig). Los flavors existen como variantes de build; **NO** implican hosts `dev-api`/`staging-api` desplegados (no existe entorno de prueba).
- Base URL por `--dart-define apiBaseUrl=...`:
  - **Local/manual:** backend local del usuario → `http://<PC_LAN_IP>:3000` (dispositivo físico) o `http://10.0.2.2:3000` (emulador Android).
  - **Producción:** `https://api.minymol.com`.
- `--dart-define-from-file` con `env/dev.json|staging.json|prod.json` (apiBaseUrl, firebaseOptions ref, flags); el `apiBaseUrl` por defecto de dev/staging apunta al backend local, no a un host inexistente.
- Nunca commitear secretos; `firebase_options_*.dart` generados por FlutterFire se referencian por flavor.

### 2.8 Identidad visual (UX-1)
- `ThemeData` con `fontFamily: 'Poppins'` y `ColorScheme` derivado de: primario `#001634`, secundario `#004aad`, acento `#5de0e6`, brand `#00ff94`; fondo `#f8f9fa`, texto `#212529`.
- Botón primario con gradiente `#004aad → #5de0e6 → #00ff94` como widget propio.

---

## 3. Modelo de datos (cambios de backend)

> Todas las migraciones usan TypeORM, `synchronize:false`, siguiendo el patrón de `backend/migrations`. Nombres `snake_case`.

### 3.1 Nuevas tablas

**`resellers`** (N-1)
| columna | tipo | notas |
|---|---|---|
| id | pk serial | |
| firebase_uid | varchar unique | liga a Firebase |
| telefono_e164 | varchar unique | normalizado |
| nombre | varchar null | perfil |
| country_code | varchar(2) default 'CO' | |
| created_at / updated_at | timestamp | |

**`reseller_shared_catalogs`** (N-2) — vínculo reseller ↔ catálogo compartido
| columna | tipo | notas |
|---|---|---|
| id | pk | |
| reseller_id | fk → resellers | |
| catalog_id | uuid fk → private_catalogs | |
| provider_id | int fk → proveedores | denormalizado para filtros |
| linked_at | timestamp | |
| unique(reseller_id, catalog_id) | | idempotencia |

**`reseller_general_catalogs`** (CG-1/CG-2/R4.3)
| columna | tipo | notas |
|---|---|---|
| id | pk uuid | |
| reseller_id | fk | |
| nombre | varchar | |
| cover_url | varchar null | portada S3 |
| checkout_enabled | boolean default false | R4.3 |
| default_margin_type | enum('percent','fixed','none') default 'percent' | |
| default_margin_value | decimal null | |
| created_at/updated_at | | |

**`reseller_general_catalog_items`** (CG-1/CG-2/CG-3)
| columna | tipo | notas |
|---|---|---|
| id | pk | |
| general_catalog_id | fk | |
| product_id | uuid fk → products | |
| provider_id | int fk | para split por proveedor |
| order_index | int default 0 | reordenar |
| margin_type | enum('percent','fixed','inherit') default 'inherit' | override |
| margin_value | decimal null | |
| unique(general_catalog_id, product_id) | | |

**`reseller_customers`** (clientes privados)
| columna | tipo | notas |
|---|---|---|
| id | pk | |
| reseller_id | fk | dueño |
| nombre | varchar | |
| celular | varchar | |
| direccion / ciudad / departamento | varchar null | |
| nit_cedula | varchar null | |
| is_deleted | boolean default false | borrado lógico |
| created_at | timestamp | |

**`checkout_groups`** (P1 — agrupador multi-proveedor)
| columna | tipo | notas |
|---|---|---|
| id | pk uuid | |
| reseller_id | fk | |
| general_catalog_id | fk null | origen |
| reseller_customer_id | fk → reseller_customers null | cliente privado |
| total_cliente | decimal | suma precios con margen |
| created_at | timestamp | |

**`device_tokens`** (FCM, Nt-1)
| columna | tipo | notas |
|---|---|---|
| id | pk | |
| owner_type | enum('reseller','provider') | |
| owner_id | int | |
| fcm_token | varchar | |
| platform | enum('android','ios') | |
| updated_at | timestamp | unique(fcm_token) |

### 3.2 Cambios a tablas existentes

**`usuarios.rol`**: añadir valor `revendedor` al enum (migración de enum). El `reseller` vive en su tabla propia, pero el enum habilita autorización coherente.

**`orders`** (P4 — extender, no duplicar):
- `reseller_id` int fk → resellers (null para pedidos no-revendedor).
- `reseller_order_status` enum('pendiente','confirmado','entregado','anulado') null.
- `provider_fulfillment_status` enum('separado','entregado') null (independiente de `status`).
- `reseller_customer_id` int fk → reseller_customers null (**privado**; nunca serializado hacia el proveedor).
- `checkout_group_id` uuid fk → checkout_groups null.
- `price_source` enum('provider') default 'provider' (el total hacia el proveedor usa precio del proveedor).

> El `order.status` existente (máquina del proveedor global) se conserva. Los nuevos campos son ortogonales.

### 3.3 Diagrama ER (estado objetivo, resumido)

```mermaid
erDiagram
    RESELLERS ||--o{ RESELLER_SHARED_CATALOGS : vincula
    RESELLERS ||--o{ RESELLER_GENERAL_CATALOGS : crea
    RESELLERS ||--o{ RESELLER_CUSTOMERS : posee
    RESELLERS ||--o{ ORDERS : genera
    RESELLERS ||--o{ CHECKOUT_GROUPS : agrupa

    PRIVATE_CATALOGS ||--o{ RESELLER_SHARED_CATALOGS : compartido
    PROVEEDORES ||--o{ RESELLER_SHARED_CATALOGS : origen

    RESELLER_GENERAL_CATALOGS ||--o{ RESELLER_GENERAL_CATALOG_ITEMS : contiene
    PRODUCTS ||--o{ RESELLER_GENERAL_CATALOG_ITEMS : referencia

    CHECKOUT_GROUPS ||--o{ ORDERS : divide
    RESELLER_CUSTOMERS ||--o{ ORDERS : "cliente privado"
    PROVEEDORES ||--o{ ORDERS : recibe

    ORDERS {
        int id PK
        int provider_id FK
        int reseller_id FK
        int reseller_customer_id FK "privado"
        uuid checkout_group_id FK
        enum status "proveedor global (existente)"
        enum reseller_order_status "pendiente|confirmado|entregado|anulado"
        enum provider_fulfillment_status "separado|entregado"
    }
```

---

## 4. Contratos de API (nuevos / extendidos)

> Prefijo sugerido `/reseller/*` para endpoints del revendedor. Auth: `FirebaseAuthGuard` + guard de rol `reseller`. App Check en públicos.

### 4.0 Autenticación del revendedor — código WhatsApp + Firebase custom token

> **Decisión aprobada (autoritativa).** El login del revendedor usa un **código de verificación por WhatsApp** emitido por el backend (Meta Cloud API + plantilla existente `verificacion_codigo`, reutilizada TAL CUAL, sin cambios en Meta), **hardened**. Tras validar el código, el backend acuña un **Firebase custom token** (`admin.auth().createCustomToken(uid)`) y la app lo canjea con `signInWithCustomToken`. **Firebase Phone Auth queda REEMPLAZADO** en la app (no híbrido). **App Check se mantiene.** Los guards del backend siguen validando el `idToken` de Firebase (el canje del custom token produce un `idToken` normal).

#### 4.0.1 Aislamiento del flujo legado (no romper lo existente)

El login del revendedor vive en endpoints NUEVOS y dedicados bajo `/auth/reseller/*`. **NO** se reutiliza ni se altera el sistema de verificación existente:

- Entidad `verification_codes` (`src/modules/notifications/entities/verification-code.entity.ts`): `code` `varchar(6)` en CLARO, `channel` {email,whatsapp}, `type` {verify_email,verify_phone,recover_password}, `expiresAt`, `isConfirmed`, **sin** contador de intentos.
- Servicio `src/modules/notifications/notifications.service.ts`: 6 dígitos con `Math.random`, expiración 30 min, **devuelve el código** en la respuesta, sin lockout.
- Controlador `src/modules/notifications/notifications.controller.ts`: `POST /notifications/verify`, `/verify/resend`, `/verify/confirm` — **abiertos** (sin guard).
- Único consumidor hoy: `src/modules/users/users.service.ts` `recoverPassword()` vía `validateCode()` (type `recover_password`), expuesto en `PATCH /users/recover-password` (`users.controller.ts`).

**Análisis de consumidores (verificado por grep en los 3 repos):** NADA más consume `/notifications/verify*` — ni `flystock-catalogos`, ni la app Flutter, ni otros módulos del backend. El flujo recover-password depende de ellos pero no tiene llamador en estos repos. **=> El riesgo de romper consumidores existentes es BAJO** siempre que AGREGUEMOS endpoints nuevos dedicados y NO cambiemos el comportamiento de `/notifications/verify*`. El endurecimiento del flujo legado se trata por separado en `docs/backlog-seguridad-verification-codes.md`.

**Confirmación explícita:** `POST /auth/login` y sus ramas provider/comerciante/empleado (`src/modules/auth/auth.service.ts`) permanecen **byte-for-byte sin cambios**; el login del revendedor es una ruta separada.

#### 4.0.2 Decisión: tabla nueva vs. valor de enum (reusar `verification_codes`)

Se evaluaron dos opciones:

- **Opción A — reutilizar `verification_codes` con un nuevo `type = 'reseller_login'`.** Ventaja: menos tablas. Desventajas: la tabla carece de hashing, contador de intentos y single-use estricto, y hoy el servicio **devuelve el código**; endurecer esa tabla/servicio tocaría el camino legado de recover-password (riesgo de regresión) y mezclaría dos políticas de seguridad en una sola entidad. Además, agregar un valor al enum requiere `ALTER TYPE ... ADD VALUE` (ver caveat abajo).
- **Opción B (RECOMENDADA, ELEGIDA) — tabla dedicada `reseller_login_codes`.** El flujo hardened queda **aislado**: hashing del código, RNG seguro, expiración corta, single-use, contador de intentos + lockout, throttle por teléfono e IP, y el código NUNCA en la respuesta. El camino legado de recover-password queda intacto. Es aditivo y no destructivo.

**Decisión: Opción B — nueva tabla `reseller_login_codes`.**

> Caveat para la Opción A (no elegida): en PostgreSQL `ALTER TYPE ... ADD VALUE` **no puede ejecutarse dentro de un bloque transaccional** y el valor no es removible fácilmente. Si por algún motivo se adoptara A, usar:
> ```sql
> ALTER TYPE verification_type_enum ADD VALUE IF NOT EXISTS 'reseller_login';
> ```
> ejecutado fuera de transacción (autocommit). No es la ruta elegida.

#### 4.0.3 Identidad: `uid` estable del revendedor

**Derivación elegida:** `uid = "reseller:" + <E.164>` (ejemplo: `reseller:+573001234567`).

- **Justificación:** determinístico (el mismo teléfono siempre produce el mismo `uid`), legible para operación/debug, y sin dependencia de estado previo. El límite de Firebase para `uid` es **128 caracteres** y acepta el conjunto usado aquí; `reseller:+<hasta 15 dígitos>` ocupa ~24 caracteres, muy por debajo del límite.
- **Resolve-or-create:** `ResellerService.createIfNotExists(firebaseUid, { telefonoE164, ... })` (`src/modules/reseller/reseller.service.ts`) es idempotente por `uid`. Como `createCustomToken(uid)` acuña un token cuyo `uid` == `firebase_uid` del revendedor, el `ResellerGuard` existente (`src/modules/reseller/guards/reseller.guard.ts`), que resuelve al revendedor **por `firebase_uid`** contra la tabla `resellers` (NO por `phone_number` del token), funciona **sin cambios de guard**.
- **Custom claim (OPCIONAL, defensa en profundidad):** se puede incluir `{ role: 'reseller' }` como segundo argumento de `createCustomToken(uid, { role: 'reseller' })`. NO es necesario para el `ResellerGuard` (que ya resuelve por `uid` contra la tabla), por lo que se marca como opcional. Si se usa, NO debe colisionar con claims reservados de Firebase (`sub`, `iat`, `exp`, `aud`, `iss`, `auth_time`, `firebase`, `nbf`); `role`/`reseller` son seguros.

#### 4.0.4 Endpoints nuevos (públicos, protegidos por App Check + throttle)

Todos son **públicos** (sin `FirebaseAuthGuard`, porque aún no hay sesión) pero protegidos por **App Check** y **throttle** por teléfono e IP. El código NUNCA se devuelve en ninguna respuesta.

**`POST /auth/reseller/request-code`**
- Body: `{ phoneNumber: string }` (E.164 o local + `countryCode`; se normaliza con `libphonenumber-js`).
- Comportamiento: genera código seguro (ver 4.0.5), lo persiste hasheado en `reseller_login_codes`, lo envía por WhatsApp (`WhatsappService` + plantilla `verificacion_codigo`). Aplica cooldown de 60 s entre envíos y tope por hora.
- Respuesta `200`: `{ ok: true, expiresInSeconds: 300, resendAvailableInSeconds: 60 }`.
- Errores: `400` número inválido; `429` cooldown activo o tope por teléfono/IP superado; `502/503` fallo de envío en Meta.

**`POST /auth/reseller/verify-code`**
- Body: `{ phoneNumber: string, code: string }`.
- Comportamiento: normaliza teléfono; compara `code` con `code_hash` (hash + comparación en tiempo constante); valida no expirado, no consumido y no bloqueado. En éxito: marca el código como consumido, resuelve-o-crea el revendedor (`uid = reseller:<E.164>`, backfill `telefono_e164`), acuña custom token y responde.
- Respuesta `200`: `{ customToken: string, reseller: { id, telefonoE164, nombre|null, countryCode }, isNewProfile: boolean }`.
- Errores: `400` código incorrecto/expirado (sin revelar si el número existe); `429` intentos excedidos → lockout; `502/503` error interno al acuñar/token.

**`POST /auth/reseller/resend-code`** (o plegar en `request-code`)
- Body: `{ phoneNumber: string }`.
- Comportamiento: reenvía respetando el cooldown de 60 s; si no hay código vigente, genera uno nuevo. Mismos límites que `request-code`.
- Respuesta `200`: `{ ok: true, resendAvailableInSeconds: 60 }`; `429` si aún en cooldown.

> **Decisión:** se expone `resend-code` como endpoint explícito para claridad del cliente; comparte la lógica de cooldown de `request-code` (una nueva solicitud dentro de los 60 s se rechaza con `429`).

Códigos de estado usados: `200` éxito; `400` validación/código; `401`/`403` reservados (App Check inválido → `403`); `409` conflicto raro de resolve-or-create; `429` throttle/lockout; `502/503` fallo de proveedor WhatsApp.

#### 4.0.5 Almacenamiento hardened del código (`reseller_login_codes`)

- **Hash:** se almacena `code_hash` (NO el código). Mecanismo: `bcrypt` (cost 10) sobre el código de 6 dígitos. Alternativa aceptable: SHA-256 con sal por fila (`crypto.randomBytes(16)`). Dado que el espacio es de 10^6, bcrypt añade coste por intento y es la opción recomendada.
- **RNG:** generación con `crypto.randomInt(100000, 1000000)` de Node (criptográficamente seguro), NO `Math.random`.
- **Expiración:** `expires_at = now() + 5 min`.
- **Single-use:** columna `consumed_at` (timestamp null); al validar con éxito se setea; un código consumido no vuelve a validar.
- **Intentos + lockout:** columna `attempts` por fila; además `locked_until` por teléfono. 5 intentos fallidos → `locked_until = now() + 15 min`.
- **Throttle de envío:** cooldown de 60 s entre envíos por teléfono; tope de 5 envíos por teléfono por hora; tope por IP por hora (p. ej. 20). El conteo por hora se deriva de `created_at` + un contador/consulta por ventana.
- **El código NUNCA aparece en ninguna respuesta.**

#### 4.0.6 Migración ADITIVA (SQL) — NO EJECUTAR en este run

> Idempotente (`IF NOT EXISTS`), no destructiva, estilo backend/migrations. Debe mostrarse al usuario para aprobación ANTES de ejecutarse. TypeORM `synchronize:false`.

```sql
-- =====================================================================
-- Migración ADITIVA: tabla reseller_login_codes (login revendedor hardened)
-- Fecha: 2026-10-XX
-- Objetivo: aislar el flujo de login por código WhatsApp del revendedor.
-- NO toca verification_codes ni el flujo de recover-password.
-- Reversible: DROP TABLE reseller_login_codes;
-- =====================================================================

CREATE TABLE IF NOT EXISTS reseller_login_codes (
    id            uuid         NOT NULL DEFAULT gen_random_uuid(),
    phone_e164    varchar(20)  NOT NULL,              -- teléfono normalizado E.164
    code_hash     varchar(255) NOT NULL,              -- hash del código (bcrypt), NUNCA en claro
    attempts      integer      NOT NULL DEFAULT 0,    -- intentos de validación de esta fila
    consumed_at   timestamptz  NULL,                  -- single-use: se setea al validar OK
    locked_until  timestamptz  NULL,                  -- lockout por fuerza bruta
    created_at    timestamptz  NOT NULL DEFAULT now(),
    expires_at    timestamptz  NOT NULL,              -- típicamente now() + 5 min
    CONSTRAINT pk_reseller_login_codes PRIMARY KEY (id)
);

-- Búsqueda del código vigente por teléfono.
CREATE INDEX IF NOT EXISTS idx_reseller_login_codes_phone
    ON reseller_login_codes (phone_e164);

-- Soporte de limpieza/expiración y throttle por ventana de tiempo.
CREATE INDEX IF NOT EXISTS idx_reseller_login_codes_expires_at
    ON reseller_login_codes (expires_at);

CREATE INDEX IF NOT EXISTS idx_reseller_login_codes_phone_created
    ON reseller_login_codes (phone_e164, created_at);
```

> Si `gen_random_uuid()` no estuviera disponible, habilitar `pgcrypto` (ADITIVO):
> ```sql
> CREATE EXTENSION IF NOT EXISTS pgcrypto;
> ```
> Limpieza opcional: un cron análogo al existente puede borrar filas con `expires_at < now()`.

#### 4.0.7 WhatsApp: reutilización de `verificacion_codigo`

La plantilla `src/modules/notifications/templates/whatsapp/verify-code.template.ts` (idioma `es_CO`) toma el código como parámetro del body y un parámetro de botón-URL con el mismo código. Es un template genérico de código de 6 dígitos, por lo que **sirve para un código de login sin cambios en Meta**. Se reutiliza TAL CUAL vía `WhatsappService`. No se crea plantilla nueva ni se modifica Meta.

#### 4.0.8 Flujo de alta de revendedor nuevo (extremo a extremo)

1. El proveedor registra el teléfono del revendedor desde la página de catálogos (`private_catalogs.telefono`).
2. App → `POST /auth/reseller/request-code` → llega el código por WhatsApp.
3. App → `POST /auth/reseller/verify-code` → backend resuelve-o-crea `reseller` (`uid = reseller:<E.164>`, backfill `telefono_e164`) + acuña custom token.
4. App → `FirebaseAuth.instance.signInWithCustomToken(customToken)` → sesión Firebase + `idToken`.
5. App → `POST /reseller/sync-shared-catalogs` → vincula `private_catalogs` por teléfono E.164.
6. App → `GET /reseller/me/shared-catalogs` → lista agrupada de catálogos (de uno o varios proveedores).

#### 4.0.9 Casos de falla (comportamiento backend + mensaje al usuario)

| Caso | Backend (status + mensaje) | App Flutter (español + acción) |
|---|---|---|
| Número sin WhatsApp / no alcanzable | `request-code` responde `200` igualmente (Meta acepta plantilla); si Meta reporta fallo de envío → `502/503` | "No pudimos enviar el código. Verifica tu número e intenta de nuevo." + permitir reintento tras cooldown |
| Fallo de envío en Meta | `502/503` "No se pudo enviar el código, intenta más tarde" | Mensaje de reintento; botón reenviar deshabilitado por cooldown |
| Código expirado | `400` "El código expiró" | "El código expiró. Te enviamos uno nuevo." + ofrecer reenvío |
| Código incorrecto | `400` genérico (no revela si el número existe) | "Código incorrecto. Revisa e intenta de nuevo." |
| Intentos excedidos → lockout | `429` "Demasiados intentos, espera 15 minutos" | "Demasiados intentos. Intenta de nuevo en unos minutos." + bloquear campo |
| Throttle por teléfono/IP (envíos) | `429` con tiempo de espera | "Espera unos minutos antes de pedir otro código." |
| Cooldown de reenvío (60 s) | `429` con `resendAvailableInSeconds` | Contador regresivo en el botón "Reenviar" |

#### 4.0.10 Cambios en Flutter (reemplazo de Firebase Phone Auth)

La pantalla OTP deja de usar `FirebaseAuth.verifyPhoneNumber` / `signInWithCredential`. En su lugar: ingresa teléfono → `request-code`; ingresa código → `verify-code` → `FirebaseAuth.instance.signInWithCustomToken(customToken)`. Se conserva `AuthRepository` como interfaz, la sesión persistente, el cooldown de reenvío y el manejo de `429`/lockout. Tareas 1.9–1.13 pasan a **re-open / adjust** (ver `tasks.md`):

- **1.9** (ingreso de teléfono): la pantalla permanece; "enviar código" ahora llama `request-code` (no `verifyPhoneNumber`).
- **1.10** (verificación): ahora llama `verify-code` + `signInWithCustomToken`, NO `verifyPhoneNumber`/credential de Firebase.
- **1.11** (App Check): se mantiene; cambio mínimo o nulo (ahora también cubre los endpoints públicos de login).
- **1.12** (persistencia de sesión): `signInWithCustomToken` también produce un `FirebaseUser`, por lo que la persistencia de `currentUser` sigue funcionando; cambia la fuente del token, no el mecanismo de sesión.
- **1.13** (perfil): sin cambios de fondo; `isNewProfile` ahora puede venir en la respuesta de `verify-code`.

### Fase 1 — Auth + catálogos compartidos
- `POST /auth/login` (existente) — **NO se modifica**; permanece byte-for-byte igual con sus ramas provider/comerciante/empleado. El login del revendedor usa los endpoints `/auth/reseller/*` descritos en §4.0.
- `POST /auth/reseller/request-code` · `POST /auth/reseller/verify-code` · `POST /auth/reseller/resend-code` — ver §4.0.4 (públicos + App Check + throttle).
- `POST /reseller/sync-shared-catalogs` — body: `{}` (usa el teléfono del token). Vincula `private_catalogs` por teléfono E.164. Idempotente. Respuesta: `{ linked: n, catalogs: [...] }`.
- `GET /reseller/me` — perfil del revendedor.
- `PATCH /reseller/me` — actualizar nombre/datos.
- `GET /reseller/me/shared-catalogs?providerId=&search=` — catálogos vinculados.
- Reutilizar vistas públicas: `GET /catalog/by-catalog/:id/products`, `POST /catalog/products/previews`, `GET /catalog/short/:shortUuid`.

### Fase 2 — Pedidos y estados
- `POST /reseller/orders` — crea pedido (un proveedor). body: `{ providerId, items[], resellerCustomerId?, notes? }`. Crea `order` con `reseller_id`, `reseller_order_status='pendiente'`.
- `GET /reseller/me/orders?status=&providerId=&page=&limit=` — listado con proveedor + ambos estados.
- `GET /reseller/orders/:id` — detalle (solo dueño).
- `PATCH /reseller/orders/:id/status` — body `{ status }`. Valida transición; rechaza si `anulado`.

### Fase 3 — Clientes privados
- `GET /reseller/customers?q=&page=` · `POST /reseller/customers` · `PATCH /reseller/customers/:id` · `DELETE /reseller/customers/:id` (lógico).
- Todos filtran por `reseller_id` del token. **Ningún** endpoint de proveedor devuelve `reseller_customers`.

### Fase 4 — Catálogo general
- CRUD `GET/POST/PATCH/DELETE /reseller/general-catalogs[/:id]`.
- `POST /reseller/general-catalogs/:id/items` (agregar producto) · `POST /reseller/general-catalogs/:id/items/bulk` (atajo "todo el catálogo de un proveedor") · `PATCH .../items/:itemId` (margen/orden) · `DELETE .../items/:itemId`.
- `PATCH /reseller/general-catalogs/:id` — `checkout_enabled`, `default_margin_*`, `nombre`.
- Portada: `POST /reseller/general-catalogs/:id/cover/signed-url` → S3 presign (reutiliza patrón banner) · `POST .../cover/confirm`.
- `POST /reseller/general-catalogs/:id/checkout` — body `{ items[], resellerCustomerId? }`. Si `checkout_enabled`: crea `checkout_group` + N `orders` (split por `provider_id`). Si OFF: devuelve payload para WhatsApp (no crea orders).
- `GET /reseller/checkout-groups/:id` — grupo + subpedidos.

### Fase 5 — Proveedor
- `GET /provider/reseller-orders?status=&page=` — pedidos de revendedores del proveedor (sin cliente privado).
- `PATCH /orders/:id/provider-fulfillment` — body `{ fulfillment: 'separado'|'entregado' }`. Guard: proveedor dueño. **No** toca `reseller_order_status`.
- Garantizar en el serializer que `reseller_customer_id`/datos del cliente privado **no** se incluyan en respuestas al proveedor.

### Fase 6 — Notificaciones
- `POST /reseller/devices` / `POST /provider/devices` — registrar/actualizar `fcm_token`.
- Backend emite FCM: a proveedor en pedido nuevo; a revendedor en cambio de `provider_fulfillment_status`.

---

## 5. Cálculo de precios y margen (CG-3)

- **Precio proveedor (costo):** viene de `products.precios` (mapa cantidad→precio) según `price_field`.
- **Precio cliente (revendedor):**
  - `percent`: `precioCliente = precioProveedor * (1 + margin_value/100)`.
  - `fixed`: `precioCliente = margin_value` (precio de venta fijo).
  - `inherit` (item): usa `default_margin_*` del catálogo general.
  - `none`: `precioCliente = precioProveedor`.
- **Regla de exposición:** las respuestas de catálogo general / checkout hacia el **cliente final** devuelven solo `precioCliente`. El `precioProveedor` solo se usa internamente y en el pedido hacia el proveedor.
- **Recalculo:** el precio cliente se calcula on-read a partir de costo actual + regla (R4.2.4). El `fixed` se conserva aunque cambie el costo.
- **Redondeo:** COP sin decimales (UX-2), usando `NumberFormat` es-CO en Flutter y entero en backend.

## 6. Checkout split multi-proveedor (P1 / R4.4)

Flujo `POST /reseller/general-catalogs/:id/checkout` con `checkout_enabled=true`:
1. Agrupar `items` por `provider_id`.
2. Crear `checkout_group` (reseller_id, general_catalog_id, reseller_customer_id, total_cliente).
3. Por cada grupo de proveedor: crear `order` con `reseller_id`, `checkout_group_id`, `provider_id`, `reseller_order_status='pendiente'`, items con precio **del proveedor** (costo). El total "cliente" se guarda a nivel de grupo/línea para el revendedor.
4. Emitir FCM a cada proveedor (pedido nuevo).
5. Devolver `{ checkoutGroupId, orders:[...] }`.

Con `checkout_enabled=false`: no se crean orders; se devuelve el mensaje/payload para abrir WhatsApp hacia el cliente final (precios con margen).

## 7. Seguridad y privacidad (RT.1)

- **Validación idToken:** todos los endpoints `/reseller/*` y `/provider/*` pasan por `FirebaseAuthGuard` (verifica `idToken`).
- **Autorización por rol + propiedad:** guard `ResellerGuard` resuelve `reseller` por `firebase_uid`; cada query filtra por `reseller_id`. Guard de proveedor filtra por `provider_id`.
- **Aislamiento de clientes privados (R3.2):**
  - `reseller_customers` nunca se incluye en endpoints `/provider/*`.
  - Serializer de pedidos del proveedor **omite** `reseller_customer_id` y datos derivados.
  - Pruebas de API obligatorias: un proveedor autenticado NO puede leer `reseller_customers` ni ver cliente en su pedido (test negativo).
- **App Check (A-3):** interceptor en móvil; backend valida App Check donde reemplaza reCAPTCHA (endpoints públicos de red de ventas **y** los nuevos endpoints públicos de login del revendedor `/auth/reseller/*`).
- **Login hardened del revendedor:** ver §4.0. Código hasheado, RNG seguro, expiración 5 min, single-use, intentos + lockout, throttle por teléfono e IP, el código nunca en la respuesta. Flujo aislado en tabla `reseller_login_codes`, sin tocar `verification_codes`/recover-password (ese endurecimiento es backlog aparte: `docs/backlog-seguridad-verification-codes.md`).
- **Transiciones de estado:** validadas en servicio (anulado = terminal); el proveedor no puede escribir `reseller_order_status` y viceversa (guards distintos + columnas distintas).
- **Secretos:** sin credenciales en el repo Flutter; `firebase_options` por flavor; backend sigue usando AWS Secrets Manager.

## 8. Offline / caché (UX-3)

- Cachear: lista de catálogos compartidos, detalle de catálogo, previews de productos.
- No cachear datos sensibles de clientes más allá de la sesión segura.
- Crear pedido / checkout: requieren red; si offline, deshabilitar acción con aviso.

## 9. Notificaciones (Nt-1)

- `firebase_messaging` en Flutter; registrar token tras login (`POST /reseller/devices`).
- Manejo foreground/background/terminated; deep link a detalle de pedido.
- Backend dispara FCM en: pedido nuevo (→ proveedor), cambio de `provider_fulfillment_status` (→ revendedor).

## 10. Riesgos y mitigaciones (resumen)

- **Re-sincronización de catálogos por teléfono:** correr sync en login y vía endpoint manual; idempotente por `unique(reseller_id, catalog_id)`.
- **Cambios de costo del proveedor vs margen fijo:** documentar regla (percent recalcula, fixed conserva).
- **Fuga de cliente privado:** cubrir con tests de contrato en backend antes de exponer endpoints del proveedor.
- **Sin entorno de prueba desplegado (RE-2):** desarrollar contra el backend local (`http://<PC_LAN_IP>:3000` / `10.0.2.2:3000`); no ejecutar escrituras destructivas contra prod. Antes de cualquier migración, hacer snapshot de RDS y mostrar el SQL al usuario para aprobación.
- **App Check en Firebase existente:** requiere configuración del proyecto `surtte-4bf22` (pasos manuales en tasks).

## 11. Dependencias Flutter propuestas

`firebase_core`, `firebase_auth`, `firebase_app_check`, `firebase_messaging`, `dio`, `go_router`, `flutter_riverpod`, `riverpod_annotation`, `freezed`/`json_serializable`, `intl`, `cached_network_image`, `url_launcher`, `image_picker`, `image_cropper`, `drift` (o `hive`), `flutter_secure_storage`, `flutter_dotenv`/dart-define. Dev: `build_runner`, `mocktail`, `flutter_lints`.

## 12. Detalle de catálogo compartido — bugfix de mapeo y evaluación de endpoint dedicado

> Añadido tras corregir dos bugs reales del flujo de catálogos compartidos del revendedor.

### 12.1 Causa raíz corregida (mapper Flutter)

El endpoint `GET /reseller/me/shared-catalogs` (`backend/src/modules/reseller/reseller.controller.ts` → `serializeSharedCatalog`) **ya** devolvía una forma anidada correcta:

```
{ id: 3 (link id INT), catalogId: "<uuid>", providerId, linkedAt,
  catalog: { id: "<uuid>", publicName, description, bannerUrl, enlace, priceField },
  provider: { id, nombreEmpresa, logoUrl, ... } }
```

El bug estaba en `Catalog.fromJson` (`lib/features/shared_catalogs/domain/catalog.dart`), que leía campos planos equivocados:

- **PROBLEMA 1 (el detalle fallaba):** usaba el `id` top-level (= `3`, el id del vínculo `reseller_shared_catalogs.id`) como id del catálogo. El detalle llama `GET /catalog/by-catalog/:catalogId/products` (`@Param ParseUUIDPipe`), que rechazaba `3` con 400 "uuid is expected". **Fix:** `id` ahora se toma de `catalogId` (= `private_catalogs.id`, UUID). Se añadió `linkId` para conservar el id del vínculo.
- **PROBLEMA 2 ("Proveedor \<id\>"):** `providerName` se buscaba plano (ausente) → la UI mostraba `Proveedor <id>`. **Fix:** se lee de `provider.nombreEmpresa`; `providerLogoUrl` de `provider.logoOptimizedUrl` (fallback `logoUrl`); `providerLabel`/iniciales nunca muestran el id.

El backend solo se **enriqueció** (aditivo, sin migración): `provider.logoOptimizedUrl`, `provider.bannerUrl`, `provider.bannerDesktopUrl`, `provider.bannerMobileUrl` (columnas ya existentes en `proveedores`). No se exponen campos sensibles del proveedor.

### 12.2 Punto 4 — Evaluación de endpoint dedicado del revendedor (DECISIÓN: NO implementar)

Se evaluó mover el detalle del endpoint público legado `GET /catalog/by-catalog/:catalogId/products` a uno dedicado del revendedor (p. ej. `GET /reseller/me/shared-catalogs/:catalogId/products`) que verifique la propiedad (que el catálogo esté vinculado al revendedor autenticado) + App Check + guard de revendedor.

**Decisión: NO se implementa ahora.** No cumple el criterio de "cambio pequeño / delegación delgada":

- El endpoint delega finalmente en `PrivateCatalogsService.getCatalogProductsFormatted` (`backend/src/modules/private-catalogs/private-catalogs.service.ts`). Para reutilizarlo desde `ResellerController`, habría que inyectar ese servicio en `ResellerModule`, lo que obliga a importar `PrivateCatalogsModule` completo (arrastra `ProductsService`, S3, PDF jobs, reCAPTCHA, etc.) con riesgo de dependencias circulares y de ampliar la superficie del módulo. Eso excede una "delegación delgada".
- El endpoint público actual **no filtra datos privados del revendedor**: devuelve la vista pública del catálogo del proveedor (los mismos productos/precios que ve cualquiera con el enlace). No hay fuga de `reseller_customers` ni de otros datos del revendedor.

**Recomendación (futuro, si se desea reforzar):** crear el endpoint dedicado cuando se aborde la Fase 2 (donde `PrivateCatalogsService` ya se integrará para pedidos), exponiendo un método delgado en `ResellerController` que: (1) valide el vínculo `(reseller_id, catalogId)` en `reseller_shared_catalogs` (ya disponible vía `ResellerService`/repositorio), (2) delegue en `getCatalogProductsFormatted`, (3) adjunte App Check + `ResellerGuard`. Mientras tanto, el detalle Flutter sigue usando el endpoint público con el **UUID correcto** (fix de PROBLEMA 1), que es lo que desbloquea el 200.
