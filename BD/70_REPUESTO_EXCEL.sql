/* ============================================================================
   SIGMA — Bloque 70
   DESCARGA Y PLANTILLA DE REPUESTOS
   ----------------------------------------------------------------------------

   Dos consultas para Excel:

     RPT_REPUESTO_EXCEL      lo que hay hoy, para llevarselo
     RPT_REPUESTO_PLANTILLA  las columnas vacias, para cargar

   POR QUE NO SE COPIA EL PATRON DE RPT_CLIENTE_USUARIO_CARGA_MASIVA

     Ese arma la consulta concatenando el @CLIENTE dentro de un VARCHAR y la
     ejecuta con EXEC. Es exactamente lo que se corrigio en el bloque 49
     cuando SEL_CLIENTE_USUARIO concatenaba el @FILTRO del buscador: era
     inyeccion SQL. Aca no hay SQL dinamico y los parametros son parametros.

   LOS ENCABEZADOS VAN EN ESPANOL Y SIN PREFIJO

     El archivo lo abre una persona, no el sistema. "rep_codigo" no le dice
     nada a un bodeguero; "CODIGO" si. Y la plantilla usa **exactamente los
     mismos** encabezados que la descarga, para que exportar, editar y volver
     a cargar sea un ciclo cerrado y no dos formatos parecidos.

   LA PLANTILLA LLEVA UNA FILA DE EJEMPLO

     Una planilla con solo encabezados obliga a adivinar el formato de cada
     columna: si SI/NO va en texto o en 1/0, si la unidad es el codigo o el
     nombre. La fila de ejemplo lo muestra y se borra antes de cargar; la
     carga la ignora porque su codigo empieza con "EJEMPLO".
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. RPT_REPUESTO_EXCEL — lo que hay
   ======================================================================== */
IF OBJECT_ID('dbo.RPT_REPUESTO_EXCEL') IS NOT NULL DROP PROCEDURE [dbo].[RPT_REPUESTO_EXCEL]
GO

CREATE PROCEDURE [dbo].[RPT_REPUESTO_EXCEL]
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

            /* Estas tres no se cargan: se calculan. Van en la descarga
               porque son lo que uno quiere ver en la planilla, y la carga
               masiva las ignora por nombre. */
            ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s
                     WHERE s.isa_repuesto = r.rep_id), 0)       AS [EXISTENCIA TOTAL],
            LTRIM(RTRIM(ISNULL(uc.usu_nombre, '') + ' ' + ISNULL(uc.usu_apellido_paterno, ''))) AS [CREADO POR],
            r.rep_fecha_creacion                                AS [FECHA CREACION]
    FROM    [dbo].[Repuesto] r
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
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
   2. RPT_REPUESTO_PLANTILLA — las columnas para cargar

      Mismos encabezados que la descarga, menos las tres calculadas: nadie
      puede "cargar" una existencia, eso lo hace un movimiento.
   ======================================================================== */
IF OBJECT_ID('dbo.RPT_REPUESTO_PLANTILLA') IS NOT NULL DROP PROCEDURE [dbo].[RPT_REPUESTO_PLANTILLA]
GO

CREATE PROCEDURE [dbo].[RPT_REPUESTO_PLANTILLA]
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
            CAST('SI' AS NVARCHAR(2))                           AS [HABILITADO]
GO


/* ========================================================================
   3. LAS UNIDADES VALIDAS, PARA LA HOJA DE AYUDA DE LA PLANTILLA

      Sin esto, quien llena la planilla escribe "unidades", "un", "u." y
      cada una falla en la carga sin que se entienda por que.
   ======================================================================== */
IF OBJECT_ID('dbo.RPT_UNIDAD_MEDIDA_EXCEL') IS NOT NULL DROP PROCEDURE [dbo].[RPT_UNIDAD_MEDIDA_EXCEL]
GO

CREATE PROCEDURE [dbo].[RPT_UNIDAD_MEDIDA_EXCEL]
AS
SET NOCOUNT ON

    SELECT  u.ume_codigo   AS [ESCRIBA ESTO EN LA COLUMNA UNIDAD],
            u.ume_nombre   AS [SIGNIFICA],
            u.ume_simbolo  AS [SIMBOLO],
            m.mag_nombre   AS [MAGNITUD]
    FROM    [dbo].[Unidad_Medida] u
    JOIN    [dbo].[Magnitud] m ON m.mag_id = u.ume_magnitud
    WHERE   u.ume_habilitado = 1
    ORDER BY m.mag_orden, u.ume_nombre
GO


/* ========================================================================
   4. VERIFICACION
   ======================================================================== */
PRINT '--- Descarga ---'
EXEC [dbo].[RPT_REPUESTO_EXCEL] @CLIENTE = 1

PRINT '--- Unidades validas ---'
EXEC [dbo].[RPT_UNIDAD_MEDIDA_EXCEL]
GO
