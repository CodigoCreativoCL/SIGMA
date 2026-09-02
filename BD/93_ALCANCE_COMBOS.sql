/* ============================================================================
   SIGMA — Bloque 93
   LOS COMBOS DEL ALCANCE                                              HU-051
   ----------------------------------------------------------------------------

   POR QUE HACEN FALTA

     La ficha de compatibilidad pregunta a qué aplica el repuesto: a un tipo
     de activo, a un modelo o a un componente.

     `SEL_ACTIVO_TIPO` ya existe (bloque 74). `Activo_Modelo` y
     `Activo_Componente` no tenían **ninguna** consulta: las tablas están
     desde las fundaciones y nunca se leyeron desde la aplicación.

   LO GLOBAL Y LO DEL CLIENTE, JUNTOS

     `amo_cliente` admite NULL y eso significa "modelo del sistema, para
     todos". Filtrar solo por el cliente escondería los modelos globales, que
     son justamente los que sirven para no volver a cargar "WEG W22" en cada
     empresa.

     Se devuelven los dos y una columna ES_GLOBAL para que la pantalla pueda
     distinguirlos, igual que hace SEL_ACTIVO_TIPO.

   SON CONSULTAS DE COMBO, NO EL CRUD DEL MODULO

     Solo leen. El mantenedor de modelos y de componentes es del módulo de
     activos y no de esta historia; cuando exista, estos SP siguen sirviendo
     porque solo consultan.

   ORDEN: despues de 92_REPUESTO_COMPATIBILIDAD.sql
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. SEL_ACTIVO_MODELO
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ACTIVO_MODELO') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ACTIVO_MODELO]
GO

CREATE PROCEDURE [dbo].[SEL_ACTIVO_MODELO]
    @CLIENTE     INT,
    @ID          INT = NULL,
    @ACTIVO_TIPO INT = NULL,
    @HABILITADO  BIT = NULL,
    @FILTRO      VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT  m.amo_id                                       AS AMO_ID,
            m.amo_cliente                                  AS AMO_CLIENTE,
            m.amo_activo_tipo                              AS AMO_ACTIVO_TIPO,
            ISNULL(m.amo_fabricante, '')                   AS AMO_FABRICANTE,
            m.amo_nombre                                   AS AMO_NOMBRE,
            ISNULL(m.amo_descripcion, '')                  AS AMO_DESCRIPCION,
            m.amo_habilitado                               AS AMO_HABILITADO,
            CAST(CASE WHEN m.amo_cliente IS NULL THEN 1 ELSE 0 END AS INT) AS ES_GLOBAL,
            ISNULL(t.ati_nombre, '')                       AS TIPO_NOMBRE,
            /* Lo que se lee en el combo: el fabricante delante, porque
               "W22 132S" sin "WEG" no le dice nada a nadie. */
            LTRIM(ISNULL(m.amo_fabricante + ' ', '') + m.amo_nombre) AS ETIQUETA
    FROM    [dbo].[Activo_Modelo] m
    LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = m.amo_activo_tipo
    WHERE   (m.amo_cliente IS NULL OR m.amo_cliente = @CLIENTE)
      AND   (@ID          IS NULL OR m.amo_id          = @ID)
      AND   (@ACTIVO_TIPO IS NULL OR m.amo_activo_tipo = @ACTIVO_TIPO)
      AND   (@HABILITADO  IS NULL OR m.amo_habilitado  = @HABILITADO)
      AND   (@FILTRO IS NULL
             OR m.amo_nombre     LIKE '%' + @FILTRO + '%'
             OR m.amo_fabricante LIKE '%' + @FILTRO + '%')
    ORDER BY m.amo_fabricante, m.amo_nombre, m.amo_id
GO

PRINT '--- SEL_ACTIVO_MODELO creado.'
GO


/* ========================================================================
   2. SEL_ACTIVO_COMPONENTE

      Un componente SIEMPRE es de un cliente: es una pieza concreta de una
      máquina concreta. No hay componentes globales, y por eso acá el filtro
      por cliente no admite NULL como en los modelos.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ACTIVO_COMPONENTE') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ACTIVO_COMPONENTE]
GO

CREATE PROCEDURE [dbo].[SEL_ACTIVO_COMPONENTE]
    @CLIENTE     INT,
    @ID          INT = NULL,
    @ACTIVO      INT = NULL,
    @HABILITADO  BIT = NULL,
    @FILTRO      VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT  c.aco_id                                       AS ACO_ID,
            c.aco_cliente                                  AS ACO_CLIENTE,
            c.aco_activo                                   AS ACO_ACTIVO,
            c.aco_codigo                                   AS ACO_CODIGO,
            c.aco_nombre                                   AS ACO_NOMBRE,
            ISNULL(c.aco_descripcion, '')                  AS ACO_DESCRIPCION,
            c.aco_habilitado                               AS ACO_HABILITADO,
            ISNULL(a.act_codigo, '')                       AS ACTIVO_CODIGO,
            ISNULL(a.act_nombre, '')                       AS ACTIVO_NOMBRE,
            ISNULL(ct.cto_nombre, '')                      AS TIPO_NOMBRE,
            /* El activo delante: "Rodamiento lado acople" se repite en
               veinte máquinas y sin la máquina no se puede elegir. */
            ISNULL(a.act_codigo + ' · ', '') + c.aco_nombre AS ETIQUETA
    FROM    [dbo].[Activo_Componente] c
    LEFT JOIN [dbo].[Activo] a         ON a.act_id  = c.aco_activo
    LEFT JOIN [dbo].[Componente_Tipo] ct ON ct.cto_id = c.aco_componente_tipo
    WHERE   c.aco_cliente = @CLIENTE
      AND   (@ID         IS NULL OR c.aco_id         = @ID)
      AND   (@ACTIVO     IS NULL OR c.aco_activo     = @ACTIVO)
      AND   (@HABILITADO IS NULL OR c.aco_habilitado = @HABILITADO)
      AND   (@FILTRO IS NULL
             OR c.aco_codigo  LIKE '%' + @FILTRO + '%'
             OR c.aco_nombre  LIKE '%' + @FILTRO + '%'
             OR a.act_codigo  LIKE '%' + @FILTRO + '%'
             OR a.act_nombre  LIKE '%' + @FILTRO + '%')
    ORDER BY a.act_codigo, c.aco_codigo, c.aco_id
GO

PRINT '--- SEL_ACTIVO_COMPONENTE creado.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
EXEC [dbo].[SEL_ACTIVO_MODELO] @CLIENTE = 1
GO

EXEC [dbo].[SEL_ACTIVO_COMPONENTE] @CLIENTE = 1
GO

PRINT '93_ALCANCE_COMBOS aplicado.'
GO
