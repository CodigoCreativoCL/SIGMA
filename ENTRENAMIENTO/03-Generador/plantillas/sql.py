# -*- coding: utf-8 -*-
"""
Generacion de los scripts SQL: tabla + SEL / INS / UPD / DEL.
Sigue al pie de la letra 00-Patrones-Originales/PATRON_SP.md.
"""

from nucleo import util

_ENCABEZADO = r'''USE [{{BD}}]
GO
/****** Objeto:  {{OBJETO}} [dbo].[{{NOMBRE}}]    Fecha de script: {{FECHA_HORA}} ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          {{AUTOR}}
-- FECHA CREACION:  {{FECHA}}
-- DESCRIPTION:     {{DESCRIPCION}}
-- ============================================='''


def _encabezado(d, objeto, nombre, descripcion):
    return util.render(_ENCABEZADO, {
        'BD': d.proyecto.base_datos,
        'OBJETO': objeto,
        'NOMBRE': nombre,
        'FECHA_HORA': d.proyecto.fecha_hora,
        'AUTOR': d.proyecto.autor,
        'FECHA': d.proyecto.fecha,
        'DESCRIPCION': descripcion,
    })


def _param_sql(columna, obligatorio):
    """Fila de la lista de parametros de un SP: (nombre, tipo, default)."""
    defecto = '' if obligatorio else '= NULL'
    return [columna.param, columna.tipo.sql, defecto]


def _valor_variables(col):
    """Convierte un parametro a VARCHAR para armar @VARIABLES de INS_EXCEPCION."""
    if col.tipo.es_texto:
        return "ISNULL(%s, '')" % col.param
    if col.tipo.categoria == 'fecha':
        return "ISNULL(CONVERT(VARCHAR(20), %s, 103), '')" % col.param
    if col.tipo.categoria == 'bool':
        return "LTRIM(STR(CONVERT(INT, %s)))" % col.param
    return "LTRIM(STR(%s))" % col.param


def _bloque_variables(d, sp, columnas, incluir_id=False):
    """Arma el SET @VARIABLES = 'SP ' + '@X = ' + ... del INS_EXCEPCION."""
    piezas = ["'%s '" % sp]
    if incluir_id:
        piezas.append("'@ID = ' + LTRIM(STR(@ID))")
    for col in columnas:
        piezas.append("'%s = ' + %s" % (col.param, _valor_variables(col)))

    if len(piezas) == 1:
        return '        SET @VARIABLES = ' + piezas[0]

    lineas = ['        SET @VARIABLES = ' + piezas[0] + ' +']
    for i, pieza in enumerate(piezas[1:], start=1):
        conector = " + ',' +" if i < len(piezas) - 1 else ''
        lineas.append('                         ' + pieza + conector)
    return '\n'.join(lineas)


# ===========================================================================
# 00 - TABLA
# ===========================================================================
def tabla(d):
    e = d.entidad
    filas = [['[%s]' % e.id_columna, 'INT', 'NOT NULL IDENTITY(1,1),']]

    def _fila(c):
        extra = c.nullable_sql
        if c.defecto is not None:
            extra += ' CONSTRAINT DF_%s DEFAULT %s' % (c.columna, c.defecto)
        return ['[%s]' % c.columna, c.tipo.sql, extra + ',']

    for c in d.columnas:
        if c is d.col_habilitado:
            continue                     # va al final, despues de la auditoria
        filas.append(_fila(c))

    if e.auditoria:
        filas.append(['[%s_USUARIO_CREACION]' % e.prefijo, 'INT', 'NOT NULL,'])
        filas.append(['[%s_FECHA_CREACION]' % e.prefijo, 'DATETIME',
                      'NOT NULL CONSTRAINT DF_%s_FECHA_CREACION DEFAULT GETDATE(),' % e.prefijo])
        filas.append(['[%s_USUARIO_ACT]' % e.prefijo, 'INT', 'NULL,'])
        filas.append(['[%s_FECHA_ACT]' % e.prefijo, 'DATETIME', 'NULL,'])

    if d.col_habilitado:
        filas.append(_fila(d.col_habilitado))

    cuerpo = ['        ' + l for l in util.alinear(filas, separador='  ')]

    # --- Constraints ---
    constraints = ['        CONSTRAINT PK_%s PRIMARY KEY CLUSTERED ([%s] ASC)'
                   % (e.tabla, e.id_columna)]
    for c in d.fks:
        constraints.append(
            '        CONSTRAINT FK_%s_%s FOREIGN KEY ([%s])\n'
            '            REFERENCES [dbo].[%s] ([%s])'
            % (e.prefijo, c.nombre, c.columna, c.fk.tabla, c.fk.columna))

    # --- Indices ---
    indices = []
    for c in d.columnas:
        if c.unico:
            indices.append(
                '    -- %s no puede repetirse.\n'
                '    CREATE UNIQUE NONCLUSTERED INDEX UX_%s_%s\n'
                '        ON [dbo].[%s] ([%s])'
                % (c.etiqueta, e.prefijo, c.nombre, e.tabla, c.columna))
        elif c.indice:
            indices.append(
                '    -- Indice de apoyo a los filtros del listado.\n'
                '    CREATE NONCLUSTERED INDEX IX_%s_%s\n'
                '        ON [dbo].[%s] ([%s])'
                % (e.prefijo, c.nombre, e.tabla, c.columna))

    partes = [
        _encabezado(d, 'Table', e.tabla,
                    'CREA LA TABLA %s DE %s.'
                    % ('MAESTRA' if e.tipo == 'maestro' else 'DE DETALLE',
                       util.sin_acentos(e.plural).upper())),
        '',
        '-- ---------------------------------------------------------------------------',
        '-- PATRON: PATRON_SP.md seccion 8.',
        '--  1. Script IDEMPOTENTE (se puede re-ejecutar sin error).',
        '--  2. Prefijo de 3 letras en todas las columnas: %s -> %s_' % (e.tabla, e.prefijo),
        '--  3. Columnas de auditoria%s.'
        % (' + %s (baja logica)' % e.col_habilitado if d.col_habilitado else ''),
        '--  4. Constraints con nombre explicito: PK_ FK_ DF_ IX_ UX_',
        '-- ---------------------------------------------------------------------------',
        '',
        'IF NOT EXISTS (',
        '    SELECT 1 FROM sys.objects',
        "    WHERE object_id = OBJECT_ID(N'[dbo].[%s]')" % e.tabla,
        "    AND type = 'U'",
        ')',
        'BEGIN',
        '    CREATE TABLE [dbo].[%s]' % e.tabla,
        '    (',
        '\n'.join(cuerpo),
        '',
        ',\n\n'.join(constraints),
        '    )',
        '',
    ]

    if indices:
        partes.append('\n\n'.join(indices))
        partes.append('')

    partes.extend([
        "    PRINT 'Tabla %s creada correctamente.'" % e.tabla,
        'END',
        'ELSE',
        "    PRINT 'Tabla %s ya existe.'" % e.tabla,
        'GO',
    ])

    return '\n'.join(partes)


# ===========================================================================
# 01 - SEL
# ===========================================================================
def sel(d):
    e = d.entidad

    # --- Parametros ---
    filas = [['@ID', 'INT', '= NULL']]
    if d.columnas_busqueda:
        filas.append(['@FILTRO', 'VARCHAR(MAX)', '= NULL'])
    if e.habilitado:
        filas.append(['@HABILITADO', 'BIT', '= NULL'])
    for c in d.columnas_filtro:
        filas.append([c.param, c.tipo.sql, '= NULL'])
    if e.seguridad_por_pais:
        filas.append(['@PAISES', 'VARCHAR(MAX)', '= NULL'])

    params = util.alinear(filas, separador=' ')
    params = ',\n'.join('    ' + p for p in params)

    # Cuando una tabla de FK comparte prefijo con la entidad, las columnas sin
    # calificar quedan ambiguas: se antepone "TABLA." a las columnas propias.
    q = d.calificador

    # --- SELECT ---
    prefijo_sel = "    SET @SELECT = 'SELECT DISTINCT  "
    sangria = ' ' * (len(prefijo_sel) - 1)

    seleccion = [q + e.id_columna]
    for c in d.columnas:
        if c is d.col_habilitado:
            continue
        if c.control == 'password':
            continue          # NUNCA se devuelve una password en el SELECT
        seleccion.append(_columna_select(c, q))
    for c in d.fks:
        seleccion.append(c.fk.columna_select)
    if e.auditoria:
        seleccion.extend([q + '%s_USUARIO_CREACION' % e.prefijo,
                          q + '%s_FECHA_CREACION' % e.prefijo,
                          q + '%s_USUARIO_ACT' % e.prefijo,
                          q + '%s_FECHA_ACT' % e.prefijo])
    if d.col_habilitado:
        seleccion.append(q + d.col_habilitado.columna)

    lineas_sel = [prefijo_sel + seleccion[0]]
    for col in seleccion[1:]:
        lineas_sel.append(sangria + ',' + col)
    lineas_sel.append(sangria + "'")

    # --- FROM ---
    prefijo_from = "    SET @FROM = ' FROM " + e.tabla
    sangria_from = ' ' * (len("    SET @FROM = ' "))
    lineas_from = [prefijo_from]
    for c in d.fks:
        tipo_join = 'INNER JOIN' if c.requerido else 'LEFT JOIN '
        if c.fk.alias_tabla:
            destino = '%s AS %s' % (c.fk.tabla, c.fk.alias_tabla)
            condicion = '%s%s = %s.%s' % (q, c.columna, c.fk.alias_tabla, c.fk.columna)
        else:
            destino = c.fk.tabla
            condicion = '%s%s = %s.%s' % (q, c.columna, c.fk.tabla, c.fk.columna) if q \
                else '%s = %s' % (c.columna, c.fk.columna)
        lineas_from.append('%s%s %s ON %s' % (sangria_from, tipo_join, destino, condicion))
    lineas_from.append(' ' * (len(sangria_from) - 2) + "'")

    # --- WHERE ---
    w = []
    w.append("    SET @WHERE = ' WHERE 1=1")
    w.append(' ' * len("    SET @WHERE = ") + "'")
    w.append('')
    w.append('    IF (@ID IS NOT NULL) BEGIN')
    w.append("        SET @WHERE = @WHERE + ' AND %s%s = ' + LTRIM(@ID)" % (q, e.id_columna))
    w.append('    END')

    for c in d.columnas_filtro:
        w.append('')
        w.append('    IF (%s IS NOT NULL) BEGIN' % c.param)
        if c.tipo.es_texto:
            w.append("        SET @WHERE = @WHERE + ' AND %s%s = ''' + %s + ''''"
                     % (q, c.columna, c.param))
        else:
            w.append("        SET @WHERE = @WHERE + ' AND %s%s = ' + LTRIM(%s)"
                     % (q, c.columna, c.param))
        w.append('    END')

    if e.seguridad_por_pais:
        col_pais = '%s_%s' % (e.prefijo, e.columna_pais)
        w.append('')
        w.append('    -- Seguridad por pais: @PAISES llega como CSV ("1,3,7") desde')
        w.append('    -- Session.UsuarioIdPaises() cuando el perfil no tiene "Ver todo paises".')
        w.append('    IF (@PAISES IS NOT NULL) BEGIN')
        w.append("        SET @WHERE = @WHERE + ' AND %s%s IN (' + @PAISES + ')'"
                 % (q, col_pais))
        w.append('    END')

    if e.habilitado:
        w.append('')
        w.append('    IF (@HABILITADO IS NOT NULL) BEGIN')
        w.append("        SET @WHERE = @WHERE + ' AND %s%s = ' + LTRIM(@HABILITADO)"
                 % (q, d.col_habilitado.columna))
        w.append('    END')

    if d.columnas_busqueda:
        cols = [q + c.columna for c in d.columnas_busqueda]
        ancho = max(len(c) for c in cols)
        w.append('')
        w.append('    -- Busqueda libre de la barra de filtros: se aplica sobre varias columnas.')
        w.append('    IF (@FILTRO IS NOT NULL) BEGIN')
        w.append("        SET @WHERE = @WHERE + ' AND (%s LIKE ''%%' + LTRIM(@FILTRO) + '%%''"
                 % cols[0].ljust(ancho))
        for c in cols[1:]:
            w.append("                                  OR %s LIKE ''%%' + LTRIM(@FILTRO) + '%%''"
                     % c.ljust(ancho))
        w.append("                                )'")
        w.append('    END')

    orden = e.orden
    if q:
        orden = ', '.join(
            (q + t.strip()) if t.strip().upper().startswith(e.prefijo + '_') else t.strip()
            for t in orden.split(','))

    w.append('')
    w.append("    SET @WHERE = @WHERE + ' ORDER BY %s '" % orden)

    partes = [
        _encabezado(d, 'StoredProcedure', e.sp_sel,
                    'SELECT DE %s. SIRVE PARA LISTADO Y PARA GET BY ID.'
                    % util.sin_acentos(e.plural).upper()),
        'CREATE OR ALTER PROCEDURE [dbo].[%s]' % e.sp_sel,
        params,
        '',
        'AS',
        'SET NOCOUNT ON',
        '',
        '-- ---------------------------------------------------------------------------',
        '-- PATRON: PATRON_SP.md seccion 4.',
        '--  1. UN SOLO SP para listar y para traer un registro (si viene @ID, filtra).',
        '--  2. Todos los parametros de filtro son "= NULL" (opcionales).',
        '--  3. Query dinamica en 3 bloques: @SELECT / @FROM / @WHERE y un unico EXEC.',
        '--  4. El WHERE arranca con 1=1 para concatenar ANDs sin preguntar.',
        '--  5. NUNCA se devuelven columnas de password en el SELECT.',
        '-- ---------------------------------------------------------------------------',
        '',
        '--SELECT',
        'BEGIN',
        '    DECLARE @SELECT VARCHAR(MAX)',
        '\n'.join(lineas_sel),
        'END',
        '',
        '--FROM',
        'BEGIN',
        '    DECLARE @FROM VARCHAR(MAX)',
        '\n'.join(lineas_from),
        'END',
        '',
        '--WHERE',
        'BEGIN',
        '    DECLARE @WHERE VARCHAR(MAX)',
        '\n'.join(w),
        'END',
        '',
        '--print(@SELECT + @FROM + @WHERE)',
        'EXEC(@SELECT + @FROM + @WHERE)',
        'GO',
    ]
    return '\n'.join(partes)


def _columna_select(c, q=''):
    """Envuelve en ISNULL las columnas opcionales para que el C# nunca reciba DBNull."""
    ref = q + c.columna
    if c.requerido or c.tipo.categoria in ('fecha', 'binario'):
        return ref
    if c.tipo.es_texto:
        # El SELECT viaja dentro de un literal SQL: la comilla simple se duplica.
        return "ISNULL(%s, '''') AS %s" % (ref, c.columna)
    if c.tipo.es_numero or c.tipo.categoria == 'bool':
        return 'ISNULL(%s, 0) AS %s' % (ref, c.columna)
    return ref


# ===========================================================================
# 02 - INS
# ===========================================================================
def ins(d):
    e = d.entidad

    filas = [['@ID', 'INT', '= NULL OUTPUT']]
    for c in d.columnas:
        if c is d.col_habilitado:
            continue
        filas.append(_param_sql(c, c.requerido))
    if d.col_habilitado:
        filas.append(['@HABILITADO', 'BIT', '= 1'])
    filas.append(['@USUARIO', 'INT', ''])

    params = ',\n'.join('    ' + p for p in util.alinear(filas, separador=' '))

    # --- Validaciones de unicidad ---
    validaciones = []
    for i, c in enumerate(d.columnas_unicas, start=1):
        validaciones.append(
            '    IF EXISTS (SELECT 1 FROM %s WHERE %s = %s)\n'
            '    BEGIN\n'
            '        RAISERROR(\'%d.- Ya existe %s %s con %s "%%s".\', 16, 1, %s)\n'
            '        RETURN -1\n'
            '    END'
            % (e.tabla, c.columna, c.param, i,
               'una' if e.genero == 'f' else 'un',
               util.sin_acentos(e.singular).lower(),
               util.sin_acentos(c.etiqueta).lower(), c.param))

    numero_error = len(d.columnas_unicas) + 1

    # --- INSERT ---
    columnas_ins = [c.columna for c in d.columnas]
    valores_ins = [c.param for c in d.columnas]
    if e.auditoria:
        columnas_ins += ['%s_USUARIO_CREACION' % e.prefijo,
                         '%s_FECHA_CREACION' % e.prefijo,
                         '%s_USUARIO_ACT' % e.prefijo,
                         '%s_FECHA_ACT' % e.prefijo]
        valores_ins += ['@USUARIO', 'GETDATE()', '@USUARIO', 'GETDATE()']

    lista_col = util.lista_con_comas(columnas_ins, indentacion=12)
    lista_val = util.lista_con_comas(valores_ins, indentacion=12)

    testigos = [c for c in d.columnas if c.requerido][:3] or d.columnas[:2]

    partes = [
        _encabezado(d, 'StoredProcedure', e.sp_ins,
                    'INSERTA %s %s Y DEVUELVE EL ID GENERADO.'
                    % (e.articulo_mayus, util.sin_acentos(e.singular).upper())),
        'CREATE OR ALTER PROCEDURE [dbo].[%s]' % e.sp_ins,
        params,
        '',
        'AS',
        'SET NOCOUNT ON',
        '',
        '-- ---------------------------------------------------------------------------',
        '-- PATRON: PATRON_SP.md seccion 3.',
        '--  1. @ID INT = NULL OUTPUT primero: devuelve SCOPE_IDENTITY() al C#.',
        '--  2. Validaciones de negocio ANTES del BEGIN TRANSACTION (RAISERROR + RETURN -1).',
        '--     Ese texto es el que ve el usuario final en el ClientAlert.',
        '--  3. Si @@ROWCOUNT = 0 -> ROLLBACK + EXEC INS_EXCEPCION.',
        '--  4. @USUARIO NUNCA lo manda la pantalla: sale de Session.UsuarioId().',
        '-- ---------------------------------------------------------------------------',
        '',
    ]

    if validaciones:
        partes += ['-- Validaciones', 'BEGIN', '\n\n'.join(validaciones), 'END', '']

    partes += [
        'BEGIN TRANSACTION',
        '',
        '    INSERT %s' % e.tabla,
        '        (',
        lista_col,
        '        )',
        '    VALUES',
        '        (',
        lista_val,
        '        )',
        '',
        '    SET @ID = SCOPE_IDENTITY()',
        '',
        '    IF @@ROWCOUNT = 0 BEGIN',
        '        ROLLBACK TRANSACTION',
        '',
        '        DECLARE @VARIABLES VARCHAR(MAX)',
        _bloque_variables(d, e.sp_ins, testigos),
        '',
        '        EXEC INS_EXCEPCION',
        "            @MSG = '%d.- NO FUE POSIBLE INSERTAR %s %s.',"
        % (numero_error, e.articulo_mayus, util.sin_acentos(e.singular).upper()),
        '            @VARIABLES = @VARIABLES',
        '        RETURN -1',
        '    END',
        '',
        'COMMIT TRANSACTION',
        '',
        'RETURN(0)',
        'GO',
    ]
    return '\n'.join(partes)


# ===========================================================================
# 03 - UPD
# ===========================================================================
def upd(d):
    e = d.entidad

    filas = [['@ID', 'INT', '']]
    for c in d.columnas:
        if c is d.col_habilitado:
            continue
        filas.append([c.param, c.tipo.sql, '= NULL'])
    if d.col_habilitado:
        filas.append(['@HABILITADO', 'BIT', '= NULL'])
    filas.append(['@USUARIO', 'INT', ''])

    params = ',\n'.join('    ' + p for p in util.alinear(filas, separador=' '))

    validaciones = []
    for i, c in enumerate(d.columnas_unicas, start=1):
        validaciones.append(
            '    IF EXISTS (SELECT 1 FROM %s WHERE %s = %s AND %s <> @ID)\n'
            '    BEGIN\n'
            '        RAISERROR(\'%d.- Ya existe otro %s con %s "%%s".\', 16, 1, %s)\n'
            '        RETURN -1\n'
            '    END'
            % (e.tabla, c.columna, c.param, e.id_columna, i,
               util.sin_acentos(e.singular).lower(),
               util.sin_acentos(c.etiqueta).lower(), c.param))

    numero_error = len(d.columnas_unicas) + 1

    # --- SET con ISNULL ---
    filas_set = []
    for c in d.columnas:
        filas_set.append([c.columna, '= ISNULL(%s,' % c.param, '%s)' % c.columna])
    if e.auditoria:
        filas_set.append(['%s_USUARIO_ACT' % e.prefijo, '= @USUARIO', ''])
        filas_set.append(['%s_FECHA_ACT' % e.prefijo, '= GETDATE()', ''])

    alineadas = util.alinear(filas_set, separador=' ')
    lineas_set = []
    for i, linea in enumerate(alineadas):
        prefijo = '    SET     ' if i == 0 else '           ,'
        lineas_set.append(prefijo + linea)

    testigos = [c for c in d.columnas if c.requerido][:2]

    partes = [
        _encabezado(d, 'StoredProcedure', e.sp_upd,
                    'ACTUALIZA %s %s EXISTENTE.'
                    % (e.articulo_mayus, util.sin_acentos(e.singular).upper())),
        'CREATE OR ALTER PROCEDURE [dbo].[%s]' % e.sp_upd,
        params,
        '',
        'AS',
        'SET NOCOUNT ON',
        '',
        '-- ---------------------------------------------------------------------------',
        '-- PATRON: PATRON_SP.md seccion 5.',
        '--  1. @ID y @USUARIO son OBLIGATORIOS. El resto es opcional.',
        '--  2. Cada columna se actualiza con ISNULL(@PARAM, columna_actual):',
        '--     eso permite updates PARCIALES con un solo SP (ej: solo @HABILITADO).',
        '--  3. La auditoria de actualizacion se pisa siempre; la de creacion nunca.',
        '-- ---------------------------------------------------------------------------',
        '',
    ]

    if validaciones:
        partes += ['-- Validaciones: los campos unicos siguen siendo unicos,',
                   '-- excluyendo al propio registro que se esta editando.',
                   'BEGIN', '\n\n'.join(validaciones), 'END', '']

    partes += [
        'BEGIN TRANSACTION',
        '',
        '    UPDATE  %s' % e.tabla,
        '\n'.join(lineas_set),
        '    WHERE   %s = @ID' % e.id_columna,
        '',
        '    IF @@ROWCOUNT = 0 BEGIN',
        '        ROLLBACK TRANSACTION',
        '',
        '        DECLARE @VARIABLES VARCHAR(MAX)',
        _bloque_variables(d, e.sp_upd, testigos, incluir_id=True),
        '',
        '        EXEC INS_EXCEPCION',
        "            @MSG = '%d.- NO FUE POSIBLE ACTUALIZAR %s %s.',"
        % (numero_error, e.articulo_mayus, util.sin_acentos(e.singular).upper()),
        '            @VARIABLES = @VARIABLES',
        '        RETURN -1',
        '    END',
        '',
        'COMMIT TRANSACTION',
        '',
        'RETURN(0)',
        'GO',
    ]
    return '\n'.join(partes)


# ===========================================================================
# 04 - DEL
# ===========================================================================
def dele(d):
    e = d.entidad

    nota = []
    if e.usa_baja_logica:
        nota = [
            '--  2. IMPORTANTE: %s es una tabla MAESTRO. En tablas maestro NO se' % e.tabla,
            '--     borra fisico: se da de baja logica con %s @HABILITADO = 0.' % e.sp_upd,
            '--     Por eso el boton del grid llama a Deshabilitar%s(), no a Delete%s().'
            % (e.singular, e.singular),
            '--     Este SP queda para casos excepcionales y limpieza de datos de prueba.',
        ]
    else:
        nota = [
            '--  2. %s es una tabla de DETALLE/RELACION: el borrado fisico si aplica.' % e.tabla,
        ]

    partes = [
        _encabezado(d, 'StoredProcedure', e.sp_del,
                    'ELIMINA FISICAMENTE %s %s.'
                    % (e.articulo_mayus, util.sin_acentos(e.singular).upper())),
        'CREATE OR ALTER PROCEDURE [dbo].[%s]' % e.sp_del,
        '    @ID INT',
        '',
        'AS',
        'SET NOCOUNT ON',
        '',
        '-- ---------------------------------------------------------------------------',
        '-- PATRON: PATRON_SP.md seccion 6.',
        '--  1. El DEL_ recibe SOLO @ID.',
    ] + nota + [
        '-- ---------------------------------------------------------------------------',
        '',
        'BEGIN TRANSACTION',
        '',
        '    DELETE  %s' % e.tabla,
        '    WHERE   %s = @ID' % e.id_columna,
        '',
        '    IF @@ROWCOUNT = 0 BEGIN',
        '        ROLLBACK TRANSACTION',
        '',
        '        DECLARE @VARIABLES VARCHAR(MAX)',
        "        SET @VARIABLES = '%s ' + LTRIM(STR(@ID))" % e.sp_del,
        '',
        '        EXEC INS_EXCEPCION',
        "            @MSG = '1.- NO FUE POSIBLE ELIMINAR %s %s.',"
        % (e.articulo_mayus, util.sin_acentos(e.singular).upper()),
        '            @VARIABLES = @VARIABLES',
        '        RETURN -1',
        '    END',
        '',
        'COMMIT TRANSACTION',
        '',
        'RETURN(0)',
        'GO',
    ]
    return '\n'.join(partes)
