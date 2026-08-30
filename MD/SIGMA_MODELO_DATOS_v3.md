# SIGMA — Modelo de datos

Inventario completo: **238 tablas** en 15 dominios, verificadas sin colisiones de prefijo.

Base: `db_acd593_sigma` · SQL Server · sin datos. Este documento es **el modelo de datos**; el
modelo de negocio que se apoya en él está en los anexos F y G, separado a propósito.

---

## 1. Cómo leer este número

**238 tablas suena a mucho hasta que se abre el número.** No todas son lo mismo ni cuestan lo mismo:

| Clase | Cantidad | Qué cuesta construirla |
|---|---:|---|
| **Catálogos** | **76** | Un `INSERT` y una FK. **Sin pantalla, sin SP, sin mantenedor** |
| Tablas de negocio | 162 | Éstas sí llevan SP y, algunas, pantalla |
| **Total** | **238** | |

Los 76 catálogos suman **457 filas** — un promedio de 6.0 filas cada uno, y 32 de ellos tienen
cuatro filas o menos. Se cargan con un solo script, `04_CATALOGOS_SIGMA.sql`, y **solo 10 llevan**
**mantenedor** porque son los que cada cliente puede ampliar. Los otros 69 son constantes con
integridad referencial: cuestan lo mismo que un `enum`, pero el motor los verifica.

> **La cuenta que importa no es cuántas tablas hay, sino cuántas pantallas se construyen.**
> Para la demo de noviembre son unas 50. Las otras 188 están modeladas, con script y
> documentadas — que es exactamente lo que se entrega como trabajo de modelado.

### 1.1 Comparación honesta

Un CMMS comercial no tiene menos tablas que éste. IBM Maximo, SAP PM e Infor EAM manejan
cientos, y ninguno cubre voz, descubrimiento en terreno ni suscripción multicliente en el mismo
esquema. **238 para el alcance de SIGMA es normal, no excesivo.**

Lo que sí sería excesivo es construir las 243. No se van a construir.

---

## 2. Los 15 dominios

El orden es también el de dependencia: cada dominio solo referencia a los anteriores.

| # | Dominio | Tablas | Catálogos | Qué resuelve |
|:--:|---|---:|---:|---|
| D1 | **Organización y seguridad** | 54 | 17 | Cliente, planta, área, usuario, perfil, permiso, especialidad, grupo, centro de costo y los catálogos transversales. |
| D2 | **Activos y ubicación técnica** | 18 | 5 | La máquina física, su posición funcional, sus componentes y sus atributos técnicos. |
| D3 | **Variables y mediciones** | 7 | 2 | La serie temporal de condición y los horómetros. Es la materia prima del predictivo. |
| D4 | **Repuestos e inventario** | 12 | 3 | Catálogo de repuestos, compatibilidad, instalación física, bodega, lote, movimiento y saldo. |
| D5 | **Motor de programación** | 10 | 1 | La recurrencia única que comparten planes, tareas y checklists. Doce casos, una sola implementación. |
| D6 | **Planes de mantenimiento** | 12 | 2 | Plan → versión → hito → actividad → ocurrencia. El hito es lo que se programa y produce UNA OT con N pasos. |
| D7 | **Checklist dinámico** | 23 | 8 | Plantilla versionada hasta la respuesta y la medición que genera. La versión publicada es inmutable. |
| D8 | **Tareas** | 11 | 2 | Actividad asignable con una o varias fechas, más liviana que una OT. |
| D9 | **Órdenes de trabajo y fallas** | 27 | 10 | La OT completa: asignación, pasos, tiempos, repuestos, validación y el árbol síntoma-modo-causa. |
| D10 | **Bitácora** | 4 | 1 | Registro libre del técnico, append-only con rectificación. |
| D11 | **Evidencias y visión** | 9 | 3 | Azure Blob, el vínculo con cada entidad y el análisis visual con revisión humana. |
| D12 | **Machine learning** | 15 | 5 | Dataset, modelo, versión ONNX, predicción, explicación y resultado real para reentrenar. |
| D13 | **Terceros y procedimientos** | 11 | 6 | Proveedor, servicio contratado, permiso de trabajo, procedimiento y alertas. |
| D14 | **Descubrimiento, voz e importación** | 7 | 3 | Registro en terreno, fusión de duplicados, dictado por voz y staging de Excel. |
| D15 | **Modelo comercial y costo de operación** ⬦ | 18 | 8 | Planes, precios en UF, suscripción con clave, períodos, pagos, bloqueo y medición del costo de nube. |
| | **TOTAL** | **238** | **76** | |

⬦ **D15 es el modelo comercial.** Sus tablas viven en la misma base porque la suscripción
condiciona lo que cada cliente puede hacer, y eso se resuelve con una FK, no con una integración.
Pero el **razonamiento** comercial — precios, márgenes, política de renovación — está fuera de este
documento, en los anexos F y G. Aquí solo están las tablas.

---

## 3. Inventario tabla por tabla

`C` marca los catálogos. El prefijo de tres letras es único en toda la base.

### D1 · Organización y seguridad

Cliente, planta, área, usuario, perfil, permiso, especialidad, grupo, centro de costo y los catálogos transversales.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Centro_Costo` | `cco` |  | `Modulos_Sistema` | `mds` |  |
| `Cliente` | `cli` |  | `Momento_Ejecucion` | `moe` | C |
| `Cliente_App_Instalacion` | `cai` |  | `Moneda` | `mon` | C |
| `Cliente_Binario` | `clb` |  | `Operador_Comparacion` | `opc` | C |
| `Cliente_Instalacion` | `cin` |  | `Paises` | `pai` |  |
| `Cliente_Instalacion_Usuario` | `ciu` |  | `Perfil_Permiso` | `ppe` |  |
| `Cliente_Usuario` | `ucl` |  | `Perfiles` | `per` |  |
| `Cliente_Usuario_Perfil` | `cup` |  | `Permiso` | `prm` |  |
| `Cliente_Usuario_Permiso` | `cpm` |  | `Permiso_Ambito` | `pam` | C |
| `Criticidad_Nivel` | `crn` | C | `Privacidad_Modulos_Sistema` | `pms` |  |
| `Dia_Semana` | `dse` | C | `Proceso_Estado` | `pes` | C |
| `Especialidad` | `esp` | C | `Registro_Origen` | `ror` | C |
| `Especialidad_Nivel` | `enl` | C | `Responsabilidad_Tipo` | `rst` | C |
| `Frecuencia_Tipo` | `fre` | C | `Severidad` | `sev` | C |
| `Grupo_Trabajo` | `gtr` |  | `Sis_Excepcion` | `lge` |  |
| `Grupo_Trabajo_Usuario` | `gtu` |  | `Sys_Parametros` | `par` |  |
| `Idioma` | `idi` |  | `Tipo_Dato` | `tda` | C |
| `Instalacion_Area` | `iar` |  | `Tipo_Perfil` | `tpp` |  |
| `Instalacion_Area_Tipo` | `iat` | C | `Unidad_Tiempo` | `uti` | C |
| `Log` | `log` |  | `Usuario` | `usu` |  |
| `Log_Estado` | `loe` |  | `Usuario_Accesibilidad` | `uac` |  |
| `Log_Tabla` | `lot` |  | `Usuario_App_Dispositivo` | `uad` |  |
| `Magnitud` | `mag` | C | `Usuario_Especialidad` | `ues` |  |
| `Menu_Funcion` | `mfu` |  | `Usuario_Foto` | `uft` |  |
| `Menu_Funcion_Perfil` | `mfp` |  | `Usuario_Paises` | `upa` |  |
| `Menu_Perfil` | `mpe` |  | `Usuario_Perfil` | `upe` |  |
| `Menus` | `mnu` |  | `Zona_Horaria` | `zho` |  |

### D2 · Activos y ubicación técnica

La máquina física, su posición funcional, sus componentes y sus atributos técnicos.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Activo` | `act` |  | `Activo_Posicion` | `apo` |  |
| `Activo_Atributo` | `aat` |  | `Activo_Posicion_Historial` | `aph` |  |
| `Activo_Componente` | `aco` |  | `Activo_Posicion_Motivo` | `apm` | C |
| `Activo_Componente_Estado` | `ace` | C | `Activo_Tipo` | `ati` |  |
| `Activo_Componente_Fusion` | `acf` |  | `Activo_Variable` | `ava` |  |
| `Activo_Estado` | `aes` | C | `Atributo_Tecnico` | `ate` |  |
| `Activo_Estado_Historial` | `aeh` |  | `Componente_Posicion` | `cpn` | C |
| `Activo_Fusion` | `afu` |  | `Componente_Repuesto_Instalacion` | `cri` |  |
| `Activo_Modelo` | `amo` |  | `Componente_Tipo` | `cto` | C |

### D3 · Variables y mediciones

La serie temporal de condición y los horómetros. Es la materia prima del predictivo.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Activo_Medicion` | `amd` |  | `Medicion_Calidad` | `mca` | C |
| `Activo_Medidor` | `ame` |  | `Unidad_Medida` | `ume` |  |
| `Activo_Medidor_Lectura` | `aml` |  | `Variable_Medicion` | `vme` |  |
| `Dato_Origen` | `dor` | C | | | |

### D4 · Repuestos e inventario

Catálogo de repuestos, compatibilidad, instalación física, bodega, lote, movimiento y saldo.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Bodega` | `bod` |  | `Repuesto_Bodega_Stock` | `rbs` |  |
| `Bodega_Ubicacion` | `bub` |  | `Repuesto_Compatibilidad` | `rco` |  |
| `Inventario_Movimiento` | `imo` |  | `Repuesto_Estado_Final` | `ref` | C |
| `Inventario_Movimiento_Tipo` | `imt` | C | `Repuesto_Fusion` | `rfu` |  |
| `Inventario_Saldo` | `isa` |  | `Repuesto_Lote` | `rlo` |  |
| `Repuesto` | `rep` |  | `Repuesto_Retiro_Motivo` | `rrm` | C |

### D5 · Motor de programación

La recurrencia única que comparten planes, tareas y checklists. Doce casos, una sola implementación.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Programacion` | `pro` |  | `Programacion_Fecha` | `pfe` |  |
| `Programacion_Calendario` | `pca` |  | `Programacion_Generacion` | `pge` |  |
| `Programacion_Calendario_Dia` | `pcd` |  | `Programacion_Intervalo` | `pin` |  |
| `Programacion_Condicion` | `pco` |  | `Programacion_Medidor` | `pme` |  |
| `Programacion_Exclusion` | `pxc` |  | `Programacion_Tipo` | `pti` | C |

### D6 · Planes de mantenimiento

Plan → versión → hito → actividad → ocurrencia. El hito es lo que se programa y produce UNA OT con N pasos.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Plan_Actividad_Checklist` | `pck` |  | `Plan_Mantenimiento_Hito` | `pmh` |  |
| `Plan_Actividad_Especialidad` | `pae` |  | `Plan_Mantenimiento_Ocurrencia` | `pmo` |  |
| `Plan_Actividad_Repuesto` | `pra` |  | `Plan_Mantenimiento_Version` | `pmv` |  |
| `Plan_Mantenimiento` | `pma` |  | `Plan_Ocurrencia_Estado` | `poe` | C |
| `Plan_Mantenimiento_Actividad` | `paa` |  | `Plan_Ocurrencia_Historial` | `poh` |  |
| `Plan_Mantenimiento_Activo` | `pac` |  | `Plan_Version_Estado` | `pve` | C |

### D7 · Checklist dinámico

Plantilla versionada hasta la respuesta y la medición que genera. La versión publicada es inmutable.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Checklist_Asignacion_Tipo` | `cat` | C | `Checklist_Ocurrencia_Historial` | `coh` |  |
| `Checklist_Ejecucion` | `cej` |  | `Checklist_Plantilla` | `cpl` |  |
| `Checklist_Ejecucion_Estado` | `cee` | C | `Checklist_Plantilla_Item` | `cpi` |  |
| `Checklist_Ejecucion_Respuesta` | `cer` |  | `Checklist_Plantilla_Seccion` | `cps` |  |
| `Checklist_Hallazgo` | `cha` |  | `Checklist_Plantilla_Version` | `cpv` |  |
| `Checklist_Item_Dependencia` | `cid` |  | `Checklist_Programacion` | `cpr` |  |
| `Checklist_Item_Opcion` | `cio` |  | `Checklist_Respuesta_Estado` | `cre` | C |
| `Checklist_Item_Tipo` | `cit` | C | `Checklist_Respuesta_Opcion` | `cro` |  |
| `Checklist_Item_Validacion` | `civ` |  | `Checklist_Version_Estado` | `cve` | C |
| `Checklist_Ocurrencia` | `coc` |  | `Cumplimiento_Politica` | `cpo` | C |
| `Checklist_Ocurrencia_Asignacion` | `coa` |  | `Dependencia_Accion` | `dac` | C |
| `Checklist_Ocurrencia_Estado` | `coe` | C | | | |

### D8 · Tareas

Actividad asignable con una o varias fechas, más liviana que una OT.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Tarea` | `tar` |  | `Tarea_Ocurrencia` | `toc` |  |
| `Tarea_Categoria` | `tca` |  | `Tarea_Ocurrencia_Asignacion` | `toa` |  |
| `Tarea_Checklist` | `tck` |  | `Tarea_Ocurrencia_Estado` | `toe` | C |
| `Tarea_Comentario` | `tco` |  | `Tarea_Prioridad` | `tpa` | C |
| `Tarea_Ejecucion` | `tej` |  | `Tarea_Programacion` | `tpr` |  |
| `Tarea_Historial` | `thi` |  | | | |

### D9 · Órdenes de trabajo y fallas

La OT completa: asignación, pasos, tiempos, repuestos, validación y el árbol síntoma-modo-causa.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Activo_Indisponibilidad` | `ain` |  | `Orden_Trabajo_Estado_Historial` | `oeh` |  |
| `Falla` | `fal` |  | `Orden_Trabajo_Estrategia` | `oet` | C |
| `Falla_Accion` | `fac` |  | `Orden_Trabajo_Mano_Obra` | `omo` |  |
| `Falla_Causa` | `fca` |  | `Orden_Trabajo_Origen` | `oto` | C |
| `Falla_Diagnostico` | `fdi` |  | `Orden_Trabajo_Paso` | `otp` |  |
| `Falla_Modo` | `fmo` |  | `Orden_Trabajo_Prioridad` | `opr` | C |
| `Falla_Sintoma` | `fsi` |  | `Orden_Trabajo_Repuesto` | `ore` |  |
| `Indisponibilidad_Motivo` | `inm` | C | `Orden_Trabajo_Servicio` | `ots` |  |
| `Orden_Trabajo` | `otr` |  | `Orden_Trabajo_Tipo` | `ott` | C |
| `Orden_Trabajo_Asignacion` | `ota` |  | `Orden_Trabajo_Validacion` | `otv` |  |
| `Orden_Trabajo_Checklist` | `otc` |  | `Resultado_Paso` | `rpa` | C |
| `Orden_Trabajo_Cierre_Motivo` | `ocm` | C | `Rol_Ejecucion` | `rej` | C |
| `Orden_Trabajo_Especialidad` | `oep` |  | `Validacion_Tipo` | `vat` | C |
| `Orden_Trabajo_Estado` | `ote` | C | | | |

### D10 · Bitácora

Registro libre del técnico, append-only con rectificación.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Bitacora` | `bit` |  | `Bitacora_Rectificacion` | `bre` |  |
| `Bitacora_Comentario` | `bco` |  | `Bitacora_Tipo` | `bti` | C |

### D11 · Evidencias y visión

Azure Blob, el vínculo con cada entidad y el análisis visual con revisión humana.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Analisis_Visual_Deteccion` | `avd` |  | `Archivo_Carga` | `acg` |  |
| `Analisis_Visual_Revision` | `avr` |  | `Archivo_Carga_Estado` | `acs` | C |
| `Archivo` | `arc` |  | `Archivo_Categoria` | `aca` | C |
| `Archivo_Analisis_Visual` | `aav` |  | `Archivo_Vinculo` | `avi` |  |
| `Archivo_Antivirus_Estado` | `aae` | C | | | |

### D12 · Machine learning

Dataset, modelo, versión ONNX, predicción, explicación y resultado real para reentrenar.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Caracteristica_Modelo` | `cmo` |  | `Modelo_Predictivo_Version` | `mpv` |  |
| `Caracteristica_Tipo` | `ctm` | C | `Nivel_Riesgo` | `nri` | C |
| `Dataset_Entrenamiento` | `den` |  | `Prediccion` | `pre` |  |
| `Entrenamiento_Ejecucion` | `eej` |  | `Prediccion_Caracteristica` | `pcr` |  |
| `Modelo_Formato` | `mfo` | C | `Prediccion_Estado` | `pde` | C |
| `Modelo_Monitoreo` | `mmo` |  | `Prediccion_Explicacion` | `pex` |  |
| `Modelo_Objetivo` | `mob` | C | `Prediccion_Resultado` | `prs` |  |
| `Modelo_Predictivo` | `mpr` |  | | | |

### D13 · Terceros y procedimientos

Proveedor, servicio contratado, permiso de trabajo, procedimiento y alertas.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Alerta` | `ale` |  | `Permiso_Trabajo_Tipo` | `ptt` | C |
| `Alerta_Estado` | `aet` | C | `Procedimiento` | `prc` |  |
| `Alerta_Tipo` | `alt` | C | `Procedimiento_Paso` | `ppa` |  |
| `Diagnostico_Metodo` | `dme` | C | `Proveedor` | `prv` |  |
| `Permiso_Trabajo` | `ptr` |  | `Servicio_Tipo` | `sti` | C |
| `Permiso_Trabajo_Estado` | `pte` | C | | | |

### D14 · Descubrimiento, voz e importación

Registro en terreno, fusión de duplicados, dictado por voz y staging de Excel.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Dictado_Voz` | `dvo` |  | `Importacion_Celda_Estado` | `ice` | C |
| `Entrada_Modo` | `emo` | C | `Importacion_Tipo` | `iti` | C |
| `Importacion_Carga` | `ica` |  | `Registro_Descubrimiento` | `rde` |  |
| `Importacion_Carga_Celda` | `icc` |  | | | |

### D15 · Modelo comercial y costo de operación

Planes, precios en UF, suscripción con clave, períodos, pagos, bloqueo y medición del costo de nube.

| Tabla | pfx | | Tabla | pfx | |
|---|:--:|:--:|---|:--:|:--:|
| `Funcionalidad` | `fun` | C | `Suscripcion_Estado` | `sue` | C |
| `Funcionalidad_Tipo` | `fnt` | C | `Suscripcion_Key_Historial` | `skh` |  |
| `Periodicidad_Cobro` | `pcb` | C | `Suscripcion_Pago` | `spa` |  |
| `Plan_Comercial` | `plc` |  | `Suscripcion_Pago_Estado` | `spo` | C |
| `Plan_Comercial_Funcionalidad` | `pcf` |  | `Suscripcion_Periodo` | `spe` |  |
| `Plan_Comercial_Precio` | `pcp` |  | `Suscripcion_Periodo_Estado` | `spd` | C |
| `Suscripcion` | `sus` |  | `Uf_Origen` | `ufo` | C |
| `Suscripcion_Bloqueo_Log` | `sbl` |  | `Valor_Uf` | `vuf` |  |
| `Suscripcion_Consumo` | `sco` |  | `Voz_Motor` | `vmo` | C |
