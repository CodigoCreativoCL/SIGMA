/* ============================================================================
   SIGMA - Bloque 324
   LA CARGA MASIVA DE REPUESTOS TRAE EL TIPO
   ----------------------------------------------------------------------------

   La planilla de carga masiva no tenia columna de tipo de repuesto: todo lo que
   entraba por ahi quedaba SIN CLASIFICAR, y habia que asignarle el tipo despues,
   repuesto por repuesto o con AsignarTipo. Cargar 600 repuestos y tener que
   clasificarlos a mano es repetir el trabajo que la planilla venia a ahorrar.

   El tipo es un dato del repuesto como cualquier otro -la ficha lo pide al
   crearlo y INS_REPUESTO ya recibe @REPUESTO_TIPO-, asi que la carga masiva
   tiene que poder traerlo.

   Tres cambios:

     1. RPT_REPUESTO_PLANTILLA   gana la columna TIPO como la numero 15.
     2. RPT_REPUESTO_EXCEL       tambien, para que lo que se descarga y lo que se
                                 carga tengan la misma forma.
     3. RPT_REPUESTO_TIPO_EXCEL  NUEVO. La hoja TIPOS VALIDOS de la plantilla:
                                 lista, por cliente, que escribir en la columna.

   POR QUE LA COLUMNA VA AL FINAL Y NO AL LADO DEL NOMBRE
     La carga lee las columnas por NOMBRE, de modo que el orden daria lo mismo
     para ella. Pero hay planillas de 14 columnas ya llenas por ahi, y poner TIPO
     en el medio cambiaria el lugar de las demas. Al final, una planilla vieja
     sigue cargando igual y simplemente queda sin tipo.

   POR QUE EL CODIGO DEL TIPO Y NO SU ID
     El id lo asigna la base y es distinto en cada cliente y en cada ambiente: una
     planilla con ids no se podria reutilizar. El codigo (MEC-RODAMIENTO) es
     legible y estable, y la carga acepta tambien el nombre.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. La plantilla
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[RPT_REPUESTO_PLANTILLA]
AS
SET NOCOUNT ON

    /* La fila de ejemplo muestra el formato de cada columna. Se reconoce
       por el codigo y la carga la salta, asi que da lo mismo si alguien
       olvida borrarla. */
    SELECT  CAST('EJEMPLO-ROD-001' AS NVARCHAR(100))            AS [CODIGO],
            CAST('Rodamiento 6205 2RS' AS NVARCHAR(400))        AS [NOMBRE],
            CAST('UNIDAD' AS NVARCHAR(100))                     AS [UNIDAD],
            CAST('SKF' AS NVARCHAR(400))                        AS [FABRICANTE],
            CAST('6205-2RS1' AS NVARCHAR(400))                  AS [MODELO],
            CAST('NO' AS NVARCHAR(2))                           AS [CONTROLA LOTE],
            CAST('NO' AS NVARCHAR(2))                           AS [CONSUMIBLE],
            CAST('NO' AS NVARCHAR(2))                           AS [REPARABLE],
            CAST(8500 AS DECIMAL(18,4))                         AS [COSTO REFERENCIA],
            CAST(8000 AS DECIMAL(18,4))                         AS [VIDA UTIL HORAS],
            CAST(NULL AS INT)                                   AS [VIDA UTIL DIAS],
            CAST(NULL AS DECIMAL(18,4))                         AS [VIDA UTIL CICLOS],
            CAST('Borre esta fila antes de cargar.' AS NVARCHAR(1000)) AS [DESCRIPCION],
            CAST('SI' AS NVARCHAR(2))                           AS [HABILITADO],
            CAST('Vea la hoja TIPOS VALIDOS' AS NVARCHAR(100))  AS [TIPO]
GO


/* ========================================================================
   2. La descarga: el mismo orden que la plantilla, con TIPO como columna 15.
      Las tres calculadas (existencia, creador, fecha) quedan despues y la
      carga las ignora por nombre.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[RPT_REPUESTO_EXCEL]
    @CLIENTE    INT,
    @FILTRO     NVARCHAR(200) = NULL,
    @HABILITADO BIT = NULL
AS
SET NOCOUNT ON

    SELECT  r.rep_codigo                                        AS [CODIGO],
            r.rep_nombre                                        AS [NOMBRE],
            ume.ume_codigo                                      AS [UNIDAD],
            ISNULL(r.rep_fabricante, '')                        AS [FABRICANTE],
            ISNULL(r.rep_modelo, '')                            AS [MODELO],
            CASE WHEN r.rep_controla_lote = 1 THEN 'SI' ELSE 'NO' END AS [CONTROLA LOTE],
            CASE WHEN r.rep_es_consumible = 1 THEN 'SI' ELSE 'NO' END AS [CONSUMIBLE],
            CASE WHEN r.rep_es_reparable  = 1 THEN 'SI' ELSE 'NO' END AS [REPARABLE],
            r.rep_costo_referencia                              AS [COSTO REFERENCIA],
            r.rep_vida_util_hora                                AS [VIDA UTIL HORAS],
            r.rep_vida_util_dia                                 AS [VIDA UTIL DIAS],
            r.rep_vida_util_ciclo                               AS [VIDA UTIL CICLOS],
            ISNULL(r.rep_descripcion, '')                       AS [DESCRIPCION],
            CASE WHEN r.rep_habilitado = 1 THEN 'SI' ELSE 'NO' END AS [HABILITADO],
            ISNULL(rt.rti_codigo, '')                           AS [TIPO],

            /* Estas tres no se cargan: se calculan. Van en la descarga
               porque son lo que uno quiere ver en la planilla, y la carga
               masiva las ignora por nombre. */
            ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s
                     WHERE s.isa_repuesto = r.rep_id), 0)       AS [EXISTENCIA TOTAL],
            LTRIM(RTRIM(ISNULL(uc.usu_nombre, '') + ' ' + ISNULL(uc.usu_apellido_paterno, ''))) AS [CREADO POR],
            r.rep_fecha_creacion                                AS [FECHA CREACION]
    FROM    [dbo].[Repuesto] r
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Repuesto_Tipo] rt ON rt.rti_id = r.rep_repuesto_tipo
    LEFT JOIN [dbo].[Usuario] uc      ON uc.usu_id = r.rep_usuario_creacion
    WHERE   r.rep_cliente = @CLIENTE
      AND   r.rep_fusionado_en IS NULL
      AND   (@HABILITADO IS NULL OR r.rep_habilitado = @HABILITADO)
      AND   (@FILTRO IS NULL OR r.rep_codigo     LIKE '%' + @FILTRO + '%'
                             OR r.rep_nombre     LIKE '%' + @FILTRO + '%'
                             OR r.rep_fabricante LIKE '%' + @FILTRO + '%'
                             OR r.rep_modelo     LIKE '%' + @FILTRO + '%')
    ORDER BY r.rep_codigo
GO


/* ========================================================================
   3. La hoja TIPOS VALIDOS

      Solo los habilitados -la carga rechaza un tipo deshabilitado- y de ESTE
      cliente: cada empresa arma su propio arbol, a diferencia de las unidades,
      que son del sistema y por eso su SP no recibe cliente.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[RPT_REPUESTO_TIPO_EXCEL]
    @CLIENTE INT
AS
SET NOCOUNT ON

    SELECT  t.rti_codigo                    AS [ESCRIBA ESTO EN LA COLUMNA TIPO],
            t.rti_nombre                    AS [SIGNIFICA],
            ISNULL(t.rti_descripcion, '')   AS [DESCRIPCION]
    FROM    [dbo].[Repuesto_Tipo] t
    WHERE   t.rti_cliente = @CLIENTE
      AND   t.rti_habilitado = 1
    ORDER BY t.rti_orden, t.rti_nombre
GO


/* ============================================================================
   COMPROBACION
   ============================================================================ */
PRINT '--- columnas de la plantilla (esperado: 15, la ultima TIPO) ---'
SELECT COUNT(*) AS columnas,
       (SELECT TOP 1 name FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.RPT_REPUESTO_PLANTILLA', NULL, 0)
         ORDER BY column_ordinal DESC) AS ultima
FROM   sys.dm_exec_describe_first_result_set(N'EXEC dbo.RPT_REPUESTO_PLANTILLA', NULL, 0)
GO
PRINT '--- tipos validos del cliente 1 ---'
EXEC [dbo].[RPT_REPUESTO_TIPO_EXCEL] @CLIENTE = 1
GO
