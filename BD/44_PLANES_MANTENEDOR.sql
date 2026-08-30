USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     BLOQUE C.3 MANTENEDOR DE PLANES COMERCIALES DESDE LA WEB.
-- =============================================
-- Va DESPUES de 43_SUSCRIPCION_MENUS.
--
-- POR QUE
--   Planes.aspx nacio de solo lectura con el argumento de que la oferta
--   comercial se cambia por script versionado y no por formulario. El
--   argumento no se sostiene en la practica: quien define los precios es el
--   area comercial, no quien despliega, y obligarlos a pedir un script para
--   subir un plan convierte una decision de negocio en un ticket tecnico.
--
--   Lo que SI hay que preservar es la razon de fondo del script: que
--   cambiar la lista de precios NO altere lo ya cotizado ni lo ya cobrado.
--   Eso no lo garantizaba el script; lo garantiza el versionado por
--   vigencia, y de eso se encarga UPS_PLAN_COMERCIAL_PRECIO.
--
-- EDITAR UN PRECIO NO ES UN UPDATE
--   Plan_Comercial_Precio tiene un indice unico filtrado que permite UNA
--   sola fila abierta (pcp_vigencia_hasta IS NULL) por plan y periodicidad.
--   Cambiar el precio es entonces: cerrar la fila vigente con la fecha de
--   ayer y abrir una nueva desde hoy, en la misma transaccion. Un UPDATE
--   sobre pcp_valor_uf borraria la historia y haria que un periodo emitido
--   el mes pasado pareciera calculado con el precio de hoy.
--
--   Los periodos ya emitidos no se tocan igual: guardan su propio numero
--   congelado (4.3). El versionado es para lo que todavia no se cobra.
--
-- LO QUE NO SE PUEDE HACER DESDE LA WEB
--   Borrar un plan. Un plan con suscripciones o con periodos emitidos es
--   historia de cobranza. Se deshabilita, y deshabilitado significa "no se
--   vende mas", no "no existio nunca".
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. INS_PLAN_COMERCIAL

      El plan nace SIN precio. Es deliberado: un plan sin fila en
      Plan_Comercial_Precio simplemente no se vende -asi lo definio el
      modelo, la ausencia de precio es la regla- y eso permite dejarlo
      preparado mientras se acuerda cuanto va a costar.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_COMERCIAL]
@ID           INT = NULL OUTPUT,
@CODIGO       NVARCHAR(50),
@NOMBRE       NVARCHAR(100),
@DESCRIPCION  NVARCHAR(500) = NULL,
@ORDEN        INT,
@DIAS_GRACIA  INT = 5,
@PUBLICO      BIT = 1,
@USUARIO      INT

AS
SET NOCOUNT ON

BEGIN
    IF @CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0
    BEGIN
        RAISERROR('1.- EL CÓDIGO DEL PLAN ES OBLIGATORIO.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial]
                WHERE plc_codigo = @CODIGO COLLATE DATABASE_DEFAULT)
    BEGIN
        RAISERROR('2.- YA EXISTE UN PLAN CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    /* El orden decide que es subir y que es bajar de plan (8). Dos planes
       con el mismo orden dejan a UPS_SUSCRIPCION_PLAN sin criterio: la
       comparacion da falso en ambos sentidos y todo cambio entre ellos se
       trata como downgrade, sin que nadie entienda por que. */
    IF @ORDEN IS NULL
    BEGIN
        RAISERROR('3.- EL ORDEN ES OBLIGATORIO: DEFINE QUÉ ES SUBIR Y QUÉ ES BAJAR DE PLAN.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_orden = @ORDEN)
    BEGIN
        RAISERROR('4.- YA HAY UN PLAN CON EL ORDEN %d. EL ORDEN DEBE SER ÚNICO.', 16, 1, @ORDEN)
        RETURN -1
    END

    IF @DIAS_GRACIA IS NULL OR @DIAS_GRACIA < 0
    BEGIN
        RAISERROR('5.- LOS DÍAS DE GRACIA NO PUEDEN SER NEGATIVOS.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Plan_Comercial]
        (plc_codigo, plc_nombre, plc_descripcion, plc_orden, plc_dias_gracia, plc_publico,
         plc_usuario_creacion, plc_fecha_creacion,
         plc_usuario_actualizacion, plc_fecha_actualizacion, plc_habilitado)
    VALUES
        (@CODIGO, @NOMBRE, @DESCRIPCION, @ORDEN, @DIAS_GRACIA, @PUBLICO,
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_COMERCIAL @CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE CREAR EL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   2. UPD_PLAN_COMERCIAL

      El CODIGO no se edita. Es la llave con la que los scripts de datos y
      cualquier integracion futura identifican al plan; renombrarlo desde un
      formulario romperia silenciosamente lo que lo referencie por codigo.
      Para eso esta el nombre, que si se edita y es lo que se muestra.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_COMERCIAL]
@ID           INT,
@NOMBRE       NVARCHAR(100),
@DESCRIPCION  NVARCHAR(500) = NULL,
@ORDEN        INT = NULL,
@DIAS_GRACIA  INT = NULL,
@PUBLICO      BIT = NULL,
@HABILITADO   BIT = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_id = @ID)
    BEGIN
        RAISERROR('1.- EL PLAN NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @ORDEN IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_orden = @ORDEN AND plc_id <> @ID)
    BEGIN
        RAISERROR('2.- YA HAY OTRO PLAN CON EL ORDEN %d. EL ORDEN DEBE SER ÚNICO.', 16, 1, @ORDEN)
        RETURN -1
    END

    /* Deshabilitar un plan que alguien esta usando deja a ese cliente con
       una suscripcion apuntando a un plan que ya no se vende. No se
       prohibe -es exactamente lo que se hace al retirar un plan del
       catalogo- pero avisar en silencio no sirve: se rechaza y quien
       quiera retirarlo tiene que migrar antes a esos clientes. */
    IF @HABILITADO = 0
       AND EXISTS (SELECT 1 FROM [dbo].[Suscripcion]
                    WHERE sus_plan_comercial = @ID AND sus_habilitado = 1)
    BEGIN
        RAISERROR('3.- HAY SUSCRIPCIONES VIGENTES EN ESTE PLAN. CÁMBIELAS DE PLAN ANTES DE DESHABILITARLO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Comercial]
    SET     plc_nombre                = @NOMBRE,
            plc_descripcion           = @DESCRIPCION,
            plc_orden                 = ISNULL(@ORDEN, plc_orden),
            plc_dias_gracia           = ISNULL(@DIAS_GRACIA, plc_dias_gracia),
            plc_publico               = ISNULL(@PUBLICO, plc_publico),
            plc_habilitado            = ISNULL(@HABILITADO, plc_habilitado),
            plc_usuario_actualizacion = @USUARIO,
            plc_fecha_actualizacion   = GETDATE()
    WHERE   plc_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_PLAN_COMERCIAL @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '4.- NO FUE POSIBLE ACTUALIZAR EL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   3. UPS_PLAN_COMERCIAL_PRECIO                                       3.3

      FIJA el precio de un plan para una periodicidad. No lo edita: cierra
      el vigente y abre uno nuevo.

          precio vigente  ->  pcp_vigencia_hasta = @DESDE - 1 dia
          precio nuevo    ->  pcp_vigencia_desde = @DESDE, hasta NULL

      Por que asi y no con un UPDATE sobre pcp_valor_uf: el precio de ayer
      tiene que seguir siendo consultable. SEL_PLAN_COMERCIAL elige el que
      corresponde A UNA FECHA, no el ultimo cargado, y de eso depende que
      una cotizacion de la semana pasada siga diciendo lo mismo.

      @DESDE por defecto es hoy. Se acepta futuro -una lista de precios
      acordada para el proximo mes se carga hoy y entra sola-. NO se acepta
      pasado: reescribir hacia atras es justamente lo que el versionado
      existe para impedir.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_COMERCIAL_PRECIO]
@ID           INT = NULL OUTPUT,
@PLAN         INT,
@PERIODICIDAD INT,
@VALOR_UF     DECIMAL(18,4),
@DESCUENTO    DECIMAL(18,2) = NULL,
@DESDE        DATE = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @HOY DATE = CAST(GETDATE() AS DATE),
        @VIGENTE INT,
        @VALOR_VIGENTE DECIMAL(18,4),
        @DESDE_VIGENTE DATE

SET @DESDE = ISNULL(@DESDE, @HOY)

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN)
    BEGIN
        RAISERROR('1.- EL PLAN NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Periodicidad_Cobro]
                    WHERE pcb_id = @PERIODICIDAD AND pcb_habilitado = 1)
    BEGIN
        RAISERROR('2.- LA PERIODICIDAD DE COBRO NO ES VÁLIDA.', 16, 1)
        RETURN -1
    END

    IF @VALOR_UF IS NULL OR @VALOR_UF <= 0
    BEGIN
        RAISERROR('3.- EL VALOR EN UF DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    IF @DESCUENTO IS NOT NULL AND (@DESCUENTO < 0 OR @DESCUENTO > 100)
    BEGIN
        RAISERROR('4.- EL DESCUENTO DEBE ESTAR ENTRE 0 Y 100.', 16, 1)
        RETURN -1
    END

    IF @DESDE < @HOY
    BEGIN
        RAISERROR('5.- NO SE PUEDE FIJAR UN PRECIO CON FECHA PASADA: ALTERARÍA LO YA COTIZADO.', 16, 1)
        RETURN -1
    END

    SELECT  @VIGENTE = pcp_id,
            @VALOR_VIGENTE = pcp_valor_uf,
            @DESDE_VIGENTE = pcp_vigencia_desde
    FROM    [dbo].[Plan_Comercial_Precio]
    WHERE   pcp_plan_comercial = @PLAN
      AND   pcp_periodicidad_cobro = @PERIODICIDAD
      AND   pcp_vigencia_hasta IS NULL
      AND   pcp_habilitado = 1

    -- Mismo numero: no se versiona nada. Guardar una fila identica solo
    -- ensucia el historial con un cambio que no ocurrio.
    IF @VIGENTE IS NOT NULL AND @VALOR_VIGENTE = @VALOR_UF
    BEGIN
        SET @ID = @VIGENTE
        RETURN(0)
    END

    /* El precio vigente empezo hoy o despues: todavia no cubrio ningun dia,
       asi que cerrarlo con "ayer" produciria hasta < desde y el CHECK lo
       rechazaria. En ese caso se corrige la fila en vez de versionarla; no
       hay historia que preservar. */
    IF @VIGENTE IS NOT NULL AND @DESDE_VIGENTE >= @DESDE
    BEGIN
        BEGIN TRANSACTION
            UPDATE  [dbo].[Plan_Comercial_Precio]
            SET     pcp_valor_uf               = @VALOR_UF,
                    pcp_descuento_porcentaje   = @DESCUENTO,
                    pcp_vigencia_desde         = @DESDE,
                    pcp_usuario_actualizacion  = @USUARIO,
                    pcp_fecha_actualizacion    = GETDATE()
            WHERE   pcp_id = @VIGENTE
        COMMIT TRANSACTION

        SET @ID = @VIGENTE
        RETURN(0)
    END
END

BEGIN TRANSACTION

    IF @VIGENTE IS NOT NULL
        UPDATE  [dbo].[Plan_Comercial_Precio]
        SET     pcp_vigencia_hasta        = DATEADD(DAY, -1, @DESDE),
                pcp_usuario_actualizacion = @USUARIO,
                pcp_fecha_actualizacion   = GETDATE()
        WHERE   pcp_id = @VIGENTE

    INSERT [dbo].[Plan_Comercial_Precio]
        (pcp_plan_comercial, pcp_periodicidad_cobro, pcp_valor_uf,
         pcp_vigencia_desde, pcp_vigencia_hasta, pcp_descuento_porcentaje,
         pcp_usuario_creacion, pcp_fecha_creacion,
         pcp_usuario_actualizacion, pcp_fecha_actualizacion, pcp_habilitado)
    VALUES
        (@PLAN, @PERIODICIDAD, @VALOR_UF,
         @DESDE, NULL, @DESCUENTO,
         @USUARIO, GETDATE(), @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_PLAN_COMERCIAL_PRECIO @PLAN = ' + LTRIM(STR(@PLAN))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE FIJAR EL PRECIO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   4. DEL_PLAN_COMERCIAL_PRECIO

      Retira una periodicidad de la venta. Baja LOGICA: la fila se conserva
      porque puede haber cotizado periodos que todavia se consultan.

      Sin fila vigente, esa combinacion plan+periodicidad deja de venderse.
      La ausencia de precio ES la regla del modelo, no un error.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_COMERCIAL_PRECIO]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Comercial_Precio]
    SET     pcp_habilitado            = 0,
            pcp_vigencia_hasta        = ISNULL(pcp_vigencia_hasta, CAST(GETDATE() AS DATE)),
            pcp_usuario_actualizacion = @USUARIO,
            pcp_fecha_actualizacion   = GETDATE()
    WHERE   pcp_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_COMERCIAL_PRECIO @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '1.- NO FUE POSIBLE RETIRAR EL PRECIO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   5. SEL_PLAN_COMERCIAL_PRECIO

      Todos los precios de un plan, vigentes e historicos. Es lo que
      alimenta la ficha: la lista de arriba muestra lo que se vende hoy, y
      el historial de abajo responde "con que precio se cobro en marzo".
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_COMERCIAL_PRECIO]
@ID            INT = NULL,
@PLAN          INT = NULL,
@PERIODICIDAD  INT = NULL,
@SOLO_VIGENTES BIT = NULL

AS
SET NOCOUNT ON

DECLARE @HOY DATE = CAST(GETDATE() AS DATE)

    SELECT  pr.pcp_id                     AS PCP_ID,
            pr.pcp_plan_comercial         AS PCP_PLAN_COMERCIAL,
            p.plc_codigo                  AS PLC_CODIGO,
            p.plc_nombre                  AS PLC_NOMBRE,
            pr.pcp_periodicidad_cobro     AS PCP_PERIODICIDAD_COBRO,
            pc.pcb_codigo                 AS PCB_CODIGO,
            pc.pcb_nombre                 AS PCB_NOMBRE,
            pr.pcp_valor_uf               AS PCP_VALOR_UF,
            pr.pcp_descuento_porcentaje   AS PCP_DESCUENTO_PORCENTAJE,
            pr.pcp_vigencia_desde         AS PCP_VIGENCIA_DESDE,
            pr.pcp_vigencia_hasta         AS PCP_VIGENCIA_HASTA,
            pr.pcp_habilitado             AS PCP_HABILITADO,
            CAST(ROUND(pr.pcp_valor_uf * ISNULL([dbo].[FNC_VALOR_UF](@HOY), 0), 0) AS DECIMAL(18,0))
                                          AS MONTO_CLP_REFERENCIAL,
            /* Tres estados y no un si/no: un precio cargado para el proximo
               mes no es lo mismo que uno que ya caduco, y en una lista
               ordenada por fecha los dos se ven igual de "no vigente". */
            CASE WHEN pr.pcp_habilitado = 0 THEN N'RETIRADO'
                 WHEN pr.pcp_vigencia_desde > @HOY THEN N'PROGRAMADO'
                 WHEN pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @HOY THEN N'VIGENTE'
                 ELSE N'HISTÓRICO' END    AS ESTADO
    FROM    [dbo].[Plan_Comercial_Precio] pr
    INNER JOIN [dbo].[Plan_Comercial] p       ON p.plc_id  = pr.pcp_plan_comercial
    INNER JOIN [dbo].[Periodicidad_Cobro] pc  ON pc.pcb_id = pr.pcp_periodicidad_cobro
    WHERE   (@ID IS NULL OR pr.pcp_id = @ID)
      AND   (@PLAN IS NULL OR pr.pcp_plan_comercial = @PLAN)
      AND   (@PERIODICIDAD IS NULL OR pr.pcp_periodicidad_cobro = @PERIODICIDAD)
      AND   (@SOLO_VIGENTES IS NULL OR @SOLO_VIGENTES = 0
             OR (pr.pcp_habilitado = 1
                 AND pr.pcp_vigencia_desde <= @HOY
                 AND (pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @HOY)))
    ORDER BY pc.pcb_orden, pr.pcp_vigencia_desde DESC

RETURN(0)
GO


/* ========================================================================
   6. PERMISO, PANTALLA DE DETALLE Y FUNCION
   ======================================================================== */

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_usuario_actualizacion, prm_fecha_actualizacion,
     prm_habilitado, prm_asignable_usuario)
SELECT  N'CREAR EDITAR PLANES COMERCIALES', N'Crear planes y fijar sus precios', N'COMERCIAL',
        (SELECT pam_id FROM [dbo].[Permiso_Ambito] WHERE pam_codigo = N'WEB'),
        NULL, 1, GETDATE(), 1, GETDATE(), 1, 0
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = N'CREAR EDITAR PLANES COMERCIALES')
GO

DECLARE @COM INT = (SELECT MIN(mnu_id) FROM [dbo].[Menus] WHERE mnu_nombre = N'Comercial' AND mnu_nivel = 2)

INSERT INTO [dbo].[Menus] (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link, mnu_visible, mnu_icon, mnu_permiso)
SELECT  N'Plan (detalle)', N'Ficha del plan y sus precios', 4, @COM, 99,
        N'~/View/Comercial/Suscripciones/Plan.aspx', 0, NULL,
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'VER PLANES COMERCIALES')
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                    WHERE LOWER(mnu_link) = N'~/view/comercial/suscripciones/plan.aspx' COLLATE DATABASE_DEFAULT)
GO

INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
SELECT  N'Crear y editar',
        (SELECT mnu_id FROM [dbo].[Menus]
          WHERE LOWER(mnu_link) = N'~/view/comercial/suscripciones/planes.aspx' COLLATE DATABASE_DEFAULT),
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'CREAR EDITAR PLANES COMERCIALES')
WHERE   EXISTS (SELECT 1 FROM [dbo].[Menus]
                 WHERE LOWER(mnu_link) = N'~/view/comercial/suscripciones/planes.aspx' COLLATE DATABASE_DEFAULT)
  AND   NOT EXISTS (
            SELECT 1 FROM [dbo].[Menu_Funcion] mf
            WHERE mf.mfu_menu = (SELECT mnu_id FROM [dbo].[Menus]
                                  WHERE LOWER(mnu_link) = N'~/view/comercial/suscripciones/planes.aspx' COLLATE DATABASE_DEFAULT)
              AND mf.mfu_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'CREAR EDITAR PLANES COMERCIALES'))
GO


/* ========================================================================
   7. QUIEN PUEDE

      Root, siempre. Gerente Comercial, porque definir la oferta es
      literalmente su trabajo.

      El Administrador del Cliente NO. Puede ver los planes -necesita saber
      que esta comprando- pero fijar el precio de lo que se le cobra no es
      una facultad que tenga sentido darle a quien paga.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  1, p.prm_id, 1
FROM    [dbo].[Permiso] p
WHERE   p.prm_habilitado = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = 1 AND pp.ppe_permiso = p.prm_id)
GO

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  pf.per_id, pm.prm_id, 1
FROM    [dbo].[Perfiles] pf
CROSS JOIN [dbo].[Permiso] pm
WHERE   pf.per_nombre = N'2. Gerente Comercial' COLLATE DATABASE_DEFAULT
  AND   pm.prm_codigo = N'CREAR EDITAR PLANES COMERCIALES' COLLATE DATABASE_DEFAULT
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = pf.per_id AND pp.ppe_permiso = pm.prm_id)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'SPs del mantenedor de planes' AS control, COUNT(*) AS valor, 5 AS esperado
FROM   sys.procedures
WHERE  name IN ('INS_PLAN_COMERCIAL','UPD_PLAN_COMERCIAL','UPS_PLAN_COMERCIAL_PRECIO',
                'DEL_PLAN_COMERCIAL_PRECIO','SEL_PLAN_COMERCIAL_PRECIO')
UNION ALL
SELECT 'permiso de edición', COUNT(*), 1
FROM   [dbo].[Permiso] WHERE prm_codigo = N'CREAR EDITAR PLANES COMERCIALES'
UNION ALL
SELECT 'pantalla Plan (detalle)', COUNT(*), 1
FROM   [dbo].[Menus] WHERE LOWER(mnu_link) = N'~/view/comercial/suscripciones/plan.aspx' COLLATE DATABASE_DEFAULT
UNION ALL
SELECT 'función Crear y editar en Planes', COUNT(*), 1
FROM   [dbo].[Menu_Funcion] mf
INNER JOIN [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
WHERE  LOWER(m.mnu_link) = N'~/view/comercial/suscripciones/planes.aspx' COLLATE DATABASE_DEFAULT
  AND  mf.mfu_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'CREAR EDITAR PLANES COMERCIALES')
GO

-- Los precios de todos los planes, con su estado.
EXEC [dbo].[SEL_PLAN_COMERCIAL_PRECIO]
GO
