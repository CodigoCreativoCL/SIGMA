/* ============================================================================
   SIGMA — Bloque 77
   CODIGO AUTOMATICO: PREFIJO DEL MODULO + ID
   ----------------------------------------------------------------------------

   QUE HACE

     Al crear un registro, su codigo se arma solo: ACT-31, BOD-9, UBI-17.
     Nadie lo teclea, nadie lo repite, nadie lo inventa distinto cada vez.

   SOLO LAS 11 ENTIDADES CON FICHA, NO LAS ~110 TABLAS CON CODIGO

     En la base hay mas de cien tablas con una columna de codigo, pero casi
     todas son catalogos donde el codigo es SEMANTICO y es la llave por la
     que se busca: Moneda.CLP, Unidad_Medida.KG, Orden_Trabajo_Estado.
     PENDIENTE.

     Convertir CLP en MON-3 romperia cada consulta que compara por codigo
     -incluido SEL_ETIQUETA, que pregunta @ORIGEN = 'BODEGA'-. Esas tablas
     no se tocan, y no es una omision: su codigo no identifica un registro,
     es un valor del dominio.

     Las 11 que si se tocan son las que tienen INS_ y ficha propia: las que
     un usuario crea.

   EL PREFIJO COINCIDE CON EL DEL QR

     BOD, UBI, REP, ACT son los mismos tres caracteres que viajan en las
     etiquetas. Asi el codigo impreso y el token escaneado son la MISMA
     cadena, y no dos identificadores para la misma cosa.

   ADVERTENCIA SOBRE LAS UBICACIONES

     Queda escrita porque el cambio se nota en terreno: hasta hoy el codigo
     de una ubicacion lo escribia una persona con un significado -PA-E3-N2
     es "Pasillo A, Estante 3, Nivel 2"- y el bodeguero CAMINA leyendo ese
     codigo. UBI-17 no dice donde queda.

     Se implementa igual porque fue lo pedido. Los registros que ya existen
     CONSERVAN su codigo: solo los nuevos se generan. Reescribir los viejos
     dejaria sin valor las etiquetas ya impresas y pegadas.

   EL SENTINELA 'AUTO'

     El codigo depende del ID, y el ID no existe hasta despues del INSERT:
     no hay forma de calcularlo antes. La ficha manda 'AUTO', el INSERT pasa
     con ese valor -que satisface el NOT NULL y nunca queda guardado- y
     enseguida se reemplaza por el definitivo.

   IDEMPOTENTE

     Se puede volver a ejecutar: crea lo que falte y parchea solo los
     procedimientos que aun no lo esten.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. EL CATALOGO DE PREFIJOS

      Tabla y no una lista dentro de cada SP: el dia que entre un modulo
      nuevo, es un INSERT.
   ======================================================================== */
IF OBJECT_ID('dbo.Modulo_Codigo') IS NULL
BEGIN
    CREATE TABLE [dbo].[Modulo_Codigo] (
        [mco_id]             INT IDENTITY(1,1) NOT NULL,
        [mco_tabla]          NVARCHAR(128) NOT NULL,
        [mco_prefijo]        NVARCHAR(6)   NOT NULL,
        [mco_columna_codigo] NVARCHAR(128) NOT NULL,
        [mco_columna_id]     NVARCHAR(128) NOT NULL,
        [mco_procedimiento]  NVARCHAR(128) NOT NULL,
        [mco_habilitado]     BIT NOT NULL DEFAULT 1,
        CONSTRAINT [PK_Modulo_Codigo] PRIMARY KEY CLUSTERED ([mco_id]),
        CONSTRAINT [UX_Modulo_Codigo_Tabla] UNIQUE ([mco_tabla])
    )
    PRINT '--- Tabla Modulo_Codigo creada'
END
ELSE PRINT '--- Tabla Modulo_Codigo ya existia'
GO

MERGE [dbo].[Modulo_Codigo] AS d
USING (VALUES
    ('Activo',              'ACT', 'act_codigo', 'act_id', 'INS_ACTIVO'),
    ('Bodega',              'BOD', 'bod_codigo', 'bod_id', 'INS_BODEGA'),
    ('Bodega_Ubicacion',    'UBI', 'bub_codigo', 'bub_id', 'INS_BODEGA_UBICACION'),
    ('Centro_Costo',        'CCO', 'cco_codigo', 'cco_id', 'INS_CENTRO_COSTO'),
    ('Cliente_Instalacion', 'PLA', 'cin_codigo', 'cin_id', 'INS_CLIENTE_INSTALACION'),
    ('Especialidad',        'ESP', 'esp_codigo', 'esp_id', 'INS_ESPECIALIDAD'),
    ('Grupo_Trabajo',       'GRU', 'gtr_codigo', 'gtr_id', 'INS_GRUPO_TRABAJO'),
    ('Instalacion_Area',    'ARE', 'iar_codigo', 'iar_id', 'INS_INSTALACION_AREA'),
    ('Plan_Comercial',      'PLC', 'plc_codigo', 'plc_id', 'INS_PLAN_COMERCIAL'),
    ('Repuesto',            'REP', 'rep_codigo', 'rep_id', 'INS_REPUESTO'),
    ('Repuesto_Lote',       'LOT', 'rlo_codigo', 'rlo_id', 'INS_REPUESTO_LOTE')
) AS o (tab, pre, col, cid, spr)
    ON d.mco_tabla = o.tab
WHEN MATCHED THEN UPDATE SET
    d.mco_prefijo = o.pre, d.mco_columna_codigo = o.col,
    d.mco_columna_id = o.cid, d.mco_procedimiento = o.spr
WHEN NOT MATCHED THEN
    INSERT (mco_tabla, mco_prefijo, mco_columna_codigo, mco_columna_id, mco_procedimiento)
    VALUES (o.tab, o.pre, o.col, o.cid, o.spr);

PRINT '--- Modulos al dia: ' + LTRIM(STR(@@ROWCOUNT))
GO


/* ========================================================================
   2. EL FORMATO, EN UN SOLO SITIO
   ======================================================================== */
IF OBJECT_ID('dbo.FNC_CODIGO_AUTOMATICO') IS NOT NULL
    DROP FUNCTION [dbo].[FNC_CODIGO_AUTOMATICO]
GO

CREATE FUNCTION [dbo].[FNC_CODIGO_AUTOMATICO] (@PREFIJO NVARCHAR(6), @ID INT)
RETURNS NVARCHAR(50)
AS
BEGIN
    RETURN UPPER(LTRIM(RTRIM(@PREFIJO))) + '-' + LTRIM(STR(@ID))
END
GO


/* ========================================================================
   3. PARCHEAR LOS INS_

      Se inyecta justo despues de que el SP conoce su @ID: antes de esa
      linea el codigo no se puede calcular.

   NO SE TOCA LA CABECERA DEL PROCEDIMIENTO

     El primer intento convertia "CREATE PROCEDURE" en "ALTER PROCEDURE" con
     un STUFF. Fallo en 7 de los 11, y EN SILENCIO: siete de estos SP estan
     escritos como CREATE seguido de TRES espacios y PROCEDURE, asi que el
     literal nunca calzo, CHARINDEX devolvio 0, y STUFF con posicion 0
     devuelve NULL. Ejecutar sp_executesql con NULL no hace nada Y NO FALLA:
     el bloque informaba exito y ningun procedimiento quedaba parcheado.

     Buscar la cabecera con comodines tampoco sirve: varios empiezan con un
     comentario que dice "Create date", y la busqueda -insensible a
     mayusculas en esta base- engancha esa palabra antes que la de verdad.

     Se deja de adivinar: se BORRA el procedimiento y se vuelve a crear con
     su texto original mas el anadido, dentro de una transaccion. Si la
     creacion falla, el DROP se deshace y el procedimiento sigue ahi.
   ======================================================================== */
DECLARE @tab NVARCHAR(128), @pre NVARCHAR(6), @col NVARCHAR(128),
        @cid NVARCHAR(128), @spr NVARCHAR(128)
DECLARE @def NVARCHAR(MAX), @nuevo NVARCHAR(MAX), @snippet NVARCHAR(MAX)
DECLARE @drop NVARCHAR(400), @hechos INT = 0, @saltados INT = 0

DECLARE cur CURSOR FOR
    SELECT mco_tabla, mco_prefijo, mco_columna_codigo, mco_columna_id, mco_procedimiento
    FROM   [dbo].[Modulo_Codigo] WHERE mco_habilitado = 1

OPEN cur
FETCH NEXT FROM cur INTO @tab, @pre, @col, @cid, @spr

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @def = OBJECT_DEFINITION(OBJECT_ID('dbo.' + @spr))

    IF @def IS NULL
    BEGIN
        PRINT '*** ' + @spr + ': no existe'
        SET @saltados = @saltados + 1
    END
    ELSE IF @def LIKE '%CODIGO AUTOMATICO%'
    BEGIN
        PRINT '--- ' + @spr + ': ya estaba'
        SET @saltados = @saltados + 1
    END
    ELSE IF CHARINDEX('SET @ID = SCOPE_IDENTITY()', @def) = 0
    BEGIN
        PRINT '*** ' + @spr + ': no tiene el punto de insercion esperado'
        SET @saltados = @saltados + 1
    END
    ELSE
    BEGIN
        SET @snippet =
            CHAR(13) + CHAR(10) +
            '    /* ---- CODIGO AUTOMATICO ----' + CHAR(13) + CHAR(10) +
            '       El codigo depende del ID, y el ID no existe hasta esta linea.' + CHAR(13) + CHAR(10) +
            '       La ficha manda ''AUTO'': ese valor satisface el NOT NULL, pasa' + CHAR(13) + CHAR(10) +
            '       por el INSERT y nunca queda guardado. */' + CHAR(13) + CHAR(10) +
            '    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = ''AUTO'')' + CHAR(13) + CHAR(10) +
            '        UPDATE [dbo].[' + @tab + ']' + CHAR(13) + CHAR(10) +
            '        SET    [' + @col + '] = [dbo].[FNC_CODIGO_AUTOMATICO](''' + @pre + ''', @ID)' + CHAR(13) + CHAR(10) +
            '        WHERE  [' + @cid + '] = @ID' + CHAR(13) + CHAR(10)

        SET @nuevo = REPLACE(@def, 'SET @ID = SCOPE_IDENTITY()',
                                   'SET @ID = SCOPE_IDENTITY()' + @snippet)

        SET @drop = 'DROP PROCEDURE [dbo].[' + @spr + ']'

        BEGIN TRY
            BEGIN TRANSACTION
                EXEC sp_executesql @drop
                EXEC sp_executesql @nuevo
            COMMIT TRANSACTION

            PRINT '--- ' + @spr + ': ' + @pre + '-<id>'
            SET @hechos = @hechos + 1
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
            PRINT '*** ' + @spr + ': ' + ERROR_MESSAGE()
            SET @saltados = @saltados + 1
        END CATCH
    END

    FETCH NEXT FROM cur INTO @tab, @pre, @col, @cid, @spr
END

CLOSE cur
DEALLOCATE cur

PRINT '=== Parcheados ahora: ' + LTRIM(STR(@hechos)) + '  |  Omitidos: ' + LTRIM(STR(@saltados))
GO


/* ========================================================================
   4. VERIFICACION

      Uno por uno. Un REPLACE que no calza no falla: deja el SP igual, y el
      codigo se seguiria escribiendo a mano sin que nadie se entere. Es
      exactamente lo que paso la primera vez.
   ======================================================================== */
SELECT  m.mco_procedimiento AS PROCEDIMIENTO,
        m.mco_prefijo       AS PREFIJO,
        CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.' + m.mco_procedimiento))
                  LIKE '%CODIGO AUTOMATICO%'
             THEN 'OK' ELSE '*** FALTA' END AS ESTADO
FROM    [dbo].[Modulo_Codigo] m
WHERE   m.mco_habilitado = 1
ORDER BY ESTADO DESC, m.mco_procedimiento
GO
