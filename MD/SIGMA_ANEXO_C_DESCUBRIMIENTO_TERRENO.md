# SIGMA — Anexo C (normativo): registro de maestros desde terreno

Cómo se alimenta el maestro de activos, componentes y repuestos **mientras el técnico ejecuta**, sin que la base se llene de basura.

Complementa `SIGMA_MODELO_LOGICO_v2.md`, `ANEXO_A` y `ANEXO_B`. Base: `db_acd593_sigma` · sin datos.

---

## 1. La corrección: no hay confirmación

Mi primera propuesta tenía un estado `PROPUESTO` y un planificador que "confirmaba". **Tu objeción es correcta y la adopto.**

El técnico tiene la máquina abierta. No está *proponiendo* que exista un rodamiento en el lado A: está *reportando* que lo vio. Pedirle a un planificador que confirme desde una oficina un hecho físico que no observó tiene dos problemas:

1. **No puede evaluarlo.** ¿Con qué criterio dice que no? Solo puede aceptar.
2. **Por lo tanto va a aceptar todo, sin mirar.** Y eso es peor que no tener control: convierte un dato sin revisar en un dato "validado". Blanquea el error en vez de atraparlo.

Un estado que todos aprueban siempre no es un control, es una pantalla más.

**Entonces el componente nace real.** Cuenta, se usa, aparece en los reportes, entra al historial y al dataset. No espera a nadie.

Lo que sí queda es un problema distinto, que no es de verdad sino de **forma**:

| Riesgo real | ¿Lo resuelve confirmar? |
|---|---|
| Dos técnicos registran el mismo rodamiento con nombres distintos | No. Se resuelve **fusionando** (§7) |
| Se creó colgando del activo equivocado | No. Se resuelve **corrigiendo el padre** |
| El nombre y el código no siguen la convención de la planta | No. Se resuelve **normalizando** (§6) |
| ¿El componente existe físicamente? | **Esa pregunta ya la respondió quien estaba ahí** |

Ninguno de esos tres requiere bloquear nada. Por eso el modelo registra **de dónde vino** y **si alguien ya lo revisó**, pero **no exige revisión para operar**.

> Es la misma regla del Anexo A §3.3, aplicada a maestros: *un estado que nadie va a evaluar de verdad no debe existir en el catálogo.*

---

## 2. El bloque de descubrimiento

Igual que `AUD-M` y `AUD-A`, se define un bloque estándar. Toda tabla maestra que pueda nacer en terreno agrega **dos columnas**:

```sql
[<pfx>_uuid]                      UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID()   -- UX, idempotencia offline
[<pfx>_registro_descubrimiento]   INT              NULL                       -- FK Registro_Descubrimiento
```

`NULL` en `_registro_descubrimiento` significa "nació en la carga inicial o lo creó el planificador desde la web". No es un caso especial: es lo normal.

Todo el contexto del hallazgo (quién, cuándo, en qué OT, con qué GPS, desde qué dispositivo) vive en **una sola tabla**, no repetido en seis.

### Tablas que lo incorporan

| Tabla | pfx | Qué encuentra el técnico |
|---|:--:|---|
| `Activo` | `act` | Una máquina que no está en SIGMA — con 935 nombres de equipo sueltos en la MATRIZ, va a pasar seguido |
| `Activo_Componente` | `aco` | El rodamiento lado A, el retén, la polea |
| `Activo_Medidor` | `ame` | El horómetro que nadie registró |
| `Activo_Atributo` | `aat` | La placa: 4800 RPM, 24.5 KW, serie 1559766 |
| `Activo_Variable` | `ava` | "A este equipo hay que medirle temperatura" |
| `Repuesto` | `rep` | La pieza que acaba de instalar y no está en el catálogo |

---

## 3. `Registro_Descubrimiento` (`rde`)

Una fila por entidad descubierta. Es el contexto del hallazgo, no la entidad.

| Columna | Tipo | Null | Nota |
|---|---|:--:|---|
| `rde_uuid` | `UNIQUEIDENTIFIER` | NO | DF `NEWID()`, UX — idempotencia del reintento |
| `rde_cliente` | `INT` | NO | FK `Cliente` |
| `rde_cliente_instalacion` | `INT` | NO | dónde estaba parado el técnico |
| `rde_usuario` | `INT` | NO | quién lo encontró |
| `rde_fecha_utc` | `DATETIME` | NO | instante del hallazgo, no de la sincronización |
| `rde_registro_origen` | `INT` | NO | FK `Registro_Origen` — ver Anexo B |
| `rde_orden_trabajo` | `INT` | SÍ | la OT durante la cual apareció |
| `rde_tarea_ocurrencia` | `INT` | SÍ | |
| `rde_checklist_ejecucion` | `INT` | SÍ | |
| `rde_bitacora` | `INT` | SÍ | |
| `rde_dispositivo_uuid` | `UNIQUEIDENTIFIER` | SÍ | qué teléfono lo capturó |
| `rde_latitud` / `rde_longitud` | `DECIMAL(10,7)` | SÍ | dónde |
| `rde_observacion` | `NVARCHAR(500)` | SÍ | "estaba muy caliente al tacto" |
| `rde_usuario_revision` | `INT` | SÍ | **NULL = nadie lo ha mirado todavía** |
| `rde_fecha_revision` | `DATETIME` | SÍ | |
| AUD-A | | | append-only: el hallazgo ocurrió, no se edita |

**`rde_usuario_revision` no es un estado, es un hecho con fecha.** Nada espera a que se complete. Sirve para una sola cosa: que el planificador sepa qué no ha mirado todavía. Por eso son dos columnas y no un catálogo con máquina de estados.

> Coherente con el Anexo A §3.3: si fuera derivable no llevaría columna. No lo es — "el planificador abrió esto y lo dio por bueno" no se deduce de ninguna otra fecha. `<pfx>_fecha_actualizacion` no sirve: se mueve cada vez que el técnico edita algo.

Las cuatro FK de contexto son explícitas y nullable, no un par `tipo_entidad/id_entidad`. Misma decisión que en `Orden_Trabajo` (v2 §8.9) y en las evidencias: la integridad referencial vale más que ahorrar columnas.

---

## 4. Prevenir el duplicado en el origen

**Esta sección importa más que todas las demás juntas.** Fusionar duplicados es caro y manual. No crearlos es gratis y automático.

El duplicado nace cuando dos técnicos escriben texto libre. Así que en terreno **no se escribe texto libre**: se arma el nombre desde catálogos.

```text
La app NO pide:     "Nombre del componente:  ___________________"

La app pide:        Tipo        [ RODAMIENTO      ▾ ]   ← Componente_Tipo (catálogo)
                    Posición    [ LADO A          ▾ ]   ← Componente_Posicion (catálogo)
                    Padre       [ Motor principal ▾ ]   ← componentes ya existentes del activo

Y SIGMA genera:     aco_componente_tipo = 3
                    aco_posicion        = 1
                    aco_nombre          = 'Rodamiento lado A'     ← derivado, no tecleado
                    aco_codigo          = 'CB01-C007'             ← correlativo, no tecleado
```

Con esto, dos técnicos que encuentran el mismo rodamiento producen **la misma fila**, no dos. El duplicado deja de ser un problema de curación y pasa a ser un caso de borde.

Esto obliga a promover `Componente_Posicion` a catálogo — el Anexo A §2.5 lo había dejado como "caso límite, texto por ahora". **Aquí deja de ser límite: es la mitad del nombre.**

**`Componente_Posicion` (`cpn`)** — catálogo, admite filas por cliente:

| id | `cpn_codigo` | `cpn_nombre` |
|---:|---|---|
| 1 | `LADO A` | Lado A |
| 2 | `LADO B` | Lado B |
| 3 | `LADO MOTOR` | Lado motor |
| 4 | `LADO ACOPLE` | Lado acople |
| 5 | `ENTRADA` | Entrada |
| 6 | `SALIDA` | Salida |
| 7 | `SUPERIOR` | Superior |
| 8 | `INFERIOR` | Inferior |
| 9 | `IZQUIERDA` | Izquierda |
| 10 | `DERECHA` | Derecha |
| 11 | `DELANTERO` | Delantero |
| 12 | `TRASERO` | Trasero |
| 13 | `CENTRAL` | Central |
| 14 | `UNICO` | Único |

El único campo de texto libre que ve el técnico es `aco_descripcion`, y es opcional.

### Detección en el momento de crear

Antes de insertar, el SP busca si ya existe:

```sql
-- INS_ACTIVO_COMPONENTE valida antes de crear
IF EXISTS (SELECT 1 FROM Activo_Componente
            WHERE aco_activo            = @ACTIVO
              AND aco_componente_tipo   = @TIPO
              AND ISNULL(aco_componente_posicion, 0) = ISNULL(@POSICION, 0)
              AND ISNULL(aco_componente_padre, 0)    = ISNULL(@PADRE, 0)
              AND aco_habilitado = 1)
BEGIN
    RAISERROR('1.- YA EXISTE UN COMPONENTE CON ESE TIPO Y POSICION EN ESTE ACTIVO.', 16, 1)
    RETURN -1
END
```

Y la app, en vez de mostrar el error, **muestra el componente que ya existe y lo deja seleccionarlo.** El técnico no crea: encuentra. Eso es lo que evita el 90 % de los duplicados.

Se refuerza con un índice único filtrado:

```sql
CREATE UNIQUE NONCLUSTERED INDEX UX_ACO_ACTIVO_TIPO_POSICION
    ON [dbo].[Activo_Componente] ([aco_activo], [aco_componente_tipo], [aco_componente_posicion])
    WHERE [aco_habilitado] = 1 AND [aco_componente_posicion] IS NOT NULL
```

---

## 5. Códigos automáticos

El técnico nunca teclea un código. Se genera con el correlativo del padre:

| Entidad | Patrón | Ejemplo |
|---|---|---|
| `Activo` nuevo en terreno | `<código de la planta>-A<nnn>` | `RENCA-A014` |
| `Activo_Componente` | `<código del activo>-C<nnn>` | `CB01-C007` |
| `Activo_Medidor` | `<código del activo>-M<n>` | `CB01-M1` |
| `Repuesto` | `TMP-<nnnnn>` | `TMP-00042` |

El correlativo se calcula dentro de la transacción del `INS_`, con `MAX(...) + 1` sobre el padre y bajo `UPDLOCK`, no con un `SELECT` previo.

**El código de un repuesto sí conviene renombrarlo después**, cuando Abastecimiento le asigne el suyo. Por eso el prefijo `TMP-`: hace evidente cuál falta. Los demás se quedan como nacieron — un código estable vale más que uno bonito, y `aco_nombre` ya es legible.

---

## 6. Normalizar: qué hace el planificador

No confirma. **Revisa y mejora**, y mientras tanto todo funciona.

Su bandeja es una vista:

```sql
CREATE OR ALTER VIEW [dbo].[VW_DESCUBRIMIENTO_PENDIENTE] AS
SELECT rde.rde_id, rde.rde_cliente, rde.rde_cliente_instalacion,
       'Activo_Componente' AS ENTIDAD, aco.aco_id AS ENTIDAD_ID,
       aco.aco_nombre AS ENTIDAD_NOMBRE, aco.aco_codigo AS ENTIDAD_CODIGO,
       rde.rde_usuario, rde.rde_fecha_utc, rde.rde_orden_trabajo, rde.rde_observacion
FROM   Registro_Descubrimiento rde
JOIN   Activo_Componente       aco ON aco.aco_registro_descubrimiento = rde.rde_id
WHERE  rde.rde_fecha_revision IS NULL
UNION ALL
SELECT rde.rde_id, rde.rde_cliente, rde.rde_cliente_instalacion,
       'Activo', act.act_id, act.act_nombre, act.act_codigo,
       rde.rde_usuario, rde.rde_fecha_utc, rde.rde_orden_trabajo, rde.rde_observacion
FROM   Registro_Descubrimiento rde
JOIN   Activo                  act ON act.act_registro_descubrimiento = rde.rde_id
WHERE  rde.rde_fecha_revision IS NULL
-- ... una rama por cada uno de los 6 maestros
GO
```

Seis ramas escritas una vez, cada una apoyada en un índice sobre `<pfx>_registro_descubrimiento`. Es la alternativa a un puntero polimórfico, y conserva las FK reales.

Al revisar, el planificador puede: renombrar, recodificar, cambiar el padre, completar marca/modelo/serie, **fusionar con otro** (§7), o simplemente marcarlo como visto. Cualquiera de esas acciones escribe `rde_usuario_revision` y `rde_fecha_revision`.

Y se le avisa: `Alerta_Tipo` suma un valor.

| id | `alt_codigo` | `alt_nombre` |
|---:|---|---|
| 8 | `DESCUBRIMIENTO TERRENO` | Registro creado en terreno sin revisar |

---

## 7. Fusionar duplicados sin perder historia

Cuando aparecen dos filas que son la misma cosa, **la perdedora no se borra**. Para ese momento ya tiene mediciones, repuestos instalados, fotos y respuestas de checklist colgando. Borrarla rompe el historial que es todo el punto del sistema.

```text
Activo_Componente 41  "Rodamiento lado A"   ← sobrevive
Activo_Componente 58  "Rodam. A"            ← se absorbe
                                               aco_fusionado_en = 41
                                               aco_habilitado   = 0
```

Y sus hijos se repuntan al superviviente, todo en una transacción:

```sql
-- SP: UPD_ACTIVO_COMPONENTE_FUSIONAR  @ORIGEN, @DESTINO, @MOTIVO, @USUARIO
BEGIN TRANSACTION
    -- 0. Validaciones: mismo cliente, mismo activo, ambos habilitados, origen <> destino
    -- 1. Repuntar los hijos
    UPDATE Activo_Variable                  SET ava_activo_componente = @DESTINO WHERE ava_activo_componente = @ORIGEN
    UPDATE Componente_Repuesto_Instalacion  SET cri_activo_componente = @DESTINO WHERE cri_activo_componente = @ORIGEN
    UPDATE Activo_Medicion                  SET amd_activo_componente = @DESTINO WHERE amd_activo_componente = @ORIGEN
    UPDATE Activo_Medidor                   SET ame_activo_componente = @DESTINO WHERE ame_activo_componente = @ORIGEN
    UPDATE Falla                            SET fal_activo_componente = @DESTINO WHERE fal_activo_componente = @ORIGEN
    UPDATE Bitacora                         SET bit_activo_componente = @DESTINO WHERE bit_activo_componente = @ORIGEN
    UPDATE Orden_Trabajo                    SET otr_activo_componente = @DESTINO WHERE otr_activo_componente = @ORIGEN
    UPDATE Prediccion                       SET pre_activo_componente = @DESTINO WHERE pre_activo_componente = @ORIGEN
    UPDATE Componente_Archivo               SET car_activo_componente = @DESTINO WHERE car_activo_componente = @ORIGEN
    UPDATE Activo_Componente                SET aco_componente_padre  = @DESTINO WHERE aco_componente_padre  = @ORIGEN
    -- ... el SP debe cubrir TODAS las FK hacia Activo_Componente

    -- 2. Marcar la absorbida
    UPDATE Activo_Componente
       SET aco_fusionado_en = @DESTINO, aco_habilitado = 0,
           aco_usuario_actualizacion = @USUARIO, aco_fecha_actualizacion = GETDATE()
     WHERE aco_id = @ORIGEN

    -- 3. Dejar constancia
    INSERT Activo_Componente_Fusion (acf_cliente, acf_componente_origen, acf_componente_destino,
                                     acf_motivo, acf_fecha_utc, acf_usuario_creacion, acf_fecha_creacion)
    VALUES (@CLIENTE, @ORIGEN, @DESTINO, @MOTIVO, GETUTCDATE(), @USUARIO, GETDATE())
COMMIT TRANSACTION
```

**`aco_fusionado_en` es lo que hace la operación reversible y auditable.** Si dentro de un mes se descubre que no eran el mismo rodamiento, la fila 58 sigue ahí con todo su rastro.

Tres tablas de fusión, una por maestro donde el duplicado es plausible:

| Tabla | pfx | Cubre |
|---|:--:|---|
| `Activo_Fusion` | `afu` | dos registros de la misma máquina |
| `Activo_Componente_Fusion` | `acf` | el caso frecuente |
| `Repuesto_Fusion` | `rfu` | el mismo rodamiento SKF cargado dos veces |

Todas append-only: `_cliente`, `_<x>_origen`, `_<x>_destino`, `_motivo NVARCHAR(500)`, `_fecha_utc`, AUD-A.

> No se hace una tabla `Fusion` genérica con `entidad/id`: rompería las FK, que es la línea que este modelo no cruza.

**Regla para las consultas:** todo `SEL_` filtra por `<pfx>_habilitado = 1`, así que las fusionadas desaparecen solas de las pantallas sin necesidad de tocar cada consulta.

---

## 8. Quién puede, y hasta dónde

Crear maestros desde terreno es potente, así que **no se habilita por perfil sino por persona**: el planificador
decide qué técnicos concretos pueden hacerlo, en qué plantas y hasta cuándo.

Tres permisos, otorgados uno a uno:

| `prm_codigo` | Qué habilita |
|---|---|
| `CREAR ACTIVO TERRENO` | registrar una máquina que no existe |
| `CREAR COMPONENTE TERRENO` | registrar componentes, medidores, atributos y variables |
| `CREAR REPUESTO TERRENO` | registrar un repuesto fuera de catálogo |

**El mecanismo completo está en `SIGMA_ANEXO_D_PERMISOS_USUARIO.md`**, que sustituye lo que decía antes esta
sección. En resumen: `Cliente_Usuario_Permiso` (`cpm`) cuelga de la afiliación del usuario al cliente, admite
acotar por planta y por vigencia, y `FNC_USUARIO_TIENE_PERMISO` resuelve el permiso efectivo en un solo lugar.

Además, cuatro límites que valen la pena:

1. **Solo en su planta.** El permiso no basta: el usuario debe estar vigente en `Cliente_Instalacion_Usuario`
   para esa planta. La FK compuesta `(cliente, id)` de v2 §5.3 impide colgar un componente de un activo de otro
   cliente aunque la API se equivoque.
2. **Un nivel por vez.** Un componente nuevo cuelga del activo o de un componente **que ya existía**. Crear tres
   niveles anidados en una sola visita es como se generan árboles inventados.
3. **El activo nuevo exige foto y tipo.** `Activo_Tipo` obligatorio y al menos un `Activo_Archivo`. Un activo
   sin foto ni tipo es un nombre suelto.
4. **Área heredada del contexto.** El activo nuevo nace en la planta y área donde está trabajando el técnico, no
   en una que él elija de una lista completa.

## 9. Offline y reintentos

El técnico va a estar en una sala de blowers sin señal. El flujo tiene que aguantarlo:

1. Flutter genera el `uuid` **en el dispositivo** y crea el componente en su base local.
2. El trabajo continúa: mediciones, repuesto instalado, fotos — todo referenciando ese `uuid` local.
3. Al recuperar señal, sincroniza. La API resuelve `uuid` → `aco_id` y reescribe las referencias.
4. Si el envío se reintenta, el `UX_ACO_UUID` hace que la segunda inserción falle limpio y la API devuelve el id existente. **Un reintento nunca duplica.**

Dos dispositivos distintos que crean "el mismo" componente sí generan dos filas — ahí no hay `uuid` compartido que valga. Eso lo atrapan el índice único filtrado de §4 (si coinciden tipo y posición) o la fusión de §7 (si no).

---

## 10. El caso real, de punta a punta

OT correctiva en el blower CB01. En SIGMA hay un activo y cero componentes.

```text
1. El técnico abre la OT 23180 en Flutter, sin señal.

2. Desarma y encuentra el rodamiento del lado A deteriorado.
   Toca [+ Componente] →  Tipo: RODAMIENTO   Posición: LADO A   Padre: (ninguno)
   SIGMA arma:   nombre 'Rodamiento lado A'   código 'CB01-C001'
                 uuid  a3f1…   registro_descubrimiento → rde (origen TERRENO ORDEN TRABAJO, OT 23180)

3. En el mismo minuto, sobre ese componente:
   · mide temperatura 78,4 °C           → Activo_Medicion
   · registra el retiro del rodamiento  → Componente_Repuesto_Instalacion (motivo FALLA, cri_fallo = 1)
   · el repuesto SKF 6312-C3 no está en catálogo → lo crea, código TMP-00042
   · instala el nuevo                   → segunda fila de Componente_Repuesto_Instalacion
   · dos fotos antes y después          → Componente_Archivo
   · lee el horómetro 9.012 h — no había medidor → lo crea, código CB01-M1

4. Sale de la sala, sincroniza. Cuatro maestros nuevos, todos con su rde.

5. El planificador ve 4 registros en su bandeja al día siguiente.
   Renombra 'TMP-00042' a 'ROD-6312C3' con el código de Abastecimiento.
   Los otros tres los deja como están y marca revisado.

6. Tres meses después, el rodamiento vuelve a fallar.
   El historial de 'Rodamiento lado A' ya tiene: vida real 2.104 h, una falla previa,
   temperatura de 78,4 °C el día del cambio, dos fotos y el lote del repuesto.
   Eso es una fila del dataset de entrenamiento — y no existiría si el técnico
   hubiera tenido que esperar a que alguien confirmara el componente.
```

El paso 6 es el argumento entero. Sin este mecanismo, el paso 3 se habría escrito así en `otr_resultado`:

```text
"Se cambió rodamiento lado A del blower 1, estaba caliente."
```

Y no se puede entrenar nada con eso.

---

## 11. Qué NO se bloquea, y qué sí

**No se bloquea nada por falta de revisión.** Un componente creado en terreno y nunca revisado:

- recibe mediciones, repuestos, fallas, evidencias y OT;
- aparece en el historial del activo y en los KPI;
- **entra al dataset de ML**, porque su existencia física está atestiguada por quien estaba ahí.

Lo único que no puede hacer, y no es por desconfianza sino por consistencia de versión:

| Restricción | Por qué |
|---|---|
| No se agrega a una `Plan_Mantenimiento_Version` ya **publicada** | Una versión publicada es inmutable (v2 §5.19). Va en la versión siguiente — vale para cualquier componente, no solo los de terreno |
| Una fila **fusionada** (`aco_fusionado_en IS NOT NULL`) no recibe registros nuevos | Su historia ya está en el superviviente |

---

## 12. Resumen de cambios

| Elemento | Detalle |
|---|---|
| **Tablas nuevas (4)** | `Registro_Descubrimiento` (`rde`) · `Activo_Fusion` (`afu`) · `Activo_Componente_Fusion` (`acf`) · `Repuesto_Fusion` (`rfu`) |
| **Catálogos nuevos (2)** | `Registro_Origen` (`ror`, 8 valores) · `Componente_Posicion` (`cpn`, 14 valores) |
| **Columnas agregadas** | `<pfx>_uuid` y `<pfx>_registro_descubrimiento` en `Activo`, `Activo_Componente`, `Activo_Medidor`, `Activo_Atributo`, `Activo_Variable`, `Repuesto`; `<pfx>_fusionado_en` en los tres maestros fusionables; `aco_componente_posicion` FK reemplaza a `aco_posicion NVARCHAR(100)` |
| **Índices** | `UX_<PFX>_UUID` en los seis maestros · `IX_<PFX>_REGISTRO_DESCUBRIMIENTO` en los seis · `UX_ACO_ACTIVO_TIPO_POSICION` filtrado |
| **Vista** | `VW_DESCUBRIMIENTO_PENDIENTE` |
| **Permisos** | `CREAR ACTIVO TERRENO` · `CREAR COMPONENTE TERRENO` · `CREAR REPUESTO TERRENO`, otorgados **por usuario** (Anexo D) |
| **Alerta** | `DESCUBRIMIENTO TERRENO` |
| **SP nuevos** | `UPD_ACTIVO_COMPONENTE_FUSIONAR` · `UPD_ACTIVO_FUSIONAR` · `UPD_REPUESTO_FUSIONAR` · `UPD_REGISTRO_DESCUBRIMIENTO_REVISAR` |
| **Descartado** | El estado `PROPUESTO` y todo el flujo de confirmación (§1) |
| **Registro de prefijos** | 217 → **223**, cero colisiones |

### Corrige al Anexo A

| Sección | Cambio |
|---|---|
| §2.5, `aco_posicion` "caso límite, texto por ahora" | **Resuelto**: pasa a catálogo `Componente_Posicion`, porque forma parte del nombre generado (§4) |
| §2.3, catálogos | Suman `Registro_Origen` y `Componente_Posicion` → **65 catálogos** |
