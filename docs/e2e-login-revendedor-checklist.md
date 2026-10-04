# Checklist E2E — Login de revendedor (código WhatsApp + custom token)

> **Para el usuario (manual, con cuentas reales).** Valida el flujo completo: dos proveedores comparten el MISMO teléfono como revendedor, el revendedor inicia sesión por código WhatsApp, se vinculan los catálogos de AMBOS proveedores y se verifica el aislamiento de datos.
>
> **Referencias:** `.kiro/specs/app-revendedores/design.md` §4.0 y §4.0.8; `requirements.md` R1.1–R1.5.
> **Entorno:** backend **local** del usuario (no hay staging). App con `--dart-define apiBaseUrl=http://<PC_LAN_IP>:3000` (dispositivo físico) o `http://10.0.2.2:3000` (emulador Android). Producción: `https://api.minymol.com`.
>
> ⚠️ **Antes de ejecutar contra una BD con migraciones aplicadas:** confirmar que la migración `reseller_login_codes` ya se ejecutó (tras snapshot de RDS y aprobación del SQL — ver tareas M-a y 1.1a). Confirmar `WHATSAPP_PHONE_NUMBER_ID` y `WHATSAPP_TOKEN` disponibles (tarea M-b).

---

## 0. Datos de prueba (NO asumir ningún número concreto)

- **Teléfono del revendedor (R):** un número con WhatsApp real al que tengas acceso, en formato E.164 (p. ej. `+57XXXXXXXXXX`). Anótalo: `__________`.
- **Proveedor A:** cuenta real de proveedor con acceso a su página de catálogos.
- **Proveedor B:** segunda cuenta real de proveedor, distinta de A.

---

## 1. Preparación (proveedores comparten el MISMO teléfono)

- [ ] 1.1 Como **Proveedor A**, en la página de catálogos, agregar el teléfono **R** como revendedor/canal (crea una fila `private_catalogs` con `telefono` = R, normalizado E.164). Anotar el `catalog_id` A: `__________`.
- [ ] 1.2 Como **Proveedor B**, repetir con el **mismo** teléfono **R**. Anotar el `catalog_id` B: `__________`.
- [ ] 1.3 Verificar (consulta de solo lectura o UI) que existen DOS filas `private_catalogs` con `telefono` = R, una por proveedor.

---

## 2. Solicitud de código (`request-code`)

- [ ] 2.1 En la app, ingresar el teléfono **R** y pulsar "Enviar código".
- [ ] 2.2 Verificar request:
  ```
  POST /auth/reseller/request-code
  Body: { "phoneNumber": "+57XXXXXXXXXX" }
  ```
- [ ] 2.3 Verificar respuesta `200` **sin el código**:
  ```json
  { "ok": true, "expiresInSeconds": 300, "resendAvailableInSeconds": 60 }
  ```
- [ ] 2.4 Verificar que llega el mensaje de WhatsApp (plantilla `verificacion_codigo`, `es_CO`) con un código de 6 dígitos.
- [ ] 2.5 (Throttle) Pulsar "Reenviar" antes de 60 s → verificar `429` y que el botón muestra el contador de cooldown.

---

## 3. Verificación del código (`verify-code`) + `signInWithCustomToken`

- [ ] 3.1 Ingresar un código **incorrecto** → verificar `400` genérico ("Código incorrecto"), sin revelar si el número existe.
- [ ] 3.2 (Opcional, lockout) Repetir código incorrecto hasta 5 veces → verificar `429` lockout (~15 min) y mensaje en español.
- [ ] 3.3 Ingresar el **código correcto**:
  ```
  POST /auth/reseller/verify-code
  Body: { "phoneNumber": "+57XXXXXXXXXX", "code": "123456" }
  ```
- [ ] 3.4 Verificar respuesta `200`:
  ```json
  {
    "customToken": "<jwt firebase custom token>",
    "reseller": { "id": 0, "telefonoE164": "+57XXXXXXXXXX", "nombre": null, "countryCode": "CO" },
    "isNewProfile": true
  }
  ```
- [ ] 3.5 Verificar en la app que `FirebaseAuth.instance.signInWithCustomToken(customToken)` crea sesión y que `currentUser.uid` == `reseller:+57XXXXXXXXXX`.
- [ ] 3.6 Verificar que un segundo intento con el **mismo** código falla (single-use consumido).
- [ ] 3.7 Verificar que las siguientes requests autenticadas llevan `Authorization: Bearer <idToken>`.

---

## 4. Sincronización y lista agrupada

- [ ] 4.1 La app llama `POST /reseller/sync-shared-catalogs` (usa el teléfono del token). Verificar respuesta `{ linked: 2, ... }` (ambos catálogos vinculados).
- [ ] 4.2 La app llama `GET /reseller/me/shared-catalogs`. Verificar que la lista muestra catálogos de **AMBOS** proveedores (A y B), agrupados/filtrables por proveedor.
- [ ] 4.3 Repetir `sync-shared-catalogs` → verificar idempotencia (no duplica; `linked` refleja solo nuevos).

---

## 5. Verificación de aislamiento (privacidad)

- [ ] 5.1 Como **Proveedor A**, verificar que NO puede ver clientes privados del revendedor ni datos de clientes del revendedor en sus pedidos (campo ausente en la respuesta del proveedor).
- [ ] 5.2 Verificar que el revendedor solo ve SUS catálogos vinculados (los de A y B por su teléfono), no catálogos de otros revendedores.
- [ ] 5.3 Verificar que `GET /reseller/me/shared-catalogs` devuelve únicamente catálogos del revendedor autenticado.

---

## 6. Datos de producción tocados y cómo revertir

> Si se ejecuta contra la BD de producción, esta prueba crea datos reales. Revertir tras validar.

| Dato creado | Dónde | Cómo revertir |
|---|---|---|
| Fila de revendedor | `resellers` (uid `reseller:+57XXXXXXXXXX`, `telefono_e164` = R) | `DELETE FROM resellers WHERE firebase_uid = 'reseller:+57XXXXXXXXXX';` (previo borrado de dependientes) |
| Vínculos de catálogo compartido | `reseller_shared_catalogs` (2 filas, A y B) | `DELETE FROM reseller_shared_catalogs WHERE reseller_id = <id>;` |
| Códigos de login | `reseller_login_codes` (filas por envío) | `DELETE FROM reseller_login_codes WHERE phone_e164 = '+57XXXXXXXXXX';` |
| Usuario Firebase | Firebase Auth (uid `reseller:+57XXXXXXXXXX`) | Borrar vía `admin.auth().deleteUser('reseller:+57XXXXXXXXXX')` o la consola de Firebase |

**NO revertir / NO tocar:**
- Las filas `private_catalogs` de los proveedores A y B (son datos legítimos del proveedor; solo se usaron como origen del vínculo por teléfono).
- `verification_codes` ni `/users/recover-password` (flujo legado, no participa).

**Orden de revert sugerido:** (1) `reseller_shared_catalogs` → (2) cualquier otra dependencia del reseller → (3) `resellers` → (4) `reseller_login_codes` → (5) usuario Firebase.

---

## 7. Criterio de aceptación global

- [ ] El revendedor inicia sesión solo con teléfono + código WhatsApp (sin Firebase Phone Auth).
- [ ] Un único `uid` estable (`reseller:<E.164>`) para el mismo teléfono en logins repetidos.
- [ ] Los catálogos de AMBOS proveedores aparecen en la cuenta del revendedor.
- [ ] El proveedor no ve clientes privados del revendedor.
- [ ] El código nunca aparece en ninguna respuesta de API.
- [ ] Throttle/cooldown/lockout funcionan según `requirements.md` R1.5.
- [ ] Datos de prueba revertidos (si se ejecutó contra producción).
