# SIGMA — Anexo D (normativo): permisos asignados por usuario

Cómo el planificador habilita a un técnico concreto para crear activos, componentes y repuestos desde la app.

**Sustituye al Anexo C §8.** Base: `db_acd593_sigma` · sin datos.

---

## 1. Qué cambia

En el Anexo C los tres permisos de terreno colgaban del perfil: si el perfil `Técnico` tenía `CREAR COMPONENTE TERRENO`, lo tenían **todos** los técnicos del cliente.

Eso no sirve para lo que necesitas. Un cliente tiene ocho técnicos y el planificador quiere habilitar a dos: el que está haciendo el levantamiento de la sala de blowers y el electromecánico de confianza. Con permisos por perfil hay que crear un perfil `Técnico con creación` y mover gente entre perfiles cada vez que cambia algo — que es como se terminan teniendo catorce perfiles casi iguales.

**Ahora el permiso se asigna a la persona.**

---

## 2. La decisión de fondo: se suma, no se reemplaza

El permiso efectivo se resuelve así:

```text
tiene_permiso = (el perfil lo otorga)  OR  (hay concesión al usuario)
                AND NO (hay revocación al usuario)
```

Una sola tabla cubre los tres casos, con una columna `cpm_otorgado BIT`:

| Perfil | Fila en `Cliente_Usuario_Permiso` | Resultado | Para qué sirve |
|---|---|---|---|
| no lo tiene | `otorgado = 1` | **sí** | habilitar a dos técnicos de ocho |
| sí lo tiene | *(ninguna)* | **sí** | el caso normal, sin filas extra |
| sí lo tiene | `otorgado = 0` | **no** | quitárselo a uno solo sin cambiarlo de perfil |
| no lo tiene | *(ninguna)* | **no** | el caso normal |

Sin `otorgado = 0` no se puede revocar a una persona: habría que sacarla del perfil, y con eso pierde todo lo demás. Es la fila que hace que el modelo sirva de verdad.

---

## 3. El permiso se otorga **dentro de un cliente y de una planta**

Esto no es opcional en SIGMA. Un técnico puede trabajar para dos clientes; habilitarlo "en general" significaría habilitarlo también donde nadie se lo pidió.

Por eso la concesión cuelga de `Cliente_Usuario` (`ucl`), que es la afiliación del usuario a un cliente, y **no** de `Usuario`.

```text
Usuario  ──  Cliente_Usuario  ──  Cliente_Usuario_Permiso  ──  Permiso
   Juan          en Hamburgo            CREAR COMPONENTE TERRENO
                                        planta: Renca  (o NULL = todas las suyas)
```

`cpm_cliente_instalacion NULL` significa "en todas las plantas donde esté autorizado". Con un valor, se acota a esa planta — útil justo en el arranque: se habilita la creación en la planta que se está levantando y no en las que ya están maduras.

### El permiso solo no basta

La API valida **dos cosas**, siempre:

1. que el permiso resuelva `sí` (§2);
2. que el usuario esté **vigente** en `Cliente_Instalacion_Usuario` para esa planta.

Un técnico con `CREAR ACTIVO TERRENO` al que le revocaron la planta no crea nada. La autorización de planta manda: el permiso dice *qué* puede hacer, `Cliente_Instalacion_Usuario` dice *dónde*.

---

## 4. `Cliente_Usuario_Permiso` (`cpm`)

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `cpm_cliente_usuario` | `INT` | NO | FK `Cliente_Usuario` — la afiliación, no el usuario suelto |
| `cpm_permiso` | `INT` | NO | FK `Permiso` |
| `cpm_cliente_instalacion` | `INT` | SÍ | NULL = todas las plantas autorizadas del usuario |
| `cpm_otorgado` | `BIT` | NO | DF 1 · **0 = revocación explícita** |
| `cpm_fecha_inicio` | `DATE` | SÍ | NULL = desde ya |
| `cpm_fecha_fin` | `DATE` | SÍ | NULL = sin vencimiento |
| `cpm_motivo` | `NVARCHAR(500)` | SÍ | "levantamiento sala de blowers, ago-sep 2026" |
| AUD-M | | | `cpm_usuario_creacion` **es el planificador que lo otorgó** |

`UX_CPM_USUARIO_PERMISO_INSTALACION (cpm_cliente_usuario, cpm_permiso, cpm_cliente_instalacion)` — una sola regla por combinación. Sin esto habría dos filas contradictorias para el mismo caso y ganaría la que el `SELECT` devolviera primero.

`cpm_fecha_fin` es lo que evita el problema clásico: se habilita a alguien "por esta semana" y queda habilitado dos años. Con fecha de término, el permiso se apaga solo.

> **Auditoría:** `Cliente_Usuario_Permiso` se registra en `Log_Tabla` (`lot`), la tabla que ya configura el trigger de auditoría de la base. Con eso cada cambio de permiso queda con usuario, fecha, columna, valor anterior y valor nuevo, sin crear una tabla de historial paralela. Es para lo que existe ese mecanismo.

---

## 5. `Permiso` (`prm`) — dos columnas nuevas

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `prm_permiso_ambito` | `INT` | NO | FK `Permiso_Ambito` — WEB / APP / AMBOS |
| `prm_asignable_usuario` | `BIT` | NO | DF 0 — **si es 0, no puede otorgarse a una persona** |

`prm_asignable_usuario` es un cierre de seguridad. Sin él, la pantalla de "asignar permisos al técnico" listaría todos los permisos del sistema, incluidos los de administración de clientes o de configuración. Con él, el planificador solo ve los que tienen sentido entregar a una persona en terreno.

Los tres de terreno nacen con `prm_asignable_usuario = 1` y `prm_permiso_ambito = APP`. Todo lo demás nace en `0`.

`prm_permiso_ambito` es lo que permite que la pantalla del planificador muestre solo permisos de la app, y que el token de la API móvil cargue solo esos.

**`Permiso_Ambito` (`pam`)** — catálogo:

| id | `pam_codigo` | `pam_nombre` |
|---:|---|---|
| 1 | `WEB` | Web administrativo |
| 2 | `APP` | Aplicación móvil |
| 3 | `AMBOS` | Web y móvil |

---

## 6. Quién puede otorgar

Un cuarto permiso, porque si no, cualquiera con acceso a la pantalla se auto-habilita:

| `prm_codigo` | `prm_nombre` | Ámbito | Asignable a usuario |
|---|---|---|:--:|
| `ASIGNAR PERMISO TERRENO` | Asignar permisos de terreno | WEB | 0 |
| `CREAR ACTIVO TERRENO` | Crear activo desde terreno | APP | **1** |
| `CREAR COMPONENTE TERRENO` | Crear componente desde terreno | APP | **1** |
| `CREAR REPUESTO TERRENO` | Crear repuesto desde terreno | APP | **1** |

`ASIGNAR PERMISO TERRENO` va al perfil `Planificador de mantenimiento`, **no** a personas — es una atribución del rol, no de un individuo. Y es `asignable_usuario = 0` a propósito: nadie puede otorgarse a sí mismo la facultad de otorgar.

Reglas que el SP `INS_CLIENTE_USUARIO_PERMISO` valida y rechaza con `RAISERROR`:

1. quien otorga tiene `ASIGNAR PERMISO TERRENO` en ese cliente;
2. el permiso que intenta otorgar tiene `prm_asignable_usuario = 1`;
3. el usuario destino está afiliado a ese cliente (`Cliente_Usuario` existe y habilitado);
4. si se indica planta, el usuario destino está autorizado en ella;
5. nadie se otorga permisos a sí mismo.

---

## 7. La función que resuelve el permiso

Una sola, para que la API, los SP y el token no implementen tres versiones distintas que se desincronizan.

```sql
CREATE OR ALTER FUNCTION [dbo].[FNC_USUARIO_TIENE_PERMISO]
(
    @USUARIO        INT,
    @CLIENTE        INT,
    @INSTALACION    INT,            -- NULL = no se evalua alcance de planta
    @PERMISO_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @PERMISO        INT
    DECLARE @CLIENTE_USUARIO INT
    DECLARE @HOY            DATE = CAST(GETDATE() AS DATE)
    DECLARE @POR_PERFIL     BIT = 0
    DECLARE @OTORGADO       BIT
    DECLARE @RESULTADO      BIT = 0

    SELECT @PERMISO = prm_id FROM [dbo].[Permiso]
     WHERE prm_codigo = @PERMISO_CODIGO AND prm_habilitado = 1
    IF @PERMISO IS NULL RETURN 0

    SELECT @CLIENTE_USUARIO = ucl_id FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id_usuario = @USUARIO AND ucl_id_cliente = @CLIENTE AND ISNULL(ucl_habilitado, 0) = 1
    IF @CLIENTE_USUARIO IS NULL RETURN 0

    -- 1. Lo que entrega el perfil dentro de ese cliente
    IF EXISTS (SELECT 1
                 FROM [dbo].[Cliente_Usuario_Perfil] cup
                 JOIN [dbo].[Perfil_Permiso]         ppe ON ppe.ppe_perfil = cup.cup_perfil
                WHERE cup.cup_id_cliente_usuario = @CLIENTE_USUARIO
                  AND ppe.ppe_permiso = @PERMISO)
        SET @POR_PERFIL = 1

    -- 2. La regla de usuario mas especifica: la de la planta gana sobre la global
    SELECT TOP 1 @OTORGADO = cpm.cpm_otorgado
      FROM [dbo].[Cliente_Usuario_Permiso] cpm
     WHERE cpm.cpm_cliente_usuario = @CLIENTE_USUARIO
       AND cpm.cpm_permiso         = @PERMISO
       AND cpm.cpm_habilitado      = 1
       AND (cpm.cpm_cliente_instalacion IS NULL OR cpm.cpm_cliente_instalacion = @INSTALACION)
       AND (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= @HOY)
       AND (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= @HOY)
     ORDER BY CASE WHEN cpm.cpm_cliente_instalacion IS NULL THEN 1 ELSE 0 END

    -- 3. La regla de usuario manda; si no hay, decide el perfil
    SET @RESULTADO = CASE WHEN @OTORGADO IS NOT NULL THEN @OTORGADO ELSE @POR_PERFIL END

    -- 4. Sin autorizacion vigente en la planta no hay permiso que valga
    IF @RESULTADO = 1 AND @INSTALACION IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                        WHERE ciu.ciu_id_usuario     = @USUARIO
                          AND ciu.ciu_id_instalacion = @INSTALACION
                          AND ciu.ciu_habilitado     = 1
                          AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= @HOY)
                          AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= @HOY))
            SET @RESULTADO = 0
    END

    RETURN @RESULTADO
END
GO
```

Dos detalles del `ORDER BY` de la consulta 2, que no son cosméticos:

- **La regla de planta gana sobre la global.** Si Juan tiene `CREAR ACTIVO TERRENO` en todas sus plantas (`instalacion NULL`) pero revocado en Renca (`instalacion = 3, otorgado = 0`), en Renca no crea. Sin ese `ORDER BY`, el resultado dependería del orden físico de las filas.
- **La regla de usuario gana sobre el perfil**, exista o no. Por eso el `CASE WHEN @OTORGADO IS NOT NULL`, no un `OR`.

---

## 8. Cómo se ve en la práctica

```text
El planificador de Hamburgo entra a la ficha de Juan Painen.
Pestaña "Permisos de terreno" — solo aparecen los de ambito APP y asignables.

  [x] Crear componente desde terreno    Planta: Renca      Hasta: 30-09-2026
  [x] Crear repuesto desde terreno      Planta: (todas)    Hasta: (sin vencimiento)
  [ ] Crear activo desde terreno

Guarda. Se escriben dos filas en Cliente_Usuario_Permiso, con
cpm_usuario_creacion = el planificador y cpm_motivo = "levantamiento sala de blowers".

En la app, Juan abre la OT del blower CB01 (planta Renca):
  · el boton [+ Componente] aparece      → FNC_USUARIO_TIENE_PERMISO(...,'CREAR COMPONENTE TERRENO') = 1
  · el boton [+ Activo] no aparece       → 0
  · el repuesto fuera de catalogo se puede crear → 1

El 1 de octubre, sin que nadie haga nada, el boton [+ Componente] desaparece:
cpm_fecha_fin ya paso.
```

La app pide los permisos una vez al iniciar sesión y los guarda en el token. **Pero el `INS_` del servidor vuelve a validar**: el botón oculto es comodidad para el técnico, no seguridad. Nunca se confía en lo que manda Flutter (contexto §68).

---

## 9. Resumen de cambios

| Elemento | Detalle |
|---|---|
| **Tabla nueva** | `Cliente_Usuario_Permiso` (`cpm`) |
| **Catálogo nuevo** | `Permiso_Ambito` (`pam`, 3 valores) |
| **Columnas nuevas** | `Permiso`: `prm_permiso_ambito`, `prm_asignable_usuario` |
| **Permiso nuevo** | `ASIGNAR PERMISO TERRENO` (perfil del planificador, no asignable a persona) |
| **Función nueva** | `FNC_USUARIO_TIENE_PERMISO` — única fuente de verdad |
| **SP nuevos** | `SEL_CLIENTE_USUARIO_PERMISO` · `INS_CLIENTE_USUARIO_PERMISO` · `UPD_CLIENTE_USUARIO_PERMISO` · `DEL_CLIENTE_USUARIO_PERMISO` |
| **Auditoría** | `Cliente_Usuario_Permiso` se registra en `Log_Tabla`, sin tabla de historial propia |
| **Sustituye** | Anexo C §8, donde los tres permisos colgaban del perfil |
| **Registro de prefijos** | 223 → **225**, cero colisiones |

### Lo que no cambia

`Perfil_Permiso` sigue existiendo y sigue siendo el mecanismo normal. Los permisos por usuario son la excepción deliberada, no el reemplazo: si todos los permisos se asignaran persona por persona, dar de alta a un técnico nuevo serían cuarenta clics en vez de elegir un perfil.
