# Backlog de seguridad — Sistema de códigos de verificación existente (recover-password)

> **Alcance:** este backlog cubre el **endurecimiento del sistema de códigos de verificación YA EXISTENTE** en el backend (`/notifications/verify*` + `/users/recover-password`). **NO** es parte de la implementación del login del revendedor. El login del revendedor usa un flujo NUEVO y aislado (`/auth/reseller/*` + tabla `reseller_login_codes`), descrito en `.kiro/specs/app-revendedores/design.md` §4.0, y NO toca estos endpoints.
>
> **Fuente de evidencia:** lectura directa del código (no se llamó a producción). Repo backend: `/mnt/ssd_secundario/Repositorios/surtte/main/backend`.
> **Fecha:** 2026-10-XX.

---

## 1. Componentes afectados (evidencia)

| Componente | Ruta | Observación |
|---|---|---|
| Entidad `verification_codes` | `src/modules/notifications/entities/verification-code.entity.ts` | `code` `varchar(6)` en **CLARO**; `channel` {email,whatsapp}; `type` {verify_email,verify_phone,recover_password}; `expiresAt`; `isConfirmed`; **sin** contador de intentos. |
| Servicio | `src/modules/notifications/notifications.service.ts` | 6 dígitos con `Math.random`; expiración **30 min**; **devuelve el código** en la respuesta JSON; sin lockout; `resend` reenvía el mismo código. |
| Controlador | `src/modules/notifications/notifications.controller.ts` | `POST /notifications/verify`, `/verify/resend`, `/verify/confirm` — **abiertos** (sin `@UseGuards`). |
| Consumidor real | `src/modules/users/users.service.ts` (`recoverPassword`) + `users.controller.ts` (`PATCH /users/recover-password`) | Usa `validateCode()` con `type='recover_password'`. |
| Limpieza | `src/modules/notifications/cron/verification-cleaner.job.ts` | Cron cada 5 min borra códigos no confirmados y expirados. |

**Análisis de consumidores (verificado por grep en los 3 repos):** NADA fuera de `recover-password` consume `/notifications/verify*` — ni `flystock-catalogos`, ni la app Flutter, ni otros módulos del backend. => El riesgo de regresión al endurecer es **bajo**, siempre que se **preserve el contrato externo** de `recover-password`.

---

## 2. Hallazgos, severidad y correcciones

> Severidad razonada desde el código. "Explotable hoy" = alcanzable sin autenticación con el comportamiento actual.

### H-1 — El endpoint de envío devuelve el código en la respuesta — **Severidad: Alta**
- **Evidencia:** `notifications.service.ts` retorna `code: success ? code : undefined`.
- **Riesgo:** cualquiera que invoque `POST /notifications/verify` (endpoint abierto) obtiene el código directamente en el JSON; anula por completo el factor "poseer el canal". Para recover-password esto permitiría, combinado con H-3, iniciar el flujo de reseteo sin acceso al WhatsApp/email del titular.
- **Explotable hoy:** **Sí** (endpoint abierto + código en respuesta).
- **Fix:** dejar de retornar el código; responder solo `{ ok, expiresInSeconds }`.

### H-2 — Endpoints abiertos (sin guard) ⇒ abuso de mensajería y enumeración — **Severidad: Alta**
- **Evidencia:** `notifications.controller.ts` sin `@UseGuards`/`@Public()`; solo aplica el rate-limit casero global de `src/main.ts` (100/min anónimos).
- **Riesgo:** envío no autenticado ⇒ abuso de WhatsApp/SES (costo y riesgo de bloqueo de la cuenta de Meta/SES); posible enumeración de cuentas según diferencias de respuesta.
- **Explotable hoy:** **Sí**.
- **Fix:** proteger con **App Check** + **throttle específico** por teléfono/email e IP (cooldown + tope por hora); respuestas uniformes para no revelar existencia.

### H-3 — Sin límite de intentos ni lockout ⇒ fuerza bruta — **Severidad: Alta**
- **Evidencia:** `confirmVerification` no cuenta intentos; la entidad no tiene columna de intentos.
- **Riesgo:** código de 6 dígitos (10^6) con ventana de **30 min** e intentos **ilimitados** es forzable por fuerza bruta. Para recover-password, esto puede derivar en toma de cuenta.
- **Explotable hoy:** **Sí**.
- **Fix:** contador de intentos por registro/teléfono + **lockout** (p. ej. 5 intentos → bloqueo 15 min).

### H-4 — RNG débil (`Math.random`) — **Severidad: Media**
- **Evidencia:** `Math.floor(100000 + Math.random()*900000)`.
- **Riesgo:** `Math.random` no es criptográficamente seguro; en teoría la salida es predecible. En la práctica el vector dominante es H-3 (fuerza bruta), pero sigue siendo una debilidad.
- **Explotable hoy:** Difícil de forma aislada; agrava H-3.
- **Fix:** usar `crypto.randomInt(100000, 1000000)` de Node.

### H-5 — Expiración larga (30 min) — **Severidad: Media**
- **Evidencia:** expiración de 30 min en `notifications.service.ts`.
- **Riesgo:** ventana amplia para fuerza bruta/reuso.
- **Explotable hoy:** agrava H-3.
- **Fix:** reducir a ~5–10 min para flujos sensibles (reseteo de contraseña). Mantener compatibilidad del contrato (ver §3).

### H-6 — Código en CLARO en la base de datos — **Severidad: Media**
- **Evidencia:** `code` `varchar(6)` sin hash.
- **Riesgo:** una fuga de BD/logs expone códigos activos; viola buenas prácticas de almacenamiento de secretos de corta vida.
- **Explotable hoy:** requiere acceso a BD (no remoto directo).
- **Fix:** almacenar `code_hash` (bcrypt o sha256+sal) y comparar en tiempo constante.

### H-7 — Single-use no estricto — **Severidad: Media**
- **Evidencia:** `confirmVerification` setea `isConfirmed=true`; `validateCode` acepta mientras `isConfirmed=true` y no expirado. No hay consumo/borrado inmediato tras el uso efectivo.
- **Riesgo:** reuso del mismo código confirmado dentro de la ventana.
- **Explotable hoy:** parcial (ventana corta tras confirmación).
- **Fix:** marcar `consumed_at`/borrar tras el uso efectivo (p. ej. tras `recoverPassword`).

### H-8 — `resend` reenvía el mismo código sin coste adicional — **Severidad: Baja**
- **Evidencia:** `resendVerification` reenvía el mismo código vigente.
- **Riesgo:** facilita spam de mensajes al mismo destinatario (molestia/costo), aunque no debilita el código por sí mismo.
- **Explotable hoy:** Sí (molestia/costo), ligada a H-2.
- **Fix:** cooldown entre reenvíos (p. ej. 60 s) y tope por hora.

---

## 3. Plan de compatibilidad para consumidores existentes

- **Contrato externo a preservar:** `PATCH /users/recover-password` depende de `validateCode({ phoneNumber, code, type:'recover_password' })`. Los cambios NO deben alterar la firma pública de recover-password ni el "happy path" (enviar código → confirmar → resetear).
- **No hay consumidores in-repo** de `/notifications/verify*` fuera de recover-password (verificado por grep). El riesgo de romper clientes externos es **bajo**, pero puede existir algún cliente fuera de estos repos; por eso:
  - Mantener las rutas y los nombres de campos de request/response existentes salvo la **remoción del `code` en la respuesta** (H-1), que es un cambio de seguridad necesario y de bajo impacto funcional (ningún cliente legítimo debería depender de recibir el código).
  - Introducir hashing/intentos/expiración como cambios **internos** (migración aditiva de columnas: `code_hash`, `attempts`, `locked_until`, `consumed_at`) manteniendo lectura/escritura compatibles durante una ventana de transición.
  - Reducir expiración y añadir throttle con **flags/config** para poder ajustar sin redeploy si algún flujo legítimo se ve afectado.
- **Secuencia sugerida:** (1) quitar el `code` de la respuesta; (2) añadir throttle + App Check en los endpoints abiertos; (3) migración aditiva de columnas + hashing + intentos/lockout; (4) RNG seguro; (5) expiración corta; (6) single-use estricto.

---

## 4. Resumen de severidades

| ID | Hallazgo | Severidad | Explotable hoy |
|---|---|---|---|
| H-1 | Código devuelto en la respuesta | Alta | Sí |
| H-2 | Endpoints abiertos (abuso/enumeración) | Alta | Sí |
| H-3 | Sin intentos/lockout (fuerza bruta) | Alta | Sí |
| H-4 | RNG débil (`Math.random`) | Media | Agrava H-3 |
| H-5 | Expiración larga (30 min) | Media | Agrava H-3 |
| H-6 | Código en claro en BD | Media | Con acceso a BD |
| H-7 | Single-use no estricto | Media | Parcial |
| H-8 | `resend` sin cooldown | Baja | Sí (molestia/costo) |

> **Nota:** el login del revendedor NO reutiliza este sistema; nace ya endurecido en `reseller_login_codes`. Este backlog es independiente y puede priorizarse por separado.
