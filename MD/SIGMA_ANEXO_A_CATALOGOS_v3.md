# SIGMA — Anexo A (normativo): catálogos, esquema real verificado y correcciones v3

Complementa `SIGMA_MODELO_LOGICO_v2.md`. **Donde este anexo difiera de v2, manda este anexo.**

Base: `db_acd593_sigma` · DDL real verificado el 19-08-2026 · **sin datos productivos**

---

## 0. Los tres hechos nuevos que cambian el diseño

| Hecho | Consecuencia |
|---|---|
| **Tengo el DDL real** | 34 tablas verificadas, de las cuales **9 se eliminan**. Dos supuestos de v2 se confirman, seis se corrigen y aparecen **dos colisiones de prefijo** que v2 no podía ver. |
| **No hay datos en SQL** | La estrategia de "congelar y migrar en paralelo" (v2 §17) **se descarta**. El checklist legado se elimina con `DROP TABLE`. Las tablas heredadas se **corrigen**, no se parchean con columnas deprecadas. Es la ventana más barata que va a existir. |
| **Regla dura: ningún valor enumerable como texto** | 38 catálogos nuevos. Toda columna `NVARCHAR` que hoy contenga un conjunto cerrado de valores pasa a `INT` + FK. |

---

## 1. Verificación contra el DDL real

### 1.1 Supuestos de v2 que se **confirman**

| Supuesto v2 | Evidencia en el DDL |
|---|---|
| El nombre de la base es `db_acd593_sigma` | `USE [db_acd593_sigma]` |
| **§75 — `cup_id_perfil` apunta a `Usuario_Perfil`, no a un perfil** | `CONSTRAINT [FK_Cliente_Usuario_Perfil_Usuario_Perfil] FOREIGN KEY([cup_id_perfil]) REFERENCES [dbo].[Usuario_Perfil] ([upe_id])` — el diagnóstico de v2 §5.16 era correcto |
| **§74 — hay dos tablas para lo mismo** | `Cliente_Instalacion_Usuario` y `Usuario_Instalacion` referencian ambas `Cliente_Instalacion` + `Usuario`. Duplicación confirmada |
| El catálogo de países ya existe con prefijo `pai` | `Paises` — **no se crea `Pais`** |

### 1.2 Supuestos de v2 que se **corrigen**

Seis prefijos que v2 dedujo por el nombre de la tabla y en la base son otros:

| Tabla | v2 asumió | **Real** |
|---|:--:|:--:|
| `Cliente_Usuario` | `cus` | **`ucl`** |
| `Menus` | `men` | **`mnu`** |
| `Modulos_Sistema` | `mos` | **`mds`** |
| `Sys_Parametros` | `sys` | **`par`** |
| `Sis_Excepcion` | `sie` | **`lge`** |
| `Perfil` (nombre de tabla) | `Perfil` | **`Perfiles`**, prefijo `per` |

### 1.3 Colisiones de prefijo que solo el DDL real revela

| Prefijo | Ocupado por (real) | Tabla de v2 que lo pedía | **Nuevo prefijo** |
|:--:|---|---|:--:|
| `per` | `Perfiles` | `Permiso` | **`prm`** |
| `par` | `Sys_Parametros` | `Plan_Actividad_Repuesto` | **`pra`** |

Sin el DDL, ambos `CREATE TABLE` habrían pasado (SQL Server no valida prefijos) y la base habría quedado con dos semánticas distintas bajo el mismo prefijo — el problema exacto que `PATRON_TABLAS.md` §1.2 intenta evitar.

### 1.4 Tablas existentes que v2 no conocía

| Tabla | pfx | Qué es | Impacto en el modelo |
|---|:--:|---|---|
| `Log_Tabla` | `lot` | **configura qué tablas audita el trigger `Log`** | Cada tabla nueva del modelo debe registrarse aquí si se quiere auditoría de columnas |
| `Log_Estado` | `loe` | catálogo de estados de log | **Tabla huérfana: `Log` no tiene FK hacia ella.** Ver §3.5 |
| `Usuario_Paises` | `upa` | países visibles por usuario | Es el mecanismo multipaís existente. `Zona_Horaria` lo complementa, no lo reemplaza |
| `Cliente_App_Instalacion` | `cai` | apps habilitadas por instalación | SIGMA sería una fila aquí |
| `Tipo_Perfil` | `tpp` | clasificación de perfiles | `Perfiles.per_tipo` → aquí. Sirve para distinguir perfiles web de perfiles móviles |
| `Privacidad_Modulos_Sistema` | `pms` | textos de privacidad por módulo | Sin impacto |

### 1.5 Defectos del esquema actual — corregibles **ahora** porque no hay datos

| # | Defecto | Evidencia | Corrección |
|---|---|---|---|
| **A-01** | `Cliente_Usuario_Perfil.cup_id_perfil` → `Usuario_Perfil.upe_id` | FK real | `DROP` de la FK, renombrar a `cup_perfil` y apuntar a `Perfiles.per_id` (§5) |
| **A-02** | `Usuario_Instalacion` duplica `Cliente_Instalacion_Usuario` | ambas FK a `Cliente_Instalacion`+`Usuario` | **`DROP TABLE [Usuario_Instalacion]`** |
| **A-03** | `Cliente_Instalacion_Usuario` **no tiene `habilitado`** — solo `usuario_creacion`/`fecha_creacion` | DDL | No hay forma de revocar acceso a una planta salvo borrando la fila, y se pierde el rastro. Agregar `ciu_habilitado`, `ciu_fecha_inicio`, `ciu_fecha_fin` y el bloque de actualización |
| **A-04** | `Cliente_Instalacion_Usuario` no tiene el cliente | DDL | Sin `ciu_cliente` no se puede aplicar la FK compuesta de v2 §5.3. Agregar `ciu_cliente NOT NULL` |
| **A-05** | `Cliente_Instalacion.cin_cliente` es **NULL-able** | DDL | Una planta sin cliente no existe. `NOT NULL` |
| **A-06** | Ni `Cliente_Usuario`, ni `Usuario_Perfil`, ni `Cliente_Instalacion_Usuario` tienen índice único sobre su par | DDL | Nada impide afiliar dos veces al mismo usuario al mismo cliente. Agregar `UX_` en las tres |
| **A-07** | `Cliente.cli_logo VARBINARY(MAX)` y `Usuario.usu_foto VARBINARY(MAX)` **dentro de la tabla maestra** | DDL | Contradice el patrón (§3.1: binario en `<Entidad>_Binario`) y su propio precedente (`Usuario_Foto`). Mover a `Cliente_Binario`; `usu_foto` ya tiene `Usuario_Foto`, se elimina la columna |
| **A-08** | `Marcacion` y `Marcacion_Binario` son control de asistencia, ajeno al alcance de SIGMA — y además `Marcacion` tiene 5 columnas `INT` que son catálogos sin tabla (`mar_tipo_marcacion`, `mar_gps`, `mar_modo_hora_dispositivo`, `mar_hora_dispositivo_servidor`, `mar_auto_manual`) | DDL | **`DROP TABLE`** de ambas (§4). Se descarta el módulo completo en vez de arrastrar cinco números mágicos que hoy nadie puede explicar |
| **A-09** | `Paises.pai_suma_resta VARCHAR(1)` + `pai_hora INT` como zona horaria | DDL | Un signo guardado como texto y un offset entero no soportan horario de verano ni IANA. Lo reemplaza `Zona_Horaria` a nivel de `Cliente_Instalacion` (v2 §2.1). `Paises` conserva sus columnas para no romper `FNC_PAIS_HORA` |
| **A-10** | Todo el esquema usa `VARCHAR`; el patrón pide `NVARCHAR` para tablas nuevas | DDL | Las tablas nuevas usan `NVARCHAR`. Las uniones son por `INT`, así que no hay conversión implícita en índices. Único punto de atención: `Sys_Parametros.par_codigo VARCHAR(50)` si alguna tabla nueva se relacionara por ese texto — no ocurre en este modelo |
| **A-11** | `Checklist_Tipo` (`ckt`) es huérfana: nadie la referencia, `ckt_id` no es `IDENTITY`, `ckt_nombre VARCHAR(2000)` | DDL | Se elimina con el resto del checklist legado |
| **A-12** | `Menus.mnu_padre INT NOT NULL` sin FK a sí misma | DDL | Jerarquía sin integridad. Fuera del alcance de SIGMA, se deja anotado |

> **A-03 y A-04 son bloqueantes**: sin ellas no se puede implementar ni la vigencia del técnico en la planta (v2 §5.17) ni el aislamiento multicliente por FK compuesta (v2 §5.3).

---

## 2. Regla dura: ningún valor enumerable como texto

### 2.1 El criterio

No todo `NVARCHAR` es un error. La regla separa tres cosas:

| Va a **catálogo** (`INT` + FK) | Se queda como **texto** | Se queda como **BIT** |
|---|---|---|
| Conjunto **cerrado y conocido** de valores que el negocio nombra: `SEMANAL`, `CRITICO`, `FALLA`, `ANTES`, `MECANICO` | Prosa libre: nombre, descripción, observación, instrucción, comentario, resultado narrado | Sí/no genuino, sin tercer valor posible: `habilitado`, `obligatorio`, `requiere_parada` |
| Cualquier valor que aparezca en un `WHERE`, un filtro de pantalla, un `GROUP BY` o un KPI | Identificadores externos: número de serie, N° de factura, código de OC, token, hash | |
| Cualquier valor que el usuario elija de un desplegable | Expresiones técnicas: regex de validación, ruta de blob, MIME | |

**La prueba práctica:** si alguien pudiera escribirlo con una falta de ortografía y romper un reporte, es un catálogo. La MATRIZ de Hamburgo tiene `Preventivo Programdo`, `Coorectivo Programado` y `Preventivo Ptogramado` — 24 escrituras para 4 conceptos. Esa es la prueba, con datos.

### 2.2 Estructura estándar de un catálogo

Todos idénticos, para que el generador de código los trate igual:

```sql
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[<Catalogo>]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[<Catalogo>]
    (
        [<pfx>_id]          INT             NOT NULL IDENTITY(1,1),
        [<pfx>_codigo]      NVARCHAR(50)    NOT NULL,   -- estable, para el codigo
        [<pfx>_nombre]      NVARCHAR(100)   NOT NULL,   -- visible, traducible
        [<pfx>_orden]       INT             NULL,
        [<pfx>_habilitado]  BIT             NOT NULL CONSTRAINT DF_<PFX>_HABILITADO DEFAULT 1,

        CONSTRAINT PK_<CATALOGO> PRIMARY KEY CLUSTERED ([<pfx>_id] ASC),
        CONSTRAINT UX_<PFX>_CODIGO UNIQUE ([<pfx>_codigo])
    )
    PRINT 'Tabla <Catalogo> creada correctamente.'
END
ELSE
    PRINT 'Tabla <Catalogo> ya existe.'
GO

SET IDENTITY_INSERT [dbo].[<Catalogo>] ON
IF NOT EXISTS (SELECT 1 FROM [<Catalogo>] WHERE <pfx>_id = 1)
    INSERT INTO [<Catalogo>] (<pfx>_id, <pfx>_codigo, <pfx>_nombre, <pfx>_orden) VALUES (1, 'CODIGO', 'Nombre', 1)
-- ... una linea por valor, idempotente
SET IDENTITY_INSERT [dbo].[<Catalogo>] OFF
GO
```

**Por qué `codigo` además de `nombre`:** el `nombre` es lo que ve el usuario y puede cambiar ("Crítica" → "Prioridad 1") o traducirse. El `codigo` es lo que el equipo usa al leer la base y no cambia nunca. **Ninguno de los dos se compara en los SP ni en C#: ahí siempre se usa el `id`.**

### 2.3 Los 38 catálogos nuevos

> **Los valores definitivos de carga están en `SIGMA_ANEXO_B_CATALOGOS_CARGA_INICIAL.md`**, que cubre los 63 catálogos del modelo (estos 38 más los 25 que ya venían de v2) y aplica la regla de escritura sin guion bajo. Los códigos que aparecen abajo son orientativos; los normativos son los del Anexo B.

#### Transversales (11) — se usan desde varios dominios

| Catálogo | pfx | Valores (id: CODIGO) |
|---|:--:|---|
| `Dia_Semana` | `dse` | 1 LUNES · 2 MARTES · 3 MIERCOLES · 4 JUEVES · 5 VIERNES · 6 SABADO · 7 DOMINGO |
| `Frecuencia_Tipo` | `fre` | 1 DIARIA · 2 SEMANAL · 3 MENSUAL · 4 ANUAL |
| `Unidad_Tiempo` | `uti` | 1 MINUTO · 2 HORA · 3 DIA · 4 SEMANA · 5 MES · 6 ANIO |
| `Operador_Comparacion` | `opc` | 1 IGUAL · 2 DISTINTO · 3 MAYOR · 4 MAYOR_IGUAL · 5 MENOR · 6 MENOR_IGUAL · 7 ENTRE · 8 CONTIENE |
| `Severidad` | `sev` | 1 NORMAL · 2 BAJA · 3 ADVERTENCIA · 4 ALTA · 5 CRITICA |
| `Tipo_Dato` | `tda` | 1 TEXTO · 2 ENTERO · 3 DECIMAL · 4 BIT · 5 FECHA · 6 FECHA_HORA · 7 HORA |
| `Magnitud` | `mag` | 1 TEMPERATURA · 2 VIBRACION · 3 PRESION · 4 VELOCIDAD_ROTACION · 5 CORRIENTE · 6 VOLTAJE · 7 CAUDAL · 8 HUMEDAD · 9 TIEMPO · 10 CONTEO · 11 LONGITUD · 12 MASA · 13 VOLUMEN · 14 POTENCIA · 15 ADIMENSIONAL |
| `Moneda` | `mon` | 1 CLP · 2 USD · 3 EUR · 4 UF |
| `Criticidad_Nivel` | `crn` | 1 BAJA · 2 MEDIA · 3 ALTA · 4 CRITICA |
| `Momento_Ejecucion` | `moe` | 1 ANTES · 2 DURANTE · 3 DESPUES |
| `Proceso_Estado` | `pes` | 1 PENDIENTE · 2 EN_PROCESO · 3 PROCESADO · 4 ERROR · 5 CANCELADO |

> **`Proceso_Estado` es la única excepción a "un catálogo por entidad"** (§3.2). Lo comparten cinco procesos asíncronos con ciclo de vida idéntico — transcripción de audio, análisis visual, entrenamiento, dataset e importación — que no son entidades de negocio sino trabajos en cola. Está documentado a propósito para que no se replique el argumento en otros casos.

#### Organización y activos (5)

| Catálogo | pfx | Valores |
|---|:--:|---|
| `Instalacion_Area_Tipo` | `iat` | 1 AREA · 2 SUBAREA · 3 LINEA_PRODUCCION · 4 SALA · 5 ZONA_EXTERIOR |
| `Especialidad_Nivel` | `enl` | 1 BASICO · 2 INTERMEDIO · 3 EXPERTO |
| `Componente_Tipo` | `cto` | 1 MOTOR · 2 REDUCTOR · 3 RODAMIENTO · 4 ACOPLE · 5 CORREA · 6 CADENA · 7 BOMBA · 8 VALVULA · 9 SENSOR · 10 TABLERO · 11 FILTRO · 12 RETEN · 13 POLEA · 14 OTRO |
| `Activo_Posicion_Motivo` | `apm` | 1 INSTALACION_INICIAL · 2 REEMPLAZO · 3 RESPALDO_TEMPORAL · 4 OVERHAUL · 5 BAJA · 6 TRASLADO |
| `Activo_Componente_Estado` | `ace` | 1 OPERATIVO · 2 CON_OBSERVACION · 3 DEGRADADO · 4 FUERA_DE_SERVICIO · 5 RETIRADO |

> `Componente_Tipo` y `Especialidad` admiten filas por cliente (`_cliente NULL` = global). Un catálogo cerrado a nivel de producto y extensible por cliente es lo que permite que SIGMA sirva a una panificadora y a una minera sin tocar el código.

#### Repuestos e inventario (3)

| Catálogo | pfx | Valores |
|---|:--:|---|
| `Repuesto_Retiro_Motivo` | `rrm` | 1 FALLA · 2 DESGASTE · 3 PREVENTIVO · 4 MEJORA · 5 DANO_EXTERNO · 6 OBSOLESCENCIA · 7 OTRO |
| `Repuesto_Estado_Final` | `ref` | 1 BUENO · 2 DESGASTE_LEVE · 3 DESGASTE_MODERADO · 4 DESGASTE_SEVERO · 5 ROTO · 6 CORROIDO · 7 NO_EVALUADO |
| `Inventario_Movimiento_Tipo` | `imt` | 1 INGRESO_COMPRA · 2 SALIDA_CONSUMO · 3 DEVOLUCION · 4 AJUSTE_POSITIVO · 5 AJUSTE_NEGATIVO · 6 TRASLADO_SALIDA · 7 TRASLADO_INGRESO · 8 MERMA |

> **`Repuesto_Retiro_Motivo` es la columna más importante de todo el modelo para machine learning.** Es la que separa una falla de un reemplazo preventivo, y por lo tanto la que decide si un caso entra al dataset como evento o como dato censurado (v2 §11.3). Que sea un catálogo con id fijo, y no texto, es la diferencia entre poder entrenar y no poder.

#### Checklist y asignación (3)

| Catálogo | pfx | Valores |
|---|:--:|---|
| `Cumplimiento_Politica` | `cpo` | 1 UNO · 2 TODOS · 3 MINIMO |
| `Responsabilidad_Tipo` | `rst` | 1 RESPONSABLE · 2 EJECUTOR · 3 CANDIDATO · 4 APOYO · 5 SUPERVISOR |
| `Dependencia_Accion` | `dac` | 1 MOSTRAR · 2 OCULTAR · 3 REQUERIR · 4 BLOQUEAR |

#### Órdenes de trabajo y fallas (7)

| Catálogo | pfx | Valores |
|---|:--:|---|
| `Rol_Ejecucion` | `rej` | 1 EJECUTOR_PRINCIPAL · 2 APOYO · 3 SUPERVISOR · 4 OBSERVADOR |
| `Validacion_Tipo` | `vat` | 1 ACEPTACION · 2 VALIDACION · 3 EJECUCION — **las tres firmas de la OT 23074** |
| `Servicio_Tipo` | `sti` | 1 SERVICIO_TECNICO · 2 ARRIENDO_EQUIPO · 3 MONTAJE · 4 DESMONTAJE · 5 MANO_OBRA_EXTERNA · 6 REPUESTO · 7 TRANSPORTE · 8 CALIBRACION |
| `Resultado_Paso` | `rpa` | 1 CONFORME · 2 NO_CONFORME · 3 NO_APLICA · 4 PENDIENTE |
| `Indisponibilidad_Motivo` | `inm` | 1 MANTENIMIENTO_PLANIFICADO · 2 FALLA · 3 ESPERA_REPUESTO · 4 ESPERA_TECNICO · 5 CAUSA_EXTERNA · 6 PARADA_PRODUCCION |
| `Permiso_Trabajo_Estado` | `pte` | 1 SOLICITADO · 2 AUTORIZADO · 3 RECHAZADO · 4 VENCIDO · 5 CERRADO |
| `Diagnostico_Metodo` | `dme` | 1 INSPECCION_VISUAL · 2 MEDICION · 3 ANALISIS_VIBRACION · 4 TERMOGRAFIA · 5 ANALISIS_ACEITE · 6 ULTRASONIDO · 7 DESARME · 8 HISTORIAL · 9 ANALISIS_IA |

> Los valores de `Servicio_Tipo` no son inventados: salen uno a uno de la hoja *Compras relacionadas* del plan de Blowers — "Arriendo de equipo para backup", "Desmontaje de blower N°3", "Montaje de blower N°3", "HH mantención blower día no hábil", "Servicio técnico de mantención".

#### Archivos, alertas, ML e importación (9)

| Catálogo | pfx | Valores |
|---|:--:|---|
| `Archivo_Antivirus_Estado` | `aae` | 1 PENDIENTE · 2 LIMPIO · 3 INFECTADO · 4 ERROR |
| `Archivo_Carga_Estado` | `acs` | 1 INICIADA · 2 EN_CURSO · 3 COMPLETADA · 4 EXPIRADA · 5 CANCELADA |
| `Alerta_Estado` | `aet` | 1 NUEVA · 2 RECONOCIDA · 3 EN_GESTION · 4 RESUELTA · 5 DESCARTADA |
| `Modelo_Objetivo` | `mob` | 1 PROBABILIDAD_FALLA · 2 VIDA_UTIL_RESTANTE · 3 DETECCION_ANOMALIA · 4 CLASIFICACION_VISUAL |
| `Modelo_Formato` | `mfo` | 1 ONNX · 2 PICKLE · 3 PMML · 4 SAVEDMODEL |
| `Nivel_Riesgo` | `nri` | 1 BAJO · 2 MEDIO · 3 ALTO · 4 CRITICO |
| `Prediccion_Estado` | `pde` | 1 GENERADA · 2 REVISADA · 3 ACEPTADA · 4 DESCARTADA · 5 MATERIALIZADA |
| `Caracteristica_Tipo` | `ctm` | 1 NUMERICA · 2 CATEGORICA · 3 BINARIA · 4 TEMPORAL · 5 DERIVADA |
| `Importacion_Tipo` | `iti` | 1 MATRIZ_OT · 2 PLAN_ANUAL · 3 ACTIVOS · 4 REPUESTOS · 5 LECTURAS_MEDIDOR · 6 MEDICIONES |
| `Importacion_Celda_Estado` | `ice` | 1 OK · 2 AMBIGUO · 3 ERROR · 4 IGNORADO |

### 2.4 Tabla de conversión: columna de v2 → catálogo de v3

Toda fila de esta tabla es un `NVARCHAR` de v2 que **deja de existir** y se reemplaza por `INT NOT NULL` + `CONSTRAINT FK_<PFX>_<CATALOGO>`.

| Tabla | Columna v2 (texto) | Columna v3 (FK) | Catálogo |
|---|---|---|---|
| `Programacion_Calendario` | `pca_frecuencia` | `pca_frecuencia_tipo` | `Frecuencia_Tipo` |
| `Programacion_Calendario_Dia` | `pcd_dia_semana INT` (1–7 sin FK) | `pcd_dia_semana` | `Dia_Semana` |
| `Programacion_Intervalo` | `pin_unidad_tiempo` | `pin_unidad_tiempo` | `Unidad_Tiempo` |
| `Programacion_Condicion` | `pco_operador` | `pco_operador_comparacion` | `Operador_Comparacion` |
| `Programacion_Condicion` | `pco_severidad` | `pco_severidad` | `Severidad` |
| `Instalacion_Area` | `iar_tipo` | `iar_instalacion_area_tipo` | `Instalacion_Area_Tipo` |
| `Activo` | `act_criticidad INT` (1–4 sin FK) | `act_criticidad_nivel` | `Criticidad_Nivel` |
| `Activo_Componente` | `aco_tipo` | `aco_componente_tipo` | `Componente_Tipo` |
| `Activo_Componente` | `aco_criticidad INT` | `aco_criticidad_nivel` | `Criticidad_Nivel` |
| `Activo_Posicion_Historial` | `aph_motivo` | `aph_activo_posicion_motivo` | `Activo_Posicion_Motivo` |
| `Atributo_Tecnico` | `ate_tipo_dato` | `ate_tipo_dato` | `Tipo_Dato` |
| `Variable_Medicion` | `vme_tipo_dato` | `vme_tipo_dato` | `Tipo_Dato` |
| `Unidad_Medida` | `ume_magnitud` | `ume_magnitud` | `Magnitud` |
| `Usuario_Especialidad` | `ues_nivel` | `ues_especialidad_nivel` | `Especialidad_Nivel` |
| `Componente_Repuesto_Instalacion` | `cri_motivo_retiro` | `cri_repuesto_retiro_motivo` | `Repuesto_Retiro_Motivo` |
| `Componente_Repuesto_Instalacion` | `cri_estado_final` | `cri_repuesto_estado_final` | `Repuesto_Estado_Final` |
| `Inventario_Movimiento` | `imo_tipo` | `imo_inventario_movimiento_tipo` | `Inventario_Movimiento_Tipo` |
| `Checklist_Programacion` | `cpr_politica` | `cpr_cumplimiento_politica` | `Cumplimiento_Politica` |
| `Checklist_Ocurrencia_Asignacion` | `coa_tipo_responsabilidad` | `coa_responsabilidad_tipo` | `Responsabilidad_Tipo` |
| `Tarea_Ocurrencia_Asignacion` | `toa_tipo` | `toa_responsabilidad_tipo` | `Responsabilidad_Tipo` |
| `Checklist_Item_Dependencia` | `cid_operador` | `cid_operador_comparacion` | `Operador_Comparacion` |
| `Checklist_Item_Dependencia` | `cid_accion` | `cid_dependencia_accion` | `Dependencia_Accion` |
| `Checklist_Item_Opcion` | `cio_severidad` | `cio_severidad` | `Severidad` |
| `Checklist_Ejecucion_Respuesta` | `cer_severidad` | `cer_severidad` | `Severidad` |
| `Checklist_Hallazgo` | `cha_severidad` | `cha_severidad` | `Severidad` |
| `Plan_Actividad_Checklist` | `pck_momento` | `pck_momento_ejecucion` | `Momento_Ejecucion` |
| `Tarea_Checklist` | `tck_momento` | `tck_momento_ejecucion` | `Momento_Ejecucion` |
| `Orden_Trabajo_Checklist` | `otc_momento` | `otc_momento_ejecucion` | `Momento_Ejecucion` |
| `Orden_Trabajo_Asignacion` | `ota_rol_ejecucion` | `ota_rol_ejecucion` | `Rol_Ejecucion` |
| `Orden_Trabajo_Validacion` | `otv_tipo` | `otv_validacion_tipo` | `Validacion_Tipo` |
| `Orden_Trabajo_Paso` | `otp_resultado` | `otp_resultado_paso` | `Resultado_Paso` |
| `Orden_Trabajo_Servicio` | `ots_tipo` | `ots_servicio_tipo` | `Servicio_Tipo` |
| `Orden_Trabajo_Servicio` | `ots_moneda` | `ots_moneda` | `Moneda` |
| `Activo_Indisponibilidad` | `ain_motivo` | `ain_indisponibilidad_motivo` | `Indisponibilidad_Motivo` |
| `Permiso_Trabajo` | `ptr_estado` | `ptr_permiso_trabajo_estado` | `Permiso_Trabajo_Estado` |
| `Falla` | `fal_severidad` | `fal_severidad` | `Severidad` |
| `Falla_Diagnostico` | `fdi_metodo` | `fdi_diagnostico_metodo` | `Diagnostico_Metodo` |
| `Archivo` | `arc_estado_antivirus` | `arc_archivo_antivirus_estado` | `Archivo_Antivirus_Estado` |
| `Archivo_Carga` | `acg_estado` | `acg_archivo_carga_estado` | `Archivo_Carga_Estado` |
| `Archivo_Transcripcion` | `atr_estado` | `atr_proceso_estado` | `Proceso_Estado` |
| `Archivo_Analisis_Visual` | `aav_estado` | `aav_proceso_estado` | `Proceso_Estado` |
| `Analisis_Visual_Deteccion` | `avd_severidad` | `avd_severidad` | `Severidad` |
| `Alerta` | `ale_estado` | `ale_alerta_estado` | `Alerta_Estado` |
| `Alerta` | `ale_severidad` | `ale_severidad` | `Severidad` |
| `Modelo_Predictivo` | `mpr_objetivo` | `mpr_modelo_objetivo` | `Modelo_Objetivo` |
| `Modelo_Predictivo_Version` | `mpv_formato` | `mpv_modelo_formato` | `Modelo_Formato` |
| `Prediccion` | `pre_nivel_riesgo` | `pre_nivel_riesgo` | `Nivel_Riesgo` |
| `Prediccion` | `pre_estado` | `pre_prediccion_estado` | `Prediccion_Estado` |
| `Caracteristica_Modelo` | `cmo_tipo` | `cmo_caracteristica_tipo` | `Caracteristica_Tipo` |
| `Dataset_Entrenamiento` | `den_estado` | `den_proceso_estado` | `Proceso_Estado` |
| `Entrenamiento_Ejecucion` | `eej_resultado` | `eej_proceso_estado` | `Proceso_Estado` |
| `Importacion_Carga` | `ica_tipo` | `ica_importacion_tipo` | `Importacion_Tipo` |
| `Importacion_Carga` | `ica_estado` | `ica_proceso_estado` | `Proceso_Estado` |
| `Importacion_Carga_Celda` | `icc_estado` | `icc_importacion_celda_estado` | `Importacion_Celda_Estado` |
| `Repuesto_Lote` | `rlo_...` | sin cambio | — |

**Total: 53 columnas de texto convertidas a FK.**

### 2.5 Columnas que se quedan como texto, y por qué

Para que no quede duda de dónde está la frontera:

| Columna | Tipo | Por qué NO es catálogo |
|---|---|---|
| `act_numero_serie`, `rlo_numero_serie` | `NVARCHAR(100)` | Identificador externo del fabricante. `1559766`, `S682730` — no es un conjunto cerrado |
| `arc_tipo_mime` | `NVARCHAR(100)` | Estándar IANA con cientos de valores; se valida en la API contra una lista blanca, no en la base |
| `civ_expresion_regular` | `NVARCHAR(500)` | Es código, no un valor de dominio |
| `arc_nombre_blob`, `arc_contenedor`, `arc_hash_sha256` | `NVARCHAR` | Rutas e identificadores técnicos |
| `otr_resultado`, `paa_descripcion`, `bit_descripcion`, `atr_texto` | `NVARCHAR(MAX)` | Prosa escrita por una persona |
| `ots_documento_referencia` | `NVARCHAR(100)` | N° de OC o factura del ERP |
| `prv_giro` | `NVARCHAR(200)` | Texto declarado por el proveedor |
| `aco_posicion` | `NVARCHAR(100)` | "lado A", "lado motor", "entrada" — **caso límite**: si se estabiliza en menos de 20 valores, conviértalo en catálogo `Componente_Posicion` en fase 2 |

---

## 3. Los estados: qué pienso

Me preguntaste directamente por el estatus. Respondo en dos partes: qué encontré en los datos, y qué criterio propongo para el modelo.

### 3.1 Qué encontré en el Excel

Fui a buscar las fórmulas del archivo, no solo los valores. Tres hallazgos:

**a) `ESTATUS OT` no es un dato: es un `VLOOKUP`.**

```excel
=IFERROR(VLOOKUP(U4,$X$1:$Y$2,2,FALSE)," ")
```

Las celdas `X1:Y2` contienen literalmente:

```text
X1 = 1    Y1 = CERRADA
X2 = 0    Y2 = ABIERTA
```

Es decir: **el planificador ya construyó un catálogo a mano, con dos celdas y un `VLOOKUP`, porque lo necesitaba.** Ese es el mejor argumento a favor de tu regla, y no lo puse yo: está en su archivo. Lo único que hace SIGMA es darle una tabla de verdad en vez de dos celdas.

**b) No hay ciclo de vida.** Las 7.043 filas tienen `Status = 1` → `ESTATUS OT = CERRADA`. Ninguna abierta, ninguna en ejecución, ninguna vencida. La planilla solo sabe registrar el final; el proceso intermedio no existe como dato.

**c) Y eso es todo lo que hay.** Solo existen dos estados, `ABIERTA` y `CERRADA`, y todas las filas están cerradas. No hay «asignada», ni «en ejecución», ni «en espera de repuesto», ni «rechazada por el supervisor». Esos momentos ocurren en la planta todos los días, pero no dejan rastro en ninguna parte.

Por eso no se puede responder hoy cuánto tarda una OT desde que se abre hasta que se ejecuta, ni cuántas quedaron esperando repuesto, ni quién las tuvo detenidas. Son las preguntas que sostienen MTTR y cumplimiento, y todas necesitan lo mismo: **un catálogo de estados y un historial de cambios**, que es lo que trae SIGMA (§3.4).

### 3.2 Un catálogo de estado **por entidad**, no uno global

La tentación al hacer 38 catálogos es crear una sola tabla `Estado` con una columna `entidad` y ahorrarse 10 tablas. **No lo hagas.**

Con un catálogo global, esta FK es válida:

```sql
-- Estado global: nada impide esto
UPDATE Orden_Trabajo SET otr_estado = 47   -- 47 = 'RESPONDIDA', de checklist
```

La base lo acepta porque 47 existe en `Estado`. El error aparece meses después, en un reporte que no cuadra. Con catálogos separados, `Orden_Trabajo_Estado` solo contiene los 9 estados de una OT y **el motor rechaza el resto**. Cada catálogo separado es una restricción de integridad gratis.

Por eso el modelo mantiene 8 catálogos de estado distintos, y está bien que sea así:

```text
Orden_Trabajo_Estado · Plan_Ocurrencia_Estado · Checklist_Ocurrencia_Estado
Checklist_Ejecucion_Estado · Checklist_Respuesta_Estado · Tarea_Ocurrencia_Estado
Plan_Version_Estado · Checklist_Version_Estado
```

Se parecen entre sí. No son lo mismo. Una ejecución "sincronizando" no tiene equivalente en una OT, y una OT "validada" no tiene equivalente en una respuesta.

> La excepción documentada es `Proceso_Estado` (§2.3): cinco trabajos asíncronos que sí comparten exactamente el mismo ciclo y que no son entidades de negocio.

### 3.3 Lo más importante: **un estado derivable no es un estado**

Este es el error que veo con más frecuencia en modelos de mantenimiento, y v2 lo tenía a medias.

`ATRASADA` **no debe ser un estado almacenado.** Es una función de dos datos que ya existen:

```sql
-- "Atrasada" se calcula, no se guarda
CASE WHEN coc_checklist_ocurrencia_estado IN (@PENDIENTE, @DISPONIBLE)
      AND coc_fecha_limite_utc < GETUTCDATE()
     THEN 1 ELSE 0 END AS ATRASADA
```

Si lo guardas como estado, necesitas un job que recorra la tabla cada hora para cambiar filas de `PENDIENTE` a `ATRASADA`. Ese job se cae un fin de semana, o se demora, y entonces la bandeja del técnico miente. Peor: el mismo dato queda en dos lugares (la fecha límite y el estado) y tarde o temprano se contradicen.

**Regla:** en el catálogo de estado solo entran los valores que cambian **porque alguien o algo hizo una acción**, nunca los que cambian **porque pasó el tiempo**.

| Va al catálogo (hubo una acción) | Se calcula (solo pasó el tiempo) |
|---|---|
| `PENDIENTE`, `DISPONIBLE`, `EN_EJECUCION`, `COMPLETADA`, `OMITIDA`, `CANCELADA`, `REPROGRAMADA` | **`ATRASADA`** — `fecha_limite_utc < ahora` |
| `ABIERTA`, `ASIGNADA`, `EJECUTADA`, `VALIDADA`, `CERRADA`, `ANULADA` | **`VENCIDA`** — ídem, con la tolerancia aplicada |
| | **`PROXIMA`** — `fecha_programada_utc` dentro de N días |

> Esto corrige v2, donde `VENCIDA` figuraba en los catálogos de ocurrencia. Se elimina de los tres catálogos (`poe`, `coe`, `toe`) y pasa a ser columna calculada en las vistas de bandeja. `OMITIDA` sí se queda: significa que **alguien decidió** no ejecutarla, que es distinto de que se le pasara la hora.

### 3.4 Todo cambio de estado se registra

Un estado sin historial responde "¿en qué está?" pero no "¿cuánto tardó?", que es la pregunta que sostiene MTTR, MTBF, cumplimiento preventivo y carga de trabajo — todos los KPI del contexto §84.

El modelo ya tiene `Orden_Trabajo_Estado_Historial` y `Tarea_Historial`. **Se agregan los que faltaban**, con la misma forma append-only:

| Tabla nueva | pfx | Cubre |
|---|:--:|---|
| `Checklist_Ocurrencia_Historial` | `coh` | ciclo de vida de la ocurrencia de checklist |
| `Plan_Ocurrencia_Historial` | `poh` | ciclo de vida de la ocurrencia de plan |

Estructura común: `<pfx>_<ocurrencia>` · `<pfx>_estado_anterior INT NULL` · `<pfx>_estado_nuevo INT` · `<pfx>_motivo NVARCHAR(500)` · `<pfx>_fecha_utc` · AUD-A.

Y la regla operativa: **ningún SP cambia un estado sin escribir su fila de historial en la misma transacción.** Si el `INSERT` del historial falla, el `UPDATE` del estado se revierte.

### 3.5 Cómo se referencian los estados en el código

Tres reglas, alineadas con `CONVENCIONES.md` §4:

1. **Ids fijos cargados con `IDENTITY_INSERT`.** El id de `CERRADA` es 8 en desarrollo, en QA y en producción. Sin esto, un `INSERT` en distinto orden rompe las comparaciones.
2. **Nunca comparar por texto.** Ni `WHERE ote_nombre = 'CERRADA'` en el SP, ni `if (ot.estado == "CERRADA")` en C#. Siempre por id, con el JOIN al catálogo solo para mostrar.
3. **Los ids se declaran en un solo lugar.** Una clase de constantes en `App_Code` o filas en `Sys_Parametros` — no repartidos por 40 SP.

> Los dos precedentes están en tu propia base. `Log_Estado` (`loe`) existe como catálogo, pero **`Log` no tiene ninguna FK hacia él**: la tabla está ahí y nadie la usa — es lo que pasa cuando se crea el catálogo pero no la FK. Y `Marcacion` iba un paso más allá, con cinco columnas `INT` que eran catálogos sin tabla ni FK; hoy ya nadie recuerda qué significa `mar_auto_manual = 2`. Esa tabla se elimina (§4), pero el error vale como advertencia.

---

## 4. Eliminación del checklist legado y de los módulos fuera de alcance

Sin datos, no hay migración. Se elimina y punto. Orden obligatorio por las FK:

```sql
USE [db_acd593_sigma]
GO
-- 1. Hijas primero
IF OBJECT_ID(N'[dbo].[CheckList_Detalle_ComboBox]', N'U') IS NOT NULL
    DROP TABLE [dbo].[CheckList_Detalle_ComboBox]
GO
IF OBJECT_ID(N'[dbo].[Checklist_Detalle]', N'U') IS NOT NULL
    DROP TABLE [dbo].[Checklist_Detalle]
GO
IF OBJECT_ID(N'[dbo].[Checklist]', N'U') IS NOT NULL
    DROP TABLE [dbo].[Checklist]
GO
-- 2. Catalogos del legado
IF OBJECT_ID(N'[dbo].[Checklist_Tipo_Objeto]', N'U') IS NOT NULL
    DROP TABLE [dbo].[Checklist_Tipo_Objeto]
GO
IF OBJECT_ID(N'[dbo].[Checklist_Tipo_Dato]', N'U') IS NOT NULL
    DROP TABLE [dbo].[Checklist_Tipo_Dato]
GO
IF OBJECT_ID(N'[dbo].[Checklist_Tipo]', N'U') IS NOT NULL
    DROP TABLE [dbo].[Checklist_Tipo]      -- huerfana: nadie la referenciaba
GO
-- 3. Tabla duplicada de autorizacion por planta (A-02)
IF OBJECT_ID(N'[dbo].[Usuario_Instalacion]', N'U') IS NOT NULL
    DROP TABLE [dbo].[Usuario_Instalacion]
GO
-- 4. Modulo de marcacion de asistencia: fuera del alcance de SIGMA (A-08)
--    Marcacion primero: tiene FK a Marcacion_Binario y a Usuario.
IF OBJECT_ID(N'[dbo].[Marcacion]', N'U') IS NOT NULL
    DROP TABLE [dbo].[Marcacion]
GO
IF OBJECT_ID(N'[dbo].[Marcacion_Binario]', N'U') IS NOT NULL
    DROP TABLE [dbo].[Marcacion_Binario]
GO
```

**Antes de ejecutar**, hay que eliminar los SP y el código que las usan:

```sql
-- Que objetos dependen del checklist legado
SELECT DISTINCT o.name AS OBJETO, o.type_desc
FROM   sys.sql_expression_dependencies d
JOIN   sys.objects o ON o.object_id = d.referencing_id
WHERE  d.referenced_entity_name IN
       ('Checklist','Checklist_Detalle','CheckList_Detalle_ComboBox',
        'Checklist_Tipo','Checklist_Tipo_Dato','Checklist_Tipo_Objeto',
        'Usuario_Instalacion','Marcacion','Marcacion_Binario')
ORDER  BY o.name;
```

Lo único que vale la pena rescatar del legado es el **mapeo conceptual** de `Checklist_Tipo_Objeto` (`cho_nombre` + `cho_tipo_dato`) al nuevo `Checklist_Item_Tipo`: el diseño viejo ya separaba "objeto de UI" de "tipo de dato", que es la idea correcta. `Checklist_Item_Tipo` la conserva, ahora con `cit_tipo_dato` FK a `Tipo_Dato` y con el catálogo de tipos completo (14 valores, contra los que hubiera en el legado).

---

## 5. Correcciones a las tablas heredadas

Con la base vacía, estas correcciones cuestan un script. Con datos, cuestan un proyecto.

### 5.1 `Cliente_Usuario_Perfil` — apuntar al perfil (A-01)

```sql
-- 1. Soltar la FK equivocada
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Cliente_Usuario_Perfil_Usuario_Perfil')
    ALTER TABLE [dbo].[Cliente_Usuario_Perfil] DROP CONSTRAINT [FK_Cliente_Usuario_Perfil_Usuario_Perfil]
GO
-- 2. Renombrar la columna a la convencion <pfx>_<entidad_referida>
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Cliente_Usuario_Perfil]') AND name = 'cup_id_perfil')
    EXEC sp_rename '[dbo].[Cliente_Usuario_Perfil].[cup_id_perfil]', 'cup_perfil', 'COLUMN'
GO
-- 3. Apuntar al catalogo correcto
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CUP_PERFILES')
    ALTER TABLE [dbo].[Cliente_Usuario_Perfil] WITH CHECK
        ADD CONSTRAINT [FK_CUP_PERFILES] FOREIGN KEY ([cup_perfil]) REFERENCES [dbo].[Perfiles] ([per_id])
GO
-- 4. Un perfil una vez por afiliacion
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_CUP_CLIENTE_USUARIO_PERFIL')
    CREATE UNIQUE NONCLUSTERED INDEX [UX_CUP_CLIENTE_USUARIO_PERFIL]
        ON [dbo].[Cliente_Usuario_Perfil] ([cup_id_cliente_usuario], [cup_perfil])
GO
```

Con esto, "todos los técnicos del cliente 7" es una consulta directa:

```sql
SELECT u.usu_id, u.usu_nombre
FROM   Cliente_Usuario        ucl
JOIN   Cliente_Usuario_Perfil cup ON cup.cup_id_cliente_usuario = ucl.ucl_id
JOIN   Usuario                u   ON u.usu_id = ucl.ucl_id_usuario
WHERE  ucl.ucl_id_cliente = 7
  AND  cup.cup_perfil     = @PERFIL_TECNICO
```

Antes de la corrección, esa consulta necesitaba pasar por `Usuario_Perfil` y el resultado dependía de que la fila global existiera.

### 5.2 `Cliente_Instalacion_Usuario` — vigencia y cliente (A-03, A-04)

```sql
ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] ADD [ciu_cliente]                INT      NULL
ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] ADD [ciu_fecha_inicio]           DATE     NULL
ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] ADD [ciu_fecha_fin]              DATE     NULL
ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] ADD [ciu_usuario_actualizacion]  INT      NULL
ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] ADD [ciu_fecha_actualizacion]    DATETIME NULL
ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] ADD [ciu_habilitado]             BIT      NOT NULL
    CONSTRAINT [DF_CIU_HABILITADO] DEFAULT 1
GO
ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] ALTER COLUMN [ciu_cliente] INT NOT NULL
GO
ALTER TABLE [dbo].[Cliente_Instalacion_Usuario] WITH CHECK
    ADD CONSTRAINT [FK_CIU_CLIENTE] FOREIGN KEY ([ciu_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_CIU_INSTALACION_USUARIO]
    ON [dbo].[Cliente_Instalacion_Usuario] ([ciu_id_instalacion], [ciu_id_usuario])
GO
```

`ciu_habilitado` es lo que permite **revocar** el acceso de un técnico a una planta conservando el rastro de que lo tuvo — indispensable para explicar una OT ejecutada hace seis meses por alguien que hoy ya no trabaja ahí.

### 5.3 `Cliente_Instalacion` — cliente obligatorio y datos de planta (A-05)

```sql
ALTER TABLE [dbo].[Cliente_Instalacion] ALTER COLUMN [cin_cliente] INT NOT NULL
GO
ALTER TABLE [dbo].[Cliente_Instalacion] ADD [cin_pais]         INT            NULL
ALTER TABLE [dbo].[Cliente_Instalacion] ADD [cin_zona_horaria] INT            NULL
ALTER TABLE [dbo].[Cliente_Instalacion] ADD [cin_codigo]       NVARCHAR(50)   NULL
ALTER TABLE [dbo].[Cliente_Instalacion] ADD [cin_latitud]      DECIMAL(10,7)  NULL
ALTER TABLE [dbo].[Cliente_Instalacion] ADD [cin_longitud]     DECIMAL(10,7)  NULL
GO
-- Clave que habilita las FK compuestas multicliente (v2 §5.3)
CREATE UNIQUE NONCLUSTERED INDEX [UX_CIN_CLIENTE_ID]
    ON [dbo].[Cliente_Instalacion] ([cin_cliente], [cin_id])
GO
```

### 5.4 Índices únicos que faltan (A-06)

```sql
CREATE UNIQUE NONCLUSTERED INDEX [UX_UCL_USUARIO_CLIENTE] ON [dbo].[Cliente_Usuario] ([ucl_id_usuario], [ucl_id_cliente])
CREATE UNIQUE NONCLUSTERED INDEX [UX_UPE_USUARIO_PERFIL]  ON [dbo].[Usuario_Perfil]  ([upe_usuario], [upe_perfil])
CREATE UNIQUE NONCLUSTERED INDEX [UX_UPA_USUARIO_PAIS]    ON [dbo].[Usuario_Paises]  ([upa_id_usuario], [upa_id_pais])
GO
```

### 5.5 Binarios fuera de las tablas maestras (A-07)

`Usuario.usu_foto` se elimina: `Usuario_Foto` ya cumple ese rol y tenerlas ambas garantiza que se desincronicen. Para `Cliente.cli_logo` se crea `Cliente_Binario` (`clb`) siguiendo el precedente de `Usuario_Foto`.

### 5.6 Perfiles que el modelo necesita

`Perfiles` debe contener, como mínimo, `PLANIFICADOR_MANTENCION` y `TECNICO`, con `per_tipo` apuntando a `Tipo_Perfil`. Se cargan de forma idempotente y **se reutilizan si ya existen** con otro nombre parecido (`CONVENCIONES.md` §6: buscar antes de crear).


---

## 6. Registro de prefijos v3 — verificado

**217 prefijos, 0 colisiones.** Verificado por script contra los 34 prefijos reales del DDL.

| Origen | Tablas |
|---|---:|
| Existentes en `db_acd593_sigma` que se conservan | 25 |
| Existentes que se eliminan (§4) | 9 |
| Del modelo v2 | 151 |
| Tablas nuevas de v3 | 3 |
| Catálogos nuevos de v3 | 38 |
| **Total de prefijos únicos** | **217** |

Los prefijos `chk`, `chd`, `cdc`, `ckt`, `cht`, `cho`, `uin`, `mar` y `mab` quedan **libres** al eliminarse sus tablas. No se reutilizan: un prefijo reciclado hace que un `SELECT` viejo devuelva datos de otra cosa.

### 6.1 Existentes que se conservan (25)

No se renombran. Sus prefijos son los del DDL real, no los deducidos por el nombre.

| Tabla | pfx | Tabla | pfx | Tabla | pfx |
|---|:--:|---|:--:|---|:--:|
| `Cliente` | `cli` | `Cliente_App_Instalacion` | `cai` | `Cliente_Instalacion` | `cin` |
| `Cliente_Instalacion_Usuario` | `ciu` | `Cliente_Usuario` | `ucl` | `Cliente_Usuario_Perfil` | `cup` |
| `Log` | `log` | `Log_Estado` | `loe` | `Log_Tabla` | `lot` |
| `Menu_Funcion` | `mfu` | `Menu_Funcion_Perfil` | `mfp` | `Menu_Perfil` | `mpe` |
| `Menus` | `mnu` | `Modulos_Sistema` | `mds` | `Paises` | `pai` |
| `Perfiles` | `per` | `Privacidad_Modulos_Sistema` | `pms` | `Sis_Excepcion` | `lge` |
| `Sys_Parametros` | `par` | `Tipo_Perfil` | `tpp` | `Usuario` | `usu` |
| `Usuario_App_Dispositivo` | `uad` | `Usuario_Foto` | `uft` | `Usuario_Paises` | `upa` |
| `Usuario_Perfil` | `upe` |  |  |  |  |

### 6.2 Catálogos nuevos de v3 (38)

Reemplazan a las 53 columnas de texto de §2.4. Sus valores de carga están en el **Anexo B**.

| Tabla | pfx | Tabla | pfx | Tabla | pfx |
|---|:--:|---|:--:|---|:--:|
| `Activo_Posicion_Motivo` | `apm` | `Alerta_Estado` | `aet` | `Archivo_Antivirus_Estado` | `aae` |
| `Archivo_Carga_Estado` | `acs` | `Caracteristica_Tipo` | `ctm` | `Componente_Tipo` | `cto` |
| `Criticidad_Nivel` | `crn` | `Cumplimiento_Politica` | `cpo` | `Dependencia_Accion` | `dac` |
| `Dia_Semana` | `dse` | `Diagnostico_Metodo` | `dme` | `Especialidad_Nivel` | `enl` |
| `Frecuencia_Tipo` | `fre` | `Importacion_Celda_Estado` | `ice` | `Importacion_Tipo` | `iti` |
| `Indisponibilidad_Motivo` | `inm` | `Instalacion_Area_Tipo` | `iat` | `Inventario_Movimiento_Tipo` | `imt` |
| `Magnitud` | `mag` | `Modelo_Formato` | `mfo` | `Modelo_Objetivo` | `mob` |
| `Momento_Ejecucion` | `moe` | `Moneda` | `mon` | `Nivel_Riesgo` | `nri` |
| `Operador_Comparacion` | `opc` | `Permiso_Trabajo_Estado` | `pte` | `Prediccion_Estado` | `pde` |
| `Proceso_Estado` | `pes` | `Repuesto_Estado_Final` | `ref` | `Repuesto_Retiro_Motivo` | `rrm` |
| `Responsabilidad_Tipo` | `rst` | `Resultado_Paso` | `rpa` | `Rol_Ejecucion` | `rej` |
| `Servicio_Tipo` | `sti` | `Severidad` | `sev` | `Tipo_Dato` | `tda` |
| `Unidad_Tiempo` | `uti` | `Validacion_Tipo` | `vat` |  |  |

### 6.3 Tablas nuevas de v3 (3)

| Tabla | pfx | Tabla | pfx | Tabla | pfx |
|---|:--:|---|:--:|---|:--:|
| `Checklist_Ocurrencia_Historial` | `coh` | `Cliente_Binario` | `clb` | `Plan_Ocurrencia_Historial` | `poh` |

Las 151 tablas del modelo v2 mantienen sus prefijos, con las dos correcciones de §1.3: `Permiso` → **`prm`** y `Plan_Actividad_Repuesto` → **`pra`**.

**Consulta de verificación antes de cada `CREATE TABLE`:**

```sql
SELECT DISTINCT TABLE_NAME
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  COLUMN_NAME LIKE '<pfx>[_]%'
ORDER  BY TABLE_NAME;   -- debe devolver 0 filas
```
---

## 7. Qué secciones de v2 quedan sustituidas

| Sección de v2 | Estado | Motivo |
|---|---|---|
| §1.2 "supuestos abiertos" | **Cerrada** | El DDL real resuelve los cinco supuestos |
| §5.16 `Cliente_Usuario_Perfil` | **Confirmada y ampliada** | El diagnóstico era correcto; el `ALTER` de §5.1 de este anexo lo reemplaza (sin datos, se corrige en vez de deprecar) |
| §5.17 `Usuario_Instalacion` | **Endurecida** | Ya no se "declara legada": se elimina |
| §8.1 tablas heredadas ampliadas | **Sustituida** por §5 de este anexo | Los `ALTER` cambian al no haber datos |
| §12 registro de prefijos (171) | **Sustituido** por §6 de este anexo (219) | Seis prefijos deducidos eran incorrectos, dos colisionaban |
| §17 de v1 (migración del checklist) | **Descartada** | Sin datos, se ejecuta el `DROP` de §4 |
| Todas las columnas `NVARCHAR` de dominio cerrado | **Sustituidas** por §2.4 | 53 columnas pasan a `INT` + FK |
| Catálogos de ocurrencia con `VENCIDA` | **Corregidos** | `VENCIDA` sale del catálogo y pasa a ser columna calculada (§3.3) |
| Resto de v2 | **Vigente** | Arquitectura por dominios, ERD, hito de plan, posición funcional, valor canónico, FK compuestas multicliente, motor de recurrencia y ML |

---

## 8. Orden de ejecución del bloque 0

Antes del bloque 1 de v2 §15, va este bloque de saneamiento. Es corto y desbloquea todo lo demás.

| Paso | Script | Contenido |
|---|---|---|
| 0.1 | `00_DEPENDENCIAS.sql` | Consulta de dependencias del checklist legado (§4) — **solo lectura**, se revisa antes de seguir |
| 0.2 | `01_DROP_FUERA_DE_ALCANCE.sql` | Los 9 `DROP TABLE` de §4: checklist legado, `Usuario_Instalacion`, `Marcacion` y `Marcacion_Binario` |
| 0.3 | `02_FIX_SEGURIDAD.sql` | A-01 a A-06: `Cliente_Usuario_Perfil`, `Cliente_Instalacion_Usuario`, `Cliente_Instalacion`, índices únicos |
| 0.4 | `03_FIX_BINARIOS.sql` | A-07: `Cliente_Binario`, eliminación de `usu_foto` |
| 0.5 | `04_CATALOGOS_TRANSVERSALES.sql` | Los 11 catálogos transversales de §2.3 con su carga idempotente |
| 0.6 | `05_PERFILES_BASE.sql` | `PLANIFICADOR_MANTENCION` y `TECNICO` en `Perfiles` |

Los 27 catálogos restantes se crean dentro del bloque de su dominio, no todos juntos: así cada bloque queda auto-contenido y ejecutable de forma independiente.

Cada script: `USE [db_acd593_sigma]`, `SET ANSI_NULLS ON`, `SET QUOTED_IDENTIFIER ON`, envuelto en `IF NOT EXISTS ... ELSE PRINT`, guardado en **UTF-8 con BOM**, y **ejecutado dos veces** para comprobar idempotencia.

---

## 9. Lo que sigue pendiente

1. **`aco_posicion`** — si en los primeros meses se estabiliza bajo 20 valores, pasa a catálogo `Componente_Posicion`.
2. **Los 16 correlativos de OT duplicados** de la MATRIZ — se resuelven al cargar el Excel, no ahora.

---

*Anexo generado sobre el DDL real de `db_acd593_sigma` verificado el 19-08-2026, los tres archivos de Hamburgo y los patrones del grupo en `C:\Capstone\PATRONES\ASP`.*
