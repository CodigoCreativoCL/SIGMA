# EP-03 · Catálogos del sistema

> Que las listas de valores del sistema sean consistentes entre clientes y ampliables donde el negocio lo exige.

**Manual de operación.** Cómo se usa este módulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, así que dice lo mismo que hace el sistema.


## 1. Dónde está en el menú

| Pantalla | Ruta en el menú | Permiso que exige |
|---|---|---|
| Países | Sistema › Geografía › Países | Ver el mantenedor de paises |
| Catálogos | Cliente › Configuración › Catálogos | Consultar los catálogos del sistema |
| Unidades de medida | Sistema › Mantenedores › Unidades de medida | Ver las unidades de medida |
| Pais (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Geografía › Pais (detalle) | Ver el mantenedor de paises |
| Unidad de medida (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Sistema › Mantenedores › Unidad de medida (detalle) | Ver las unidades de medida |
| Valor de catálogo (detalle) *(no aparece en el menú; se abre desde otra pantalla)* | Cliente › Configuración › Valor de catálogo (detalle) | Consultar los catálogos del sistema |


## 2. Qué permisos hacen falta

Sin estos permisos el módulo no se ve, y la acción se rechaza en el servidor aunque se intente por otra vía:

- **Consultar los catálogos del sistema**
- **Ver el mantenedor de paises**
- **Ver las unidades de medida**


## 3. Qué tiene que existir antes

Este módulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operación:

- `HU-020` — Consultar los catálogos del sistema


## 4. Paso a paso


### HU-021 · Agregar valores propios a un catálogo ampliable

**Para qué.** Como administrador del cliente, agregar valores propios en los catálogos que lo permiten, que el sistema hable con los términos que usa mi planta.

*Web · Sprint 1*

**Qué se completa:**

| Campo | Control | Obligatorio | Qué valida |
|---|---|---|---|
| Catálogo | Lista desplegable (solo ampliables) | Sí | Catálogos habilitados para extensión |
| Código | Texto | Sí | Mayúsculas sin acentos. Único por cliente y catálogo |
| Nombre visible | Texto | Sí | Es el texto que ve el usuario final |
| Descripción | Texto multilinea | No | Máximo 500 caracteres |
| Orden | Numérico entero | No | Define la posición en las listas |

**Cómo saber que quedó bien:**

1. **Alta de un valor propio** — Cuando agrego un valor a un catálogo ampliable Entonces queda disponible solo para mi cliente Y aparece en las listas junto a los valores del sistema
2. **Catálogo no ampliable** — Cuando abro un catálogo que no admite valores propios Entonces la acción de agregar no se muestra
3. **Valor en uso** — Cuando intento deshabilitar un valor que tiene registros asociados Entonces se advierte cuántos registros lo usan Y al confirmar el valor deja de ofrecerse pero los registros existentes lo conservan


### HU-020 · Consultar los catálogos del sistema

**Para qué.** Como administrador del cliente, consultar los valores disponibles de cada catálogo, saber qué opciones va a ver el usuario antes de configurar el sistema.

*Web · Sprint 1*

**Cómo saber que quedó bien:**

1. **Consulta de un catálogo** — Cuando abro un catálogo del sistema Entonces veo su código, su nombre visible y su descripción Y no puedo modificar ni eliminar sus valores
2. **Búsqueda transversal** — Cuando busco un texto en el buscador de catálogos Entonces se listan todos los catálogos que contienen ese valor


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la acción se intente desde la API o desde la app.

- **HU-021 · Valor en uso** — Cuando intento deshabilitar un valor que tiene registros asociados Entonces se advierte cuántos registros lo usan Y al confirmar el valor deja de ofrecerse pero los registros existentes lo conservan


## 6. Si algo no funciona

| Síntoma | Causa más probable |
|---|---|
| No aparece la opción en el menú | Falta el permiso de la sección 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el botón no hace nada | Falta el permiso de la función (ver ≠ crear y editar) |
| Dice que no se puede guardar sin más detalle | Alguna regla de la sección 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacíos | Falta construir lo de la sección 3 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx` y la tabla `Menus`. Para actualizarlo: `python _scratch/gen_manuales.py`.*
