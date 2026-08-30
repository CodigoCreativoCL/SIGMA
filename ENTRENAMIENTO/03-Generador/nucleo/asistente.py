# -*- coding: utf-8 -*-
"""
Modo interactivo: arma el JSON de definicion preguntando por consola.
Pensado para el que no quiere escribir JSON a mano.
"""

from __future__ import print_function

import os

from .tipos import Tipo, tipos_soportados
from . import util


def _p(texto=''):
    try:
        print(texto)
    except UnicodeEncodeError:
        print(texto.encode('ascii', 'replace').decode('ascii'))


def _pregunta(texto, defecto=None, obligatorio=True):
    sufijo = ' [%s]' % defecto if defecto not in (None, '') else ''
    while True:
        try:
            valor = input('%s%s: ' % (texto, sufijo)).strip()
        except (EOFError, KeyboardInterrupt):
            _p('\nCancelado.')
            raise SystemExit(1)
        if not valor and defecto is not None:
            return defecto
        if valor:
            return valor
        if not obligatorio:
            return ''
        _p('  * Este dato es obligatorio.')


def _si_no(texto, defecto=True):
    d = 's' if defecto else 'n'
    while True:
        valor = _pregunta('%s (s/n)' % texto, d).lower()
        if valor in ('s', 'si', 'y', 'yes'):
            return True
        if valor in ('n', 'no'):
            return False
        _p('  * Responde s o n.')


def _opcion(texto, opciones, defecto):
    while True:
        valor = _pregunta('%s (%s)' % (texto, '/'.join(opciones)), defecto).lower()
        if valor in opciones:
            return valor
        _p('  * Opciones validas: %s' % ', '.join(opciones))


def ejecutar():
    _p()
    _p('=' * 74)
    _p('  ASISTENTE DE GENERACION DE MANTENEDORES')
    _p('  Enter = aceptar el valor entre corchetes.')
    _p('=' * 74)

    # --------------------------------------------------------------- proyecto
    _p()
    _p('--- 1. PROYECTO ---')
    proyecto = {
        'baseDatos': _pregunta('Base de datos', 'SIGMA').upper(),
        'namespace': _pregunta('Namespace raiz (ej. Sigma -> Sigma.Model / Sigma.Controller)', 'Sigma'),
        'autor': _pregunta('Autor para el encabezado de los SP', 'EQUIPO CODIGO CREATIVO'),
    }
    proyecto['rutaAppCode'] = _pregunta('Ruta de App_Code',
                                        'App_Code/MVC/%s' % proyecto['namespace'])
    proyecto['rutaView'] = _pregunta('Ruta de View', 'View')
    proyecto['master'] = _pregunta('MasterPage', '~/Master/Default.master')

    # --------------------------------------------------------------- entidad
    _p()
    _p('--- 2. ENTIDAD ---')
    tabla = _pregunta('Nombre de la tabla (MAYUSCULAS, ej. PRODUCTO)').upper()
    prefijo = _pregunta('Prefijo de 3 letras de las columnas', tabla[:3]).upper()
    singular = _pregunta('Nombre singular en codigo (ej. Producto)', util.pascal(tabla))
    plural = _pregunta('Nombre plural en codigo (ej. Productos)', singular + 's')

    entidad = {
        'tabla': tabla,
        'prefijo': prefijo,
        'singular': singular,
        'plural': plural,
        'modulo': _pregunta('Modulo (carpeta bajo View/, ej. Inventario)', 'Comun'),
        'subModulo': _pregunta('Submodulo (carpeta de las paginas)', plural),
        'menu': _pregunta('Menu de permisos en SitioBase.Paginas', 'menu_1'),
        'tituloListado': _pregunta('Titulo de la pagina de listado', plural),
        'tituloFormulario': _pregunta('Titulo de la pagina de formulario',
                                      'Ficha de ' + singular),
        'tipo': _opcion('Tipo de tabla', ['maestro', 'detalle'], 'maestro'),
        'auditoria': _si_no('Lleva columnas de auditoria', True),
        'habilitado': _si_no('Lleva columna HABILITADO (baja logica)', True),
        'seguridadPorPais': _si_no('Filtra por pais del usuario logueado', False),
    }
    if entidad['seguridadPorPais']:
        entidad['columnaPais'] = _pregunta(
            'Nombre de la columna de pais (sin prefijo)', 'PAIS').upper()

    # -------------------------------------------------------------- columnas
    _p()
    _p('--- 3. COLUMNAS ---')
    _p('No declares ID ni las de auditoria ni HABILITADO: se agregan solas.')
    _p('Enter en el nombre para terminar.')
    _p('Tipos: %s' % ', '.join(tipos_soportados()))

    columnas = []
    while True:
        _p()
        nombre = _pregunta('Columna #%d (sin el prefijo %s_)' % (len(columnas) + 1, prefijo),
                           '', obligatorio=False)
        if not nombre:
            if columnas:
                break
            _p('  * Necesitas al menos una columna.')
            continue

        nombre = nombre.upper()
        col = {'nombre': nombre}

        while True:
            tipo_txt = _pregunta('  Tipo SQL', 'NVARCHAR(200)').upper()
            try:
                tipo = Tipo(tipo_txt)
                break
            except ValueError as ex:
                _p('  * %s' % ex)
        col['tipo'] = tipo_txt

        col['requerido'] = _si_no('  Obligatorio (NOT NULL)', True)
        col['etiqueta'] = _pregunta('  Etiqueta en pantalla', util.titulo(nombre))

        if _si_no('  Es FK a otra tabla', tipo.categoria == 'entero' and nombre.endswith('ID')):
            tabla_fk = _pregunta('    Tabla referenciada').upper()
            fk = {'tabla': tabla_fk}
            fk['prefijo'] = _pregunta('    Prefijo de esa tabla', tabla_fk[:3]).upper()
            fk['columna'] = _pregunta('    Columna PK de esa tabla', fk['prefijo'] + '_ID').upper()
            fk['columnaTexto'] = _pregunta('    Columna a mostrar en el combo/grid',
                                           fk['prefijo'] + '_NOMBRE').upper()
            fk['modelo'] = _pregunta('    Clase Model', util.pascal(tabla_fk))
            fk['controller'] = _pregunta('    Clase Controller', fk['modelo'] + 'Controller')
            fk['metodoLista'] = _pregunta('    Metodo que devuelve la lista',
                                          'Get' + fk['modelo'] + 's')
            fk['filtroHabilitado'] = _opcion('    Tipo de filtro_habilitado en ese Model',
                                             ['bool', 'string', 'none'], 'bool')
            col['fk'] = fk
        else:
            control_sugerido = tipo.control_sugerido(nombre)
            col['control'] = _opcion('  Control de pantalla',
                                     ['texto', 'textarea', 'numero', 'check',
                                      'fecha', 'password', 'ninguno'],
                                     control_sugerido)
            if col['control'] == 'texto':
                if _si_no('  Convertir a MAYUSCULAS al escribir', False):
                    col['upperCase'] = True
                elif _si_no('  Convertir a minusculas al escribir', False):
                    col['lowerCase'] = True

        if tipo.es_texto and not col.get('fk'):
            col['unico'] = _si_no('  Valor unico (genera validacion + indice UX_)', False)

        col['grid'] = _si_no('  Se muestra en el listado', True)

        columnas.append(col)

    _p()
    _p('--- RESUMEN ---')
    _p('  Tabla    : %s (%s_)' % (tabla, prefijo))
    _p('  Clases   : %s.Model.%s / %s.Controller.%sController'
       % (proyecto['namespace'], singular, proyecto['namespace'], singular))
    _p('  Vistas   : %s/%s/Controls/%s/  y  %s/%s/%s/'
       % (proyecto['rutaView'], entidad['modulo'], singular,
          proyecto['rutaView'], entidad['modulo'], entidad['subModulo']))
    _p('  Columnas : %d' % len(columnas))
    for c in columnas:
        _p('     - %s_%s  %s%s' % (prefijo, c['nombre'], c['tipo'],
                                   '  (FK -> %s)' % c['fk']['tabla'] if c.get('fk') else ''))
    _p()

    if not _si_no('Generar ahora', True):
        _p('Cancelado.')
        return None

    return {'proyecto': proyecto, 'entidad': entidad, 'columnas': columnas}
