/* ============================================================================
   SIGMA — Bloque 125
   LA FICHA DEL PROVEEDOR
   ----------------------------------------------------------------------------

   QUE AGREGA

     `SEL_PROVEEDOR` devuelve las columnas de la tabla. La ficha necesita
     ademas SABER CON QUE ESTA COMPROMETIDO el proveedor: cuantas ordenes lo
     tienen asignado, en cuantas puso mano de obra, cuantos servicios presto y
     cuantos lotes de repuesto entrego.

   PARA QUE SIRVEN ESOS NUMEROS

     Para dos cosas concretas, no para decorar:

     1. La ficha puede decir "no se puede eliminar: tiene 1 servicio asociado"
        ANTES de que la persona apriete el boton y reciba el rechazo. Un boton
        que se ve disponible y falla siempre es peor que uno deshabilitado que
        explica por que.

     2. Deshabilitar un proveedor con trabajo asociado no es lo mismo que
        deshabilitar uno recien creado. El aviso cambia segun el caso.

   SE CUENTA, NO SE ADIVINA

     Las cuatro son las tablas que de verdad apuntan a `Proveedor` —salieron
     de sus llaves foraneas, no de suponer—. Si manana aparece una quinta, la
     ficha va a seguir diciendo que no hay dependencias cuando si las hay: por
     eso la lista esta escrita explicita y no con un COUNT generico.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.SEL_PROVEEDOR_FICHA') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PROVEEDOR_FICHA]
GO

CREATE PROCEDURE [dbo].[SEL_PROVEEDOR_FICHA]
    @ID         INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON

    SELECT  p.prv_id,
            p.prv_cliente,
            p.prv_rut,
            p.prv_razon_social,
            ISNULL(p.prv_nombre_fantasia, '')   AS prv_nombre_fantasia,
            ISNULL(p.prv_giro, '')              AS prv_giro,
            ISNULL(p.prv_contacto, '')          AS prv_contacto,
            ISNULL(p.prv_email, '')             AS prv_email,
            ISNULL(p.prv_telefono, '')          AS prv_telefono,
            ISNULL(p.prv_direccion, '')         AS prv_direccion,
            p.prv_es_contratista,
            p.prv_es_proveedor_repuesto,
            ISNULL(p.prv_observacion, '')       AS prv_observacion,
            p.prv_habilitado,

            p.prv_usuario_creacion,
            p.prv_fecha_creacion,
            p.prv_usuario_actualizacion,
            p.prv_fecha_actualizacion,
            ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
            ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE,

            /* ---- Con que esta comprometido ----
               Las cuatro tablas que apuntan a Proveedor. Salieron de las
               llaves foraneas, no de suponer cuales podrian ser. */
            SERVICIOS = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Servicio] s
                          WHERE s.ots_proveedor = p.prv_id),

            ASIGNACIONES = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Asignacion] a
                             WHERE a.ota_proveedor = p.prv_id),

            MANO_OBRA = (SELECT COUNT(*) FROM [dbo].[Orden_Trabajo_Mano_Obra] m
                          WHERE m.omo_proveedor = p.prv_id),

            LOTES = (SELECT COUNT(*) FROM [dbo].[Repuesto_Lote] l
                      WHERE l.rlo_proveedor = p.prv_id)

    FROM    [dbo].[Proveedor] p
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = p.prv_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = p.prv_usuario_actualizacion
    WHERE   p.prv_id = @ID
      AND   p.prv_cliente = @CLIENTE
GO

PRINT '--- SEL_PROVEEDOR_FICHA creado.'
GO

DECLARE @P INT
SELECT TOP 1 @P = prv_id FROM [dbo].[Proveedor] WHERE prv_cliente = 1 ORDER BY prv_id
EXEC [dbo].[SEL_PROVEEDOR_FICHA] @ID = @P, @CLIENTE = 1
GO

PRINT '125_PROVEEDOR_FICHA aplicado.'
GO
