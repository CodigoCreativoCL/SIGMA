# -*- coding: utf-8 -*-
"""
Catalogo de piezas generables.

Cada pieza es un artefacto independiente que se puede activar o desactivar.
Lo usan tanto la interfaz grafica (checkboxes) como la consola (--incluir / --excluir),
para que las dos ofrezcan exactamente las mismas opciones.
"""

# grupo -> (etiqueta del grupo, [(clave de pieza, etiqueta, descripcion)])
GRUPOS = [
    ('bd', 'Base de datos', [
        ('tabla',      'CREATE TABLE',   'Script idempotente de la tabla, indices y constraints'),
        ('sel',        'SP  SEL_',       'Listado y get-by-id (query dinamica @SELECT/@FROM/@WHERE)'),
        ('ins',        'SP  INS_',       'Alta con @ID OUTPUT y validaciones de unicidad'),
        ('upd',        'SP  UPD_',       'Modificacion con ISNULL(@PARAM, columna)'),
        ('del',        'SP  DEL_',       'Baja fisica por @ID'),
    ]),
    ('mvc', 'Capa MVC', [
        ('model',      'Model',          'POCO [Serializable] con columnas, JOIN y filtro_*'),
        ('controller', 'Controller',     'Get/Insert/Update/Delete sobre los SP'),
    ]),
    ('vistas', 'UserControls (.ascx + .ascx.cs)', [
        ('listado',    'Listado (grid)', '<Plural>.ascx  -  RadGrid2, filtros y accion masiva'),
        ('formulario', 'Formulario',     '<Singular>.ascx  -  contenedor de tabs'),
        ('tab',        'Tab de campos',  '<Tab>.ascx  -  campos, combos, Bloqueo y Guardar'),
    ]),
    ('paginas', 'Paginas (.aspx + .aspx.cs)', [
        ('pagina_listado',    'Pagina de listado',    '<Plural>.aspx  -  permisos del menu'),
        ('pagina_formulario', 'Pagina de formulario', '<Singular>.aspx  -  descifra el querystring'),
    ]),
    ('doc', 'Documentacion', [
        ('leeme',      'Checklist',      '_LEEME_<TABLA>.md con los pasos de puesta en marcha'),
    ]),
]

# Todas las claves, en orden de generacion.
TODAS = [clave for _, _, piezas in GRUPOS for clave, _, _ in piezas]

# Alias que se pueden usar en la consola: --incluir bd,mvc
ALIAS = dict([(grupo, [c for c, _, _ in piezas]) for grupo, _, piezas in GRUPOS])
ALIAS['todo'] = list(TODAS)
ALIAS['sp'] = ['sel', 'ins', 'upd', 'del']
ALIAS['crud'] = ['model', 'controller']
ALIAS['ui'] = ALIAS['vistas'] + ALIAS['paginas']

# Dependencias logicas: pieza -> piezas de las que depende para compilar/funcionar.
DEPENDENCIAS = {
    'controller':        ['model'],
    'listado':           ['model', 'controller'],
    'tab':               ['model', 'controller'],
    'formulario':        ['tab'],
    'pagina_listado':    ['listado'],
    'pagina_formulario': ['formulario'],
    'sel':               ['tabla'],
    'ins':               ['tabla'],
    'upd':               ['tabla'],
    'del':               ['tabla'],
}

ETIQUETAS = dict([(clave, etiqueta)
                  for _, _, piezas in GRUPOS for clave, etiqueta, _ in piezas])


def expandir(texto):
    """
    Convierte "bd,model" en el conjunto de claves correspondiente.
    Devuelve (conjunto, lista_de_desconocidas).
    """
    claves = set()
    desconocidas = []
    for bruto in (texto or '').replace(';', ',').split(','):
        pieza = bruto.strip().lower()
        if not pieza:
            continue
        if pieza in ALIAS:
            claves.update(ALIAS[pieza])
        elif pieza in TODAS:
            claves.add(pieza)
        else:
            desconocidas.append(bruto.strip())
    return claves, desconocidas


def resolver(incluir=None, excluir=None):
    """
    Devuelve el conjunto final de piezas a generar.
    Sin argumentos -> todas.
    """
    if incluir:
        seleccion, malas_i = expandir(incluir)
    else:
        seleccion, malas_i = set(TODAS), []

    malas_e = []
    if excluir:
        quitar, malas_e = expandir(excluir)
        seleccion -= quitar

    return seleccion, malas_i + malas_e


def faltantes(seleccion):
    """
    Piezas que la seleccion necesita y no estan incluidas.
    No bloquea la generacion: se avisa, porque puede que ya existan en el proyecto.
    """
    avisos = []
    for pieza in sorted(seleccion):
        for requerida in DEPENDENCIAS.get(pieza, []):
            if requerida not in seleccion:
                avisos.append((pieza, requerida))
    return avisos


def nombres_validos():
    return sorted(set(list(TODAS) + list(ALIAS.keys())))
