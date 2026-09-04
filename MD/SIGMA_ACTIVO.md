# SIGMA — El Activo: funcionamiento y arquitectura

> Documento de referencia del módulo **Activos**. Explica qué es un activo, qué
> datos y pantallas lo componen hoy, y la propuesta para **centralizar todo en
> una sola vista con pestañas** (reducir los 8 ítems de menú actuales).

---

## 1. Qué es un activo

Un **activo** es un equipo o máquina sobre el que se planifica y ejecuta el
mantenimiento (una bomba, un motor, una modeladora…). Es el centro del sistema:
sobre él cuelgan medidores, componentes, atributos técnicos, historial de
estados, órdenes de trabajo y planes.

- Tabla principal: **`Activo`** (`act_*`).
- Un activo pertenece a **un cliente** (`act_cliente`) y a **una planta**
  (`act_cliente_instalacion`); opcionalmente a un **área** y a un **activo
  superior** (jerarquía padre/hijo para subactivos).
- Su **código es automático** (`ACT-<id>`, sistema `Modulo_Codigo`): no se
  teclea, se genera al guardar.
- Baja lógica: `act_habilitado = 0` (INACTIVO); el activo **no se borra**, se
  conserva con toda su historia.

### Campos clave de `Activo`
| Campo | Qué es |
|---|---|
| `act_codigo` | Código automático `ACT-<id>` |
| `act_nombre` | Nombre visible |
| `act_activo_tipo` | Tipo (catálogo `Activo_Tipo`) |
| `act_activo_modelo` | Modelo (catálogo `Activo_Modelo`) — opcional |
| `act_activo_estado` | Estado actual (Operativo, En mantenimiento, Detenido…) |
| `act_criticidad_nivel` | Criticidad (Crítica, Alta, Media, Baja) |
| `act_cliente_instalacion` / `act_instalacion_area` | Planta / área |
| `act_activo_padre` | Activo superior (subactivos) |
| `act_numero_serie`, `act_fabricante`, `act_anio_fabricacion`, `act_fecha_puesta_marcha` | Ficha técnica |
| `act_habilitado` | Baja lógica |

---

## 2. Todo lo que "cuelga" del activo

| Entidad | Tabla | Relación | Pantalla actual |
|---|---|---|---|
| **Estado (historial)** | `Activo_Estado_Historial` | 1 activo → N tramos de estado | Cambiar estado / Ficha |
| **Componentes** | `Activo_Componente` | 1 activo → N piezas (con jerarquía) | Componentes |
| **Medidores** | `Activo_Medidor` | 1 activo → N horómetros/contadores | Medidores |
| **Atributos (valores)** | `Activo_Atributo` | 1 activo → N valores de atributos técnicos | (aún sin pantalla) |
| **Imagen de referencia** | `Archivo` + `Archivo_Vinculo` (`avi_activo`, `avi_es_referencia`) | 1 activo → 1 imagen vigente | En la ficha del activo |

### Catálogos que **configuran** al activo (no son del activo, son de la plataforma/cliente)
| Catálogo | Tabla | Para qué |
|---|---|---|
| **Tipos de activo** | `Activo_Tipo` | Familia del equipo (árbol jerárquico) |
| **Modelos de activo** | `Activo_Modelo` | Fabricante + modelo por tipo |
| **Atributos técnicos** | `Atributo_Tecnico` | Qué datos describe cada tipo (potencia, voltaje…) |
| **Unidades de medida** | `Unidad_Medida` | Unidades (kW, V, l/min) — vive en Sistema |

---

## 3. Pantallas y SPs (estado actual)

Menú **Activos** (8 ítems visibles hoy):

| # | Pantalla | Ámbito | SPs |
|---|---|---|---|
| 1 | **Activos** (listado + ficha alta/edición) | Por activo | `SEL/INS/UPD/DEL_ACTIVO` |
| 2 | **Medidores** | Por activo | `SEL/INS/UPD/DEL_ACTIVO_MEDIDOR` |
| 3 | **Tipos de activo** | Catálogo | `SEL/INS/UPD/DEL_ACTIVO_TIPO` |
| 4 | **Ficha e historial** (vista 360°) | Por activo | `SEL_ACTIVO`, `SEL_ACTIVO_FICHA` |
| 5 | **Componentes** | Por activo | `SEL/INS/UPD/DEL_ACTIVO_COMPONENTE` |
| 6 | **Cambiar estado** | Por activo (acción) | `ACTIVO_CAMBIAR_ESTADO`, `SEL_ACTIVO_ESTADO_HISTORIAL` |
| 7 | **Modelos de activo** | Catálogo | `SEL/INS/UPD/DEL_ACTIVO_MODELO` |
| 8 | **Atributos técnicos** | Catálogo | `SEL/INS/UPD/DEL_ATRIBUTO_TECNICO` |

### Reglas transversales (todas las pantallas)
- **Seguridad por datos**: siempre se filtra por el **cliente en sesión**
  (`Session.ClienteId()`); el SP rechaza el activo de otra empresa.
- **Permisos en el servidor**: `Token.Puede(...)` / `Token.PuedeFuncion(...)`
  (no se esconde solo el botón).
- **Código automático** donde aplica (`ACT-`, `MED-`, `COM-`, `TIP-`, `ATR-`).
- **Auditoría**: usuario/fecha de creación y actualización, con `FNC_PAIS_HORA`.
- **Modales** con `SigmaModal.open(...)` para las fichas; listados con `RadGrid2`.

### La imagen del activo
- No vive en `Activo`: se guarda en **`Archivo`** (categoría 10, *REFERENCIA*) y
  se enlaza por **`Archivo_Vinculo`** (`avi_activo` + `avi_es_referencia = 1`).
- Se sube al crear/editar el activo (a **Azure**, vía `Almacenamiento.Actual()`);
  `VIN_ACTIVO_IMAGEN` deja **una sola vigente**; `DEL_ACTIVO_IMAGEN` la quita.
- Se muestra en la ficha 360°; si no hay, una ilustración de respaldo.

---

## 4. El problema: demasiados menús

Hoy el activo está **repartido en 8 ítems de menú**. Para ver "todo lo de un
activo" hay que saltar entre Ficha, Componentes, Medidores, Cambiar estado…, y
elegir el activo en cada pantalla. Además, **3 de esos 8 son catálogos** de
configuración (Tipos, Modelos, Atributos técnicos), que no son "de un activo"
sino de la plataforma, y ensucian el menú operativo.

---

## 5. Centralización en pestañas (la Ficha como hub) — IMPLEMENTADO

> ✅ Aplicado el 01-09-2026 (bloque **133** + rediseño de `ActivoFicha`). El menú
> pasó de **8 a 3** y la ficha ahora carga componentes, medidores y atributos
> del activo en pestañas (solo lectura + botón **Gestionar**).

**Una sola pantalla** — la *Ficha e historial* (vista 360°) — pasa a ser el
**centro del activo**: se elige el activo una vez y **todo** se ve en pestañas.

```
Activos  ▸  (elige un activo)  ▸  Ficha 360°
                                   ├─ Resumen        (datos + imagen + métricas)
                                   ├─ Historial      (línea de tiempo de eventos)
                                   ├─ Componentes    (piezas del activo)
                                   ├─ Medidores      (horómetros/contadores)
                                   ├─ Atributos      (valores técnicos del activo)
                                   ├─ Documentos     (archivos adjuntos)
                                   └─ [Acción] Cambiar estado, Editar, Generar OT
```

### Menú resultante (de 8 → 3)
```
Activos                     ← listado + alta/edición (entrada)
Ficha e historial           ← el hub con todas las pestañas
Configuración de activos ▸   ← subgrupo con los catálogos
    ├─ Tipos de activo
    ├─ Modelos de activo
    └─ Atributos técnicos
```

- **Medidores, Componentes, Cambiar estado** dejan de ser ítems de menú:
  viven como **pestañas/acciones dentro de la ficha** (siguen existiendo sus
  pantallas de gestión, accesibles desde cada pestaña con "Gestionar").
- **Tipos, Modelos, Atributos técnicos** se agrupan bajo *Configuración de
  activos*: siguen siendo catálogos, pero no compiten con lo operativo.

### Beneficios
- Se ve **todo lo del activo en un solo lugar**, sin re-elegirlo en cada pantalla.
- El menú operativo queda **limpio** (3 en vez de 8).
- La separación **operación (ficha) vs configuración (catálogos)** queda clara.

### Cómo se implementa (sin perder nada)
- Las pestañas **cargan datos reales** del activo elegido reutilizando los
  controllers existentes (`ActivoComponenteController`, `ActivoMedidorController`,
  `AtributoTecnicoController`, `ActivoImagenController`).
- Cada pestaña tiene un botón **"Gestionar"** que abre el mantenedor completo
  (crear/editar) en modal `SigmaModal`, así no se reescribe la lógica de ABM.
- El menú se reordena en `Menus` (baja lógica de visibilidad, no se borran las
  pantallas: las fichas de detalle siguen con `mnu_visible = 0`).

---

## 6. Bitácora del módulo (bloques BD)
- Activo, tipos, ficha, medidores: bloques 74, 76, 90–92.
- Unidades de medida: 93–95. Componentes: 96–98. Código automático: 77, 100.
- Estado/historial: 101–103. Modelos: 104–106. Atributos técnicos: 107–110.
- Imagen del activo: 132.

*(Para la numeración exacta ver `MD/SIGMA_ESTADO_DESARROLLO.md`.)*
