# -*- coding: utf-8 -*-
"""Checklist post-generacion que se escribe junto a los archivos generados."""

from nucleo import util


def leeme(d, archivos):
    e = d.entidad
    p = d.proyecto

    lista = '\n'.join('- `%s`' % a for a in archivos)

    combos_filtro = [c for c in d.columnas_filtro]
    bloque_filtros = ''
    if combos_filtro or e.habilitado:
        filas = []
        if e.habilitado:
            filas.append('| `cboHabilitado` | Todos / Habilitados / Deshabilitados | ya existe en la mayoria de los proyectos |')
        for c in combos_filtro:
            filas.append('| `cbo%s` | %s | se carga desde `%s.%s` |'
                         % (util.pascal(c.nombre), c.etiqueta,
                            c.fk.controller if c.fk else '-',
                            c.fk.metodo_lista if c.fk else '-'))
        bloque_filtros = (
            '\n### 4. Combos de la barra de filtros\n\n'
            'El listado busca estos controles dentro de `FiltroAvanzado.ascx` con\n'
            '`FindControl`. Si alguno no existe, el filtro simplemente no se aplica\n'
            '(el codigo generado valida `!= null`), pero conviene agregarlos:\n\n'
            '| Control | Contenido | Nota |\n'
            '|---|---|---|\n'
            + '\n'.join(filas) + '\n')

    fks = ''
    if d.fks:
        filas = []
        for c in d.fks:
            filas.append('| `%s` | `%s` | `%s.%s()` | `%s` / `%s` |'
                         % (c.columna, c.fk.tabla, c.fk.controller, c.fk.metodo_lista,
                            c.fk.prop_valor, c.fk.prop_texto))
        fks = ('\n### 3. Dependencias (FK)\n\n'
               'El codigo generado asume que estos Model/Controller **ya existen**\n'
               'en `%s`. Si alguno no existe, generalo primero.\n\n'
               '| Columna | Tabla | Controller usado | Value / Text del combo |\n'
               '|---|---|---|---|\n' % p.ruta_app_code
               + '\n'.join(filas) + '\n')

    plantilla = r'''# Mantenedor generado: {{SINGULAR}} ({{TABLA}})

Generado el {{FECHA}} por `03-Generador` a partir de la definicion de la entidad.

- Base de datos: **{{BD}}**
- Namespaces: `{{NS_MODEL}}` / `{{NS_CONTROLLER}}`
- Modulo / submodulo: `{{MODULO}}` / `{{SUB_MODULO}}`
- Menu de permisos: `SitioBase.Paginas.{{MENU}}`
- Tipo de tabla: **{{TIPO}}** ({{BAJA}})

---

## Archivos generados

{{LISTA}}

---

## Pasos para dejarlo funcionando

### 1. Base de datos

Ejecutar en **este orden** sobre `{{BD}}`:

```
BD/00_TBL_{{TABLA}}.sql
BD/01_{{SP_SEL}}.sql
BD/02_{{SP_INS}}.sql
BD/03_{{SP_UPD}}.sql
BD/04_{{SP_DEL}}.sql
```

Los scripts son idempotentes (`IF NOT EXISTS` / `CREATE OR ALTER`): se pueden
re-ejecutar sin romper nada.

### 2. Copiar los archivos al proyecto Web

Copiar respetando la estructura de carpetas:

```
{{RUTA_APP_CODE}}/Model/{{CLASE_MODEL}}.cs
{{RUTA_APP_CODE}}/Controller/{{CLASE_CONTROLLER}}.cs
{{DIR_CONTROLS}}/
{{DIR_PAGINAS}}/
```

> Todos los archivos salen en **UTF-8 con BOM** y **CRLF**, como pide el patron.
> No los abras/guardes con un editor que cambie la codificacion.
{{FKS}}{{FILTROS}}
### 5. Registrar el menu y los permisos

1. Agregar el enum `{{MENU}}` en `SitioBase.Paginas` con, al menos:
   `Ver`, `Crear_Editar`, `Ver_Todo`{{ENUM_PAISES}}.
2. Dar de alta el menu en la tabla de menus/funciones y asignar los permisos
   a los perfiles que correspondan.
3. Apuntar el item del menu a `{{URL_LISTADO}}`.

### 6. Probar

| Accion | Que deberia pasar |
|---|---|
| Entrar al listado | Grid con los datos y la barra Nuevo / {{BOTON}} |
| Click en Nuevo | Abre `{{SINGULAR}}.aspx` sin querystring (alta) |
| Guardar | Mensaje "{{MSG_CREADO}}" |
| Click en el lapiz de una fila | Abre la ficha con los datos cargados |
| Guardar de nuevo | Mensaje "{{MSG_ACTUALIZADO}}" |
| Seleccionar filas + {{BOTON}} | Confirmacion SweetAlert y luego el mensaje del Controller |
| Perfil sin Crear/Editar | El formulario se abre en modo consulta (ReadOnly) |

---

## Que NO genera el generador

- El enum de `SitioBase.Paginas` (paso 5).
- Los combos nuevos dentro de `FiltroAvanzado.ascx` (paso 4).
- Tabs adicionales del formulario: el generado trae solo `{{TAB}}`.
  Para agregar otro, crear el `.ascx` hermano y registrarlo en
  `{{SINGULAR}}.ascx` + propagar `ReadOnly`/`Id{{SINGULAR}}` en su `Page_PreRender`.
- Reglas de negocio propias: van en el SP (validaciones con `RAISERROR`)
  o en `btnGuardar_Click`.

---

## Regenerar

Si cambia la tabla, edita el JSON de definicion y volve a correr:

```
python generar.py --definicion <tu-definicion>.json --forzar
```

`--forzar` sobreescribe. Sin ese flag, los archivos que ya existen se respetan
(util cuando ya tocaste el codigo generado a mano).
'''

    return util.render(plantilla, {
        'SINGULAR': e.singular,
        'TABLA': e.tabla,
        'FECHA': p.fecha,
        'BD': p.base_datos,
        'NS_MODEL': p.ns_model,
        'NS_CONTROLLER': p.ns_controller,
        'MODULO': e.modulo,
        'SUB_MODULO': e.sub_modulo,
        'MENU': e.menu,
        'TIPO': e.tipo,
        'BAJA': 'baja logica con HABILITADO = 0' if e.usa_baja_logica else 'borrado fisico',
        'LISTA': lista,
        'SP_SEL': e.sp_sel,
        'SP_INS': e.sp_ins,
        'SP_UPD': e.sp_upd,
        'SP_DEL': e.sp_del,
        'RUTA_APP_CODE': p.ruta_app_code,
        'CLASE_MODEL': e.clase_model,
        'CLASE_CONTROLLER': e.clase_controller,
        'DIR_CONTROLS': e.dir_controls,
        'DIR_PAGINAS': e.dir_paginas,
        'FKS': fks,
        'FILTROS': bloque_filtros,
        'ENUM_PAISES': ' y `Ver_Todo_Paises`' if e.seguridad_por_pais else '',
        'URL_LISTADO': e.url_pagina_listado,
        'BOTON': 'Deshabilitar' if e.usa_baja_logica else 'Eliminar',
        'MSG_CREADO': e.mensaje('creado'),
        'MSG_ACTUALIZADO': e.mensaje('actualizado'),
        'TAB': e.tab,
    })
