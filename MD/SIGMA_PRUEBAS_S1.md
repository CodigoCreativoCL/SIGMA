# SIGMA — Evidencia de pruebas · Sprint 1

> Registro de la ejecución de casos de prueba del Sprint 1. Un caso por cada
> criterio de aceptación (CA). Aquí vive la **evidencia** (petición, respuesta
> real y veredicto); el resultado resumido (Sí/No) va además en la columna
> **Verificado** de la hoja *Criterios de aceptación* del
> `SIGMA_Sprint_Backlog_S1.xlsx`.

**Responsable:** Catalina Pescio · **Tarea:** T-1011 (Pruebas)
**Fecha de ejecución:** 01-09-2026
**Enfoque:** prueba manual de integración contra la API levantada (cURL / Postman).

---

## Entorno

| | |
|---|---|
| **Endpoint bajo prueba** | `POST /sesion` — [`SesionController.cs`](../Solucion/SIGMA/API/Controllers/SesionController.cs) |
| **Base URL** | `http://localhost/SIGMA/Servicio/API` |
| **Tecnología** | ASP.NET Web API 2 · .NET Framework 4.8 · JWT |
| **Estado del canal** | API arriba y **base de datos respondiendo** (primer ejercicio real contra la base; hasta ahora "no probada" según el estado de la API) |
| **Cuenta de prueba** | `catalina@codigocreativo.cl` / `1` (habilitada, cliente "Hamburgo SA") |

> La contraseña de prueba se documenta solo por ser una cuenta de desarrollo
> sin valor productivo.

---

## HU-001 · Iniciar sesión en SIGMA

La historia tiene **4 criterios de aceptación**. Se ejecutó un caso por cada uno.

### CA1 · Credenciales válidas — ⚠️ No verificado

**Criterio.** Dado que mi cuenta está habilitada · Cuando ingreso correo y
contraseña correctos · Entonces accedo a la pantalla de inicio · Y el sistema
registra la fecha y hora de mi último acceso.

**Petición.**
```bash
curl -X POST http://localhost/SIGMA/Servicio/API/sesion \
  -H "Content-Type: application/json" \
  -d '{"login":"catalina@codigocreativo.cl","password":"1"}'
```

**Respuesta.** `HTTP 200`
```json
{"<usuario>k__BackingField":3,"<login>k__BackingField":"catalina@codigocreativo.cl",
 "<nombre>k__BackingField":null,"<cliente>k__BackingField":1,
 "<cliente_nombre>k__BackingField":"Hamburgo SA",
 "<token>k__BackingField":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9…",
 "<expira_minutos>k__BackingField":480,"<debe_elegir_cliente>k__BackingField":false}
```

**Veredicto: No cumple.** El servidor concede el acceso (200 y token firmado
válido), pero:

1. **La respuesta expone los *backing fields* en lugar de las propiedades**
   (`<token>k__BackingField` en vez de `token`). Un cliente que lea el campo
   `token` no lo encuentra: en la práctica la app **no podría completar el
   inicio de sesión**. → **Defecto 1**.
2. El sub-criterio *"registra la fecha y hora de mi último acceso"* **no se
   verificó**: requiere consultar la base y aún no se tiene ese acceso.

---

### CA2 · Credenciales inválidas — ⚠️ No verificado

**Criterio.** Cuando ingreso una contraseña incorrecta · Entonces se muestra el
mensaje *"Correo o contraseña incorrectos"* · Y el mensaje no indica cuál de
los dos campos falló · Y el intento queda registrado en el log de excepciones.

**Petición.**
```bash
curl -X POST http://localhost/SIGMA/Servicio/API/sesion \
  -H "Content-Type: application/json" \
  -d '{"login":"catalina@codigocreativo.cl","password":"clave_incorrecta_xyz"}'
```

**Respuesta.** `HTTP 401`
```json
{"Message":"Equivalent to HTTP status 401. Unauthorized indicates that the requested
 resource requires authentication. The WWW-Authenticate header contains the details of
 how to perform the authentication."}
```

**Veredicto: No cumple.** El código HTTP es el correcto (401) y no se distingue
cuál campo falló (bien). Pero **el cuerpo no contiene el mensaje exigido**
"Correo o contraseña incorrectos": llega un texto genérico del framework, en
inglés. El controller sí construye el mensaje correcto (`Error(401, "Correo o
contraseña incorrectos.")`), así que algo en la tubería reemplaza el cuerpo de
los 401. → **Defecto 2**. El sub-criterio *"queda registrado en el log de
excepciones"* **no se verificó** (requiere acceso a la base / logs del
servidor).

---

### CA3 · Cuenta deshabilitada — ⏸️ Pendiente

**Criterio.** Dado que mi cuenta fue deshabilitada · Cuando ingreso credenciales
correctas · Entonces se muestra *"Su cuenta no está habilitada. Contacte al
administrador"* · Y no se inicia sesión.

**Veredicto: Pendiente.** No se dispone de una cuenta deshabilitada de prueba.
Queda sin ejecutar hasta contar con una (o poder deshabilitar una en la base).

---

### CA4 · Bloqueo por intentos fallidos — ✅ Cumple

**Criterio.** Cuando fallo cinco veces consecutivas en quince minutos · Entonces
la cuenta se bloquea por quince minutos · Y se informa el tiempo restante.

**Petición.** Intentos fallidos consecutivos con la misma cuenta:
```bash
# repetido con contraseñas incorrectas hasta gatillar el bloqueo
curl -X POST http://localhost/SIGMA/Servicio/API/sesion \
  -H "Content-Type: application/json" \
  -d '{"login":"catalina@codigocreativo.cl","password":"malaclave_N"}'
```

**Respuesta (al superar el umbral).** `HTTP 423`
```json
{"codigo":423,"mensaje":"Su cuenta está bloqueada por intentos fallidos. Vuelva a
 intentar en 15 minuto(s).","esDeNegocio":true}
```

**Veredicto: Cumple.** Tras los intentos fallidos la cuenta se bloquea, se
responde **HTTP 423** y **se informa el tiempo restante** ("en 15 minuto(s)").
El conteo lo lleva `SEL_LOGIN`, no el controller. Observación colateral: a
diferencia del 401, el cuerpo del 423 **sí** llega completo y en español, lo que
confirma que el Defecto 2 es específico de los 401.

---

## Defectos encontrados

Las pruebas se registran tal cual; los defectos quedan documentados para que el
equipo decida su corrección (no se modificó código en esta pasada).

### Defecto 1 — El login exitoso serializa *backing fields*

- **Dónde:** `POST /sesion`, respuesta 200 (DTO `SesionDto`).
- **Síntoma:** las claves salen como `<token>k__BackingField`, `<usuario>k__BackingField`, etc.
- **Impacto:** alto. Un cliente no puede leer `token` por su nombre → el login
  es inutilizable end-to-end pese al 200.
- **Causa probable:** `SesionDto` está marcado `[Serializable]`
  ([`Dto.cs`](../Solucion/SIGMA/API/MVC/Model/Dto.cs)); los DTOs sin ese atributo
  serializan limpio.
- **Corrección sugerida:** quitar `[Serializable]` de `SesionDto` (o configurar
  el resolver JSON para ignorarlo) y re-probar CA1.

### Defecto 2 — El 401 pierde el mensaje del controller

- **Dónde:** `POST /sesion`, respuesta 401 (credenciales inválidas).
- **Síntoma:** el cuerpo es el texto genérico del framework en inglés, no
  "Correo o contraseña incorrectos".
- **Impacto:** medio. El código 401 es correcto; el texto exigido por CA2 no
  llega. La app tendría que mapear el 401 a su propio mensaje.
- **Observación:** afecta **solo a los 401** (el 423 sí entrega su cuerpo),
  lo que apunta a la intercepción del 401 en la tubería (`TokenValidationHandler`
  / IIS y su `WWW-Authenticate`).
- **Corrección sugerida:** investigar los *message handlers* y la config de IIS
  para que el cuerpo de los 401 propios de la API no se reemplace.

---

## Resumen

| CA | Escenario | Código HTTP | Verificado |
|----|-----------|-------------|------------|
| CA1 | Credenciales válidas | 200 | **No** (Defecto 1 · último acceso sin verificar) |
| CA2 | Credenciales inválidas | 401 | **No** (Defecto 2 · log sin verificar) |
| CA3 | Cuenta deshabilitada | — | **Pendiente** (sin cuenta) |
| CA4 | Bloqueo por intentos | 423 | **Sí** |

**1 de 4 criterios cumple** en esta pasada. HU-001 no puede darse por terminada
hasta corregir los defectos 1 y 2, verificar CA1/CA2 contra la base, y ejecutar
CA3.

### Pendientes para cerrar HU-001
- Corregir **Defecto 1** y re-probar CA1.
- Corregir **Defecto 2** (o confirmar que el mensaje es responsabilidad de la app).
- Verificar en **base de datos**: registro de último acceso (CA1) y registro en
  el log de excepciones (CA2).
- Conseguir una **cuenta deshabilitada** para ejecutar **CA3**.
- Trasladar los 4 veredictos a la columna *Verificado* del Sprint Backlog S1.

> La cuenta `catalina@codigocreativo.cl` quedó bloqueada ~15 min tras ejecutar
> CA4 (comportamiento esperado).
