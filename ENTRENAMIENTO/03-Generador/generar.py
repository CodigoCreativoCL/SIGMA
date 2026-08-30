# -*- coding: utf-8 -*-
"""
GENERADOR DE MANTENEDORES  -  patron WebForms + MVC propio (FacilityGes / SIGMA)

A partir de un JSON con la tabla y sus columnas genera, listo para copiar:

    BD/        00_TBL_  01_SEL_  02_INS_  03_UPD_  04_DEL_   (.sql)
    App_Code/  Model + Controller                            (.cs)
    View/      Controls: listado, formulario y tab           (.ascx + .ascx.cs)
    View/      Paginas:  listado y formulario                (.aspx + .aspx.cs)

Todo en UTF-8 con BOM y CRLF, como exige el patron.

USO
    python generar.py --definicion ejemplos/producto.json
    python generar.py --definicion mi.json --salida C:\\Temp\\Salida --forzar
    python generar.py --asistente
    python generar.py --ejemplo mi_entidad.json
    python generar.py --validar mi.json
    python generar.py --tipos
"""

from __future__ import print_function

import argparse
import codecs
import datetime
import io
import json
import os
import sys

RAIZ = os.path.dirname(os.path.abspath(__file__))
if RAIZ not in sys.path:
    sys.path.insert(0, RAIZ)

from nucleo import definicion as defmod          # noqa: E402
from nucleo import piezas                        # noqa: E402
from nucleo.escritor import Escritor             # noqa: E402
from nucleo.tipos import tipos_soportados        # noqa: E402
from plantillas import sql, modelo, controlador  # noqa: E402
from plantillas import vistas, paginas, documentacion  # noqa: E402


# ---------------------------------------------------------------------------
# Consola: en Windows la consola suele ser cp1252 y revienta con acentos.
# ---------------------------------------------------------------------------
def _p(texto=''):
    try:
        print(texto)
    except UnicodeEncodeError:
        print(texto.encode('ascii', 'replace').decode('ascii'))


# ===========================================================================
# GENERACION
# ===========================================================================
def generar(d, carpeta_salida, forzar=False, seleccion=None):
    """
    Escribe los archivos de las piezas seleccionadas.
    seleccion = None -> todas (ver nucleo/piezas.py).
    """
    e = d.entidad
    p = d.proyecto
    activas = set(piezas.TODAS) if seleccion is None else set(seleccion)

    escritor = Escritor(carpeta_salida, forzar=forzar)

    def _si(clave, ruta, contenido):
        if clave in activas:
            escritor.escribir(ruta, contenido())

    # ---------------- BD ----------------
    _si('tabla', '%s/00_TBL_%s.sql' % (p.ruta_bd, e.tabla), lambda: sql.tabla(d))
    _si('sel', '%s/01_%s.sql' % (p.ruta_bd, e.sp_sel), lambda: sql.sel(d))
    _si('ins', '%s/02_%s.sql' % (p.ruta_bd, e.sp_ins), lambda: sql.ins(d))
    _si('upd', '%s/03_%s.sql' % (p.ruta_bd, e.sp_upd), lambda: sql.upd(d))
    _si('del', '%s/04_%s.sql' % (p.ruta_bd, e.sp_del), lambda: sql.dele(d))

    # ---------------- App_Code ----------------
    _si('model', '%s/Model/%s.cs' % (p.ruta_app_code, e.clase_model),
        lambda: modelo.generar(d))
    _si('controller', '%s/Controller/%s.cs' % (p.ruta_app_code, e.clase_controller),
        lambda: controlador.generar(d))

    # ---------------- UserControls ----------------
    _si('listado', '%s/%s.ascx' % (e.dir_controls, e.plural),
        lambda: vistas.listado_ascx(d))
    _si('listado', '%s/%s.ascx.cs' % (e.dir_controls, e.plural),
        lambda: vistas.listado_cs(d))
    _si('formulario', '%s/%s.ascx' % (e.dir_controls, e.singular),
        lambda: vistas.formulario_ascx(d))
    _si('formulario', '%s/%s.ascx.cs' % (e.dir_controls, e.singular),
        lambda: vistas.formulario_cs(d))
    _si('tab', '%s/%s.ascx' % (e.dir_controls, e.tab), lambda: vistas.tab_ascx(d))
    _si('tab', '%s/%s.ascx.cs' % (e.dir_controls, e.tab), lambda: vistas.tab_cs(d))

    # ---------------- Paginas ----------------
    _si('pagina_listado', '%s/%s.aspx' % (e.dir_paginas, e.plural),
        lambda: paginas.listado_aspx(d))
    _si('pagina_listado', '%s/%s.aspx.cs' % (e.dir_paginas, e.plural),
        lambda: paginas.listado_aspx_cs(d))
    _si('pagina_formulario', '%s/%s.aspx' % (e.dir_paginas, e.singular),
        lambda: paginas.formulario_aspx(d))
    _si('pagina_formulario', '%s/%s.aspx.cs' % (e.dir_paginas, e.singular),
        lambda: paginas.formulario_aspx_cs(d))

    # ---------------- Checklist ----------------
    if 'leeme' in activas:
        generados = list(escritor.escritos) + list(escritor.omitidos)
        escritor.escribir('_LEEME_%s.md' % e.tabla,
                          documentacion.leeme(d, sorted(generados)))

    return escritor


def _fechar(d):
    ahora = datetime.datetime.now()
    if not d.proyecto.fecha:
        d.proyecto.fecha = ahora.strftime('%d-%m-%Y')
    d.proyecto.fecha_hora = ahora.strftime('%d-%m-%Y %H:%M:%S')


def _resumen(d, escritor, carpeta, seleccion=None):
    e = d.entidad
    activas = set(piezas.TODAS) if seleccion is None else set(seleccion)
    _p()
    _p('=' * 74)
    _p('  %s (%s)  ->  %d archivos' % (e.singular, e.tabla, escritor.total))
    _p('=' * 74)
    if activas != set(piezas.TODAS):
        _p('  Piezas     : %s' % ', '.join(k for k in piezas.TODAS if k in activas))
    _p('  Salida     : %s' % os.path.abspath(carpeta))
    _p('  Namespaces : %s / %s' % (d.proyecto.ns_model, d.proyecto.ns_controller))
    _p('  Columnas   : %d  (grid: %d, formulario: %d, filtros: %d, FK: %d)'
       % (len(d.columnas), len(d.columnas_grid), len(d.columnas_formulario),
          len(d.columnas_filtro), len(d.fks)))
    _p('  Baja       : %s' % ('logica (HABILITADO = 0)' if e.usa_baja_logica
                              else 'fisica (DELETE)'))

    if d.prefijos_en_conflicto:
        _p('-' * 74)
        _p('  AVISO: %s comparte el prefijo "%s_" con: %s'
           % (e.tabla, e.prefijo, ', '.join(d.prefijos_en_conflicto)))
        _p('         El patron pide un prefijo distinto por tabla. Se calificaron')
        _p('         las columnas con "%s." para que el SEL no quede ambiguo,' % e.tabla)
        _p('         pero conviene revisar el prefijo de la entidad.')

    avisos = piezas.faltantes(activas)
    if avisos:
        _p('-' * 74)
        for pieza, requerida in avisos:
            _p('  NOTA: "%s" necesita "%s", que no se genero en esta corrida.'
               % (piezas.ETIQUETAS[pieza], piezas.ETIQUETAS[requerida]))
        _p('        Si ya existe en el proyecto, ignora este aviso.')

    _p('-' * 74)

    for a in escritor.escritos:
        _p('  [OK]   %s' % a)
    for a in escritor.omitidos:
        _p('  [SKIP] %s  (ya existe, usa --forzar)' % a)

    _p('-' * 74)
    if 'leeme' in activas:
        _p('  Siguiente paso: leer _LEEME_%s.md' % e.tabla)
    _p('=' * 74)
    _p()


# ===========================================================================
# PLANTILLA DE EJEMPLO
# ===========================================================================
EJEMPLO = {
    "proyecto": {
        "baseDatos": "SIGMA",
        "namespace": "Sigma",
        "autor": "EQUIPO CODIGO CREATIVO",
        "master": "~/Master/Default.master",
        "rutaAppCode": "App_Code/MVC/Sigma",
        "rutaView": "View"
    },
    "entidad": {
        "tabla": "PRODUCTO",
        "prefijo": "PRO",
        "singular": "Producto",
        "plural": "Productos",
        "modulo": "Inventario",
        "subModulo": "Productos",
        "menu": "menu_12",
        "tituloListado": "Productos",
        "tituloFormulario": "Ficha de Producto",
        "tipo": "maestro",
        "auditoria": True,
        "habilitado": True,
        "seguridadPorPais": False
    },
    "columnas": [
        {
            "nombre": "CODIGO",
            "tipo": "NVARCHAR(20)",
            "requerido": True,
            "etiqueta": "Codigo",
            "unico": True,
            "upperCase": True
        },
        {
            "nombre": "NOMBRE",
            "tipo": "NVARCHAR(200)",
            "requerido": True,
            "etiqueta": "Nombre"
        },
        {
            "nombre": "DESCRIPCION",
            "tipo": "NVARCHAR(MAX)",
            "requerido": False,
            "etiqueta": "Descripcion",
            "control": "textarea"
        },
        {
            "nombre": "CATEGORIA",
            "tipo": "INT",
            "requerido": True,
            "etiqueta": "Categoria",
            "fk": {
                "tabla": "CATEGORIA",
                "prefijo": "CAT",
                "modelo": "Categoria",
                "controller": "CategoriaController",
                "metodoLista": "GetCategorias"
            }
        },
        {
            "nombre": "PRECIO",
            "tipo": "DECIMAL(18,2)",
            "requerido": True,
            "etiqueta": "Precio"
        }
    ]
}


def escribir_ejemplo(ruta):
    if os.path.exists(ruta):
        _p('Ya existe: %s' % ruta)
        return 1
    carpeta = os.path.dirname(os.path.abspath(ruta))
    if carpeta and not os.path.isdir(carpeta):
        os.makedirs(carpeta)
    with io.open(ruta, 'w', encoding='utf-8') as f:
        f.write(json.dumps(EJEMPLO, indent=2, ensure_ascii=False))
    _p('Plantilla de definicion creada: %s' % os.path.abspath(ruta))
    _p('Editala y despues: python generar.py --definicion %s' % ruta)
    return 0


# ===========================================================================
# MAIN
# ===========================================================================
def main(argv=None):
    parser = argparse.ArgumentParser(
        prog='generar.py',
        description='Generador de mantenedores (tabla + SP + Model + Controller + vistas).',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Ejemplos:\n'
               '  python generar.py --definicion ejemplos/producto.json\n'
               '  python generar.py --asistente\n'
               '  python generar.py --ejemplo mi_entidad.json\n')

    parser.add_argument('-d', '--definicion', help='JSON con la definicion de la entidad.')
    parser.add_argument('-p', '--proyecto', help='JSON con la configuracion comun del proyecto.')
    parser.add_argument('-s', '--salida', help='Carpeta de salida (por defecto ./salida/<TABLA>).')
    parser.add_argument('-f', '--forzar', action='store_true',
                        help='Sobreescribe los archivos que ya existan.')
    parser.add_argument('-a', '--asistente', action='store_true',
                        help='Modo interactivo: arma la definicion preguntando.')
    parser.add_argument('-e', '--ejemplo', metavar='ARCHIVO',
                        help='Escribe una definicion de ejemplo para editar.')
    parser.add_argument('-v', '--validar', metavar='ARCHIVO',
                        help='Valida una definicion sin generar nada.')
    parser.add_argument('-t', '--tipos', action='store_true',
                        help='Lista los tipos SQL soportados.')
    parser.add_argument('-i', '--incluir', metavar='PIEZAS',
                        help='Genera SOLO estas piezas. Ej: --incluir bd  |  '
                             '--incluir model,controller  |  --incluir vistas,paginas')
    parser.add_argument('-x', '--excluir', metavar='PIEZAS',
                        help='Genera todo MENOS estas piezas. Ej: --excluir bd,leeme')
    parser.add_argument('--piezas', action='store_true',
                        help='Lista las piezas y los alias disponibles.')

    args = parser.parse_args(argv)

    if args.tipos:
        _p('Tipos SQL soportados:')
        _p('  ' + ', '.join(tipos_soportados()))
        return 0

    if args.piezas:
        _p('Piezas generables (--incluir / --excluir):')
        for _, etiqueta_grupo, lista in piezas.GRUPOS:
            _p('')
            _p('  %s' % etiqueta_grupo)
            for clave, etiqueta, descripcion in lista:
                _p('    %-20s %-18s %s' % (clave, etiqueta, descripcion))
        _p('')
        _p('Alias de grupo: %s' % ', '.join(sorted(piezas.ALIAS)))
        return 0

    if args.ejemplo:
        return escribir_ejemplo(args.ejemplo)

    if args.validar:
        try:
            d = defmod.cargar(args.validar, args.proyecto)
        except defmod.ErrorDefinicion as ex:
            _p('ERROR: %s' % ex)
            return 1
        _p('Definicion valida: %s (%s), %d columnas.'
           % (d.entidad.singular, d.entidad.tabla, len(d.columnas)))
        return 0

    if args.asistente:
        from nucleo import asistente
        datos = asistente.ejecutar()
        if datos is None:
            return 1
        try:
            d = defmod.Definicion(datos)
        except defmod.ErrorDefinicion as ex:
            _p('ERROR: %s' % ex)
            return 1
        ruta_def = os.path.join(RAIZ, 'definiciones', '%s.json' % d.entidad.tabla.lower())
        carpeta = os.path.dirname(ruta_def)
        if not os.path.isdir(carpeta):
            os.makedirs(carpeta)
        with io.open(ruta_def, 'w', encoding='utf-8') as f:
            f.write(json.dumps(datos, indent=2, ensure_ascii=False))
        _p('Definicion guardada en: %s' % ruta_def)
    else:
        if not args.definicion:
            parser.print_help()
            return 1
        try:
            d = defmod.cargar(args.definicion, args.proyecto)
        except defmod.ErrorDefinicion as ex:
            _p('ERROR: %s' % ex)
            return 1

    _fechar(d)

    seleccion, desconocidas = piezas.resolver(args.incluir, args.excluir)
    if desconocidas:
        _p('ERROR: pieza desconocida: %s' % ', '.join(desconocidas))
        _p('Piezas validas: %s' % ', '.join(piezas.nombres_validos()))
        return 1
    if not seleccion:
        _p('ERROR: la seleccion de piezas quedo vacia.')
        return 1

    carpeta = (args.salida or d.proyecto.salida or
               os.path.join(RAIZ, 'salida', d.entidad.tabla))

    try:
        escritor = generar(d, carpeta, forzar=args.forzar, seleccion=seleccion)
    except Exception as ex:                        # noqa: BLE001
        _p('ERROR generando: %s' % ex)
        raise

    _resumen(d, escritor, carpeta, seleccion)
    return 0


if __name__ == '__main__':
    sys.exit(main())
