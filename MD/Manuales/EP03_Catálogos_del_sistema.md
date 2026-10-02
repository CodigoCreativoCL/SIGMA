# EP-03 - Catálogos del sistema

> Que las listas de valores del sistema sean consistentes entre clientes y ampliables donde el negocio lo exige.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Países | Sistema > Geografía > Países | - | Ver el mantenedor de paises |
| Catálogos | Cliente > Configuración > Catálogos | - | Consultar los catálogos del sistema |
| Unidades de medida | Sistema > Mantenedores > Unidades de medida | - | Ver las unidades de medida |
| Pais (detalle) *(se abre desde otra pantalla)* | Sistema > Geografía > Pais (detalle) | - | Ver el mantenedor de paises |
| Unidad de medida (detalle) *(se abre desde otra pantalla)* | Sistema > Mantenedores > Unidad de medida (detalle) | - | Ver las unidades de medida |
| Valor de catálogo (detalle) *(se abre desde otra pantalla)* | Cliente > Configuración > Valor de catálogo (detalle) | - | Consultar los catálogos del sistema |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Consultar los catálogos del sistema**
- **Ver el mantenedor de paises**
- **Ver las unidades de medida**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-020` - Consultar los catálogos del sistema

## 4. Paso a paso

### HU-021 - Agregar valores propios a un catálogo ampliable

**Para que.** Como administrador del cliente, agregar valores propios en los catálogos que lo permiten, que el sistema hable con los términos que usa mi planta.

*Web - Sprint 1*

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Catálogo | Lista desplegable (solo ampliables) | Si | Catálogos habilitados para extensión |
| Código | Texto | Si | Mayúsculas sin acentos. Único por cliente y catálogo |
| Nombre visible | Texto | Si | Es el texto que ve el usuario final |
| Descripción | Texto multilinea | No | Máximo 500 caracteres |
| Orden | Numérico entero | No | Define la posición en las listas |

**Como saber que quedo bien:**

1. **Alta de un valor propio** - Cuando agrego un valor a un catálogo ampliable Entonces queda disponible solo para mi cliente Y aparece en las listas junto a los valores del sistema
2. **Catálogo no ampliable** - Cuando abro un catálogo que no admite valores propios Entonces la acción de agregar no se muestra
3. **Valor en uso** - Cuando intento deshabilitar un valor que tiene registros asociados Entonces se advierte cuántos registros lo usan Y al confirmar el valor deja de ofrecerse pero los registros existentes lo conservan


### HU-020 - Consultar los catálogos del sistema

**Para que.** Como administrador del cliente, consultar los valores disponibles de cada catálogo, saber qué opciones va a ver el usuario antes de configurar el sistema.

*Web - Sprint 1*

**Como saber que quedo bien:**

1. **Consulta de un catálogo** - Cuando abro un catálogo del sistema Entonces veo su código, su nombre visible y su descripción Y no puedo modificar ni eliminar sus valores
2. **Búsqueda transversal** - Cuando busco un texto en el buscador de catálogos Entonces se listan todos los catálogos que contienen ese valor


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la accion se intente desde la API o desde la app.

- **HU-021 - Valor en uso** - Cuando intento deshabilitar un valor que tiene registros asociados Entonces se advierte cuántos registros lo usan Y al confirmar el valor deja de ofrecerse pero los registros existentes lo conservan

## 6. Si algo no funciona

| Sintoma | Causa mas probable |
|---|---|
| No aparece la opcion en el menu | Falta el permiso de la seccion 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el boton no hace nada | Falta el permiso de la funcion: ver no es lo mismo que crear y editar |
| Dice que no se puede guardar, sin mas detalle | Alguna regla de la seccion 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacios | Falta construir lo de la seccion 3 |
| Estoy en la pantalla correcta y no veo el formulario | Falta pulsar la pestana que indica cada operacion en la seccion 4 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx`, la tabla `Menus` y las pestanas declaradas en los .aspx. Para actualizarlo: `python _scratch/gen_manuales.py`.*
