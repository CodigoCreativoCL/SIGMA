# -*- coding: utf-8 -*-
"""Generacion del Model (POCO) - PATRON_MVC.md seccion 2."""

from nucleo import util


def _prop(tipo_cs, nombre, comentario=None):
    linea = []
    if comentario:
        linea.append('        /// <summary>%s</summary>' % comentario)
    linea.append('        public %s %s { get; set; }' % (tipo_cs, nombre))
    return '\n'.join(linea)


def tipo_filtro(columna):
    """Tipo C# de la propiedad filtro_* asociada a una columna."""
    if columna.tipo.es_texto:
        return 'string'
    if columna.tipo.categoria == 'bool':
        return 'bool?'
    if columna.tipo.categoria == 'largo':
        return 'long?'
    if columna.tipo.categoria == 'decimal':
        return 'decimal?'
    return 'int?'


def generar(d):
    e = d.entidad
    p = d.proyecto

    bloques = []

    # ---- columnas reales ----
    reales = ['        // ------------------------------------------------------------------',
              '        // COLUMNAS REALES DE LA TABLA %s' % e.tabla,
              '        // ------------------------------------------------------------------',
              '',
              _prop('int', e.id_prop, 'PK. Columna %s (IDENTITY).' % e.id_columna)]

    for c in d.columnas:
        comentario = 'Columna %s.' % c.columna
        if c.fk:
            comentario = 'FK a %s. Columna %s.' % (c.fk.tabla, c.columna)
        elif c is d.col_habilitado:
            comentario = ('Columna %s. Baja logica: en tablas maestro NO se borra fisico.'
                          % c.columna)
        elif c.control == 'password':
            comentario = 'Columna %s. Nunca se devuelve en los listados.' % c.columna
        reales.append('')
        reales.append(_prop(c.tipo.tipo_propiedad(not c.requerido), c.prop, comentario))

    bloques.append('\n'.join(reales))

    # ---- auditoria ----
    if e.auditoria:
        bloques.append('\n'.join([
            '        // ------------------------------------------------------------------',
            '        // COLUMNAS DE AUDITORIA (van en TODAS las tablas del patron)',
            '        // ------------------------------------------------------------------',
            '',
            '        public int %s_usuario_creacion { get; set; }' % e.prefijo_lower,
            '        public DateTime? %s_fecha_creacion { get; set; }' % e.prefijo_lower,
            '        public int %s_usuario_act { get; set; }' % e.prefijo_lower,
            '        public DateTime? %s_fecha_act { get; set; }' % e.prefijo_lower,
        ]))

    # ---- campos denormalizados del JOIN ----
    if d.fks:
        join = ['        // ------------------------------------------------------------------',
                '        // CAMPOS DENORMALIZADOS QUE TRAE EL JOIN DEL SP',
                '        // No son columnas de %s: vienen de los JOIN. Sirven para que el' % e.tabla,
                '        // grid muestre el nombre en vez del id.',
                '        // ------------------------------------------------------------------',
                '']
        for c in d.fks:
            join.append('        public string %s { get; set; }   // %s.%s'
                        % (c.fk.prop_denormalizada, c.fk.tabla, c.fk.columna_texto))
        bloques.append('\n'.join(join))

    # ---- filtros ----
    filtros = ['        // ------------------------------------------------------------------',
               '        // CAMPOS DE FILTRO (NO EXISTEN EN LA TABLA)',
               '        // Solo los lee el Controller para decidir que parametros le manda',
               '        // al SP %s. Son nullable para poder preguntar si vienen informados.' % e.sp_sel,
               '        // ------------------------------------------------------------------',
               '']

    if d.columnas_busqueda:
        campos = ', '.join(util.sin_acentos(c.etiqueta).lower() for c in d.columnas_busqueda)
        filtros.append(_prop('string', 'filtro',
                             'Texto libre de la barra de busqueda: busca en %s.' % campos))
        filtros.append('')

    if e.habilitado:
        filtros.append(_prop('bool?', 'filtro_habilitado',
                             'null = todos, true = solo habilitados, false = solo deshabilitados.'))
        filtros.append('')

    for c in d.columnas_filtro:
        filtros.append(_prop(tipo_filtro(c), 'filtro_' + c.nombre.lower(),
                             'Filtro por %s (combo de la barra de filtros).'
                             % util.sin_acentos(c.etiqueta).lower()))
        filtros.append('')

    if e.seguridad_por_pais:
        filtros.append(_prop('string', 'filtro_paises',
                             'CSV de paises a los que el usuario logueado tiene acceso.'))
        filtros.append('')

    if len(filtros) > 6:
        bloques.append('\n'.join(filtros).rstrip())

    cuerpo = '\n\n'.join(bloques)

    plantilla = r'''using System;

namespace {{NS_MODEL}}
{
    /// <summary>
    /// MODEL (POCO) de la entidad {{TABLA}}.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 2):
    ///  1. Namespace {{NS_MODEL}}.
    ///  2. Clase [Serializable] porque viaja en ViewState / Session.
    ///  3. SOLO datos. Cero logica, cero acceso a BD, cero validaciones.
    ///  4. Nombre de propiedad = nombre de columna EN MINUSCULAS, con el
    ///     prefijo de 3 letras de la tabla ({{PREFIJO_LOWER}}_).
    ///  5. Ademas de las columnas reales se agregan campos "filtro_*" que NO
    ///     existen en la tabla: solo los usa el Controller para armar los
    ///     parametros del Stored Procedure {{SP_SEL}}.
    ///
    /// ARCHIVO GENERADO por 03-Generador. Si cambia la tabla, regeneralo.
    /// </summary>
    [Serializable]
    public class {{CLASE}}
    {
{{CUERPO}}
    }
}'''

    return util.render(plantilla, {
        'NS_MODEL': p.ns_model,
        'TABLA': e.tabla,
        'PREFIJO_LOWER': e.prefijo_lower,
        'SP_SEL': e.sp_sel,
        'CLASE': e.clase_model,
        'CUERPO': cuerpo,
    })
