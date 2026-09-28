USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  25-09-2026
-- DESCRIPTION:     REPUESTOS PLANIFICADOS DE UNA ACTIVIDAD (HU-082 #3).
-- =============================================
-- POR QUE ESTE BLOQUE EXISTE
--   El criterio 3 de HU-082 dice: "cuando asocio un repuesto con su cantidad
--   a la actividad, la orden generada incluye ese repuesto como cantidad
--   planificada". La segunda mitad YA ESTA: INS_ORDEN_TRABAJO_OCURRENCIA
--   (bloque 220) lee Plan_Actividad_Repuesto, suma por repuesto y escribe
--   Orden_Trabajo_Repuesto. La tabla tambien estaba, con su indice unico por
--   actividad + repuesto y sus tres FK.
--
--   Lo que no existia era la primera mitad: NINGUNA pantalla ni SP escribia
--   esa tabla, asi que la consulta del generador siempre leia cero filas. Un
--   camino de lectura sin camino de escritura es una promesa que nunca se
--   cumple, y ademas se ve bien en el codigo.
--
-- ES UNA LISTA, NO UNA ENTIDAD
--   La tabla no tiene pra_habilitado ni fecha de actualizacion: se agrega y
--   se quita. Por eso el DEL borra la fila de verdad -no hay historia que
--   proteger, y una baja logica sin columna donde anotarla es una columna
--   nueva para nada-. Cambiar la cantidad es quitar y volver a agregar, que
--   es como se comporta cualquier lista de materiales.
--
-- LA UNIDAD NO SE PIDE
--   Se toma la del repuesto. Dejar elegir otra unidad abre la puerta a
--   planificar "3" de algo que se compra en litros, y despues nadie sabe si
--   eran 3 litros o 3 bidones. Si algun dia hace falta convertir, la columna
--   esta y el SP se cambia sin migrar nada.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_PLAN_ACTIVIDAD_REPUESTO — lo que la actividad va a consumir
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_ACTIVIDAD_REPUESTO]
@ID          INT = NULL,
@CLIENTE     INT = NULL,
@ACTIVIDAD   INT = NULL,
@HITO        INT = NULL

AS
SET NOCOUNT ON

    SELECT  r.pra_id                                  AS PRA_ID,
            r.pra_plan_mantenimiento_actividad        AS PRA_PLAN_MANTENIMIENTO_ACTIVIDAD,
            r.pra_repuesto                            AS PRA_REPUESTO,
            r.pra_cantidad                            AS PRA_CANTIDAD,
            r.pra_unidad_medida                       AS PRA_UNIDAD_MEDIDA,
            r.pra_obligatorio                         AS PRA_OBLIGATORIO,
            ISNULL(r.pra_observacion, '')             AS PRA_OBSERVACION,
            r.pra_usuario_creacion                    AS PRA_USUARIO_CREACION,
            r.pra_fecha_creacion                      AS PRA_FECHA_CREACION,

            rep.rep_codigo                            AS REPUESTO_CODIGO,
            rep.rep_nombre                            AS REPUESTO_NOMBRE,
            ISNULL(rep.rep_fabricante, '')            AS REPUESTO_FABRICANTE,
            ISNULL(rep.rep_modelo, '')                AS REPUESTO_MODELO,
            ISNULL(ume.ume_simbolo, '')               AS UNIDAD_SIMBOLO,
            ISNULL(ume.ume_nombre, '')                AS UNIDAD_NOMBRE,

            a.paa_codigo                              AS ACTIVIDAD_CODIGO,
            a.paa_nombre                              AS ACTIVIDAD_NOMBRE,
            a.paa_plan_mantenimiento_hito             AS HITO_ID,
            pma.pma_cliente                           AS PLAN_CLIENTE,

            /* Lo que hay en bodega hoy, para que el planificador vea que esta
               planificando algo que no existe ANTES de que el tecnico llegue
               al pañol. Suma de saldos del cliente; NULL seria "no se sabe",
               y cero se sabe. */
            ISNULL(sal.existencia, 0)                 AS EXISTENCIA,

            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE

    FROM    [dbo].[Plan_Actividad_Repuesto] r
    INNER JOIN [dbo].[Plan_Mantenimiento_Actividad] a   ON a.paa_id = r.pra_plan_mantenimiento_actividad
    INNER JOIN [dbo].[Plan_Mantenimiento_Hito] pmh      ON pmh.pmh_id = a.paa_plan_mantenimiento_hito
    INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv   ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
    INNER JOIN [dbo].[Plan_Mantenimiento] pma           ON pma.pma_id = pmv.pmv_plan_mantenimiento
    INNER JOIN [dbo].[Repuesto] rep                     ON rep.rep_id = r.pra_repuesto
    LEFT  JOIN [dbo].[Unidad_Medida] ume                ON ume.ume_id = r.pra_unidad_medida
    LEFT  JOIN [dbo].[Usuario] uc                       ON uc.usu_id  = r.pra_usuario_creacion
    OUTER APPLY (SELECT SUM(s.isa_cantidad) AS existencia
                   FROM [dbo].[Inventario_Saldo] s
                  WHERE s.isa_repuesto = r.pra_repuesto
                    AND s.isa_cliente  = pma.pma_cliente) sal

    WHERE   (@ID IS NULL OR r.pra_id = @ID)
      AND   (@CLIENTE IS NULL OR pma.pma_cliente = @CLIENTE)
      AND   (@ACTIVIDAD IS NULL OR r.pra_plan_mantenimiento_actividad = @ACTIVIDAD)
      AND   (@HITO IS NULL OR a.paa_plan_mantenimiento_hito = @HITO)

    ORDER BY a.paa_orden, rep.rep_codigo
GO
PRINT '--- SEL_PLAN_ACTIVIDAD_REPUESTO creado.'
GO

-- ---------------------------------------------------------------------------
-- 2) INS_PLAN_ACTIVIDAD_REPUESTO
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_ACTIVIDAD_REPUESTO]
@ID           INT = NULL OUTPUT,
@CLIENTE      INT,
@ACTIVIDAD    INT,
@REPUESTO     INT,
@CANTIDAD     DECIMAL(18,4),
@OBLIGATORIO  BIT = 1,
@OBSERVACION  NVARCHAR(500) = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @ESTADO INT, @CLIENTE_ACTIVIDAD INT, @UNIDAD INT

BEGIN
    SELECT @ESTADO = pmv.pmv_plan_version_estado,
           @CLIENTE_ACTIVIDAD = pma.pma_cliente
    FROM   [dbo].[Plan_Mantenimiento_Actividad] a
    INNER JOIN [dbo].[Plan_Mantenimiento_Hito] pmh    ON pmh.pmh_id = a.paa_plan_mantenimiento_hito
    INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
    INNER JOIN [dbo].[Plan_Mantenimiento] pma         ON pma.pma_id = pmv.pmv_plan_mantenimiento
    WHERE  a.paa_id = @ACTIVIDAD

    IF @CLIENTE_ACTIVIDAD IS NULL
    BEGIN
        RAISERROR('1.- LA ACTIVIDAD NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE_ACTIVIDAD <> @CLIENTE
    BEGIN
        RAISERROR('2.- LA ACTIVIDAD NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* Una version publicada ya genero ordenes con estos repuestos
       planificados adentro. Agregar uno ahora haria que la orden de ayer y el
       plan de hoy no coincidan. */
    IF @ESTADO <> 1
    BEGIN
        RAISERROR('3.- LA VERSIÓN DE ESTA ACTIVIDAD YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA MODIFICARLA.', 16, 1)
        RETURN -1
    END

    SELECT @UNIDAD = rep_unidad_medida
      FROM [dbo].[Repuesto]
     WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE AND ISNULL(rep_habilitado, 1) = 1

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto]
                    WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE AND ISNULL(rep_habilitado, 1) = 1)
    BEGIN
        RAISERROR('4.- EL REPUESTO NO EXISTE, ESTÁ DESHABILITADO O NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@CANTIDAD IS NULL OR @CANTIDAD <= 0)
    BEGIN
        RAISERROR('5.- LA CANTIDAD PLANIFICADA DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    /* El indice UX_PRA_ACTIVIDAD_REPUESTO lo rechazaria igual, pero con el
       mensaje de SQL. Este dice que hacer. */
    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Actividad_Repuesto]
                WHERE pra_plan_mantenimiento_actividad = @ACTIVIDAD AND pra_repuesto = @REPUESTO)
    BEGIN
        RAISERROR('6.- ESTE REPUESTO YA ESTÁ PLANIFICADO EN LA ACTIVIDAD. QUÍTELO Y VUELVA A AGREGARLO SI NECESITA OTRA CANTIDAD.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
    SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

    INSERT INTO [dbo].[Plan_Actividad_Repuesto]
        (pra_plan_mantenimiento_actividad, pra_repuesto, pra_cantidad, pra_unidad_medida,
         pra_obligatorio, pra_observacion, pra_usuario_creacion, pra_fecha_creacion)
    VALUES
        (@ACTIVIDAD, @REPUESTO, @CANTIDAD, @UNIDAD,
         ISNULL(@OBLIGATORIO, 1), NULLIF(LTRIM(RTRIM(ISNULL(@OBSERVACION, ''))), ''), @USUARIO, @DATE_NOW)

    SET @ID = SCOPE_IDENTITY()

    IF (@ID IS NULL)
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_ACTIVIDAD_REPUESTO ' + LTRIM(STR(@ACTIVIDAD)) + ' / ' + LTRIM(STR(@REPUESTO))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '7.- NO FUE POSIBLE AGREGAR EL REPUESTO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
PRINT '--- INS_PLAN_ACTIVIDAD_REPUESTO creado.'
GO

-- ---------------------------------------------------------------------------
-- 3) DEL_PLAN_ACTIVIDAD_REPUESTO — baja fisica, ver la cabecera
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_ACTIVIDAD_REPUESTO]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @ESTADO INT

BEGIN
    SELECT @ESTADO = pmv.pmv_plan_version_estado
    FROM   [dbo].[Plan_Actividad_Repuesto] r
    INNER JOIN [dbo].[Plan_Mantenimiento_Actividad] a  ON a.paa_id = r.pra_plan_mantenimiento_actividad
    INNER JOIN [dbo].[Plan_Mantenimiento_Hito] pmh     ON pmh.pmh_id = a.paa_plan_mantenimiento_hito
    INNER JOIN [dbo].[Plan_Mantenimiento_Version] pmv  ON pmv.pmv_id = pmh.pmh_plan_mantenimiento_version
    WHERE  r.pra_id = @ID

    IF @ESTADO IS NULL
    BEGIN
        RAISERROR('1.- EL REPUESTO PLANIFICADO NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @ESTADO <> 1
    BEGIN
        RAISERROR('2.- LA VERSIÓN DE ESTA ACTIVIDAD YA NO ESTÁ EN BORRADOR. ABRA UNA VERSIÓN NUEVA PARA MODIFICARLA.', 16, 1)
        RETURN -1
    END
END

DELETE FROM [dbo].[Plan_Actividad_Repuesto] WHERE pra_id = @ID

RETURN(0)
GO
PRINT '--- DEL_PLAN_ACTIVIDAD_REPUESTO creado.'
GO

PRINT '291_PLAN_ACTIVIDAD_REPUESTO aplicado.'
GO
