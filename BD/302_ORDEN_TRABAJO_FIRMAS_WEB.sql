USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  27-09-2026
-- DESCRIPTION:     HU-118 · FIRMAS DE LA ORDEN EN LA WEB (T-5244, T-5245).
-- =============================================
-- Las firmas de aceptación, ejecución y validación ya existían para la app
-- (Orden_Trabajo_Validacion + API_INS/API_SEL_ORDEN_TRABAJO_VALIDACION). La
-- web ESCRIBE por el mismo API_INS —dos caminos de escritura darían dos
-- vocabularios, como ya pasó con ACEPTADA/APROBADO— y lee con este SEL, que
-- además devuelve el id del archivo de la firma para mostrarla con el visor
-- de siempre (el SEL de la API solo trae la ruta).
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SEL_ORDEN_TRABAJO_VALIDACION]
@CLIENTE INT,
@ORDEN   INT

AS
SET NOCOUNT ON

SELECT  v.otv_id                                AS ID,
        v.otv_validacion_tipo                   AS TIPO_ID,
        t.vat_codigo                            AS TIPO_CODIGO,
        t.vat_nombre                            AS TIPO_NOMBRE,
        v.otv_resultado                         AS RESULTADO,
        v.otv_fecha_utc                         AS FECHA_UTC,
        CAST(v.otv_fecha_utc AT TIME ZONE 'UTC' AT TIME ZONE 'Pacific SA Standard Time' AS DATETIME) AS FECHA,
        v.otv_observacion                       AS OBSERVACION,
        v.otv_archivo_firma                     AS ARCHIVO_FIRMA,
        LTRIM(RTRIM(u.usu_nombre + ' ' + ISNULL(u.usu_apellido_paterno, ''))) AS USUARIO_NOMBRE
FROM    [dbo].[Orden_Trabajo_Validacion] v
JOIN    [dbo].[Orden_Trabajo]            o ON o.otr_id = v.otv_orden_trabajo AND o.otr_cliente = @CLIENTE
JOIN    [dbo].[Validacion_Tipo]          t ON t.vat_id = v.otv_validacion_tipo
LEFT JOIN [dbo].[Usuario]                u ON u.usu_id = v.otv_usuario
WHERE   v.otv_orden_trabajo = @ORDEN
ORDER BY v.otv_fecha_utc DESC, v.otv_id DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_VALIDACION_TIPO]
AS
SET NOCOUNT ON
SELECT vat_id AS ID, vat_codigo AS CODIGO, vat_nombre AS NOMBRE
FROM   [dbo].[Validacion_Tipo]
WHERE  vat_habilitado = 1
ORDER BY vat_orden
GO

-- NOTA (27-09-2026): una primera versión registraba la firma en una ficha
-- modal (OrdenTrabajoFirma.aspx) y dio de alta su fila en Menus (mnu_id 2231,
-- oculta, permiso VALIDAR ORDEN TRABAJO). Se reemplazó por UN solo cuadro de
-- firma dentro de la pestaña Cierre de la orden, sin modal. La página se
-- eliminó; la fila queda oculta porque los menús no se borran.

PRINT '302_ORDEN_TRABAJO_FIRMAS_WEB aplicado.'
GO
